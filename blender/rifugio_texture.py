"""Rifugio - texture procedurali dipinte (solo numpy, funziona anche dentro Blender).

Ogni texture è un quadrato ripetibile senza cuciture. Il nome del file dice
motivo e colori, per esempio ``mattoni_c9644f_e2cda0.png``. La dimensione reale
di un quadrato (in metri) è in ``RIPETIZIONE``: serve alle coordinate UV.
"""

import os
import struct
import zlib

import numpy as np

DIM = 256

# metri coperti da un quadrato di texture
RIPETIZIONE = {
    "mattoni": 1.6,
    "intonaco": 3.0,
    "assi": 1.8,
    "tavole": 2.0,
    "lamiera": 2.0,
    "tegole": 1.6,
    "cemento": 3.2,
    "piastrelle": 1.2,
    "erba": 2.5,
    "terra": 2.0,
    "ghiaia": 1.5,
    "righe": 1.6,
    "metallo": 2.0,
    "legno": 1.2,
    "pietra": 2.2,
    "tela": 1.0,
    "lastre": 2.0,
}


# ------------------------------------------------------------------ utilità


def rgb(esadecimale):
    h = esadecimale.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def _rng(seme):
    return np.random.default_rng(seme)


def rumore(cx, cy=None, seme=0, dim=DIM):
    """Rumore a valori ripetibile: griglia cy x cx interpolata morbida. 0..1"""
    cy = cx if cy is None else cy
    g = _rng(seme).random((cy, cx))
    tx = np.arange(dim) / dim * cx
    ty = np.arange(dim) / dim * cy
    ix0 = np.floor(tx).astype(int)
    iy0 = np.floor(ty).astype(int)
    fx = tx - ix0
    fy = ty - iy0
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    ix1 = (ix0 + 1) % cx
    iy1 = (iy0 + 1) % cy
    r0 = g[iy0]
    r1 = g[iy1]
    alto = r0[:, ix0] * (1 - fx)[None, :] + r0[:, ix1] * fx[None, :]
    basso = r1[:, ix0] * (1 - fx)[None, :] + r1[:, ix1] * fx[None, :]
    return alto * (1 - fy)[:, None] + basso * fy[:, None]


def fbm(seme=0, base=4, ottave=4, dim=DIM, anisotropia=(1, 1)):
    tot = np.zeros((dim, dim))
    peso = 0.0
    a = 1.0
    c = base
    for i in range(ottave):
        tot += a * rumore(max(1, int(c * anisotropia[0])), max(1, int(c * anisotropia[1])), seme + i * 31, dim)
        peso += a
        a *= 0.5
        c *= 2
    return tot / peso


def granello(seme, forza=0.06, dim=DIM):
    return 1.0 + (_rng(seme).random((dim, dim)) - 0.5) * 2 * forza


def _colora(valori, colore):
    return valori[:, :, None] * colore[None, None, :]


def _mescola(a, b, t):
    t = np.clip(t, 0, 1)
    if t.ndim == 2:
        t = t[:, :, None]
    return a * (1 - t) + b * t


def voronoi(punti, seme, dim=DIM):
    """Distanze dal punto più vicino e dal secondo (ripetibili) e indice del più vicino."""
    p = _rng(seme).random((punti, 2)) * dim
    y, x = np.mgrid[0:dim, 0:dim].astype(float)
    d1 = np.full((dim, dim), 1e9)
    d2 = np.full((dim, dim), 1e9)
    idx = np.zeros((dim, dim), dtype=int)
    for i, (px, py) in enumerate(p):
        dx = np.abs(x - px)
        dx = np.minimum(dx, dim - dx)
        dy = np.abs(y - py)
        dy = np.minimum(dy, dim - dy)
        d = np.sqrt(dx * dx + dy * dy)
        nuovo = d < d1
        d2 = np.where(nuovo, d1, np.minimum(d2, d))
        idx = np.where(nuovo, i, idx)
        d1 = np.where(nuovo, d, d1)
    return d1, d2, idx


# ------------------------------------------------------------------ motivi
# Ogni motivo restituisce un'immagine float (DIM, DIM, 3) in sRGB 0..1.
# La riga 0 è il lato alto (verso il cielo sui muri).


