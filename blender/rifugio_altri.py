"""Rifugio - mura della città, lotti liberi e infestati, cantiere, lampione."""

import math

import numpy as np

from rifugio_modello import *  # noqa: F401,F403

COSTRUTTORI = {}


def modello(nome):
    def registra(funzione):
        COSTRUTTORI[nome] = funzione
        return funzione
    return registra


# ================================================================== MURA

X_FRONTE, X_RETRO = -13.5, 9.0
CANCELLO = (-11.4, -7.0)


def _torretta(m, tx, ty, legni, liv):
    """Torretta di guardia sul lato della città (in legno, poi blindata)."""
    gambe = ("legno", legni[1]) if liv < 3 else ("metallo", ACCIAIO_S)
    for ddx in (-0.65, 0.65):
        for ddy in (-0.65, 0.65):
            m.cilindro(0.1 if liv < 3 else 0.12, 4.6, (tx + ddx, ty + ddy, 2.3), gambe, lati=7, liscio=False,
                       metallo=0.0 if liv < 3 else 0.5)
    for ddx in (-0.65, 0.65):
        for segno in (-1, 1):
            m.scatola((0.08, 1.5, 0.1), (tx + ddx, ty, 1.8), MARRONE if liv < 3 else ACCIAIO_S,
                      rot=(segno * 50, 0, 0), smusso=0.02, contorno=0.02)
    m.scatola((1.8, 1.8, 0.18), (tx, ty, 4.6), ("tavole", legni[0]) if liv < 3 else ("lamiera", ACCIAIO), smusso=0.03)
    parapetto = ("tavole", legni[2]) if liv == 1 else (("lamiera", RUGGINE) if liv == 2 else ("lamiera", OLIVA))
    for ddx, ddy, l, p in ((0, -0.85, 1.8, 0.1), (0, 0.85, 1.8, 0.1), (-0.85, 0, 0.1, 1.8), (0.85, 0, 0.1, 1.8)):
        m.scatola((l, p, 0.7 + 0.15 * (liv - 1)), (tx + ddx, ty + ddy, 5.05 + 0.07 * (liv - 1)), parapetto,
                  smusso=0.02, contorno=0.025)
    for ddx in (-0.8, 0.8):
        for ddy in (-0.8, 0.8):
            m.cilindro(0.06, 1.5, (tx + ddx, ty + ddy, 5.45), MARRONE if liv < 3 else ACCIAIO_S, lati=6, contorno=0.02)
    tetto = ("tegole", ROSSO) if liv < 3 else ("lamiera", ROSSO_S)
    m.cilindro(1.55, 0.9, (tx, ty, 6.6), tetto, raggio_alto=0.0, lati=4, rot=(0, 0, 45), liscio=False)
    m.faro((tx - 0.5, ty + 0.3, 5.55), (-1, 0, 0.1))
    if liv >= 2:
        m.faro((tx + 0.5, ty + 0.6, 5.55), (-0.4, 1, 0.15), raggio=0.26)
    m.scala_pioli((tx + 0.3, ty - 0.85, 0.0), 4.6, colore=LEGNO_S if liv < 3 else ACCIAIO_S)


