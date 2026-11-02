"""Rifugio - costruisce i modelli dentro Blender, li esporta in .glb e fa le anteprime.

Usato da crea_modelli.py quando lo script gira in Blender. Ogni parte diventa
un oggetto (comodo da ritoccare a mano); ogni modello ha la sua collezione.
I segnaposti per il gioco (insegna, cima) sono oggetti vuoti.
"""

import math
import os
import time

import bpy

import rifugio_geometria as geo
import rifugio_texture as tex

LARGHEZZA_LOTTO = 6.4
_MATERIALI = {}
_IMMAGINI = {}


def pulisci_scena():
    for raccolta in (bpy.data.objects, bpy.data.meshes, bpy.data.materials, bpy.data.images,
                     bpy.data.lights, bpy.data.cameras, bpy.data.worlds):
        for elemento in list(raccolta):
            raccolta.remove(elemento)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)
    _MATERIALI.clear()
    _IMMAGINI.clear()


def _ingresso(nodo, nomi):
    for nome in nomi:
        presa = nodo.inputs.get(nome)
        if presa is not None:
            return presa
    return None


def _imposta(nodo, nomi, valore):
    presa = _ingresso(nodo, nomi)
    if presa is not None:
        presa.default_value = valore


def materiale_blender(m, cartella_texture):
    """Materiale di Blender equivalente a un geo.Materiale."""
    if m.chiave in _MATERIALI:
        return _MATERIALI[m.chiave]
    mat = bpy.data.materials.new(m.nome)
    if bpy.app.version < (5, 0, 0):
        mat.use_nodes = True
    mat.use_backface_culling = True
    colore = geo.lineare(m.colore) + [1.0]
    mat.diffuse_color = colore
    nodi = mat.node_tree.nodes
    bsdf = nodi.get("Principled BSDF")
    _imposta(bsdf, ["Base Color"], colore)
    _imposta(bsdf, ["Roughness"], m.ruvido)
    _imposta(bsdf, ["Metallic"], m.metallo)
    _imposta(bsdf, ["Specular IOR Level", "Specular"], 0.2)
    if m.motivo:
        percorso = tex.genera(m.motivo, m.colori_tex, cartella_texture)
        if percorso not in _IMMAGINI:
            _IMMAGINI[percorso] = bpy.data.images.load(percorso, check_existing=True)
        nodo = nodi.new("ShaderNodeTexImage")
        nodo.image = _IMMAGINI[percorso]
        nodo.location = (-400, 200)
        mat.node_tree.links.new(nodo.outputs["Color"], _ingresso(bsdf, ["Base Color"]))
    if m.luce > 0:
        _imposta(bsdf, ["Emission Color", "Emission"], colore)
        _imposta(bsdf, ["Emission Strength"], m.luce)
    if m.alfa < 1.0:
        _imposta(bsdf, ["Alpha"], m.alfa)
        for attributo, valore in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
            if hasattr(mat, attributo):
                try:
                    setattr(mat, attributo, valore)
                except Exception:
                    pass
    _MATERIALI[m.chiave] = mat
    return mat


def _imposta_lisce(mesh, lisce):
    try:
        mesh.polygons.foreach_set("use_smooth", lisce)
    except Exception:
        attributo = mesh.attributes.get("sharp_face") or mesh.attributes.new("sharp_face", "BOOLEAN", "FACE")
        attributo.data.foreach_set("value", [not s for s in lisce])