def mattoni(colore, malta="#d9c9a8", seme=1):
    c = rgb(colore)
    m = rgb(malta)
    file, per_fila = 8, 4
    y, x = np.mgrid[0:DIM, 0:DIM]
    fh = DIM // file
    bw = DIM // per_fila
    fila = y // fh
    xb = (x + (fila % 2) * (bw // 2)) % DIM
    col = xb // bw
    r = _rng(seme)
    tinta = 0.82 + 0.3 * r.random((file, per_fila))
    sfum = r.random((file, per_fila, 3)) * 0.08 - 0.04
    lx = xb % bw
    ly = y % fh
    spess = 3
    giunto = (ly < spess) | (lx < spess)
    base = c[None, None, :] * tinta[fila, col][:, :, None] + sfum[fila, col]
    base *= (0.86 + 0.24 * fbm(seme + 5, 8))[:, :, None]
    base *= granello(seme + 7, 0.05)[:, :, None]
    # luce sul bordo alto, ombra sotto
    base *= np.where((ly >= spess) & (ly < spess + 2), 1.12, 1.0)[:, :, None]
    base *= np.where(ly > fh - 3, 0.82, 1.0)[:, :, None]
    # mattoni scheggiati qua e là
    scheggia = fbm(seme + 9, 6) > 0.68
    base = np.where(scheggia[:, :, None], base * 0.9 + m * 0.1, base)
    malta_img = m[None, None, :] * (0.8 + 0.2 * fbm(seme + 11, 16))[:, :, None]
    return np.where(giunto[:, :, None], malta_img * 0.85, base)


def intonaco(colore, seme=2, sporco=0.22):
    c = rgb(colore)
    v = 0.92 + 0.12 * fbm(seme, 3)
    v *= granello(seme + 1, 0.035)
    img = _colora(v, c)
    # macchie di umidità e intonaco scrostato
    macchie = fbm(seme + 3, 4, 5)
    img = _mescola(img, img * 0.8, (macchie - 0.58) * 4 * sporco / 0.22)
    crepe = (np.abs(fbm(seme + 8, 5) - 0.5) < 0.0035) & (fbm(seme + 12, 3) > 0.55)
    img = np.where(crepe[:, :, None], img * 0.72, img)
    return img


def assi(colore, seme=3):
    """Perline orizzontali delle case americane."""
    c = rgb(colore)
    n = 8
    y, x = np.mgrid[0:DIM, 0:DIM]
    h = DIM // n
    riga = y // h
    ly = y % h
    r = _rng(seme)
    tinta = 0.92 + 0.12 * r.random(n)
    v = tinta[riga] * (1.06 - 0.16 * ly / h)
    v *= 0.94 + 0.08 * fbm(seme + 2, 3, 4, anisotropia=(1, 6))
    v = np.where(ly > h - 4, v * 0.62, v)
    v = np.where(ly < 2, v * 1.08, v)
    img = _colora(v * granello(seme + 4, 0.03), c)
    vernice_saltata = fbm(seme + 6, 7) > 0.76
    return np.where(vernice_saltata[:, :, None], img * 0.55 + rgb("#8a6b4a") * 0.35, img)


def tavole(colore, seme=4, chiodi=True):
    """Tavole verticali di legno."""
    c = rgb(colore)
    r = _rng(seme)
    larghezze = []
    tot = 0
    while tot < DIM:
        w = int(r.integers(26, 44))
        larghezze.append(w)
        tot += w
    larghezze[-1] -= tot - DIM
    y, x = np.mgrid[0:DIM, 0:DIM]
    indice = np.zeros(DIM, dtype=int)
    inizio = np.zeros(DIM, dtype=int)
    pos = 0
    for i, w in enumerate(larghezze):
        indice[pos:pos + w] = i
        inizio[pos:pos + w] = pos
        pos += w
    k = indice[x]
    lx = x - inizio[x]
    w = np.array(larghezze)[k]
    tinta = (0.8 + 0.3 * r.random(len(larghezze)))[k]
    venatura = fbm(seme + 1, 4, 4, anisotropia=(8, 1))
    v = tinta * (0.82 + 0.3 * venatura)
    v *= 0.9 + 0.1 * np.sin((x + venatura * 40) * 0.9) ** 2
    v = np.where(lx < 3, v * 0.45, v)
    v = np.where(lx > w - 3, v * 0.8, v)
    img = _colora(v * granello(seme + 2, 0.04), c)
    if chiodi:
        for cy in (18, DIM - 18):
            d = (y - cy) ** 2 + (lx - w // 2) ** 2
            img = np.where((d < 7)[:, :, None], rgb("#3a3036"), img)
    return img


def lamiera(colore, ruggine="#b8602f", seme=5, quanta=0.35):
    c = rgb(colore)
    rg = rgb(ruggine)
    y, x = np.mgrid[0:DIM, 0:DIM]
    onde = 16
    s = np.sin(x / DIM * onde * 2 * np.pi)
    v = 0.86 + 0.16 * s + 0.05 * np.cos(x / DIM * onde * 2 * np.pi)
    v *= 0.95 + 0.08 * fbm(seme, 4)
    img = _colora(v * granello(seme + 1, 0.03), c)
    colature = rumore(48, 3, seme + 2)
    macchie = fbm(seme + 3, 4)
    maschera = (macchie - (0.62 - 0.25 * quanta)) * 4 + (colature - 0.7) * 3 * quanta
    ruggine_img = _colora((0.75 + 0.35 * fbm(seme + 4, 16)) * (0.95 + 0.05 * s), rg)
    img = _mescola(img, ruggine_img, maschera)
    # giunta orizzontale con rivetti
    img = np.where((y > DIM - 6)[:, :, None], img * 0.6, img)
    riv = ((y - (DIM - 12)) ** 2 + ((x % 32) - 16) ** 2) < 6
    img = np.where(riv[:, :, None], rgb("#3a3036") * 0.6 + c * 0.4, img)
    return img


def tegole(colore, seme=6):
    c = rgb(colore)
    file, per_fila = 8, 6
    y, x = np.mgrid[0:DIM, 0:DIM]
    fh = DIM // file
    tw = DIM // per_fila + 1
    fila = y // fh
    xs = (x + (fila % 2) * (tw // 2)) % DIM
    col = np.minimum(xs // tw, per_fila - 1)
    lx = xs % tw
    ly = y % fh
    r = _rng(seme)
    tinta = 0.78 + 0.32 * r.random((file, per_fila))
    v = tinta[fila, col] * (0.85 + 0.25 * ly / fh)
    v *= 0.9 + 0.15 * fbm(seme + 1, 8)
    v = np.where(ly < 5, v * (0.45 + 0.1 * ly), v)
    v = np.where(lx < 2, v * 0.6, v)
    img = _colora(v * granello(seme + 2, 0.05), c)
    muschio = fbm(seme + 3, 5) > 0.7
    return np.where(muschio[:, :, None], img * 0.6 + rgb("#6f7a3a") * 0.35, img)


def cemento(colore, seme=7, fori=True):
    c = rgb(colore)
    y, x = np.mgrid[0:DIM, 0:DIM]
    v = 0.9 + 0.14 * fbm(seme, 3)
    v *= granello(seme + 1, 0.07)
    # pannelli di getto
    v = np.where((x % 128 < 2) | (y % 128 < 2), v * 0.7, v)
    img = _colora(v, c)
    if fori:
        fx = (x % 64) - 32
        fy = (y % 64) - 32
        img = np.where(((fx * fx + fy * fy) < 9)[:, :, None], img * 0.55, img)
    colature = rumore(40, 2, seme + 2)
    img = _mescola(img, img * 0.7, (colature - 0.62) * 3)
    macchie = fbm(seme + 3, 4)
    return _mescola(img, img * 0.75, (macchie - 0.6) * 3)


def piastrelle(colore, colore2=None, seme=8, n=8):
    c1 = rgb(colore)
    c2 = rgb(colore2) if colore2 else c1 * 0.8
    y, x = np.mgrid[0:DIM, 0:DIM]
    t = DIM // n
    scacco = ((x // t + y // t) % 2)[:, :, None]
    img = c1 * (1 - scacco) + c2 * scacco
    img = img * (0.94 + 0.08 * fbm(seme, 4))[:, :, None]
    giunto = (x % t < 2) | (y % t < 2)
    img = np.where(giunto[:, :, None], rgb("#bcb2a2") * 0.8, img)
    sporco = fbm(seme + 1, 3)
    return _mescola(img, img * 0.75, (sporco - 0.6) * 3)


def erba(colore, seme=9):
    c = rgb(colore)
    v = 0.8 + 0.3 * fbm(seme, 4)
    r = _rng(seme + 1)
    fili = r.random((DIM, DIM))
    v = np.where(fili > 0.93, v * 1.25, v)
    v = np.where(fili < 0.06, v * 0.7, v)
    img = _colora(v, c)
    secco = fbm(seme + 2, 3)
    return _mescola(img, img * 0.7 + rgb("#b59a5a") * 0.35, (secco - 0.62) * 3)


def terra(colore, seme=10, solchi=True):
    c = rgb(colore)
    y, x = np.mgrid[0:DIM, 0:DIM]
    v = 0.82 + 0.25 * fbm(seme, 6)
    if solchi:
        v *= 0.8 + 0.25 * (0.5 + 0.5 * np.sin(y / DIM * 8 * 2 * np.pi)) ** 2
    zolle = _rng(seme + 1).random((DIM, DIM)) > 0.97
    v = np.where(zolle, v * 0.7, v)
    return _colora(v * granello(seme + 2, 0.08), c)


def ghiaia(colore, seme=11):
    c = rgb(colore)
    d1, d2, idx = voronoi(90, seme)
    tinta = 0.7 + 0.45 * _rng(seme + 1).random(90)
    v = tinta[idx] * (0.85 + 0.3 * np.clip((d2 - d1) / 8, 0, 1))
    v = np.where(d2 - d1 < 1.6, 0.45, v)
    return _colora(v * granello(seme + 2, 0.05), c)


def righe(colore, colore2="#fbf3e2", seme=12, n=4):
    c1 = rgb(colore)
    c2 = rgb(colore2)
    y, x = np.mgrid[0:DIM, 0:DIM]
    banda = ((x * 2 * n) // DIM) % 2
    img = np.where((banda == 0)[:, :, None], c1, c2)
    trama = 0.95 + 0.05 * np.sin(x * 2.2) * np.sin(y * 2.2)
    img = img * (trama * (0.92 + 0.12 * fbm(seme, 4)))[:, :, None]
    sporco = fbm(seme + 1, 3)
    return _mescola(img, img * 0.72, (sporco - 0.6) * 3)


def metallo(colore, seme=13, ruggine=0.25):
    c = rgb(colore)
    y, x = np.mgrid[0:DIM, 0:DIM]
    v = 0.92 + 0.1 * fbm(seme, 4)
    v = np.where((x % 128 < 3) | (y % 128 < 3), v * 0.6, v)
    v = np.where((x % 128 >= 3) & (x % 128 < 5), v * 1.15, v)
    riv = (((x % 128) - 10) ** 2 + ((y % 32) - 16) ** 2 < 6) | (((x % 128) - 118) ** 2 + ((y % 32) - 16) ** 2 < 6)
    v = np.where(riv, v * 0.7, v)
    img = _colora(v * granello(seme + 1, 0.03), c)
    # graffi
    r = _rng(seme + 2)
    for _ in range(14):
        x0, y0 = r.integers(0, DIM, 2)
        ang = r.random() * np.pi
        lung = r.integers(10, 40)
        for t in range(lung):
            px = int(x0 + t * np.cos(ang)) % DIM
            py = int(y0 + t * np.sin(ang)) % DIM
            img[py, px] = img[py, px] * 1.25
    macchie = fbm(seme + 3, 5)
    return _mescola(img, _colora(0.8 + 0.2 * fbm(seme + 4, 16), rgb("#a8572c")), (macchie - (0.75 - ruggine * 0.4)) * 5)


def legno(colore, seme=14):
    """Legno con venature per casse, travi e mobili."""
    c = rgb(colore)
    y, x = np.mgrid[0:DIM, 0:DIM]
    n = fbm(seme, 3, 3, anisotropia=(1, 4))
    anelli = 0.5 + 0.5 * np.sin((y / DIM * 22 + n * 6) * np.pi)
    v = 0.8 + 0.22 * anelli ** 3
    v *= 0.9 + 0.12 * fbm(seme + 1, 6)
    # quattro assi per quadrato
    v = np.where((y % 64) < 2, v * 0.5, v)
    return _colora(v * granello(seme + 2, 0.03), c)


def pietra(colore, malta="#cfc2a6", seme=15):
    c = rgb(colore)
    d1, d2, idx = voronoi(36, seme)
    r = _rng(seme + 1)
    tinta = 0.75 + 0.35 * r.random(36)
    v = tinta[idx] * (0.85 + 0.25 * np.clip((d2 - d1) / 14, 0, 1))
    v *= 0.9 + 0.15 * fbm(seme + 2, 8)
    img = _colora(v * granello(seme + 3, 0.05), c)
    giunto = (d2 - d1) < 3.0
    return np.where(giunto[:, :, None], rgb(malta) * 0.75, img)


def tela(colore, seme=16):
    c = rgb(colore)
    y, x = np.mgrid[0:DIM, 0:DIM]
    trama = 0.9 + 0.1 * (np.sin(x * 1.6) * np.sin(y * 1.6))
    v = trama * (0.85 + 0.25 * fbm(seme, 4))
    return _colora(v * granello(seme + 1, 0.05), c)


def lastre(colore, seme=17):
    """Pannelli verniciati lisci con fughe (prefabbricati, bunker, frigoriferi)."""
    c = rgb(colore)
    y, x = np.mgrid[0:DIM, 0:DIM]
    v = 0.95 + 0.07 * fbm(seme, 3)
    v = np.where((x % 128 < 2), v * 0.7, v)
    v = np.where((x % 128 >= 2) & (x % 128 < 4), v * 1.1, v)
    img = _colora(v * granello(seme + 1, 0.025), c)
    colature = rumore(36, 2, seme + 2)
    img = _mescola(img, img * 0.78, (colature - 0.66) * 3)
    return _mescola(img, img * 0.8, (fbm(seme + 3, 4) - 0.64) * 3)


MOTIVI = {
    "mattoni": mattoni,
    "intonaco": intonaco,
    "assi": assi,
    "tavole": tavole,
    "lamiera": lamiera,
    "tegole": tegole,
    "cemento": cemento,
    "piastrelle": piastrelle,
    "erba": erba,
    "terra": terra,
    "ghiaia": ghiaia,
    "righe": righe,
    "metallo": metallo,
    "legno": legno,
    "pietra": pietra,
    "tela": tela,
    "lastre": lastre,
}


# ------------------------------------------------------------------ file


def nome_file(motivo, colori):
    return motivo + "_" + "_".join(c.lstrip("#").lower() for c in colori) + ".png"


def png(img):
    """Codifica un'immagine (H, W, 3) float 0..1 in PNG senza librerie esterne."""
    dati = (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)
    h, w = dati.shape[:2]
    grezzo = b"".join(b"\x00" + dati[r].tobytes() for r in range(h))

    def blocco(tipo, contenuto):
        c = struct.pack(">I", len(contenuto)) + tipo + contenuto
        return c + struct.pack(">I", zlib.crc32(tipo + contenuto) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n" + blocco(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
            + blocco(b"IDAT", zlib.compress(grezzo, 9)) + blocco(b"IEND", b""))


def genera(motivo, colori, cartella):
    """Scrive la texture se manca e restituisce il percorso."""
    os.makedirs(cartella, exist_ok=True)
    percorso = os.path.join(cartella, nome_file(motivo, colori))
    if not os.path.isfile(percorso):
        seme = sum(ord(ch) for ch in motivo + "".join(colori))
        img = MOTIVI[motivo](*colori, seme=seme)
        with open(percorso, "wb") as f:
            f.write(png(img))
    return percorso