def _battenti(m, liv, legni, y):
    """Due battenti chiusi, ognuno in un gruppo con il perno sul cardine:
    il gioco li ruota per aprirli verso l'esterno quando entra qualcuno."""
    g0, g1 = CANCELLO
    larghezza = (g1 - g0) / 2
    altezza = 3.2 if liv == 1 else (3.5 if liv == 2 else 3.9)
    for nome, cardine, verso in (("anta_sx", g0, 1), ("anta_dx", g1, -1)):
        m.inizia_gruppo(nome, (cardine, y, 0.0))
        cx = cardine + verso * larghezza / 2
        if liv < 3:
            m.scatola((larghezza - 0.04, 0.14, altezza), (cx, y, 0.1 + altezza / 2), ("tavole", legni[0]), smusso=0.03,
                      uv_ruota=True)
            for z in (0.6, 0.1 + altezza / 2, altezza - 0.4):
                m.scatola((larghezza - 0.14, 0.26, 0.18), (cx, y, z), ("legno", MARRONE), smusso=0.02, contorno=0.02)
            # diagonale di rinforzo
            m.scatola((0.16, 0.24, altezza - 0.9), (cx, y, 0.1 + altezza / 2), ("legno", LEGNO_S),
                      rot=(0, verso * 32, 0), smusso=0.02, contorno=0.02)
            if liv == 2:
                # lamiere inchiodate sul lato esterno
                for k, z in enumerate((0.9, 2.3)):
                    m.scatola((larghezza * 0.72, 0.04, 1.0), (cx + verso * 0.1 * (k - 0.5), y + 0.16, z),
                              ("lamiera", RUGGINE if k == 0 else ACCIAIO), smusso=0.01, contorno=0.015, metallo=0.3)
        else:
            m.scatola((larghezza - 0.04, 0.22, altezza), (cx, y, 0.1 + altezza / 2), ("lamiera", ACCIAIO_S),
                      smusso=0.03, metallo=0.5, ruvido=0.6)
            for z in (0.5, 0.1 + altezza / 2, altezza - 0.3):
                m.scatola((larghezza - 0.1, 0.3, 0.22), (cx, y, z), ("metallo", SCURO), smusso=0.02, contorno=0.02,
                          metallo=0.6)
                for k in range(4):
                    xr = cardine + verso * (0.3 + k * (larghezza - 0.6) / 3)
                    m.sfera(0.05, (xr, y + 0.17, z), CROMO, contorno=0, liscio=True)
            # fascia di pericolo gialla e nera in basso
            m.scatola((larghezza - 0.1, 0.05, 0.35), (cx, y + 0.13, 1.05), ("righe", SENAPE, SCURO), smusso=0,
                      contorno=0.01, scala_uv=0.6)
        m.fine_gruppo()
    # chiavistello sul battente sinistro (si apre con lui)
    m.inizia_gruppo("anta_sx", (g0, y, 0.0))
    centro = (g0 + g1) / 2
    m.scatola((0.7, 0.12, 0.14), (centro - 0.25, y + 0.2, 1.7), ("metallo", SCURO), smusso=0.02, contorno=0.02,
              metallo=0.6)
    m.fine_gruppo()


def _palizzata(m, liv, legni, altezza):
    g0, g1 = CANCELLO
    segmenti = ((X_FRONTE - 0.3, g0 - 0.3), (g1 + 0.3, X_RETRO + 0.3))
    for xa, xb in segmenti:
        m.tronco((xb - xa, 1.6), (xb - xa - 0.2, 0.6), 0.35, ((xa + xb) / 2, 0, 0), ("terra", "#7a6550"), contorno=0)
    x = X_FRONTE
    i = 0
    while x <= X_RETRO:
        if not (g0 - 0.15 < x < g1 + 0.15):
            h = altezza + (0.3 if i % 3 == 0 else (0.12 if i % 3 == 1 else 0.0))
            colore = ("legno", legni[i % 3])
            m.cilindro(0.19, h, (x, 0, h / 2), colore, lati=7, liscio=False, rot=(0, 0, i * 23))
            m.cilindro(0.19, 0.45, (x, 0, h + 0.22), colore, raggio_alto=0.0, lati=7, liscio=False, rot=(0, 0, i * 23))
        x += 0.38
        i += 1
    for z in (0.9, altezza - 0.8):
        for xa, xb in ((X_FRONTE - 0.2, g0 - 0.3), (g1 + 0.3, X_RETRO + 0.2)):
            m.scatola((xb - xa, 0.14, 0.2), ((xa + xb) / 2, -0.24, z), ("legno", MARRONE), smusso=0.03, contorno=0.02)
    if liv == 2:
        # basamento in pietra sul lato esterno e lamiere di rinforzo
        for xa, xb in segmenti:
            m.scatola((xb - xa - 0.2, 0.5, 1.3), ((xa + xb) / 2, 0.38, 0.65), ("pietra", CEMENTO), smusso=0.08)
            m.scatola((xb - xa - 0.1, 0.62, 0.14), ((xa + xb) / 2, 0.38, 1.35), ("cemento", CEMENTO_S), smusso=0.03,
                      contorno=0.02)
        cas = m.casuale
        for xa, xb in segmenti:
            n = int((xb - xa) / 2.6)
            for k in range(n):
                xk = xa + 1.2 + k * (xb - xa - 1.6) / max(1, n - 1)
                m.scatola((1.1, 0.04, 1.1), (xk, 0.25, 2.3 + cas.uniform(-0.2, 0.3)),
                          ("lamiera", cas.choice([RUGGINE, ACCIAIO, RUGGINE_S])), rot=(0, cas.uniform(-8, 8), 0),
                          smusso=0.01, contorno=0.015, metallo=0.3)


