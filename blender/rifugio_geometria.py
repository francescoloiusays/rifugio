"""Rifugio - geometria low poly, materiali ed esportazione.

Le forme sono costruite qui in Python puro (numpy), così lo stesso modello
esce identico sia da Blender sia dall'esportatore glTF interno.

Convenzioni (come in Blender): Z in alto, facciata verso -Y, misure in metri.
Ogni parte è convessa e ha:
  - smusso: spigoli tagliati a 45° (look low poly che prende la luce),
  - contorno: guscio rovesciato scuro (effetto fumetto),
  - texture: motivo dipinto proiettato sulle facce in metri reali.
"""

import json
import math
import os
import struct

import numpy as np

import rifugio_texture as tex

CONTORNO = 0.028
COLORE_CONTORNO = "#24181a"


def lineare(esadecimale):
    c = tex.rgb(esadecimale)
    return [float(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c]


# ------------------------------------------------------------------ materiali


class Materiale:
    """colore: '#rrggbb' oppure ('motivo', colore1, colore2...) per una texture."""

    def __init__(self, colore, ruvido=0.85, metallo=0.0, luce=0.0, alfa=1.0, ombra=True):
        if isinstance(colore, (tuple, list)):
            self.motivo = colore[0]
            self.colori_tex = tuple(colore[1:])
            self.colore = self.colori_tex[0]
        else:
            self.motivo = None
            self.colori_tex = ()
            self.colore = colore
        self.ruvido = ruvido
        self.metallo = metallo
        self.luce = luce
        self.alfa = alfa
        self.unlit = False

    @property
    def chiave(self):
        return (self.motivo, self.colori_tex, self.colore, round(self.ruvido, 2), round(self.metallo, 2),
                round(self.luce, 2), round(self.alfa, 2), self.unlit)

    @property
    def nome(self):
        if self.unlit:
            return "contorno"
        base = (self.motivo + "_" + "_".join(c.lstrip("#") for c in self.colori_tex)) if self.motivo \
            else "tinta_" + self.colore.lstrip("#")
        if self.luce > 0:
            base += "_luce"
        if self.alfa < 1:
            base += "_vetro"
        if self.metallo > 0:
            base += "_met"
        return base

    @property
    def ripetizione(self):
        return tex.RIPETIZIONE.get(self.motivo, 1.0) if self.motivo else 1.0


def materiale_contorno():
    m = Materiale(COLORE_CONTORNO, ruvido=1.0)
    m.unlit = True
    return m


# ------------------------------------------------------------------ forme di base


def _orienta(v, facce):
    """Gira le facce in modo che le normali puntino fuori (forme convesse)."""
    centro = v.mean(axis=0)
    risultato = []
    for f in facce:
        p = v[list(f)]
        n = _normale_poligono(p)
        if np.dot(n, p.mean(axis=0) - centro) < 0:
            f = tuple(reversed(f))
        risultato.append(tuple(f))
    return risultato


def _normale_poligono(p):
    n = np.zeros(3)
    for i in range(len(p)):
        a, b = p[i], p[(i + 1) % len(p)]
        n[0] += (a[1] - b[1]) * (a[2] + b[2])
        n[1] += (a[2] - b[2]) * (a[0] + b[0])
        n[2] += (a[0] - b[0]) * (a[1] + b[1])
    lung = np.linalg.norm(n)
    return n / lung if lung > 1e-12 else np.array([0.0, 0.0, 1.0])


class Forma:
    def __init__(self, v, facce, lisce=None, uv=None):
        self.v = np.asarray(v, dtype=float)
        self.facce = _orienta(self.v, facce)
        self.lisce = lisce if lisce is not None else [False] * len(self.facce)
        self.uv = uv  # funzione (indice faccia, punto locale, normale locale) -> (u, v) in metri, opzionale


def forma_scatola(dx, dy, dz, smusso):
    hx, hy, hz = dx / 2, dy / 2, dz / 2
    c = min(smusso, dx * 0.3, dy * 0.3, dz * 0.3)
    if c < 0.004:
        v = [(sx * hx, sy * hy, sz * hz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
        idx = lambda sx, sy, sz: ((sx > 0) * 4 + (sy > 0) * 2 + (sz > 0))
        facce = []
        for asse in range(3):
            for s in (-1, 1):
                angoli = []
                for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                    k = [0, 0, 0]
                    k[asse] = s
                    altri = [i for i in range(3) if i != asse]
                    k[altri[0]], k[altri[1]] = a, b
                    angoli.append(idx(*k))
                facce.append(tuple(angoli))
        return Forma(v, facce)
    v = []
    indice = {}
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                for asse in range(3):
                    p = [sx * (hx - c), sy * (hy - c), sz * (hz - c)]
                    p[asse] = (sx, sy, sz)[asse] * (hx, hy, hz)[asse]
                    indice[(sx, sy, sz, asse)] = len(v)
                    v.append(tuple(p))
    facce = []
    # facce principali
    for asse in range(3):
        altri = [i for i in range(3) if i != asse]
        for s in (-1, 1):
            angoli = []
            for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                k = [0, 0, 0]
                k[asse] = s
                k[altri[0]], k[altri[1]] = a, b
                angoli.append(indice[(k[0], k[1], k[2], asse)])
            facce.append(tuple(angoli))
    # smussi sugli spigoli
    for asse in range(3):
        b, c2 = [i for i in range(3) if i != asse]
        for sb in (-1, 1):
            for sc in (-1, 1):
                q = []
                for sa, quale in ((-1, b), (1, b), (1, c2), (-1, c2)):
                    k = [0, 0, 0]
                    k[asse], k[b], k[c2] = sa, sb, sc
                    q.append(indice[(k[0], k[1], k[2], quale)])
                facce.append(tuple(q))
    # triangoli sugli angoli
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                facce.append(tuple(indice[(sx, sy, sz, a)] for a in range(3)))
    return Forma(v, facce)


def forma_cilindro(r1, r2, h, n, liscio):
    v = []
    for z, r in ((-h / 2, r1), (h / 2, r2)):
        for i in range(n):
            a = 2 * math.pi * (i + 0.5) / n
            v.append((r * math.cos(a), r * math.sin(a), z))
    facce = []
    lisce = []
    for i in range(n):
        j = (i + 1) % n
        facce.append((i, j, n + j, n + i))
        lisce.append(liscio)
    tetto = r2 > 1e-4
    base = r1 > 1e-4
    if base:
        facce.append(tuple(range(n)))
        lisce.append(False)
    if tetto:
        facce.append(tuple(range(n, 2 * n)))
        lisce.append(False)
    if not tetto:
        # cono: le facce in cima convergono su un vertice
        v = v[:n] + [(0, 0, h / 2)]
        facce = [(i, (i + 1) % n, n) for i in range(n)] + ([tuple(range(n))] if base else [])
        lisce = [liscio] * n + ([False] if base else [])
    circonferenza = math.pi * (r1 + r2)
    forma = Forma(v, facce, lisce)
    forma.uv = _uv_cilindro_senza_cucitura(forma, circonferenza, n)
    return forma


def _uv_cilindro_senza_cucitura(forma, circonferenza, n):
    """UV cilindriche: la faccia che attraversa l'angolo 0 non si stira."""
    def uv(indice_faccia, punti, normale):
        if abs(normale[2]) > 0.95:
            return [(p[0], -p[1]) for p in punti]
        angoli = [math.atan2(p[1], p[0]) % (2 * math.pi) for p in punti]
        if max(angoli) - min(angoli) > math.pi:
            angoli = [a + 2 * math.pi if a < math.pi else a for a in angoli]
        return [(a / (2 * math.pi) * circonferenza, -p[2]) for a, p in zip(angoli, punti)]
    return uv


def forma_sfera(raggio, suddivisioni, liscio):
    t = (1 + 5 ** 0.5) / 2
    v = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t),
         (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    v = [np.array(p, float) / np.linalg.norm(p) for p in v]
    f = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6),
         (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10),
         (8, 6, 7), (9, 8, 1)]
    for _ in range(suddivisioni):
        cache = {}

        def medio(a, b):
            k = (min(a, b), max(a, b))
            if k not in cache:
                p = (v[a] + v[b]) / 2
                v.append(p / np.linalg.norm(p))
                cache[k] = len(v) - 1
            return cache[k]

        nuove = []
        for a, b, c in f:
            ab, bc, ca = medio(a, b), medio(b, c), medio(c, a)
            nuove += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        f = nuove
    return Forma([p * raggio for p in v], f, [liscio] * len(f))


def forma_prisma(larghezza, profondita, altezza):
    """Timpano con la base a z=0: colmo lungo X."""
    x, y = larghezza / 2, profondita / 2
    v = [(-x, -y, 0), (x, -y, 0), (x, y, 0), (-x, y, 0), (-x, 0, altezza), (x, 0, altezza)]
    f = [(0, 1, 2, 3), (0, 1, 5, 4), (2, 3, 4, 5), (0, 4, 3), (1, 2, 5)]
    return Forma(v, f)


def forma_profilo(punti, profondita, liscio=False):
    """Profilo convesso nel piano XZ estruso lungo Y (centrato)."""
    n = len(punti)
    y = profondita / 2
    v = [(px, -y, pz) for px, pz in punti] + [(px, y, pz) for px, pz in punti]
    f = [tuple(range(n)), tuple(range(n, 2 * n))]
    lisce = [False, False]
    for i in range(n):
        j = (i + 1) % n
        f.append((i, j, n + j, n + i))
        lisce.append(liscio)
    return Forma(v, f, lisce)


def forma_tronco(base, cima, altezza):
    """Tronco di piramide: base (dx, dy) a z=0, cima (dx, dy) a z=altezza."""
    bx, by = base[0] / 2, base[1] / 2
    cx, cy = cima[0] / 2, cima[1] / 2
    v = [(-bx, -by, 0), (bx, -by, 0), (bx, by, 0), (-bx, by, 0),
         (-cx, -cy, altezza), (cx, -cy, altezza), (cx, cy, altezza), (-cx, cy, altezza)]
    f = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    if cx < 1e-4 and cy < 1e-4:
        v = v[:4] + [(0, 0, altezza)]
        f = [(0, 1, 2, 3), (0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)]
    return Forma(v, f)


# ------------------------------------------------------------------ trasformazioni


def matrice_rotazione(rot):
    if isinstance(rot, np.ndarray):
        return rot
    ax, ay, az = (math.radians(a) for a in rot)
    rx = np.array([[1, 0, 0], [0, math.cos(ax), -math.sin(ax)], [0, math.sin(ax), math.cos(ax)]])
    ry = np.array([[math.cos(ay), 0, math.sin(ay)], [0, 1, 0], [-math.sin(ay), 0, math.cos(ay)]])
    rz = np.array([[math.cos(az), -math.sin(az), 0], [math.sin(az), math.cos(az), 0], [0, 0, 1]])
    return rz @ ry @ rx


def matrice_da_direzione(d):
    """Rotazione che porta l'asse Z sulla direzione d."""
    z = np.asarray(d, float)
    z = z / np.linalg.norm(z)
    aiuto = np.array([0, 0, 1.0]) if abs(z[2]) < 0.9 else np.array([1.0, 0, 0])
    x = np.cross(aiuto, z)
    x /= np.linalg.norm(x)
    y = np.cross(z, x)
    return np.column_stack([x, y, z])


# ------------------------------------------------------------------ parte pronta


class Parte:
    """Forma posizionata nel modello, con normali, UV e contorno calcolati."""

    def __init__(self, nome, forma, materiale, pos, rot, contorno, scala_uv=1.0, uv_ruota=False):
        r = matrice_rotazione(rot)
        locali = forma.v
        self.nome = nome
        self.materiale = materiale
        self.v = locali @ r.T + np.asarray(pos, float)
        self.facce = forma.facce
        self.lisce = forma.lisce
        normali_locali = [_normale_poligono(locali[list(f)]) for f in self.facce]
        self.normali = [r @ n for n in normali_locali]
        # UV in metri divise per la ripetizione della texture
        rip = materiale.ripetizione * scala_uv
        self.uv = []
        for i, f in enumerate(self.facce):
            punti = locali[list(f)]
            n = normali_locali[i]
            if forma.uv is not None:
                coppie = forma.uv(i, punti, n)
            else:
                coppie = [_proietta(p, n) for p in punti]
            if uv_ruota:
                coppie = [(-b, a) for a, b in coppie]
            self.uv.append([(a / rip, b / rip) for a, b in coppie])
        self.normali_vertici = self._normali_lisce()
        self.guscio = self._guscio(contorno) if contorno > 0 else None

    def _normali_lisce(self):
        somma = np.zeros_like(self.v)
        for f, n, liscia in zip(self.facce, self.normali, self.lisce):
            if liscia:
                for i in f:
                    somma[i] += n
        lung = np.linalg.norm(somma, axis=1)
        lung[lung < 1e-9] = 1
        return somma / lung[:, None]

    def _guscio(self, spessore):
        vicine = [[] for _ in range(len(self.v))]
        for f, n in zip(self.facce, self.normali):
            for i in f:
                vicine[i].append(n)
        nuovi = np.zeros_like(self.v)
        for i, normali in enumerate(vicine):
            if not normali:
                nuovi[i] = self.v[i]
                continue
            # normali distinte (le facce piatte affiancate contano una volta)
            uniche = []
            for n in normali:
                if all(np.dot(n, u) < 0.999 for u in uniche):
                    uniche.append(n)
            media = np.sum(uniche, axis=0)
            lung = np.linalg.norm(media)
            if lung < 1e-9:
                nuovi[i] = self.v[i]
                continue
            media /= lung
            minimo = min(np.dot(media, n) for n in uniche)
            fattore = 1.0 / max(minimo, 0.4)
            nuovi[i] = self.v[i] + media * spessore * fattore
        facce = [tuple(reversed(f)) for f in self.facce]
        return nuovi, facce


def _proietta(p, n):
    ax = int(np.argmax(np.abs(n)))
    if ax == 1:
        return (p[0] if n[1] < 0 else -p[0]), -p[2]
    if ax == 0:
        return (p[1] if n[0] > 0 else -p[1]), -p[2]
    return p[0], -p[1]


# ------------------------------------------------------------------ esportazione glTF interna


def _triangoli(parte):
    """Restituisce [(posizione, normale, uv)] a gruppi di tre per il materiale della parte."""
    vertici = []
    for i, f in enumerate(parte.facce):
        liscia = parte.lisce[i]
        angoli = []
        for k, vi in enumerate(f):
            n = parte.normali_vertici[vi] if liscia else parte.normali[i]
            angoli.append((parte.v[vi], n, parte.uv[i][k]))
        for k in range(1, len(angoli) - 1):
            vertici += [angoli[0], angoli[k], angoli[k + 1]]
    return vertici


def _triangoli_guscio(parte):
    v, facce = parte.guscio
    vertici = []
    for f in facce:
        p = [v[i] for i in f]
        n = _normale_poligono(np.array(p))
        for k in range(1, len(p) - 1):
            vertici += [(p[0], n, (0, 0)), (p[k], n, (0, 0)), (p[k + 1], n, (0, 0))]
    return vertici


def _a_gltf(p):
    return (float(p[0]), float(p[2]), float(-p[1]))


class ScrittoreGLB:
    def __init__(self, cartella_texture, uri_texture="texture/", incorpora=False):
        self.cartella_texture = cartella_texture
        self.uri_texture = uri_texture
        self.incorpora = incorpora

    def scrivi(self, modello, percorso):
        # Ogni gruppo (per esempio un'anta del cancello) diventa un nodo a sé,
        # con l'origine nel suo perno, così il gioco lo può ruotare.
        perni = getattr(modello, "gruppi", {})
        per_gruppo = {}
        materiali = {}
        for parte in modello.parti:
            nome_gruppo = getattr(parte, "gruppo", None)
            perno = np.asarray(perni.get(nome_gruppo, (0.0, 0.0, 0.0)), float)
            gruppi = per_gruppo.setdefault(nome_gruppo, {})
            m = parte.materiale
            gruppi.setdefault(m.chiave, []).extend((p - perno, n, uv) for p, n, uv in _triangoli(parte))
            materiali[m.chiave] = m
            if parte.guscio is not None:
                mc = materiale_contorno()
                gruppi.setdefault(mc.chiave, []).extend((p - perno, n, uv) for p, n, uv in _triangoli_guscio(parte))
                materiali[mc.chiave] = mc
        indice_mat = {}

        binario = bytearray()
        viste, accessori, mats, immagini, textures = [], [], [], [], []
        indice_img = {}

        def aggiungi_vista(dati, bersaglio=None):
            while len(binario) % 4:
                binario.append(0)
            vista = {"buffer": 0, "byteOffset": len(binario), "byteLength": len(dati)}
            if bersaglio:
                vista["target"] = bersaglio
            binario.extend(dati)
            viste.append(vista)
            return len(viste) - 1

        meshes = []
        ordine_gruppi = [None] + [g for g in per_gruppo if g is not None]
        for nome_gruppo in ordine_gruppi:
          primitive = []
          for chiave, vertici in per_gruppo.get(nome_gruppo, {}).items():
            m = materiali[chiave]
            mappa = {}
            pos, nor, uvs, ind = [], [], [], []
            for p, n, uv in vertici:
                gp, gn = _a_gltf(p), _a_gltf(n)
                k = (round(gp[0], 4), round(gp[1], 4), round(gp[2], 4), round(gn[0], 3), round(gn[1], 3),
                     round(gn[2], 3), round(float(uv[0]), 4), round(float(uv[1]), 4))
                if k not in mappa:
                    mappa[k] = len(pos)
                    pos.append(gp)
                    nor.append(gn)
                    uvs.append((float(uv[0]), float(uv[1])))
                ind.append(mappa[k])
            ap = np.array(pos, np.float32)
            an = np.array(nor, np.float32)
            an /= np.maximum(np.linalg.norm(an, axis=1), 1e-9)[:, None]
            au = np.array(uvs, np.float32)
            grande = len(pos) > 65535
            ai = np.array(ind, np.uint32 if grande else np.uint16)
            attr = {}
            for nome, arr, tipo in (("POSITION", ap, "VEC3"), ("NORMAL", an, "VEC3"), ("TEXCOORD_0", au, "VEC2")):
                acc = {"bufferView": aggiungi_vista(arr.tobytes(), 34962), "componentType": 5126,
                       "count": len(arr), "type": tipo}
                if nome == "POSITION":
                    acc["min"] = ap.min(axis=0).tolist()
                    acc["max"] = ap.max(axis=0).tolist()
                accessori.append(acc)
                attr[nome] = len(accessori) - 1
            accessori.append({"bufferView": aggiungi_vista(ai.tobytes(), 34963),
                              "componentType": 5125 if grande else 5123, "count": len(ai), "type": "SCALAR"})
            if chiave not in indice_mat:
                indice_mat[chiave] = len(mats)
                mats.append(self._materiale(m, immagini, textures, indice_img, aggiungi_vista))
            primitive.append({"attributes": attr, "indices": len(accessori) - 1, "material": indice_mat[chiave]})

          meshes.append({"name": nome_gruppo or modello.nome, "primitives": primitive})

        figli = len(modello.segnaposti) + len(meshes) - 1
        nodi = [{"name": modello.nome, "mesh": 0, "children": list(range(1, 1 + figli))}]
        for nome, pos, angolo in modello.segnaposti:
            q = (0.0, math.sin(math.radians(angolo) / 2), 0.0, math.cos(math.radians(angolo) / 2))
            nodi.append({"name": nome, "translation": list(_a_gltf(pos)), "rotation": list(q)})
        for k, nome_gruppo in enumerate(ordine_gruppi[1:], start=1):
            nodi.append({"name": nome_gruppo, "mesh": k, "translation": list(_a_gltf(perni[nome_gruppo]))})
        doc = {
            "asset": {"version": "2.0", "generator": "Rifugio crea_modelli"},
            "scene": 0,
            "scenes": [{"nodes": [0]}],
            "nodes": nodi,
            "meshes": meshes,
            "materials": mats,
            "accessors": accessori,
            "bufferViews": viste,
            "buffers": [{"byteLength": len(binario)}],
            "extensionsUsed": ["KHR_materials_unlit", "KHR_materials_emissive_strength"],
        }
        if textures:
            doc["textures"] = textures
            doc["images"] = immagini
            doc["samplers"] = [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}]
        js = json.dumps(doc, separators=(",", ":")).encode()
        while len(js) % 4:
            js += b" "
        while len(binario) % 4:
            binario.append(0)
        totale = 12 + 8 + len(js) + 8 + len(binario)
        with open(percorso, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, totale))
            f.write(struct.pack("<II", len(js), 0x4E4F534A))
            f.write(js)
            f.write(struct.pack("<II", len(binario), 0x004E4942))
            f.write(bytes(binario))

    def _materiale(self, m, immagini, textures, indice_img, aggiungi_vista):
        pbr = {"metallicFactor": m.metallo, "roughnessFactor": m.ruvido}
        if m.motivo:
            percorso = tex.genera(m.motivo, m.colori_tex, self.cartella_texture)
            nome = os.path.basename(percorso)
            if nome not in indice_img:
                if self.incorpora:
                    with open(percorso, "rb") as f:
                        immagini.append({"bufferView": aggiungi_vista(f.read()), "mimeType": "image/png", "name": nome})
                else:
                    immagini.append({"uri": self.uri_texture + nome, "name": nome})
                textures.append({"source": len(immagini) - 1, "sampler": 0})
                indice_img[nome] = len(textures) - 1
            pbr["baseColorTexture"] = {"index": indice_img[nome]}
            pbr["baseColorFactor"] = [1, 1, 1, m.alfa]
        else:
            pbr["baseColorFactor"] = lineare(m.colore) + [m.alfa]
        mat = {"name": m.nome, "pbrMetallicRoughness": pbr}
        if m.unlit:
            mat["extensions"] = {"KHR_materials_unlit": {}}
            mat["pbrMetallicRoughness"] = {"baseColorFactor": lineare(m.colore) + [1.0], "metallicFactor": 0,
                                           "roughnessFactor": 1}
        if m.luce > 0:
            mat["emissiveFactor"] = lineare(m.colore)
            if m.luce > 1:
                mat.setdefault("extensions", {})["KHR_materials_emissive_strength"] = {"emissiveStrength": m.luce}
        if m.alfa < 1:
            mat["alphaMode"] = "BLEND"
        return mat