def oggetto_da_parte(parte, nome, collezione, cartella_texture):
    vertici = parte.v.tolist()
    facce = [list(f) for f in parte.facce]
    indici = [0] * len(facce)
    lisce = list(parte.lisce)
    uv = []
    for coppie in parte.uv:
        for u, v in coppie:
            uv += [float(u), 1.0 - float(v)]
    if parte.guscio is not None:
        gv, gf = parte.guscio
        n = len(vertici)
        vertici += gv.tolist()
        facce += [[i + n for i in f] for f in gf]
        indici += [1] * len(gf)
        lisce += [False] * len(gf)
        for f in gf:
            uv += [0.0, 0.0] * len(f)
    mesh = bpy.data.meshes.new(nome)
    mesh.from_pydata(vertici, [], facce)
    mesh.materials.append(materiale_blender(parte.materiale, cartella_texture))
    if parte.guscio is not None:
        mesh.materials.append(materiale_blender(geo.materiale_contorno(), cartella_texture))
    mesh.polygons.foreach_set("material_index", indici)
    _imposta_lisce(mesh, lisce)
    strato = mesh.uv_layers.new(name="UVMap")
    if len(strato.data) * 2 == len(uv):
        strato.data.foreach_set("uv", uv)
    mesh.update()
    ob = bpy.data.objects.new(nome, mesh)
    collezione.objects.link(ob)
    return ob


def costruisci(modello, cartella_texture):
    collezione = bpy.data.collections.new(modello.nome)
    bpy.context.scene.collection.children.link(collezione)
    from mathutils import Matrix
    perni = {}
    for nome, perno in getattr(modello, "gruppi", {}).items():
        # parti mobili (ante del cancello): un vuoto nel perno fa da genitore
        vuoto = bpy.data.objects.new(nome, None)
        vuoto.empty_display_type = "SPHERE"
        vuoto.empty_display_size = 0.2
        vuoto.location = perno
        collezione.objects.link(vuoto)
        perni[nome] = (vuoto, perno)
    for i, parte in enumerate(modello.parti):
        ob = oggetto_da_parte(parte, "%s_%s_%03d" % (modello.nome, parte.nome, i), collezione, cartella_texture)
        gruppo = getattr(parte, "gruppo", None)
        if gruppo in perni:
            vuoto, perno = perni[gruppo]
            ob.parent = vuoto
            ob.matrix_parent_inverse = Matrix.Translation(perno).inverted()
    for nome, pos, angolo in modello.segnaposti:
        vuoto = bpy.data.objects.new(nome, None)
        vuoto.empty_display_type = "PLAIN_AXES"
        vuoto.empty_display_size = 0.3
        vuoto.location = pos
        vuoto.rotation_euler = (0.0, 0.0, math.radians(angolo))
        collezione.objects.link(vuoto)
    return collezione


def esporta(collezione, percorso):
    livello = bpy.context.view_layer
    livello.update()
    for ob in bpy.data.objects:
        try:
            ob.select_set(False)
        except RuntimeError:
            pass
    parti = list(collezione.objects)
    for ob in parti:
        ob.select_set(True)
    # l'esportatore glTF vuole un oggetto attivo
    livello.objects.active = parti[0]
    bpy.ops.export_scene.gltf(filepath=percorso, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)


# ------------------------------------------------------------------ anteprime


def prepara_studio(scena):
    studio = bpy.data.collections.new("_studio")
    scena.collection.children.link(studio)
    suolo = bpy.data.meshes.new("suolo")
    suolo.from_pydata([(-80, -12, 0), (80, -12, 0), (80, 40, 0), (-80, 40, 0)], [], [(0, 1, 2, 3)])
    ob = bpy.data.objects.new("suolo", suolo)
    mat = bpy.data.materials.new("Suolo")
    mat.diffuse_color = geo.lineare("#a88a62") + [1.0]
    if bpy.app.version < (5, 0, 0):
        mat.use_nodes = True
    _imposta(mat.node_tree.nodes.get("Principled BSDF"), ["Base Color"], geo.lineare("#a88a62") + [1.0])
    suolo.materials.append(mat)
    studio.objects.link(ob)

    luce = bpy.data.lights.new("Sole", type="SUN")
    luce.energy = 3.2
    luce.color = geo.lineare("#ffd2a0")
    sole = bpy.data.objects.new("Sole", luce)
    sole.rotation_euler = (math.radians(52), 0, math.radians(-38))
    studio.objects.link(sole)

    mondo = bpy.data.worlds.new("Tramonto")
    if bpy.app.version < (5, 0, 0):
        mondo.use_nodes = True
    sfondo = mondo.node_tree.nodes.get("Background")
    if sfondo is not None:
        sfondo.inputs[0].default_value = geo.lineare("#c98a8a") + [1.0]
        sfondo.inputs[1].default_value = 0.9
    scena.world = mondo

    camera = bpy.data.cameras.new("Camera")
    camera.lens = 50
    cam = bpy.data.objects.new("Camera", camera)
    studio.objects.link(cam)
    scena.camera = cam
    for motore in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scena.render.engine = motore
            break
        except TypeError:
            continue
    try:
        scena.eevee.taa_render_samples = 32
    except Exception:
        pass
    try:
        scena.view_settings.view_transform = "Standard"
    except Exception:
        pass
    scena.render.resolution_x = 1600
    scena.render.resolution_y = 800
    scena.render.resolution_percentage = 100
    scena.render.image_settings.file_format = "PNG"
    return cam