def _muro_fortezza(m, altezza):
    """Livello 3: muro di cemento armato con piastre e merli, camminamento sul retro."""
    g0, g1 = CANCELLO
    for xa, xb in ((X_FRONTE - 0.3, g0 - 0.3), (g1 + 0.3, X_RETRO + 0.3)):
        lunghezza = xb - xa
        cx = (xa + xb) / 2
        m.scatola((lunghezza, 1.0, 0.5), (cx, 0.0, 0.25), ("cemento", CEMENTO_S), smusso=0.06)
        m.scatola((lunghezza - 0.1, 0.8, altezza - 0.5), (cx, 0.0, 0.5 + (altezza - 0.5) / 2), ("cemento", CEMENTO),
                  smusso=0.06)
        # piastre metalliche sul lato esterno
        n = int(lunghezza / 1.6)
        for k in range(n):
            xk = xa + (k + 0.5) * lunghezza / n
            m.scatola((lunghezza / n - 0.12, 0.06, altezza - 1.6), (xk, 0.43, 0.6 + (altezza - 1.6) / 2 + 0.4),
                      ("lamiera", OLIVA if k % 3 else ACCIAIO_S), smusso=0.01, contorno=0.015, metallo=0.35)
        # merli
        k = 0
        x = xa + 0.35
        while x < xb - 0.3:
            m.scatola((0.6, 0.85, 0.55), (x, 0.0, altezza + 0.27), ("cemento", CEMENTO), smusso=0.05)
            x += 1.0
            k += 1
        # camminamento sul lato della città
        m.scatola((lunghezza - 0.2, 0.9, 0.16), (cx, -0.85, altezza - 1.2), ("lamiera", ACCIAIO_S), smusso=0.02,
                  metallo=0.4)
        for xs in np.arange(xa + 0.6, xb - 0.3, 2.2):
            m.cilindro(0.08, altezza - 1.2, (xs, -1.2, (altezza - 1.2) / 2), ("metallo", ACCIAIO_S), lati=6,
                       metallo=0.5, contorno=0.02)


@modello("mura_l1")
def crea_mura_l1():
    return crea_mura(1)


@modello("mura_l2")
def crea_mura_l2():
    return crea_mura(2)


@modello("mura_l3")
def crea_mura_l3():
    return crea_mura(3)


