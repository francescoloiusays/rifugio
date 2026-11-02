"""Rifugio - generatore dei modelli 3D low poly con texture dipinte.

Da Blender (crea anche il file .blend da ritoccare e le anteprime):
    /Applications/Blender.app/Contents/MacOS/Blender --background --python ~/Desktop/rifugio/blender/crea_modelli.py

Senza Blender (solo i .glb, basta Python 3 con numpy):
    python3 ~/Desktop/rifugio/blender/crea_modelli.py

Opzioni (dopo "--" se lanciato da Blender):
    --solo case,orto      genera solo questi edifici
    --senza-anteprime     salta i render (solo Blender)

Cosa produce:
    gioco/assets/modelli/<edificio>_l1.glb, _l2.glb, _l3.glb   un modello per livello
    gioco/assets/modelli/texture/*.png                        texture condivise
    blender/modelli.blend, blender/anteprime/*.png            solo da Blender
"""

import importlib
import os
import sys
import time


def _cartella_script():
    try:
        cartella = os.path.dirname(os.path.abspath(__file__))
        if os.path.isfile(os.path.join(cartella, "crea_modelli.py")):
            return cartella
    except NameError:
        pass
    return os.path.expanduser("~/Desktop/rifugio/blender")


CARTELLA_BLENDER = _cartella_script()
if CARTELLA_BLENDER not in sys.path:
    sys.path.insert(0, CARTELLA_BLENDER)

import rifugio_texture  # noqa: E402
import rifugio_geometria  # noqa: E402
import rifugio_modello  # noqa: E402
import rifugio_edifici  # noqa: E402
import rifugio_altri  # noqa: E402

# da Blender lo script si può rilanciare: ricarica i moduli modificati
for _m in (rifugio_texture, rifugio_geometria, rifugio_modello, rifugio_edifici, rifugio_altri):
    importlib.reload(_m)

RADICE = os.path.dirname(CARTELLA_BLENDER)
CARTELLA_MODELLI = os.path.join(RADICE, "gioco", "assets", "modelli")
CARTELLA_TEXTURE = os.path.join(CARTELLA_MODELLI, "texture")
CARTELLA_ANTEPRIME = os.path.join(CARTELLA_BLENDER, "anteprime")

try:
    import bpy  # noqa: F401
    IN_BLENDER = True
except ImportError:
    IN_BLENDER = False


def tutti_i_modelli(solo=None):
    """[(nome_file, funzione)] di tutti i modelli da generare."""
    elenco = []
    for nome, crea in rifugio_edifici.COSTRUTTORI.items():
        if solo and nome not in solo:
            continue
        for liv in (1, 2, 3):
            elenco.append(("%s_l%d" % (nome, liv), (lambda c, l: (lambda: c(l)))(crea, liv)))
    for nome, crea in rifugio_altri.COSTRUTTORI.items():
        if solo and nome not in solo:
            continue
        elenco.append((nome, crea))
    return elenco


def argomenti():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ([] if IN_BLENDER else sys.argv[1:])
    solo = None
    if "--solo" in args:
        solo = set(args[args.index("--solo") + 1].split(","))
    uscita = CARTELLA_MODELLI
    if "--uscita" in args:
        uscita = os.path.abspath(args[args.index("--uscita") + 1])
    return solo, uscita, "--senza-anteprime" in args


def main_python(solo, uscita):
    os.makedirs(uscita, exist_ok=True)
    scrittore = rifugio_geometria.ScrittoreGLB(os.path.join(uscita, "texture"))
    inizio = time.time()
    for nome, crea in tutti_i_modelli(solo):
        modello = crea()
        modello.nome = nome
        percorso = os.path.join(uscita, nome + ".glb")
        scrittore.scrivi(modello, percorso)
        triangoli = sum(len(f) - 2 for p in modello.parti for f in p.facce)
        print("%-24s %4d parti %6d triangoli  %5.0f KB" % (nome, len(modello.parti), triangoli,
                                                            os.path.getsize(percorso) / 1024))
    print("FATTO in %.1f s" % (time.time() - inizio))


if __name__ == "__main__":
    _solo, _uscita, _senza = argomenti()
    if IN_BLENDER:
        import rifugio_blender
        importlib.reload(rifugio_blender)
        rifugio_blender.main(tutti_i_modelli(_solo), _uscita, CARTELLA_BLENDER, CARTELLA_ANTEPRIME, not _senza)
    else:
        main_python(_solo, _uscita)