def inquadra(cam, bersaglio, distanza, altezza):
    from mathutils import Vector
    cam.location = Vector((bersaglio[0], bersaglio[1] - distanza, altezza))
    direzione = Vector(bersaglio) - cam.location
    cam.rotation_euler = direzione.to_track_quat("-Z", "Y").to_euler()


def renderizza(scena, percorso):
    scena.render.filepath = percorso
    bpy.ops.render.render(write_still=True)


def anteprime(collezioni, cartella):
    """Un render per edificio con i tre livelli affiancati, uno per gli altri modelli."""
    os.makedirs(cartella, exist_ok=True)
    scena = bpy.context.scene
    cam = prepara_studio(scena)
    gruppi = {}
    for nome, collezione in collezioni.items():
        base = nome.rsplit("_l", 1)[0] if nome[-3:-1] == "_l" else nome
        gruppi.setdefault(base, []).append(collezione)
    for base, membri in gruppi.items():
        for c in collezioni.values():
            c.hide_render = c not in membri
        spostati = []
        for k, c in enumerate(membri):
            dx = (k - (len(membri) - 1) / 2) * LARGHEZZA_LOTTO
            for ob in c.objects:
                ob.location[0] += dx
                spostati.append((ob, dx))
        if base == "mura":
            inquadra(cam, (-2.5, 0, 2.6), 30.0, 7.0)
        else:
            inquadra(cam, (0, 0, 3.0), 13.0 + 7.0 * len(membri), 7.5)
        renderizza(scena, os.path.join(cartella, base + ".png"))
        for ob, dx in spostati:
            ob.location[0] -= dx
    for c in collezioni.values():
        c.hide_render = False


def main(elenco, uscita, cartella_blender, cartella_anteprime, con_anteprime=True):
    inizio = time.time()
    os.makedirs(uscita, exist_ok=True)
    cartella_texture = os.path.join(uscita, "texture")
    pulisci_scena()
    collezioni = {}
    rapporto = ["Blender %s" % bpy.app.version_string]
    for nome, crea in elenco:
        modello = crea()
        modello.nome = nome
        collezione = costruisci(modello, cartella_texture)
        percorso = os.path.join(uscita, nome + ".glb")
        esporta(collezione, percorso)
        collezioni[nome] = collezione
        riga = "%-24s %4d parti -> %s" % (nome, len(modello.parti), percorso)
        rapporto.append(riga)
        print(riga)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(cartella_blender, "modelli.blend"))
    if con_anteprime:
        anteprime(collezioni, cartella_anteprime)
    rapporto.append("Completato in %.0f s" % (time.time() - inizio))
    os.makedirs(cartella_anteprime, exist_ok=True)
    with open(os.path.join(cartella_anteprime, "rapporto.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(rapporto) + "\n")
    print("FATTO in %.0f s" % (time.time() - inizio))