def crea_mura(liv=1):
    """Mura che attraversano la strada (lungo X) con il cancello sulla carreggiata.

    Nel gioco il modello viene ruotato di 90°: l'asse X diventa la profondità della
    strada (X negativo = verso la telecamera), il lato -Y guarda la città e il
    lato +Y l'esterno, dove si aprono i battenti (gruppi "anta_sx" e "anta_dx").
    1 = palizzata, 2 = palizzata rinforzata, 3 = fortezza di cemento.
    """
    m = Modello("mura_l%d" % liv)
    legni = ["#b07a4c", "#8d5a37", "#9c6942"]
    g0, g1 = CANCELLO
    centro = (g0 + g1) / 2
    altezza = (3.8, 4.3, 4.6)[liv - 1]
    if liv < 3:
        _palizzata(m, liv, legni, altezza)
    else:
        _muro_fortezza(m, altezza)
    # montanti e trave del cancello
    alto_montante = altezza + 1.1
    for xp in (g0 - 0.2, g1 + 0.2):
        if liv < 3:
            m.cilindro(0.3, alto_montante, (xp, 0, alto_montante / 2), ("legno", legni[1]), lati=9, liscio=False)
            m.cilindro(0.3, 0.5, (xp, 0, alto_montante + 0.25), ("legno", legni[1]), raggio_alto=0.0, lati=9,
                       liscio=False)
            for z in (0.6, 2.2, altezza):
                m.cilindro(0.32, 0.12, (xp, 0, z), ("metallo", ACCIAIO_S), lati=9, liscio=False, metallo=0.5)
        else:
            m.scatola((0.9, 1.3, alto_montante + 0.4), (xp, 0, (alto_montante + 0.4) / 2), ("cemento", CEMENTO_S),
                      smusso=0.06)
            m.scatola((1.0, 1.4, 0.25), (xp, 0, alto_montante + 0.5), ("cemento", CEMENTO), smusso=0.05)
            m.faro((xp, -0.2, alto_montante + 0.9), (0, 1, -0.25), raggio=0.24)
    trave_z = alto_montante - 0.45
    if liv < 3:
        m.cilindro(0.22, g1 - g0 + 1.4, (centro, 0, trave_z), ("legno", legni[0]), rot=(0, 90, 0), lati=9, liscio=False)
    else:
        m.scatola((g1 - g0 + 1.2, 0.5, 0.5), (centro, 0, trave_z), ("metallo", SCURO), smusso=0.03, metallo=0.6)
        m.scatola((g1 - g0 + 0.4, 0.06, 0.32), (centro, 0.27, trave_z), ("righe", SENAPE, SCURO), smusso=0,
                  contorno=0.01, scala_uv=0.6)
    m.asta((centro, 0, trave_z - 0.2), (centro, 0, trave_z - 0.45), 0.035, ACCIAIO_S, metallo=0.7, contorno=0)
    m.insegna((centro, 0, trave_z - 0.9), 2.2, 0.6, angolo=-60)
    _battenti(m, liv, legni, 0.15 if liv < 3 else 0.35)
    # torretta di guardia sul lato della città
    _torretta(m, -5.3, -1.3, legni, liv)
    if liv == 3:
        _torretta(m, 4.6, -1.5, legni, liv)
        m.bandiera((-5.3, -1.3, 7.0), altezza=1.8, colore=ROSSO, colore2=CREMA)
    # sacchi di sabbia ai lati del cancello
    m.sacchi(-13.4, -11.6, -0.65 if liv < 3 else -1.1, 2 if liv == 1 else 3)
    m.sacchi(-6.8, -5.6, -0.65 if liv < 3 else -1.1, 2 if liv == 1 else 3)
    # filo spinato in cima
    giri = 1 if liv == 1 else 2
    cima_filo = altezza + (0.55 if liv < 3 else 0.75)
    for xa, xb in ((X_FRONTE, g0 - 0.4), (g1 + 0.4, X_RETRO)):
        n = int((xb - xa) / 0.6)
        for giro in range(giri):
            for k in range(n):
                xk = xa + (k + 0.5) * (xb - xa) / n
                m.scatola((0.65, 0.03, 0.03), (xk, 0.12 * giro, cima_filo + 0.18 * giro + (0.08 if k % 2 else 0.0)),
                          ACCIAIO_S, rot=(0, 15 if k % 2 else -15, 0), smusso=0, contorno=0, metallo=0.7)
    if liv >= 2:
        # cavalli di frisia all'esterno, lontani dalla carreggiata
        for x0 in (X_FRONTE + 0.8, g1 + 1.5, g1 + 5.0):
            for k in range(2):
                xc = x0 + k * 1.3
                for segno in (-1, 1):
                    m.asta((xc - 0.5, 2.0 + segno * 0.45, 0.0), (xc + 0.5, 2.0 - segno * 0.45, 1.1), 0.06,
                           LEGNO_S if liv == 2 else ACCIAIO_S, contorno=0.02)
                m.asta((xc - 0.55, 2.0, 0.55), (xc + 0.55, 2.0, 0.55), 0.07, MARRONE if liv == 2 else SCURO,
                       contorno=0.02)
    m.bidone_fuoco((-6.3, -1.6 if liv < 3 else -2.0, 0.0))
    if liv == 3:
        m.barile((-4.0, -2.2, 0.0), colore=ROSSO)
        m.cassa((-3.2, -2.3, 0.0), lato=0.7, colore=OLIVA)
    m.cima(alto_montante + 0.2, x=centro)
    return m


# ================================================================== LOTTI


@modello("lotto_libero")
def crea_lotto_libero():
    m = Modello("lotto_libero")
    m.cilindro(2.8, 0.06, (0, -0.4, 0.03), ("terra", "#a0805c"), lati=20, contorno=0, scala=(1, 0.6, 1))
    for x in (-0.9, 0.9):
        m.cilindro(0.08, 2.0, (x, -0.2, 1.0), ("legno", LEGNO_S), lati=7)
    m.insegna((0, -0.3, 1.75), 2.2, 1.0)
    angoli = ((-2.6, -1.6), (2.6, -1.6), (-2.6, 0.6), (2.6, 0.6))
    for x, y in angoli:
        m.scatola((0.1, 0.1, 0.9), (x, y, 0.45), ("legno", CREMA_S), smusso=0.02, contorno=0.02)
    for (xa, ya), (xb, yb) in (((-2.6, -1.6), (2.6, -1.6)), ((-2.6, -1.6), (-2.6, 0.6)), ((2.6, -1.6), (2.6, 0.6))):
        lunghezza = math.hypot(xb - xa, yb - ya)
        rot_z = math.degrees(math.atan2(yb - ya, xb - xa))
        m.scatola((lunghezza, 0.02, 0.09), ((xa + xb) / 2, (ya + yb) / 2, 0.75), ("righe", ROSSO, BIANCO),
                  rot=(0, 0, rot_z), smusso=0, contorno=0.01, scala_uv=0.5)
    cas = m.casuale
    for _ in range(16):
        x, y = cas.uniform(-2.5, 2.5), cas.uniform(-1.5, 0.5)
        m.cilindro(0.1, 0.3, (x, y, 0.15), cas.choice([VERDE, VERDE_S]), raggio_alto=0.0, lati=5, contorno=0)
    for k in range(4):
        m.scatola((1.6, 0.28, 0.1), (1.55, -0.85 + (k % 2) * 0.04, 0.12 + k * 0.1), ("legno", "#c48a55"),
                  rot=(0, 0, -12 + k * 5), smusso=0.02, contorno=0.02, uv_ruota=True)
    for fila in range(3):
        for k in range(3 - fila):
            m.scatola((0.36, 0.2, 0.16), (-1.95 + k * 0.38 + fila * 0.19, -0.9, 0.11 + fila * 0.17), MATTONE,
                      smusso=0.03, contorno=0.02)
    m.sfera(0.5, (-1.2, -0.3, 0.0), ("terra", SABBIA), scala=(1.2, 1.0, 0.6))
    m.asta((-1.3, -0.3, 0.1), (-0.7, -0.3, 1.15), 0.03, LEGNO_S)
    m.scatola((0.22, 0.04, 0.3), (-1.33, -0.3, 0.12), ACCIAIO_S, rot=(0, 30, 0), smusso=0, metallo=0.6, contorno=0.015)
    # carriola
    cx, cy = 2.3, 0.4
    m.tronco((0.9, 0.6), (0.6, 0.4), 0.35, (cx, cy, 0.3), ("metallo", TEAL), rot=(180, 0, 0))
    m.copertone((cx + 0.55, cy, 0.17), 0.17, 0.08, rot=(90, 0, 0))
    for s in (-1, 1):
        m.asta((cx - 0.3, cy + s * 0.22, 0.32), (cx - 0.95, cy + s * 0.25, 0.55), 0.025, LEGNO_S, contorno=0.01)
        m.asta((cx - 0.2, cy + s * 0.2, 0.0), (cx - 0.2, cy + s * 0.2, 0.25), 0.025, ACCIAIO_S, contorno=0.01)
    return m


@modello("lotto_bloccato")
def crea_lotto_bloccato():
    m = Modello("lotto_bloccato")
    cas = m.casuale
    m.cilindro(2.9, 0.05, (0, -0.2, 0.025), ("terra", "#6e5a49"), lati=18, contorno=0, scala=(1, 0.65, 1))
    # auto distrutta
    m.auto((-1.15, -0.1, 0.0), colore="#5e8580", rot=0, rottame=True, lunghezza=3.2)
    # macerie
    for _ in range(10):
        colore = cas.choice([("cemento", CEMENTO), ("mattoni", MATTONE_S), ("cemento", "#8d7a6c")])
        dim = (cas.uniform(0.3, 0.8), cas.uniform(0.3, 0.7), cas.uniform(0.2, 0.5))
        m.scatola(dim, (cas.uniform(0.7, 2.9), cas.uniform(-0.2, 0.9), dim[2] * 0.35), colore,
                  rot=(cas.uniform(-25, 25), cas.uniform(-25, 25), cas.uniform(0, 90)), smusso=0.05)
    for k in range(3):
        m.cilindro(0.08, 1.4, (1.6 + k * 0.25, 0.4, 0.25 + k * 0.05), ("metallo", RUGGINE), rot=(0, 90, 20 + k * 25),
                   lati=8, metallo=0.6, contorno=0.02)
    # barricata a strisce con il teschio
    for x in (0.9, 2.7):
        for segno in (-1, 1):
            m.scatola((0.1, 0.1, 1.3), (x, -1.3 + segno * 0.2, 0.6), ("legno", LEGNO_S), rot=(segno * 18, 0, 0),
                      smusso=0.02, contorno=0.02)
    m.scatola((2.3, 0.12, 0.38), (1.8, -1.28, 1.05), ("righe", ROSSO, BIANCO), smusso=0.02, scala_uv=0.6)
    m.scatola((0.9, 0.06, 0.55), (1.8, -1.42, 1.65), ("lastre", SENAPE), rot=(0, 6, 0), smusso=0.03)
    m.sfera(0.15, (1.8, -1.47, 1.7), BIANCO, scala=(1, 0.3, 1), contorno=0.01)
    for dx in (-0.06, 0.06):
        m.sfera(0.04, (1.8 + dx, -1.52, 1.71), SCURO, contorno=0)
    m.asta((1.6, -1.47, 1.45), (2.0, -1.47, 1.6), 0.025, BIANCO, contorno=0.01)
    m.asta((1.6, -1.47, 1.6), (2.0, -1.47, 1.45), 0.025, BIANCO, contorno=0.01)
    m.bidone_fuoco((-2.75, -1.0, 0.0))
    m.albero((-2.6, 0.9, 0.0), 3.4, secco=True)
    m.mucchio_rottami((0.2, 1.4, 0.0), 0.8, 0.7, 6)
    return m


@modello("cantiere")
def crea_cantiere():
    """Lotto con un edificio in costruzione: fondamenta, impalcatura, betoniera."""
    m = Modello("cantiere")
    giallo, arancio = "#f2b62e", "#ef7d2d"
    m.cilindro(2.9, 0.06, (0, -0.3, 0.03), ("terra", "#9a7a55"), lati=20, contorno=0, scala=(1, 0.65, 1))
    m.scatola((4.0, 2.8, 0.3), (0, 0.3, 0.15), ("cemento", CEMENTO), smusso=0.04)
    m.scatola((3.9, 0.22, 0.57), (0.0, -0.95, 0.58), ("mattoni", MATTONE), smusso=0.02)
    m.scatola((0.22, 2.4, 0.38), (-1.95, 0.4, 0.49), ("mattoni", MATTONE), smusso=0.02)
    for k in range(5):
        m.scatola((0.38, 0.22, 0.18), (-1.0 + k * 0.4, -0.95, 0.96), MATTONE, smusso=0.03, contorno=0.015)
    xs, ys = (-2.1, -0.7, 0.7, 2.1), (-1.35, 1.65)
    for x in xs:
        for y in ys:
            m.cilindro(0.05, 4.2, (x, y, 2.1), ACCIAIO, lati=6, metallo=0.6, ruvido=0.4, contorno=0.02)
    for z in (1.5, 3.0, 4.15):
        for y in ys:
            m.cilindro(0.04, 4.3, (0, y, z), ACCIAIO, rot=(0, 90, 0), lati=6, metallo=0.6, contorno=0.02)
        for x in xs:
            m.cilindro(0.04, 3.1, (x, 0.15, z), ACCIAIO, rot=(90, 0, 0), lati=6, metallo=0.6, contorno=0.02)
    for z in (1.5, 3.0):
        m.scatola((4.2, 1.0, 0.06), (0, -1.48, z + 0.06), ("tavole", LEGNO), smusso=0.01, contorno=0.02, uv_ruota=True)
    for x in xs[:-1]:
        m.asta((x, -1.35, 1.5), (x + 1.4, -1.35, 3.0), 0.035, ACCIAIO_S, contorno=0, metallo=0.6)
    m.scatola((1.4, 0.03, 1.3), (1.4, -1.38, 3.6), ("tela", "#4f9a8f"), smusso=0)
    # betoniera
    bx, by = 2.6, -1.4
    m.scatola((0.9, 0.6, 0.2), (bx, by, 0.35), giallo, smusso=0.05)
    for ddx in (-0.35, 0.35):
        m.cilindro(0.2, 0.1, (bx + ddx, by - 0.32, 0.2), GOMMA, rot=(90, 0, 0), contorno=0.02)
    m.cilindro(0.42, 0.75, (bx, by, 0.9), ("metallo", arancio), raggio_alto=0.25, rot=(0, -35, 0), lati=10)
    m.cilindro(0.25, 0.12, (bx - 0.38, by, 1.18), ACCIAIO_S, rot=(0, -35, 0), contorno=0.02, metallo=0.5, lati=10)
    # coni stradali
    for x, y in ((-2.7, -1.9), (-1.0, -2.0), (0.9, -2.0)):
        m.cilindro(0.2, 0.55, (x, y, 0.3), arancio, raggio_alto=0.03, lati=10)
        m.cilindro(0.14, 0.1, (x, y, 0.36), BIANCO, raggio_alto=0.11, lati=10, contorno=0)
        m.scatola((0.46, 0.46, 0.06), (x, y, 0.03), arancio, smusso=0.02, contorno=0.015)
    for x in (-2.6, -1.4):
        m.cilindro(0.05, 1.5, (x, -1.75, 0.75), ("legno", LEGNO_S), lati=7, contorno=0.02)
    m.insegna((-2.0, -1.8, 1.25), 1.4, 0.55, fondo=SENAPE, bordo=SCURO)
    m.asta((2.0, -1.5, 3.0), (2.0, -1.5, 4.3), 0.03, SCURO, contorno=0)
    m.sfera(0.13, (2.0, -1.5, 4.35), LUCE_CALDA, luce=4.0, contorno=0)
    for k in range(3):
        m.scatola((0.55, 0.38, 0.16), (-0.4 + k * 0.05, -1.75, 0.1 + k * 0.16), ("tela", "#d9d2c3"),
                  rot=(0, 0, k * 9), smusso=0.06)
    m.cima(4.55)
    return m


@modello("lampione")
def crea_lampione():
    m = Modello("lampione")
    m.cilindro(0.2, 0.3, (0, 0, 0.15), SCURO, lati=8, metallo=0.5, ruvido=0.4)
    m.cilindro(0.07, 3.6, (0, 0, 1.9), SCURO, lati=8, metallo=0.5, ruvido=0.4)
    m.scatola((0.7, 0.08, 0.08), (0.3, 0, 3.65), SCURO, smusso=0.02, metallo=0.5)
    m.cilindro(0.28, 0.22, (0.62, 0, 3.55), TEAL, raggio_alto=0.08, lati=10)
    m.sfera(0.14, (0.62, 0, 3.4), LUCE_CALDA, contorno=0, luce=6.0)
    return m
