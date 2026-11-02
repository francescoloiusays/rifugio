"""Rifugio - gli edifici della città, tre livelli ciascuno.

Ogni funzione crea(livello) restituisce un Modello. I livelli si costruiscono
uno sopra l'altro: il livello 2 ha tutto quello del livello 1 più le aggiunte
del potenziamento, e così via, così si vede subito cosa è cambiato.
"""

import math

import rifugio_geometria as geo

from rifugio_modello import *  # noqa: F401,F403 - palette e Modello

COSTRUTTORI = {}


def edificio(nome):
    def registra(funzione):
        COSTRUTTORI[nome] = funzione
        return funzione
    return registra


# ================================================================== CASE


@edificio("case")
def crea_case(liv):
    m = Modello("case_l%d" % liv)
    m.suolo(("erba", "#86b25a"))
    m.vialetto(-0.9, -2.65, -1.5, 0.9)
    pareti = ("assi", MENTA)
    fronte = -1.35
    x0, x1 = -2.75, 1.65 if liv == 1 else 1.45
    larg = x1 - x0
    cx = (x0 + x1) / 2
    prof = 3.1
    cy = fronte + prof / 2
    piani = 2 if liv >= 3 else 1
    h = 2.55 * piani + 0.35
    # basamento in mattoni e corpo della casa
    m.scatola((larg + 0.12, prof + 0.12, 0.4), (cx, cy, 0.2), ("mattoni", MATTONE_S), smusso=0.03)
    m.scatola((larg, prof, h - 0.4), (cx, cy, 0.4 + (h - 0.4) / 2), pareti, smusso=0.04)
    # cornici d'angolo bianche
    for x in (x0 + 0.04, x1 - 0.04):
        m.scatola((0.14, 0.14, h - 0.4), (x, fronte - 0.01, 0.4 + (h - 0.4) / 2), BIANCO, smusso=0.02,
                  contorno=0.018)
    m.tetto_falde(larg, prof, 1.15, (cx, cy, h), ("tegole", SALMONE_S), timpano=pareti, colmo=ROSSO_S)
    # porta, finestre
    m.porta(-0.9, fronte, colore=TEAL, gradino=True)
    m.finestra(-2.05, 1.45, fronte, persiane=SALMONE)
    m.finestra(0.55, 1.45, fronte, larghezza=1.2, persiane=SALMONE, tenda=CREMA)
    m.lampada_muro(-0.25, fronte, 2.2)
    if piani == 2:
        m.scatola((larg + 0.08, 0.08, 0.12), (cx, fronte - 0.04, 2.95), BIANCO, smusso=0.02, contorno=0.018)
        for x in (-2.05, -0.9, 0.55):
            m.finestra(x, 4.05, fronte, larghezza=0.75, altezza=0.85, persiane=SALMONE, accesa=(x != -0.9))
    # giardino
    m.staccionata(-2.95, -1.45, -2.45)
    m.staccionata(-0.35, 1.6 if liv == 1 else 1.3, -2.45)
    m.cespuglio((-2.4, -1.95, 0.08), 0.4)
    m.cespuglio((0.9, -1.95, 0.08), 0.35, VERDE_S)
    # cassetta della posta
    m.asta((-0.05, -2.35, 0.08), (-0.05, -2.35, 1.0), 0.04, LEGNO_S)
    m.profilo([(-0.16, 0), (0.16, 0), (0.16, 0.18), (0.11, 0.26), (0, 0.29), (-0.11, 0.26), (-0.16, 0.18)], 0.45,
              (-0.05, -2.35, 1.0), ("metallo", TEAL), parte="posta")
    m.scatola((0.03, 0.03, 0.2), (0.13, -2.4, 1.3), ROSSO, smusso=0, contorno=0.012)
    if liv == 1:
        m.albero((2.4, 0.4, 0.08), 3.4)
        m.barile((2.3, -1.6, 0.08), colore=TEAL)
    else:
        # garage con serranda e mansarda
        gx0, gx1 = 1.55, 3.0
        gcx = (gx0 + gx1) / 2
        m.scatola((gx1 - gx0, 2.8, 2.5), (gcx, fronte + 1.4 + 0.15, 1.25), ("tavole", SALMONE), smusso=0.04)
        m.scatola((1.25, 0.08, 1.8), (gcx, fronte + 0.1, 0.98), ("lamiera", CREMA_S), smusso=0.01, contorno=0.015)
        m.scatola((gx1 - gx0 + 0.3, 3.2, 0.14), (gcx, fronte + 1.5, 2.56), ("lamiera", ACCIAIO_S), rot=(-6, 0, 0),
                  smusso=0.02)
        m.vialetto(gcx, -2.65, fronte, 1.3, ("cemento", CEMENTO))
        # abbaino
        dx = cx - 0.6
        m.scatola((1.0, 1.0, 0.9), (dx, cy - 0.55, h + 0.55), pareti, smusso=0.03)
        m.tetto_falde(1.0, 1.0, 0.45, (dx, cy - 0.55, h + 1.0), ("tegole", SALMONE_S), sporgenza=0.12,
                      spessore=0.1, timpano=pareti)
        m.finestra(dx, h + 0.55, cy - 1.06, larghezza=0.55, altezza=0.55, persiane=None)
        m.comignolo((cx + 1.3, cy + 0.6, h + 0.4), 1.4)
        m.antenna((cx + 1.3, cy + 0.6, h + 1.95), 1.2)
    if liv >= 3:
        # veranda con colonne, sedia a dondolo, cisterna e pannelli sul garage
        vz = 2.45
        m.scatola((larg + 0.2, 1.0, 0.12), (cx, fronte - 0.5, 0.42), ("tavole", LEGNO_C), smusso=0.02,
                  uv_ruota=True)
        for x in (x0 + 0.15, -1.6, -0.2, x1 - 0.15):
            m.cilindro(0.08, vz - 0.45, (x, fronte - 0.88, 0.45 + (vz - 0.45) / 2), BIANCO, lati=8)
        m.scatola((larg + 0.3, 1.2, 0.1), (cx, fronte - 0.5, vz + 0.05), ("tegole", SALMONE_S), rot=(-10, 0, 0),
                  smusso=0.02)
        m.scatola((larg + 0.2, 0.06, 0.06), (cx, fronte - 0.88, 0.95), BIANCO, smusso=0, contorno=0.015)
        m.cisterna((2.25, fronte + 2.0, 2.6), raggio=0.5, altezza=0.8, gambe=0.5)
        m.pannello_solare((2.2, fronte + 0.7, 2.62), 1.1, 0.8, 22)
        m.luci_filo((x0 + 0.15, fronte - 0.9, vz - 0.05), (x1 - 0.15, fronte - 0.9, vz - 0.05), n=9, cedimento=0.2)
        m.scatola((0.5, 0.45, 0.06), (-2.2, fronte - 0.55, 0.85), LEGNO, smusso=0.02)
        m.scatola((0.5, 0.06, 0.5), (-2.2, fronte - 0.32, 1.1), LEGNO, smusso=0.02)
    m.cima(h + 1.6 + (0.6 if liv >= 2 else 0))
    return m


# ================================================================== DEPOSITO ROTTAMI


@edificio("deposito_rottami")
def crea_deposito_rottami(liv):
    m = Modello("deposito_rottami_l%d" % liv)
    m.suolo(("ghiaia", "#8f8478"))
    # capannone di lamiera aperto davanti, tetto a una falda
    x0, x1, y0, y1 = -2.9, -0.25, -1.0, 2.2
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hf, hr = 3.0, 2.4
    lam = ("lamiera", ACCIAIO)
    m.scatola((x1 - x0, 0.1, hr), (cx, y1, hr / 2), lam, smusso=0.02)
    for x in (x0, x1):
        m.profilo([(y0, 0), (y1, 0), (y1, hr), (y0, hf)], 0.1, (x, 0, 0), lam, rot=(0, 0, 90))
    m.scatola((x1 - x0 - 0.1, y1 - y0, 0.04), (cx, cy, 0.1), ("cemento", CEMENTO_S), smusso=0, contorno=0)
    pend = math.degrees(math.atan2(hf - hr, y1 - y0))
    m.scatola((x1 - x0 + 0.5, y1 - y0 + 0.7, 0.1), (cx, cy - 0.1, (hf + hr) / 2 + 0.08), ("lamiera", RUGGINE),
              rot=(pend, 0, 0), smusso=0.02, uv_ruota=True)
    for x in (x0 + 0.08, x1 - 0.08):
        m.scatola((0.16, 0.16, hf), (x, y0, hf / 2), ("metallo", SENAPE), smusso=0.02)
    m.scatola((x1 - x0, 0.2, 0.3), (cx, y0, hf - 0.1), ("metallo", SENAPE), smusso=0.02)
    m.insegna((cx, y0 - 0.15, hf + 0.38), 2.1, 0.55)
    # dentro: scaffali con pezzi
    for z in (0.7, 1.4):
        m.scatola((1.9, 0.5, 0.06), (cx, y1 - 0.35, z), ("legno", LEGNO_S), smusso=0, contorno=0.015)
        for i in range(4):
            m.scatola((0.3, 0.3, 0.22), (x0 + 0.6 + i * 0.5, y1 - 0.35, z + 0.14),
                      [("metallo", TEAL), ("lamiera", RUGGINE), ("lastre", SENAPE), ("metallo", ACCIAIO)][i],
                      smusso=0.02, contorno=0.015)
    m.mucchio_rottami((1.55, 0.7, 0.08), raggio=1.3, altezza=1.8, n=18)
    m.lampada_muro(cx, y0 - 0.05, 2.35)
    # gomme e bidoni
    for i in range(3):
        m.copertone((2.45, -1.75, 0.22 + i * 0.25), 0.36, 0.24)
    m.barile((-0.05, -1.9, 0.08), colore=ROSSO_S)
    m.barile((-0.55, -2.15, 0.08), colore=TEAL)
    if liv == 1:
        # gru a bandiera a mano
        px, py = 0.35, -0.35
        m.cilindro(0.12, 3.6, (px, py, 1.8), ("metallo", SENAPE), lati=8)
        m.scatola((1.9, 0.14, 0.18), (px + 0.9, py, 3.45), ("metallo", SENAPE), smusso=0.02)
        m.asta((px, py, 2.6), (px + 1.3, py, 3.38), 0.04, SENAPE_S)
        m.asta((px + 1.7, py, 3.38), (px + 1.7, py, 1.9), 0.015, SCURO, contorno=0)
        m.profilo([(-0.12, 0), (0.12, 0), (0.12, -0.12), (0, -0.22), (-0.12, -0.12)], 0.06, (px + 1.7, py, 1.9),
                  ACCIAIO_S, metallo=0.6)
        m.cilindro(0.18, 0.2, (px, py, 1.2), SCURO, rot=(90, 0, 0), lati=10)
        m.cima(4.0)
    if liv >= 2:
        m.auto((1.15, -1.55, 0.08), colore=MENTA_S, rot=-8, rottame=True)
        m.mucchio_rottami((2.4, 1.8, 0.08), raggio=0.75, altezza=0.8, n=7)
        # banco da lavoro con morsa nel capannone
        m.scatola((1.2, 0.6, 0.08), (x0 + 0.85, y0 + 0.9, 0.9), ("legno", LEGNO), smusso=0.02)
        for dx in (-0.5, 0.5):
            m.scatola((0.08, 0.5, 0.82), (x0 + 0.85 + dx, y0 + 0.9, 0.5), LEGNO_S, smusso=0, contorno=0.015)
        m.scatola((0.25, 0.2, 0.18), (x0 + 0.5, y0 + 0.75, 1.03), ("metallo", TEAL), smusso=0.02, contorno=0.015)
        m.bidone_fuoco((0.15, 1.75, 0.08))
    if liv == 2:
        m.cima(3.9)
    if liv >= 3:
        # gru con elettrocalamita su traliccio
        tx, ty = 2.45, 1.95
        for dx, dy in ((-0.3, -0.3), (0.3, -0.3), (0.3, 0.3), (-0.3, 0.3)):
            m.asta((tx + dx, ty + dy, 0.08), (tx + dx * 0.7, ty + dy * 0.7, 5.3), 0.05, SENAPE, metallo=0.4)
        for z in (1.2, 2.4, 3.6, 4.8):
            m.asta((tx - 0.28, ty - 0.28, z - 0.6), (tx + 0.25, ty - 0.25, z), 0.03, SENAPE_S, contorno=0)
            m.asta((tx + 0.28, ty - 0.28, z - 0.6), (tx - 0.25, ty - 0.25, z), 0.03, SENAPE_S, contorno=0)
        m.scatola((0.9, 0.9, 0.7), (tx, ty, 5.6), ("lastre", SENAPE), smusso=0.06)
        m.scatola((0.5, 0.05, 0.35), (tx, ty - 0.46, 5.65), VETRO_ACCESO, smusso=0, contorno=0, luce=0.5)
        m.scatola((3.4, 0.25, 0.3), (tx - 1.6, ty - 0.4, 5.95), ("metallo", SENAPE), rot=(0, 0, -28), smusso=0.03)
        bx, by = tx - 2.9, ty - 1.95
        m.asta((bx, by, 5.85), (bx, by, 3.1), 0.02, SCURO, contorno=0)
        m.cilindro(0.5, 0.25, (bx, by, 3.0), ("metallo", GOMMA), lati=14, metallo=0.6)
        m.cilindro(0.2, 0.1, (bx, by, 3.18), ROSSO, lati=10)
        m.scatola((0.7, 0.4, 0.15), (bx + 0.05, by, 2.75), ("lamiera", MENTA_S), rot=(0, 8, 20), smusso=0.02,
                  contorno=0.015)
        # pressa: cubi di rottami schiacciati
        for i, (dx, dz) in enumerate(((0, 0), (0.62, 0), (0.31, 0.58))):
            m.scatola((0.58, 0.58, 0.58), (-0.05 + dx, -0.85, 0.37 + dz),
                      [("lamiera", RUGGINE), ("lamiera", MENTA_S), ("lamiera", ACCIAIO)][i], rot=(0, 0, i * 7),
                      smusso=0.03, metallo=0.3)
        m.faro((0.55, -0.75, 4.2), (-0.2, -1, -0.4))
        m.asta((0.6, -0.65, 0.08), (0.6, -0.65, 4.05), 0.05, ACCIAIO_S, metallo=0.6)
        m.cima(6.3)
    return m


# ================================================================== ORTO


def _ortaggi(m, x0, x1, y, tipo):
    n = int((x1 - x0) / 0.32)
    for i in range(n):
        x = x0 + 0.16 + i * (x1 - x0) / n
        if tipo == "cavoli":
            m.sfera(0.15, (x, y, 0.62), VERDE, scala=(1, 1, 0.8), contorno=0.015)
        elif tipo == "carote":
            m.tronco((0.14, 0.14), (0.0, 0.0), 0.12, (x, y, 0.52), FUOCO, contorno=0.012)
            for a in (-25, 0, 25):
                m.scatola((0.03, 0.03, 0.26), (x, y, 0.72), VERDE_S, rot=(0, a, 0), smusso=0, contorno=0)
        elif tipo == "pomodori":
            m.asta((x, y, 0.5), (x, y, 1.25), 0.018, LEGNO_S, contorno=0)
            m.sfera(0.16, (x, y, 0.95), VERDE_S, scala=(1, 1, 1.5), contorno=0.012)
            for dz, dx in ((0.85, 0.1), (1.05, -0.08), (0.75, -0.06)):
                m.sfera(0.065, (x + dx, y - 0.12, dz), ROSSO, contorno=0.01)
        elif tipo == "zucche":
            m.sfera(0.2, (x, y, 0.62), FUOCO, scala=(1.2, 1.2, 0.8), dettaglio=1, contorno=0.015)


def _aiuola(m, x0, x1, y0, y1, tipo):
    m.scatola((x1 - x0, y1 - y0, 0.42), ((x0 + x1) / 2, (y0 + y1) / 2, 0.29), ("tavole", LEGNO), smusso=0.02)
    m.scatola((x1 - x0 - 0.16, y1 - y0 - 0.16, 0.06), ((x0 + x1) / 2, (y0 + y1) / 2, 0.49), ("terra", "#5e3f2c"),
              smusso=0, contorno=0)
    for y in ((y0 + 0.2 + (y1 - y0) * 0.3), (y1 - 0.2 - (y1 - y0) * 0.05)) if y1 - y0 > 0.9 else ((y0 + y1) / 2,):
        _ortaggi(m, x0, x1, y, tipo)


def _serra(m, x0, x1, y0, y1, h=2.0, colmo=1.0, colore_telaio=BIANCO):
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    vetro = CELESTE
    m.scatola((x1 - x0, y1 - y0, 0.25), (cx, cy, 0.2), ("mattoni", MATTONE_S), smusso=0.02)
    m.scatola((x1 - x0 - 0.05, y1 - y0 - 0.05, h - 0.3), (cx, cy, 0.3 + (h - 0.3) / 2), vetro, smusso=0, alfa=0.3,
              ruvido=0.1)
    m.profilo([(y0, h), (y1, h), (cy, h + colmo)], x1 - x0 - 0.05, (cx, 0, 0), vetro, rot=(0, 0, 90), contorno=0)
    m.parti[-1].materiale = m._mat(vetro, 0.1, 0, 0, 0.3)
    m.parti[-1].guscio = None
    # telaio
    for x in (x0, cx, x1):
        for y in (y0, y1):
            m.asta((x, y, 0.3), (x, y, h), 0.035, colore_telaio, contorno=0.012)
        m.asta((x, y0, h), (x, cy, h + colmo), 0.035, colore_telaio, contorno=0.012)
        m.asta((x, y1, h), (x, cy, h + colmo), 0.035, colore_telaio, contorno=0.012)
    for y in (y0, y1, cy):
        z = h + (colmo if y == cy else 0)
        m.asta((x0, y, z), (x1, y, z), 0.035, colore_telaio, contorno=0.012)
    for y in [y0 + (y1 - y0) * k / 4 for k in (1, 3)]:
        for x in (x0, x1):
            m.asta((x, y, 0.3), (x, y, h), 0.025, colore_telaio, contorno=0)
    m.asta((x0, y0, 1.15), (x1, y0, 1.15), 0.025, colore_telaio, contorno=0)
    # piante dentro
    for i in range(3):
        for j in range(2):
            m.sfera(0.32, (x0 + 0.45 + i * (x1 - x0 - 0.9) / 2, y0 + 0.7 + j * (y1 - y0 - 1.3), 0.75),
                    [VERDE, VERDE_S, "#8cbf5a"][(i + j) % 3], scala=(1, 1, 1.3), contorno=0.012)


@edificio("orto")
def crea_orto(liv):
    m = Modello("orto_l%d" % liv)
    m.suolo(("erba", "#7da653"))
    m.scatola((2.6, 2.4, 0.04), (1.55, -1.25, 0.1), ("terra", "#6b4a33"), smusso=0, contorno=0)
    # serra con la porta verso la strada
    x0, x1, y0, y1 = -2.85, -0.35, -0.75, 2.25
    _serra(m, x0, x1, y0, y1)
    cx = (x0 + x1) / 2
    m.scatola((0.8, 0.08, 1.75), (cx, y0 - 0.03, 1.15), ("tavole", MENTA_S), smusso=0.02)
    m.sfera(0.04, (cx + 0.28, y0 - 0.1, 1.15), SENAPE, contorno=0)
    m.insegna((cx, y0 - 0.12, 2.32), 1.5, 0.48, fondo=CREMA)
    m.vialetto(cx, -2.65, y0, 0.8, ("ghiaia", "#a89c8a"))
    _aiuola(m, 0.25, 2.85, -2.35, -1.25, "cavoli")
    _aiuola(m, 0.25, 2.85, -0.95, 0.15, "pomodori")
    # spaventapasseri
    sx, sy = 1.6, 1.15
    m.asta((sx, sy, 0.08), (sx, sy, 2.1), 0.05, LEGNO_S)
    m.asta((sx - 0.6, sy, 1.6), (sx + 0.6, sy, 1.6), 0.04, LEGNO_S)
    m.scatola((0.55, 0.3, 0.6), (sx, sy, 1.45), ("tela", ROSSO_S), smusso=0.06)
    m.sfera(0.2, (sx, sy, 1.98), ("tela", SABBIA), contorno=0.015)
    m.cilindro(0.35, 0.05, (sx, sy, 2.14), SENAPE_S, lati=10)
    m.cilindro(0.17, 0.2, (sx, sy, 2.25), SENAPE_S, raggio_alto=0.12, lati=10)
    m.cilindro(0.15, 0.25, (0.0, -1.9, 0.2), ("metallo", ACCIAIO), raggio_alto=0.12, lati=10, metallo=0.4)
    m.asta((0.0, -1.9, 0.3), (0.25, -1.9, 0.45), 0.025, ACCIAIO_S, contorno=0)
    if liv == 1:
        m.staccionata(0.15, 2.95, -2.55, 0.6, LEGNO_C)
        m.cespuglio((2.5, 2.0, 0.08), 0.45)
        m.cima(3.6)
    if liv >= 2:
        _aiuola(m, 0.25, 1.15, 1.55, 2.3, "zucche")
        # barili per l'acqua piovana sotto la grondaia
        for i, x in enumerate((-0.15, 0.35)):
            m.barile((x, -0.35 + i * 0.1, 0.08), colore=TEAL, altezza=0.95, raggio=0.28)
        m.asta((-0.35, 0.0, 2.0), (-0.15, -0.3, 1.1), 0.03, ACCIAIO_S)
        # mulino a vento che pompa l'acqua
        wx, wy = 2.45, 1.7
        for dx, dy in ((-0.35, -0.35), (0.35, -0.35), (0.35, 0.35), (-0.35, 0.35)):
            m.asta((wx + dx, wy + dy, 0.08), (wx + dx * 0.25, wy + dy * 0.25, 4.6), 0.04, ACCIAIO_S, metallo=0.5)
        for z in (1.2, 2.4, 3.5):
            k = 0.35 - 0.1 * z / 1.15 * 0.75
            m.asta((wx - k, wy - k, z), (wx + k, wy - k, z), 0.025, ACCIAIO_S, contorno=0)
        m.cilindro(0.12, 0.35, (wx, wy - 0.15, 4.75), ("metallo", ROSSO), rot=(90, 0, 0), lati=8)
        for i in range(12):
            a = i * 30
            m.scatola((0.12, 0.03, 0.75), (wx + 0.5 * math.sin(math.radians(a)), wy - 0.38,
                                          4.75 + 0.5 * math.cos(math.radians(a))), ("lastre", BIANCO),
                      rot=(0, a, 0), smusso=0, contorno=0.012)
        m.scatola((0.04, 1.0, 0.5), (wx, wy + 0.55, 4.8), ("lastre", ROSSO), smusso=0, contorno=0.015)
        for x in (0.6, 0.85, 1.05):
            m.asta((x, 2.25, 0.08), (x, 2.25, 1.6 + x * 0.3), 0.03, VERDE_S, contorno=0)
            m.cilindro(0.18, 0.06, (x, 2.2, 1.6 + x * 0.3), SENAPE, rot=(80, 0, 0), lati=10, contorno=0.012)
            m.cilindro(0.08, 0.07, (x, 2.17, 1.6 + x * 0.3), MARRONE, rot=(80, 0, 0), lati=8, contorno=0)
    if liv == 2:
        m.staccionata(0.15, 2.95, -2.55, 0.6, LEGNO_C)
        m.cima(5.4)
    if liv >= 3:
        # cisterna dell'acqua dietro la serra, tubi per l'irrigazione, arnie
        m.cisterna((-1.6, 2.0, 0.08), raggio=0.75, altezza=1.1, gambe=2.8, colore=("tavole", LEGNO), tetto=VERDE_S)
        m.asta((-1.0, 1.7, 2.9), (-0.2, 1.4, 2.9), 0.05, ("metallo", ACCIAIO_S))
        m.asta((-0.2, 1.4, 2.9), (-0.2, 1.4, 0.6), 0.05, ("metallo", ACCIAIO_S))
        m.asta((-0.2, 1.4, 0.6), (-0.2, -1.8, 0.6), 0.05, ("metallo", ACCIAIO_S))
        for i in range(3):
            ax = 1.45 + i * 0.5
            for k, c in enumerate((BIANCO, SENAPE, BIANCO)):
                m.scatola((0.42, 0.4, 0.2), (ax, 2.05, 0.2 + k * 0.21), ("assi", c), smusso=0.02, contorno=0.015)
            m.scatola((0.48, 0.46, 0.06), (ax, 2.05, 0.86), MARRONE, smusso=0.02, contorno=0.015)
        m.staccionata(0.15, 2.95, -2.55, 0.75, BIANCO)
        m.albero((2.7, 0.75, 0.08), 2.8)
        for dz, dx in ((2.3, 2.6), (2.0, 2.9), (2.45, 2.85)):
            m.sfera(0.08, (dx, 0.45, dz), ROSSO, contorno=0.01)
        m.cima(5.6)
    return m


# ================================================================== NEGOZIO


@edificio("negozio")
def crea_negozio(liv):
    m = Modello("negozio_l%d" % liv)
    m.suolo(("lastre", "#b3a58f"))
    fronte = -1.2
    x0, x1 = -2.8, 1.5
    cx = (x0 + x1) / 2
    prof = 3.2
    cy = fronte + prof / 2
    h = 3.0 if liv < 3 else 4.9
    # corpo in mattoni con facciata alta "western"
    m.scatola((x1 - x0, prof, h), (cx, cy, h / 2), ("mattoni", "#b56a48"), smusso=0.03)
    hf = h + 1.0
    m.scatola((x1 - x0 + 0.2, 0.18, hf), (cx, fronte - 0.05, hf / 2), ("assi", SENAPE), smusso=0.03)
    m.scatola((x1 - x0 + 0.4, 0.3, 0.16), (cx, fronte - 0.08, hf + 0.04), BIANCO, smusso=0.03)
    for x in (x0 - 0.02, x1 + 0.02):
        m.scatola((0.18, 0.28, hf), (x, fronte - 0.06, hf / 2), BIANCO, smusso=0.02, contorno=0.02)
    zi = hf - 0.62
    m.insegna((cx, fronte - 0.18, zi), 2.9, 0.62, fondo=CREMA, bordo=TEAL, lampadine=liv >= 2)
    # vetrine e porta
    m.porta(cx + 0.95, fronte - 0.15, colore=ROSSO_S, vetro=True)
    for xv in (cx - 0.95,):
        m.scatola((1.9, 0.1, 1.5), (xv, fronte - 0.17, 1.35), BIANCO, smusso=0.02, contorno=0.02)
        m.scatola((1.7, 0.05, 1.3), (xv, fronte - 0.2, 1.35), VETRO_ACCESO, smusso=0, contorno=0, luce=0.4)
        for i in range(4):
            m.scatola((0.3, 0.2, 0.3), (xv - 0.6 + i * 0.4, fronte - 0.05, 0.85 + (i % 2) * 0.1),
                      [("lastre", ROSSO), ("lastre", TEAL), ("lastre", SENAPE), ("lastre", MENTA)][i], smusso=0.02,
                      contorno=0.015)
        m.scatola((2.0, 0.3, 0.12), (xv, fronte - 0.3, 0.55), BIANCO, smusso=0.02)
    m.tenda(cx, fronte - 0.2, x1 - x0 - 0.2, 2.55, profondita=1.0, caduta=0.45, colori=(TEAL, BIANCO))
    # merce fuori
    for i, colore in enumerate((ROSSO, "#8cbf5a", FUOCO)):
        x = x0 + 0.5 + i * 0.62
        m.cassa((x, -2.15, 0.08), 0.5, rot=i * 4)
        for k in range(3):
            m.sfera(0.1, (x - 0.12 + k * 0.12, -2.15, 0.66), colore, contorno=0.01)
    m.barile((1.0, -2.2, 0.08), colore=LEGNO_S, altezza=0.7, raggio=0.25)
    # lavagnetta delle offerte
    m.asta((0.3, -2.25, 0.08), (0.35, -2.05, 1.0), 0.025, LEGNO_S, contorno=0.01)
    m.asta((0.3, -2.25, 0.08), (0.35, -2.45, 1.0), 0.025, LEGNO_S, contorno=0.01)
    m.scatola((0.55, 0.03, 0.6), (0.33, -2.28, 0.68), SCURO, rot=(-12, 0, 0), smusso=0, contorno=0.015)
    # lato destro: bicicletta da carico e panchina
    m.scatola((1.2, 0.4, 0.06), (2.3, -0.5, 0.5), ("legno", LEGNO), smusso=0.02)
    for dx in (-0.5, 0.5):
        m.scatola((0.08, 0.35, 0.42), (2.3 + dx, -0.5, 0.29), SCURO, smusso=0, contorno=0.012)
    if liv == 1:
        m.cespuglio((2.5, 1.5, 0.08), 0.5)
        m.cima(hf + 0.7)
    if liv >= 2:
        # distributore di bibite e insegna al neon "aperto"
        m.scatola((0.8, 0.7, 1.9), (2.35, 0.75, 1.03), ("lastre", ROSSO), smusso=0.08)
        m.scatola((0.5, 0.05, 1.0), (2.2, 0.38, 1.25), VETRO_ACCESO, smusso=0, contorno=0, luce=0.8)
        m.scatola((0.12, 0.05, 0.4), (2.6, 0.38, 1.2), CROMO, smusso=0, contorno=0.01, metallo=0.6)
        m.neon([(cx - 1.6, fronte - 0.28, 1.95), (cx - 0.3, fronte - 0.28, 1.95), (cx - 0.3, fronte - 0.28, 1.75),
                (cx - 1.6, fronte - 0.28, 1.75), (cx - 1.6, fronte - 0.28, 1.95)], NEON_ROSA, 0.025)
        m.neon([(cx - 1.4, fronte - 0.3, 1.85), (cx - 0.5, fronte - 0.3, 1.85)], NEON_AZZURRO, 0.03)
        m.lampada_muro(x1 - 0.3, fronte - 0.15, 3.0)
    if liv == 2:
        m.cima(hf + 0.7)
    if liv >= 3:
        # piano di sopra abitato, cartellone pubblicitario sul tetto
        for x in (cx - 1.3, cx, cx + 1.3):
            m.finestra(x, 3.8, fronte - 0.15, larghezza=0.75, altezza=0.85, persiane=TEAL, tenda=ROSA)
        bx, by, bz = cx, cy + 0.6, h + 0.15
        for dx in (-1.4, 1.4):
            m.asta((bx + dx, by, bz), (bx + dx, by, bz + 1.3), 0.07, ACCIAIO_S, metallo=0.5)
            m.asta((bx + dx, by + 0.6, bz), (bx + dx, by, bz + 1.2), 0.04, ACCIAIO_S, contorno=0)
        m.scatola((3.6, 0.14, 1.6), (bx, by, bz + 2.1), ("lastre", CELESTE), smusso=0.03)
        m.scatola((3.8, 0.2, 0.12), (bx, by, bz + 2.95), BIANCO, smusso=0.02)
        m.scatola((3.8, 0.2, 0.12), (bx, by, bz + 1.25), BIANCO, smusso=0.02)
        # pubblicità: bottiglia di gazzosa e sole
        m.cilindro(0.22, 0.8, (bx - 0.8, by - 0.1, bz + 1.95), ("lastre", "#6fae7c"), lati=10, contorno=0.015)
        m.cilindro(0.1, 0.4, (bx - 0.8, by - 0.1, bz + 2.55), ("lastre", "#6fae7c"), raggio_alto=0.06, lati=10,
                   contorno=0.015)
        m.cilindro(0.08, 0.06, (bx - 0.8, by - 0.1, bz + 2.78), ROSSO, lati=10, contorno=0.012)
        m.scatola((0.4, 0.05, 0.25), (bx - 0.8, by - 0.33, bz + 1.95), CREMA, smusso=0, contorno=0.01)
        m.cilindro(0.45, 0.04, (bx + 0.8, by - 0.09, bz + 2.15), SENAPE, rot=(90, 0, 0), lati=14, contorno=0.015)
        for i in range(8):
            a = math.radians(i * 45)
            m.scatola((0.06, 0.04, 0.22), (bx + 0.8 + 0.6 * math.cos(a), by - 0.1, bz + 2.15 + 0.6 * math.sin(a)),
                      SENAPE, rot=(0, -math.degrees(a) + 90, 0), smusso=0, contorno=0.01)
        for dx in (-1.4, 0, 1.4):
            m.faro((bx + dx, by - 0.55, bz + 1.1), (0, 0.6, 1), raggio=0.13)
        m.bandiera((x0 + 0.3, cy + 1.0, h), 1.8)
        m.cima(h + 3.4)
    return m


# ================================================================== TAVOLA CALDA


@edificio("tavola_calda")
def crea_tavola_calda(liv):
    m = Modello("tavola_calda_l%d" % liv)
    m.suolo(("lastre", "#b9ab95"))
    m.scatola((4.4, 1.3, 0.05), (-0.4, -1.75, 0.105), ("piastrelle", BIANCO, SCURO), smusso=0, contorno=0)
    fronte = -0.95
    x0, x1 = -2.8, 1.95
    cx = (x0 + x1) / 2
    prof = 2.9
    cy = fronte + prof / 2
    h = 2.75
    # carrozzeria cromata con gli spigoli tagliati come un vagone
    m.scatola((x1 - x0, prof, 0.45), (cx, cy, 0.3), ("lastre", ROSSO_S), smusso=0.05)
    m.scatola((x1 - x0, prof, h - 0.5), (cx, cy, 0.5 + (h - 0.5) / 2), ("lamiera", CROMO), smusso=0.32, metallo=0.45,
              ruvido=0.4, uv_ruota=True)
    m.scatola((x1 - x0 + 0.04, prof + 0.04, 0.22), (cx, cy, 1.05), ROSSO, smusso=0.1, contorno=0.02)
    m.scatola((x1 - x0 + 0.04, prof + 0.04, 0.14), (cx, cy, h - 0.2), MENTA, smusso=0.06, contorno=0.02)
    m.scatola((x1 - x0 - 0.1, prof - 0.1, 0.2), (cx, cy, h + 0.08), ("metallo", ACCIAIO_S), smusso=0.06)
    # fila di finestre
    for i in range(6):
        x = x0 + 0.5 + i * 0.66
        if abs(x - (cx + 0.4)) < 0.55:
            continue
        m.scatola((0.56, 0.05, 0.85), (x, fronte - 0.01, 1.68), VETRO_ACCESO, smusso=0, contorno=0, luce=0.5)
        m.scatola((0.6, 0.12, 0.06), (x, fronte - 0.02, 2.13), CROMO, smusso=0, contorno=0.012, metallo=0.6)
        m.scatola((0.6, 0.12, 0.06), (x, fronte - 0.02, 1.23), CROMO, smusso=0, contorno=0.012, metallo=0.6)
        m.sfera(0.12, (x, fronte + 0.25, 1.5), [ROSSO, TEAL, SENAPE][i % 3], scala=(1, 1, 1.4), contorno=0.012)
    # ingresso a bussola
    ex = cx + 0.4
    m.scatola((1.3, 0.8, 2.45), (ex, fronte - 0.3, 1.3), ("lamiera", CROMO), smusso=0.12, metallo=0.45, ruvido=0.4)
    m.scatola((1.5, 1.0, 0.14), (ex, fronte - 0.35, 2.6), MENTA, smusso=0.04)
    m.porta(ex, fronte - 0.7, larghezza=0.85, colore=ROSSO, cornice=CROMO, gradino=False)
    # insegna sul tetto con lampadine
    for dx in (-1.1, 1.1):
        m.asta((cx + dx, cy, h + 0.15), (cx + dx, cy - 0.2, h + 0.75), 0.05, ACCIAIO_S, metallo=0.5)
    m.insegna((cx, cy - 0.25, h + 1.15), 2.9, 0.7, fondo=CREMA, bordo=ROSSO, cornice=MENTA_S, lampadine=True)
    # camino della cucina e condizionatore
    m.cilindro(0.16, 1.2, (x0 + 0.5, cy + 0.8, h + 0.6), ("metallo", ACCIAIO), lati=10, metallo=0.5)
    m.cilindro(0.26, 0.14, (x0 + 0.5, cy + 0.8, h + 1.25), ACCIAIO_S, raggio_alto=0.05, lati=10, metallo=0.5)
    m.condizionatore((x1 - 0.5, cy + 0.6, h + 0.18))
    m.cespuglio((x1 + 0.6, -1.9, 0.08), 0.4)
    m.cilindro(0.22, 0.75, (x0 + 0.25, -1.95, 0.45), ("metallo", MENTA_S), lati=10)
    if liv == 1:
        m.cima(h + 2.0)
    if liv >= 2:
        # tavolini all'aperto con ombrelloni e lavagna del menù
        for k, (tx, ty) in enumerate(((2.35, -1.6), (2.35, 0.4))):
            m.cilindro(0.38, 0.05, (tx, ty, 0.8), BIANCO, lati=12, contorno=0.015)
            m.asta((tx, ty, 0.08), (tx, ty, 2.2), 0.03, CROMO, metallo=0.6)
            m.cilindro(1.0, 0.45, (tx, ty, 2.25), ("righe", [ROSSO, TEAL][k], BIANCO), raggio_alto=0.05, lati=8,
                       liscio=False)
            for dx in (-0.55, 0.55):
                m.cilindro(0.17, 0.08, (tx + dx, ty, 0.5), ROSSO, lati=10, contorno=0.012)
                m.asta((tx + dx, ty, 0.08), (tx + dx, ty, 0.46), 0.025, CROMO, contorno=0)
        m.scatola((0.7, 0.06, 0.9), (x0 + 0.9, -1.95, 0.9), SCURO, rot=(-8, 0, 0), smusso=0.02)
        m.scatola((0.8, 0.08, 1.0), (x0 + 0.9, -1.92, 0.9), LEGNO, rot=(-8, 0, 0), smusso=0.02)
        for i in range(4):
            m.scatola((0.45, 0.02, 0.04), (x0 + 0.85, -1.99, 1.15 - i * 0.15), CREMA, rot=(-8, 0, 0), smusso=0,
                      contorno=0)
    if liv == 2:
        m.cima(h + 2.0)
    if liv >= 3:
        # panino gigante sul tetto e freccia al neon
        bx, by, bz = x0 + 0.95, cy + 0.2, h + 0.2
        m.cilindro(0.08, 0.6, (bx, by, bz + 0.3), ACCIAIO_S, lati=8, metallo=0.5)
        m.cilindro(0.85, 0.3, (bx, by, bz + 0.75), "#d99a4e", raggio_alto=0.9, lati=14)
        m.cilindro(0.95, 0.12, (bx, by, bz + 0.96), VERDE, lati=14, contorno=0.015)
        m.cilindro(0.9, 0.25, (bx, by, bz + 1.12), MARRONE, lati=14)
        m.scatola((1.5, 1.5, 0.06), (bx, by, bz + 1.27), SENAPE, rot=(0, 0, 45), smusso=0, contorno=0.015)
        m.sfera(0.9, (bx, by, bz + 1.32), "#e0a65a", scala=(1, 1, 0.55), liscio=True)
        for dx, dy in ((0.2, -0.5), (-0.3, -0.35), (0.45, -0.1), (-0.1, -0.6)):
            m.sfera(0.05, (bx + dx, by + dy, bz + 1.72 - abs(dx) * 0.2), CREMA, contorno=0)
        m.neon([(ex + 1.3, fronte - 1.0, 2.4), (ex + 0.9, fronte - 1.0, 2.0), (ex + 1.3, fronte - 1.0, 1.6)], NEON_ROSA)
        m.neon([(ex + 0.9, fronte - 1.0, 2.0), (ex + 1.7, fronte - 1.0, 2.0)], NEON_ROSA)
        m.cima(h + 2.4)
    return m


# ================================================================== MAGAZZINO


@edificio("magazzino")
def crea_magazzino(liv):
    m = Modello("magazzino_l%d" % liv)
    m.suolo(("cemento", CEMENTO))
    fronte = -0.85
    x0, x1 = -2.9, 1.9
    cx = (x0 + x1) / 2
    prof = 3.1
    cy = fronte + prof / 2
    h = 3.7
    m.scatola((x1 - x0, prof, h), (cx, cy, h / 2), ("mattoni", "#a85b45"), smusso=0.03)
    # facciata a gradoni
    for i, (w, z) in enumerate(((x1 - x0 + 0.1, h), (3.0, h + 0.4), (1.6, h + 0.8))):
        m.scatola((w, 0.25, 0.4 if i else 0.25), (cx, fronte - 0.02, z + 0.2), ("mattoni", "#94503d"), smusso=0.02)
        m.scatola((w + 0.1, 0.32, 0.08), (cx, fronte - 0.02, z + (0.42 if i else 0.3)), CREMA, smusso=0.02)
    m.insegna((cx, fronte - 0.2, h - 0.2), 2.5, 0.5, fondo=CREMA, bordo=ROSSO_S)
    # banchina di carico e serrande
    m.scatola((x1 - x0 + 0.2, 1.0, 0.65), (cx, fronte - 0.45, 0.33), ("cemento", CEMENTO_S), smusso=0.03)
    for xs in (cx - 1.2, cx + 1.2):
        m.scatola((1.65, 0.12, 2.3), (xs, fronte - 0.03, 1.8), CREMA, smusso=0.02)
        m.scatola((1.45, 0.08, 2.15), (xs, fronte - 0.06, 1.73), ("lamiera", SENAPE), smusso=0.01, contorno=0.015,
                  uv_ruota=True)
        m.scatola((1.5, 0.14, 0.12), (xs, fronte - 0.08, 0.72), SCURO, smusso=0.02, contorno=0.015)
        for dx in (-0.6, 0.6):
            m.scatola((0.18, 0.15, 0.3), (xs + dx, fronte - 0.97, 0.45), GOMMA, smusso=0.04, contorno=0.015)
        m.lampada_muro(xs, fronte - 0.05, 3.15)
    m.scala_pioli((x1 - 0.2, fronte - 0.98, 0.08), 0.6, colore=SENAPE_S)
    for i in range(5):
        m.finestra(x0 + 0.5 + i * (x1 - x0 - 1.0) / 4, 3.25, fronte, larghezza=0.5, altezza=0.3, persiane=None,
                   accesa=False, davanzale=False, croce=False, cornice=CREMA)
    # bancali con casse
    bancali = {1: ((2.45, -1.9), (2.45, -0.7)), 2: ((2.45, 0.55), (2.45, 1.7)), 3: ((2.45, 0.4),)}[liv]
    for i, (px, py) in enumerate(bancali):
        m.scatola((1.0, 1.0, 0.14), (px, py, 0.15), ("legno", LEGNO_C), smusso=0.01)
        m.cassa((px - 0.22, py - 0.2, 0.22), 0.5)
        m.cassa((px + 0.24, py + 0.15, 0.22), 0.45, rot=8)
        if i == 0:
            m.cassa((px, py, 0.72), 0.42, rot=-6)
    if liv == 1:
        m.barile((2.6, 0.7, 0.08), colore=TEAL)
        m.cima(h + 1.5)
    if liv >= 2:
        # muletto giallo con una cassa sulle forche
        fx, fy = 2.45, -1.0
        m.scatola((0.9, 1.2, 0.7), (fx, fy, 0.55), ("lastre", SENAPE), smusso=0.1)
        m.scatola((0.7, 0.4, 0.4), (fx, fy + 0.35, 1.05), ("lastre", SENAPE), smusso=0.08)
        for dx in (-0.35, 0.35):
            m.asta((fx + dx, fy - 0.3, 0.9), (fx + dx, fy - 0.3, 2.1), 0.03, SCURO)
            m.asta((fx + dx, fy + 0.45, 0.9), (fx + dx, fy + 0.45, 2.1), 0.03, SCURO)
        m.scatola((0.78, 0.8, 0.05), (fx, fy - 0.25, 2.12), SCURO, smusso=0, contorno=0.012)
        for dx in (-0.25, 0.25):
            m.scatola((0.08, 0.06, 1.7), (fx + dx, fy - 0.68, 0.95), ACCIAIO_S, smusso=0, contorno=0.015, metallo=0.5)
            m.scatola((0.08, 0.7, 0.05), (fx + dx, fy - 1.0, 0.25), ACCIAIO_S, smusso=0, contorno=0.015, metallo=0.5)
        m.cassa((fx, fy - 1.05, 0.28), 0.55)
        for dy in (-0.45, 0.45):
            for s in (-1, 1):
                m.copertone((fx + s * 0.48, fy + dy, 0.28), 0.22, 0.18, rot=(0, 90, 0))
        for i in range(3):
            m.barile((-2.75 + i * 0.62, -2.15, 0.08), colore=[TEAL, ROSSO_S, TEAL][i])
        m.barile((-2.45, -2.15, 0.93), colore=SENAPE_S)
    if liv == 2:
        m.cima(h + 1.5)
    if liv >= 3:
        # container e silo
        m.scatola((2.5, 1.1, 1.15), (cx - 0.6, 1.6, h + 0.65), ("lamiera", TEAL), smusso=0.03)
        sx, sy = x1 + 0.5, 1.75
        m.cilindro(0.62, 5.0, (sx, sy, 2.6), ("lamiera", CROMO), lati=14, metallo=0.4, ruvido=0.5)
        m.cilindro(0.67, 0.7, (sx, sy, 5.45), ("metallo", CROMO), raggio_alto=0.12, lati=14, metallo=0.4)
        m.scala_pioli((sx - 0.47, sy - 0.47, 0.08), 5.0, angolo=-45)
        for z in (1.3, 2.6, 3.9):
            m.cilindro(0.64, 0.08, (sx, sy, z), ACCIAIO_S, lati=14, contorno=0, metallo=0.6)
        m.cima(h + 2.6)
    return m


# ================================================================== MURA E TORRETTE


def _torretta(m, pos, angolo=0.0, colore=OLIVA):
    """Mitragliatrice su base girevole, rivolta verso -X (fuori dalle mura)."""
    x, y, z = pos
    a = math.radians(angolo)
    d = (-math.cos(a), -math.sin(a))
    m.cilindro(0.45, 0.3, (x, y, z + 0.15), ("metallo", ACCIAIO_S), lati=10, metallo=0.4)
    m.scatola((0.75, 0.65, 0.5), (x, y, z + 0.55), ("metallo", colore), rot=(0, 0, angolo), smusso=0.08, metallo=0.3)
    m.scatola((0.08, 0.9, 0.6), (x + d[0] * 0.42, y + d[1] * 0.42, z + 0.7), ("metallo", colore),
              rot=(0, 0, angolo), smusso=0.02, metallo=0.3)
    for s in (-0.13, 0.13):
        px, py = x - d[1] * s, y + d[0] * s
        m.asta((px, py, z + 0.6), (px + d[0] * 1.3, py + d[1] * 1.3, z + 0.66), 0.045, SCURO, metallo=0.6)
        m.cilindro(0.06, 0.15, (px + d[0] * 1.3, py + d[1] * 1.3, z + 0.66), SCURO, rot=(0, 90, angolo), lati=8)
    m.scatola((0.3, 0.2, 0.25), (x + d[1] * 0.42, y - d[0] * 0.42, z + 0.5), ("metallo", OLIVA), rot=(0, 0, angolo),
              smusso=0.02, contorno=0.015)


@edificio("mura_torrette")
def crea_mura_torrette(liv):
    m = Modello("mura_torrette_l%d" % liv)
    m.suolo(("terra", "#7a6550"))
    # bunker di cemento con feritoie
    x0, x1, y0, y1 = -2.75, 0.75, -0.6, 2.2
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    h = 2.4
    m.tronco((x1 - x0 + 0.3, y1 - y0 + 0.3), (x1 - x0 - 0.2, y1 - y0 - 0.2), h, (cx, cy, 0.08), ("cemento", CEMENTO))
    m.scatola((x1 - x0 + 0.1, y1 - y0 + 0.1, 0.25), (cx, cy, h + 0.2), ("cemento", CEMENTO_S), smusso=0.06)
    # mimetica dipinta a strisce
    for i, (dx, w) in enumerate(((-1.2, 0.7), (0.1, 0.9), (1.1, 0.5))):
        m.scatola((w, 0.03, 0.5), (cx + dx, y0 - 0.12, 1.2 + (i % 2) * 0.4), OLIVA, rot=(-5, 0, 0), smusso=0,
                  contorno=0)
    for x in (x0 + 0.6, x1 - 0.6):
        m.scatola((0.9, 0.1, 0.22), (x, y0 - 0.1, 1.75), SCURO, rot=(-5, 0, 0), smusso=0.02, contorno=0.015)
    m.scatola((0.9, 0.12, 1.75), (cx, y0 - 0.1, 0.95), ("metallo", OLIVA), rot=(-5, 0, 0), smusso=0.02)
    for zz in (0.5, 1.4):
        m.scatola((0.95, 0.15, 0.08), (cx, y0 - 0.16, zz), ACCIAIO_S, rot=(-5, 0, 0), smusso=0, contorno=0.012,
                  metallo=0.5)
    m.insegna((cx, y0 - 0.1, h + 0.62), 2.2, 0.5, fondo=SENAPE, bordo=SCURO, cornice=SCURO)
    for dx in (-0.9, 0.9):
        m.asta((cx + dx, y0 + 0.05, h + 0.3), (cx + dx, y0 + 0.05, h + 0.4), 0.04, SCURO, contorno=0)
    m.sacchi(x0 - 0.1, x0 + 1.4, y0 - 0.6, 2)
    m.sacchi(x1 - 1.2, x1 + 0.2, y0 - 0.6, 2)
    # torre di guardia con la prima torretta
    tx, ty = 2.0, 0.6
    for dx in (-0.6, 0.6):
        for dy in (-0.6, 0.6):
            m.cilindro(0.09, 3.0, (tx + dx, ty + dy, 1.58), ("legno", LEGNO_S), lati=7)
    for dy in (-0.6, 0.6):
        m.asta((tx - 0.6, ty + dy, 0.4), (tx + 0.6, ty + dy, 2.6), 0.045, LEGNO_S)
    m.scatola((1.6, 1.6, 0.16), (tx, ty, 3.1), ("tavole", LEGNO), smusso=0.03)
    for i in range(3):
        m.scatola((0.5, 0.35, 0.28), (tx - 0.55 + i * 0.55, ty - 0.68, 3.32), ("tela", SABBIA), smusso=0.1,
                  rot=(0, 0, i * 6 - 6))
    _torretta(m, (tx, ty, 3.18), angolo=-20)
    m.scala_pioli((tx - 0.3, ty - 0.95, 0.08), 3.0, colore=LEGNO_S)
    m.cassa((-0.3 + x1, -2.1, 0.08), 0.5, colore=OLIVA)
    m.cassa((0.25 + x1, -2.15, 0.08), 0.45, rot=10, colore=OLIVA)
    if liv == 1:
        m.cima(4.6)
    if liv >= 2:
        # seconda torretta sul bunker e filo spinato davanti
        _torretta(m, (cx - 0.4, cy + 0.3, h + 0.33), angolo=10)
        m.sacchi(cx - 1.3, cx + 0.5, cy - 0.5, 1, z=h + 0.33)
        for x in (-2.6, -1.1, 0.4):
            for k in range(6):
                a0, a1 = k * 60, (k + 1) * 60
                c = (x + 0.12 * k, -2.35)
                m.asta((c[0], c[1] + 0.25 * math.cos(math.radians(a0)), 0.35 + 0.25 * math.sin(math.radians(a0))),
                       (c[0] + 0.12, c[1] + 0.25 * math.cos(math.radians(a1)), 0.35 + 0.25 * math.sin(math.radians(a1))),
                       0.012, ACCIAIO, contorno=0, lati=4, metallo=0.7)
            m.asta((x - 0.1, -2.35, 0.08), (x - 0.1, -2.35, 0.75), 0.03, LEGNO_S)
    if liv == 2:
        m.cima(4.6)
    if liv >= 3:
        # terza torretta su un pilone, riflettore e sirena
        px, py = 2.4, 2.0
        m.cilindro(0.35, 4.2, (px, py, 2.18), ("cemento", CEMENTO), raggio_alto=0.28, lati=8, liscio=False)
        m.cilindro(0.75, 0.15, (px, py, 4.35), ("metallo", ACCIAIO_S), lati=10)
        _torretta(m, (px, py, 4.4), angolo=-35)
        m.asta((x0 + 0.3, cy + 0.9, h + 0.33), (x0 + 0.3, cy + 0.9, h + 2.6), 0.05, ACCIAIO_S, metallo=0.6)
        m.faro((x0 + 0.3, cy + 0.6, h + 2.7), (0.3, -1, 0.7), raggio=0.32)
        for a in (0, 120, 240):
            r = math.radians(a)
            m.cilindro(0.16, 0.45, (x0 + 0.3 + 0.25 * math.cos(r), cy + 0.9 + 0.25 * math.sin(r), h + 2.2), ROSSO,
                       raggio_alto=0.04, rot=(0, -80, a), lati=8)
        m.cima(5.9)
    return m


# ================================================================== ARMERIA


def _bersaglio(m, pos, raggio=0.5, rot=(90, 0, 0)):
    x, y, z = pos
    for i, c in enumerate((BIANCO, ROSSO, BIANCO, ROSSO)):
        r = raggio * (1 - i * 0.24)
        m.cilindro(r, 0.05 + i * 0.012, (x, y - i * 0.012, z), c, rot=rot, lati=16, contorno=0.015 if i == 0 else 0)


def _fucile(m, base, alto, colore=LEGNO_S):
    m.asta(base, alto, 0.035, SCURO, metallo=0.5)
    m.asta(base, (base[0], base[1], base[2] + 0.3), 0.06, colore)


@edificio("armeria")
def crea_armeria(liv):
    m = Modello("armeria_l%d" % liv)
    m.suolo(("cemento", CEMENTO))
    fronte = -1.0
    x0, x1 = -2.85, 1.55
    cx = (x0 + x1) / 2
    prof = 3.1
    cy = fronte + prof / 2
    h = 3.0
    m.scatola((x1 - x0, prof, h), (cx, cy, h / 2), ("cemento", "#8d9180"), smusso=0.04)
    m.scatola((x1 - x0 + 0.06, prof + 0.06, 0.6), (cx, cy, 0.3), ("pietra", "#8a8478"), smusso=0.03)
    m.tetto_piano(x1 - x0, prof, h, cx, cy, ("cemento", CEMENTO_S), bordo=("cemento", "#7c806f"))
    # porta blindata
    m.scatola((1.35, 0.2, 2.3), (cx, fronte - 0.05, 1.15), ("metallo", OLIVA), smusso=0.03)
    m.scatola((1.15, 0.12, 2.1), (cx, fronte - 0.12, 1.12), ("metallo", "#6b6a3c"), smusso=0.02, metallo=0.3)
    for z in (0.45, 1.1, 1.75):
        m.scatola((1.2, 0.18, 0.12), (cx, fronte - 0.18, z), ACCIAIO_S, smusso=0.02, contorno=0.015, metallo=0.5)
    m.cilindro(0.14, 0.08, (cx + 0.35, fronte - 0.25, 1.15), ACCIAIO, rot=(90, 0, 0), lati=8, metallo=0.6)
    # finestre con le sbarre
    for x in (x0 + 0.75, x1 - 0.7):
        m.finestra(x, 1.65, fronte, larghezza=0.8, altezza=0.7, persiane=None, cornice=CEMENTO_S, croce=False)
        for k in range(5):
            xx = x - 0.32 + k * 0.16
            m.asta((xx, fronte - 0.1, 1.25), (xx, fronte - 0.1, 2.05), 0.022, SCURO, contorno=0, metallo=0.6)
    m.insegna((cx, fronte - 0.1, 2.65), 2.0, 0.45, fondo=SENAPE, bordo=SCURO, cornice=SCURO)
    _bersaglio(m, (x0 + 0.75, fronte - 0.05, 2.65), 0.3)
    # strisce di pericolo sul gradino
    m.scatola((1.6, 0.6, 0.1), (cx, fronte - 0.35, 0.13), ("righe", SENAPE, SCURO), rot=(0, 0, 0), smusso=0.01,
              contorno=0.015, uv_ruota=False)
    # casse di munizioni
    for i, (x, y, z) in enumerate(((x1 + 0.6, -1.95, 0.08), (x1 + 0.65, -1.4, 0.08), (x1 + 0.62, -1.7, 0.55))):
        m.scatola((0.75, 0.45, 0.45), (x, y, z + 0.23), ("legno", OLIVA), rot=(0, 0, i * 5), smusso=0.03)
        m.scatola((0.3, 0.02, 0.1), (x, y - 0.235, z + 0.25), SENAPE, rot=(0, 0, i * 5), smusso=0, contorno=0)
    m.barile((x0 + 0.3, -2.1, 0.08), colore=OLIVA, simbolo=SENAPE)
    if liv == 1:
        m.cima(h + 1.2)
    if liv >= 2:
        # muretto di sacchi, bersaglio da tiro e rastrelliera
        m.sacchi(x0 - 0.05, x0 + 1.8, -2.3, 2, rot=0)
        tx, ty = 2.45, 1.2
        m.asta((tx - 0.3, ty, 0.08), (tx - 0.1, ty, 1.5), 0.04, LEGNO_S)
        m.asta((tx + 0.3, ty, 0.08), (tx + 0.1, ty, 1.5), 0.04, LEGNO_S)
        m.asta((tx, ty + 0.4, 0.08), (tx, ty, 1.4), 0.04, LEGNO_S)
        m.scatola((0.8, 0.05, 0.8), (tx, ty - 0.05, 1.25), ("tavole", CREMA), smusso=0, contorno=0.015)
        _bersaglio(m, (tx, ty - 0.08, 1.25), 0.34)
        for k in range(4):
            x = x0 + 1.75 + k * 0.18
            _fucile(m, (x, fronte - 0.08, 0.5), (x + 0.04, fronte - 0.08, 1.5), [LEGNO_S, SCURO][k % 2])
        m.scatola((0.9, 0.12, 0.08), (x0 + 2.02, fronte - 0.08, 1.35), LEGNO, smusso=0, contorno=0.012)
    if liv == 2:
        m.cima(h + 1.2)
    if liv >= 3:
        # proiettile gigante sul tetto e lamiere di rinforzo
        bx, by = cx + 0.9, cy + 0.3
        m.cilindro(0.5, 0.25, (bx, by, h + 0.32), ("metallo", ACCIAIO_S), lati=12, metallo=0.5)
        m.cilindro(0.38, 1.6, (bx, by, h + 1.25), ("metallo", SENAPE), lati=14, metallo=0.7, ruvido=0.35)
        m.cilindro(0.4, 0.1, (bx, by, h + 0.5), SENAPE_S, lati=14, metallo=0.7, contorno=0.015)
        m.cilindro(0.38, 0.7, (bx, by, h + 2.4), ("metallo", RUGGINE), raggio_alto=0.12, lati=14, metallo=0.7,
                   ruvido=0.35)
        m.sfera(0.13, (bx, by, h + 2.75), RUGGINE, scala=(1, 1, 0.8), liscio=True)
        for x in (x0 + 0.4, x1 - 0.3):
            m.scatola((0.5, 0.06, 2.4), (x, fronte - 0.04, 1.4), ("metallo", ACCIAIO_S), smusso=0.02, metallo=0.4)
        m.faro((x0 + 0.5, cy, h + 0.6), (0.2, -1, 0.5))
        m.asta((x0 + 0.5, cy + 0.2, h + 0.1), (x0 + 0.5, cy + 0.2, h + 0.5), 0.05, ACCIAIO_S)
        m.cima(h + 3.2)
    return m


# ================================================================== AMBULATORIO


def _croce(m, pos, lato=0.6, spessore=0.08, luce=0.0, colore=ROSSO, rot=(0, 0, 0)):
    x, y, z = pos
    m.scatola((lato, spessore, lato / 3), (x, y, z), colore, rot=rot, smusso=0.02, contorno=0.015, luce=luce)
    m.scatola((lato / 3, spessore, lato), (x, y, z), colore, rot=rot, smusso=0.02, contorno=0.015, luce=luce)


@edificio("ambulatorio")
def crea_ambulatorio(liv):
    m = Modello("ambulatorio_l%d" % liv)
    m.suolo(("lastre", "#c2b7a6"))
    fronte = -1.0
    x0, x1 = -2.85, 1.45
    cx = (x0 + x1) / 2
    prof = 3.1
    cy = fronte + prof / 2
    h = 3.1 if liv < 3 else 5.5
    m.scatola((x1 - x0, prof, h), (cx, cy, h / 2), ("intonaco", BIANCO), smusso=0.04)
    m.scatola((x1 - x0 + 0.06, prof + 0.06, 0.55), (cx, cy, 0.28), ("lastre", MENTA_S), smusso=0.03)
    m.scatola((x1 - x0 + 0.06, prof + 0.06, 0.12), (cx, cy, 2.8), MENTA, smusso=0.03, contorno=0.02)
    m.tetto_piano(x1 - x0, prof, h, cx, cy, ("cemento", CEMENTO_S), bordo=MENTA)
    # ingresso con pensilina
    ex = cx + 0.55
    m.porta(ex - 0.42, fronte, larghezza=0.8, colore=MENTA_S, gradino=False)
    m.porta(ex + 0.42, fronte, larghezza=0.8, colore=MENTA_S, gradino=False, maniglia=False)
    m.scatola((2.2, 0.8, 0.5), (ex, fronte - 0.25, 0.1), ("cemento", CEMENTO), smusso=0.03)
    m.scatola((2.4, 1.3, 0.14), (ex, fronte - 0.6, 2.45), BIANCO, smusso=0.03)
    for dx in (-1.05, 1.05):
        m.asta((ex + dx, fronte - 1.15, 0.08), (ex + dx, fronte - 1.15, 2.4), 0.05, ACCIAIO, metallo=0.5)
    m.insegna((ex, fronte - 1.3, 2.75), 2.1, 0.45, fondo=BIANCO, bordo=ROSSO, cornice=MENTA_S)
    # croce rossa illuminata e finestre con le veneziane
    m.cilindro(0.55, 0.1, (x0 + 0.8, fronte - 0.05, 2.0), BIANCO, rot=(90, 0, 0), lati=16)
    _croce(m, (x0 + 0.8, fronte - 0.12, 2.0), 0.75, luce=1.5)
    m.finestra(x0 + 0.8, 1.05, fronte, larghezza=0.85, altezza=0.65, persiane=None, tenda=None, croce=False)
    for k in range(4):
        m.scatola((0.85, 0.03, 0.04), (x0 + 0.8, fronte - 0.04, 0.85 + k * 0.14), BIANCO, smusso=0, contorno=0)
    # barella e asta della flebo
    bx, by = (x1 + 0.6, -1.8) if liv < 3 else (x0 + 0.5, cy + 2.0)
    m.scatola((0.6, 1.5, 0.12), (bx, by, 0.75), ("tela", BIANCO), smusso=0.04)
    m.scatola((0.5, 0.35, 0.12), (bx, by + 0.55, 0.85), CREMA, smusso=0.05, contorno=0.015)
    for dx in (-0.25, 0.25):
        for dy in (-0.65, 0.65):
            m.asta((bx + dx, by + dy, 0.2), (bx + dx, by + dy, 0.7), 0.025, ACCIAIO, metallo=0.6)
            m.sfera(0.07, (bx + dx, by + dy, 0.15), GOMMA, contorno=0)
    m.asta((bx + 0.45, by + 0.3, 0.08), (bx + 0.45, by + 0.3, 1.8), 0.02, ACCIAIO, metallo=0.6)
    m.asta((bx + 0.3, by + 0.3, 1.75), (bx + 0.6, by + 0.3, 1.75), 0.02, ACCIAIO, metallo=0.6)
    m.scatola((0.14, 0.06, 0.24), (bx + 0.35, by + 0.3, 1.58), CELESTE, smusso=0.02, contorno=0.012, alfa=1.0)
    m.cespuglio((x0 + 0.3, -2.1, 0.08), 0.35)
    if liv == 1:
        m.cima(h + 1.0)
    if liv >= 2:
        # tenda da campo con la croce
        tx, ty = (2.35, 0.55) if liv == 2 else (2.35, 1.45)
        m.prisma(1.4, 2.0, 1.6, (tx, ty, 0.08), ("tela", "#b9bd92"))
        _croce(m, (tx, ty - 0.52, 0.9), 0.42, 0.03, rot=(-32, 0, 0))
        m.asta((tx - 0.75, ty, 0.08), (tx - 0.75, ty, 1.75), 0.03, LEGNO_S)
        m.asta((tx + 0.75, ty, 0.08), (tx + 0.75, ty, 1.75), 0.03, LEGNO_S)
        for x in (cx - 0.6, cx + 0.2):
            m.scatola((0.6, 0.45, 0.4), (x, cy + 1.95, 0.28), ("lastre", BIANCO), smusso=0.03)
            _croce(m, (x, cy + 1.72, 0.3), 0.2, 0.02)
        m.cassa((x0 + 0.3, 2.0, 0.08), 0.5)
    if liv == 2:
        m.cima(h + 1.0)
    if liv >= 3:
        # secondo piano, croce che gira sul tetto, ambulanza
        for x in (x0 + 0.8, cx + 0.2, x1 - 0.6):
            m.finestra(x, 4.15, fronte, larghezza=0.75, altezza=0.7, persiane=MENTA_S)
        m.asta((cx, cy, h + 0.1), (cx, cy, h + 0.9), 0.06, ACCIAIO_S, metallo=0.5)
        m.cilindro(0.75, 0.14, (cx, cy - 0.05, h + 1.5), BIANCO, rot=(90, 0, 0), lati=16)
        _croce(m, (cx, cy - 0.14, h + 1.5), 1.0, 0.06, luce=2.0)
        m.furgone((2.35, -1.05, 0.08), rot=-90, croce=True)
        m.cima(h + 2.3)
    return m


# ================================================================== BAR


def _bicchiere_neon(m, x, y, z, s=1.0, colore=NEON_AZZURRO):
    m.neon([(x - 0.35 * s, y, z + 0.5 * s), (x, y, z), (x + 0.35 * s, y, z + 0.5 * s),
            (x - 0.35 * s, y, z + 0.5 * s)], colore)
    m.neon([(x, y, z), (x, y, z - 0.4 * s)], colore)
    m.neon([(x - 0.2 * s, y, z - 0.4 * s), (x + 0.2 * s, y, z - 0.4 * s)], colore)
    m.sfera(0.07 * s, (x + 0.1 * s, y - 0.02, z + 0.3 * s), VERDE, contorno=0, luce=2.0)


def _sgabello(m, x, y, h=0.65, colore=ROSSO):
    m.asta((x, y, 0.08), (x, y, h), 0.03, CROMO, metallo=0.6, contorno=0)
    m.cilindro(0.17, 0.08, (x, y, h + 0.04), colore, lati=10, contorno=0.012)


@edificio("bar")
def crea_bar(liv):
    m = Modello("bar_l%d" % liv)
    m.suolo(("lastre", "#ab9c87"))
    fronte = -0.9
    x0, x1 = -2.85, 1.35
    cx = (x0 + x1) / 2
    prof = 3.0
    cy = fronte + prof / 2
    h = 3.3
    m.scatola((x1 - x0, prof, h), (cx, cy, h / 2), ("mattoni", "#8a4a3c"), smusso=0.03)
    m.tetto_piano(x1 - x0, prof, h, cx, cy, ("cemento", CEMENTO_S), bordo=("mattoni", "#6e3a30"))
    # zoccolo in legno scuro, vetrina e porta con l'oblò
    m.scatola((x1 - x0 + 0.08, 0.1, 1.0), (cx, fronte - 0.04, 0.5), ("tavole", MARRONE), smusso=0.02)
    wx = cx - 0.7
    m.scatola((2.3, 0.1, 1.35), (wx, fronte - 0.08, 1.75), ("legno", MARRONE), smusso=0.02)
    m.scatola((2.1, 0.05, 1.15), (wx, fronte - 0.12, 1.75), "#c97a3c", smusso=0, contorno=0, luce=0.35)
    for x in (wx - 0.7, wx + 0.5):
        m.sfera(0.13, (x, fronte + 0.2, 1.5), SCURO, scala=(1, 1, 1.5), contorno=0)
        m.sfera(0.1, (x, fronte + 0.2, 1.8), SCURO, contorno=0)
    _bicchiere_neon(m, wx + 0.55, fronte - 0.18, 1.85, 0.6, NEON_AZZURRO)
    px = x1 - 0.65
    m.porta(px, fronte, larghezza=0.85, colore=("legno", MARRONE), vetro=False, gradino=True)
    m.cilindro(0.17, 0.05, (px, fronte - 0.12, 1.55), "#e09a4e", rot=(90, 0, 0), lati=12, contorno=0.015,
               luce=0.6)
    m.insegna((cx, fronte - 0.12, 2.85), 2.6, 0.5, fondo=SCURO, bordo=NEON_ROSA, cornice=MARRONE, lampadine=True)
    m.lampada_muro(x0 + 0.3, fronte, 2.5)
    # botti come tavolini
    for i, x in enumerate((x0 + 0.5, 0.0)):
        m.barile((x, -2.0, 0.08), colore=LEGNO_S, altezza=0.9, raggio=0.3)
        _sgabello(m, x + 0.45, -1.95, colore=ROSSO if i else TEAL)
        m.cilindro(0.05, 0.18, (x - 0.08, -2.0, 1.07), "#e3a33a", lati=8, contorno=0.01, alfa=1.0)
    if liv == 1:
        m.cassa((x1 + 0.7, 1.3, 0.08), 0.5)
        m.barile((x1 + 0.7, 0.5, 0.08), colore=LEGNO_S)
        m.cima(h + 1.0)
    if liv >= 2:
        # dehors con pedana, luci a festone e ombrellone
        m.scatola((1.7, 3.4, 0.16), (x1 + 0.85, -0.6, 0.16), ("tavole", LEGNO_C), smusso=0.02, uv_ruota=True)
        for y in (-2.2, 1.0):
            m.asta((x1 + 1.6, y, 0.2), (x1 + 1.6, y, 2.6), 0.04, LEGNO_S)
        m.luci_filo((x1 + 1.6, -2.2, 2.55), (x1 + 1.6, 1.0, 2.55), n=8, cedimento=0.3)
        m.luci_filo((x1, fronte - 0.1, 2.6), (x1 + 1.6, -2.2, 2.55), n=5, cedimento=0.2)
        m.cilindro(0.35, 0.05, (x1 + 0.8, -1.3, 0.85), ("legno", LEGNO), lati=10, contorno=0.015)
        m.asta((x1 + 0.8, -1.3, 0.24), (x1 + 0.8, -1.3, 0.85), 0.04, SCURO, contorno=0)
        for dy in (-0.45, 0.45):
            _sgabello(m, x1 + 0.8, -1.3 + dy, 0.5, NEON_ROSA if dy < 0 else SENAPE)
        m.cilindro(0.35, 0.05, (x1 + 0.8, 0.3, 0.85), ("legno", LEGNO), lati=10, contorno=0.015)
        m.asta((x1 + 0.8, 0.3, 0.24), (x1 + 0.8, 0.3, 0.85), 0.04, SCURO, contorno=0)
        m.sfera(0.05, (x1 + 0.8, 0.3, 0.94), LUCE_CALDA, contorno=0, luce=3.0)
    if liv == 2:
        m.cima(h + 1.0)
    if liv >= 3:
        # terrazza sul tetto con ringhiera, piante e grande insegna verticale
        for y in (fronte + 0.1, cy + prof / 2 - 0.1):
            m.asta((x0 + 0.1, y, h + 1.1), (x1 - 0.1, y, h + 1.1), 0.03, CROMO, metallo=0.6)
        for x in (x0 + 0.1, cx, x1 - 0.1):
            m.asta((x, fronte + 0.1, h + 0.3), (x, fronte + 0.1, h + 1.1), 0.03, CROMO, metallo=0.6)
        for x in (x0 + 0.5, x1 - 0.5):
            m.cilindro(0.25, 0.45, (x, cy + 0.9, h + 0.5), ("mattoni", MATTONE), raggio_alto=0.3, lati=8)
            for a in range(0, 360, 60):
                m.scatola((0.08, 0.6, 0.03), (x + 0.25 * math.cos(math.radians(a)), cy + 0.9 + 0.25 * math.sin(math.radians(a)),
                                              h + 1.05), VERDE, rot=(25, 0, a + 90), smusso=0, contorno=0.01)
        m.luci_filo((x0 + 0.1, fronte + 0.1, h + 1.6), (x1 - 0.1, fronte + 0.1, h + 1.6), n=10, cedimento=0.25)
        m.cilindro(0.85, 0.05, (cx - 0.5, cy + 0.2, h + 1.6), ("righe", NEON_ROSA, BIANCO), raggio_alto=0.05, lati=8,
                   liscio=False)
        m.asta((cx - 0.5, cy + 0.2, h + 0.15), (cx - 0.5, cy + 0.2, h + 1.6), 0.03, CROMO)
        # insegna a bandiera con la coppa
        vx = x0 + 0.25
        m.scatola((0.12, 0.85, 2.2), (vx, fronte - 0.45, h + 0.6), SCURO, smusso=0.03)
        for dz in range(5):
            m.sfera(0.05, (vx - 0.08, fronte - 0.85, h - 0.4 + dz * 0.5), LUCE_CALDA, contorno=0, luce=2.5)
            m.sfera(0.05, (vx - 0.08, fronte - 0.05, h - 0.4 + dz * 0.5), LUCE_CALDA, contorno=0, luce=2.5)
        m.neon([(vx - 0.08, fronte - 0.75, h + 1.2), (vx - 0.08, fronte - 0.45, h + 0.75),
                (vx - 0.08, fronte - 0.15, h + 1.2), (vx - 0.08, fronte - 0.75, h + 1.2)], NEON_ROSA)
        m.neon([(vx - 0.08, fronte - 0.45, h + 0.75), (vx - 0.08, fronte - 0.45, h + 0.25)], NEON_ROSA)
        m.cima(h + 2.0)
    return m


# ================================================================== OFFICINA


def _chiave_inglese(m, pos, s=1.0, colore=CROMO):
    x, y, z = pos
    m.asta((x - 0.35 * s, y, z - 0.35 * s), (x + 0.35 * s, y, z + 0.35 * s), 0.07 * s, colore, metallo=0.6, lati=6)
    for k in (-1, 1):
        cx, cz = x + k * 0.42 * s, z + k * 0.42 * s
        m.cilindro(0.17 * s, 0.06, (cx, y, cz), colore, rot=(90, 0, 0), lati=8, metallo=0.6)
        m.cilindro(0.08 * s, 0.07, (cx + k * 0.06 * s, y - 0.01, cz + k * 0.06 * s), SCURO, rot=(90, 0, 0), lati=6,
                   contorno=0)


def _bombola(m, pos, colore):
    x, y, z = pos
    m.cilindro(0.14, 0.9, (x, y, z + 0.45), colore, lati=10)
    m.sfera(0.14, (x, y, z + 0.9), colore, scala=(1, 1, 0.7))
    m.cilindro(0.04, 0.12, (x, y, z + 1.05), ACCIAIO, lati=6, metallo=0.6, contorno=0.01)


@edificio("officina")
def crea_officina(liv):
    m = Modello("officina_l%d" % liv)
    m.suolo(("cemento", "#9a948c"))
    fronte = -1.0
    x0, x1 = -2.85, 1.35
    cx = (x0 + x1) / 2
    prof = 3.1
    cy = fronte + prof / 2
    h = 3.3
    m.scatola((x1 - x0, prof, 1.3), (cx, cy, 0.65), ("mattoni", "#9b5a46"), smusso=0.03)
    m.scatola((x1 - x0 - 0.06, prof - 0.06, h - 1.3), (cx, cy, 1.3 + (h - 1.3) / 2), ("lamiera", "#6f8a91"),
              smusso=0.03)
    # tetto a shed con vetrate
    for i in range(2):
        sx = x0 + (i + 0.5) * (x1 - x0) / 2
        m.profilo([(-1.05, 0), (1.05, 0), (1.05, 0.9)], prof + 0.2, (sx, cy, h), ("lamiera", ACCIAIO_S), rot=(0, 0, 0))
        m.scatola((0.05, prof - 0.2, 0.75), (sx + 1.04, cy, h + 0.45), CELESTE, smusso=0, contorno=0.015, ruvido=0.2)
    # portone aperto con l'auto sul ponte sollevatore
    dx0 = cx - 0.55
    m.scatola((2.5, 0.15, 2.55), (dx0, fronte - 0.03, 1.3), ("metallo", SENAPE), smusso=0.03)
    m.scatola((2.2, 0.1, 2.3), (dx0, fronte - 0.06, 1.2), "#1e1a22", smusso=0, contorno=0)
    m.scatola((2.2, 0.1, 0.35), (dx0, fronte - 0.1, 2.2), ("lamiera", SENAPE_S), smusso=0.01, contorno=0.015,
              uv_ruota=True)
    for dx in (-0.95, 0.95):
        m.scatola((0.14, 0.14, 1.9), (dx0 + dx, fronte + 0.4, 1.0), ("metallo", ROSSO_S), smusso=0.02)
    m.scatola((2.0, 0.6, 0.08), (dx0, fronte + 0.45, 0.8), ("metallo", ACCIAIO_S), smusso=0.01, contorno=0.015)
    m.auto((dx0, fronte + 0.6, 0.5), colore=SALMONE, rot=0, lunghezza=2.0)
    m.insegna((dx0, fronte - 0.12, 2.95), 2.0, 0.45, fondo=CREMA, bordo=TEAL)
    _chiave_inglese(m, (x1 - 0.55, fronte - 0.1, 2.3), 0.7)
    m.finestra(x1 - 0.55, 1.4, fronte, larghezza=0.6, altezza=0.6, persiane=None, accesa=True, cornice=SENAPE)
    # gomme, fusti d'olio, bombole
    for i in range(4):
        m.copertone((x1 + 0.55, -1.9, 0.2 + i * 0.25), 0.36, 0.24)
    m.barile((x1 + 0.7, -0.9, 0.08), colore=SCURO, simbolo=SENAPE)
    m.barile((x1 + 1.2, -1.15, 0.08), colore=TEAL, simbolo=BIANCO)
    _bombola(m, (x0 + 0.25, -1.6, 0.08), ROSSO)
    _bombola(m, (x0 + 0.55, -1.75, 0.08), VERDE_S)
    if liv == 1:
        m.cima(h + 1.5)
    if liv >= 2:
        # forgia con il camino acceso e incudine
        fx, fy = x0 + 0.5, cy + 1.0
        m.scatola((0.7, 0.7, h + 1.5), (fx, fy, (h + 1.5) / 2 + 0.08), ("mattoni", MATTONE), smusso=0.03)
        m.scatola((0.85, 0.85, 0.15), (fx, fy, h + 1.65), CEMENTO_S, smusso=0.02)
        m.cilindro(0.18, 0.2, (fx, fy, h + 1.8), FUOCO, raggio_alto=0.05, lati=6, liscio=False, luce=3.0)
        ax, ay = -0.15, -1.85
        m.cilindro(0.18, 0.5, (ax, ay, 0.33), ("legno", LEGNO_S), lati=8)
        m.profilo([(-0.3, 0), (0.2, 0), (0.25, 0.12), (0.45, 0.2), (-0.3, 0.2)], 0.22, (ax, ay, 0.58),
                  ("metallo", SCURO), metallo=0.6)
        m.barile((ax + 0.6, ay - 0.1, 0.08), colore=ACCIAIO_S, altezza=0.6, raggio=0.28)
    if liv == 2:
        m.cima(h + 2.1)
    if liv >= 3:
        # carroponte sul cortile con un motore appeso
        gx, gy0, gy1 = x1 + 0.85, -2.3, 1.9
        for gy in (gy0, gy1):
            m.asta((gx - 0.55, gy, 0.08), (gx, gy, 3.6), 0.07, ("metallo", SENAPE), metallo=0.4)
            m.asta((gx + 0.55, gy, 0.08), (gx, gy, 3.6), 0.07, ("metallo", SENAPE), metallo=0.4)
        m.scatola((0.25, gy1 - gy0 + 0.3, 0.3), (gx, (gy0 + gy1) / 2, 3.75), ("metallo", SENAPE), smusso=0.03)
        m.scatola((0.35, 0.4, 0.3), (gx, 0.2, 3.45), ("lastre", ROSSO_S), smusso=0.04)
        m.asta((gx, 0.2, 3.3), (gx, 0.2, 2.1), 0.015, SCURO, contorno=0)
        m.scatola((0.6, 0.45, 0.5), (gx, 0.2, 1.8), ("metallo", ACCIAIO_S), smusso=0.05, metallo=0.5)
        for k in range(3):
            m.cilindro(0.06, 0.2, (gx - 0.18 + k * 0.18, 0.2, 2.12), SCURO, lati=6, contorno=0.01)
        # generatore
        m.scatola((0.9, 0.6, 0.7), (-1.3, -2.0, 0.43), ("lastre", VERDE_S), smusso=0.06)
        m.cilindro(0.06, 0.5, (-1.0, -2.0, 1.0), ACCIAIO_S, lati=6, contorno=0.012)
        m.cima(h + 2.1)
    return m


# ================================================================== RADIO


def _traliccio(m, base, altezza, larghezza=0.9, colore=ROSSO, colore2=BIANCO):
    x, y, z = base
    gambe = [(x + larghezza * math.cos(math.radians(a)), y + larghezza * math.sin(math.radians(a)))
             for a in (90, 210, 330)]
    cima = 0.18

    def punto(i, t):
        gx, gy = gambe[i]
        k = 1 - t * (1 - cima / larghezza)
        return (x + (gx - x) * k, y + (gy - y) * k, z + altezza * t)

    tratti = int(altezza / 1.0)
    for i in range(3):
        for s in range(tratti):
            t0, t1 = s / tratti, (s + 1) / tratti
            c = colore if s % 2 == 0 else colore2
            m.asta(punto(i, t0), punto(i, t1), 0.045, c, metallo=0.3)
            j = (i + 1) % 3
            m.asta(punto(i, t0), punto(j, t1), 0.02, ACCIAIO_S, contorno=0, lati=4)
            m.asta(punto(i, t1), punto(j, t1), 0.022, ACCIAIO_S, contorno=0, lati=4)
    m.asta((x, y, z + altezza), (x, y, z + altezza + 1.2), 0.03, ACCIAIO_S, metallo=0.6)
    m.sfera(0.12, (x, y, z + altezza + 1.25), ROSSO, contorno=0.012, luce=4.0)
    return z + altezza + 1.4


def _parabola(m, pos, raggio=0.7, inclinazione=35, angolo=0):
    x, y, z = pos
    m.cilindro(0.08, 0.6, (x, y, z + 0.3), ACCIAIO_S, lati=8, metallo=0.5)
    m.cilindro(0.12, raggio * 0.35, (x, y, z + 0.75), ("lastre", BIANCO), raggio_alto=raggio, rot=(inclinazione, 0, angolo),
               lati=14)
    r = math.radians(angolo)
    m.asta((x, y, z + 0.75), (x + math.sin(r) * raggio * 0.55, y - math.cos(r) * raggio * 0.55, z + 0.75 + raggio * 0.5),
           0.02, ACCIAIO_S, contorno=0)


@edificio("radio")
def crea_radio(liv):
    m = Modello("radio_l%d" % liv)
    m.suolo(("ghiaia", "#968b7c"))
    fronte = -0.6
    x0, x1 = -2.85, -0.2 if liv < 3 else 0.6
    cx = (x0 + x1) / 2
    prof = 2.7
    cy = fronte + prof / 2
    h = 2.7
    m.scatola((x1 - x0, prof, h), (cx, cy, h / 2), ("assi", "#d9c69a"), smusso=0.03)
    m.scatola((x1 - x0 + 0.06, prof + 0.06, 0.35), (cx, cy, 0.18), ("cemento", CEMENTO_S), smusso=0.02)
    m.tetto_falde(x1 - x0, prof, 0.8, (cx, cy, h), ("lamiera", TEAL_S), timpano=("assi", "#d9c69a"))
    m.porta(x0 + 0.65, fronte, larghezza=0.8, colore=("tavole", TEAL))
    m.finestra(x0 + 1.75, 1.5, fronte, larghezza=0.8, altezza=0.65, persiane=ROSSO_S)
    m.insegna((cx + 0.15 if liv < 3 else x0 + 1.3, fronte - 0.1, h - 0.3), 1.9, 0.42, fondo=CREMA, bordo=ROSSO)
    # spia "in onda"
    m.scatola((0.5, 0.12, 0.22), (x0 + 0.65, fronte - 0.08, 2.35), ROSSO, smusso=0.03, luce=2.0)
    _parabola(m, (cx + 0.5, cy + 0.6, h + 0.25), 0.4, 40, 15)
    # traliccio
    altezza = 6.0 if liv == 1 else (7.0 if liv == 2 else 8.6)
    tx, ty = 1.85, 0.9
    cima = _traliccio(m, (tx, ty, 0.08), altezza, 0.85 if liv < 3 else 1.0)
    for a in (40, 160, 280):
        r = math.radians(a)
        m.asta((tx, ty, 0.08 + altezza * 0.7), (tx + 1.3 * math.cos(r), ty + 1.3 * math.sin(r) * 0.8, 0.12), 0.01,
               SCURO, contorno=0, lati=4)
    m.cilindro(0.12, 0.25, (tx, ty, 0.2), ("cemento", CEMENTO), raggio_alto=0.12, lati=6)
    # generatore e cavi
    m.scatola((0.8, 0.5, 0.6), (0.4, -1.9, 0.38), ("lastre", SENAPE), smusso=0.06)
    m.cilindro(0.05, 0.4, (0.65, -1.9, 0.85), ACCIAIO_S, lati=6, contorno=0.01)
    m.asta((0.0, -1.9, 0.4), (x1, fronte + 0.5, 0.3), 0.02, SCURO, contorno=0)
    m.barile((1.1, -2.0, 0.08), colore=ROSSO_S)
    if liv >= 2:
        _parabola(m, (2.35, -1.6, 0.08), 0.85, 30, -20)
        for a, z in ((200, 0.7), (330, 0.72)):
            r = math.radians(a)
            px, py = tx + 0.25 * math.cos(r), ty + 0.25 * math.sin(r)
            m.cilindro(0.22, 0.45, (px, py - 0.2, altezza * z), ("metallo", ACCIAIO), raggio_alto=0.06,
                       rot=(80, 0, a - 90 if a == 200 else 0), lati=10, metallo=0.5)
    if liv >= 3:
        m.pannello_solare((x1 - 0.6, cy + 0.6, h + 0.35), 1.0, 0.7, 25)
        m.neon([(x1 - 1.5, fronte - 0.12, 1.8), (x1 - 0.5, fronte - 0.12, 1.8)], NEON_ROSA)
        m.finestra(x1 - 1.0, 1.25, fronte, larghezza=0.9, altezza=0.65, persiane=None)
        m.bandiera((x0 + 0.3, cy + 1.0, h + 0.4), 1.6, colore=TEAL)
    m.cima(cima - 0.6)
    return m


# ================================================================== PALESTRA


def _manubrio(m, pos, lunghezza=1.3, rot=0, dischi=SCURO):
    x, y, z = pos
    a = math.radians(rot)
    dx, dy = math.cos(a) * lunghezza / 2, math.sin(a) * lunghezza / 2
    m.asta((x - dx, y - dy, z), (x + dx, y + dy, z), 0.025, CROMO, metallo=0.7, contorno=0.01)
    for k in (-0.8, 0.8):
        m.cilindro(0.2, 0.08, (x + dx * k, y + dy * k, z), dischi, rot=(0, 90, rot), lati=12)


@edificio("palestra")
def crea_palestra(liv):
    m = Modello("palestra_l%d" % liv)
    m.suolo(("lastre", "#b8ab96"))
    fronte = -0.9
    x0, x1 = -2.85, 0.85
    cx = (x0 + x1) / 2
    prof = 3.0
    cy = fronte + prof / 2
    h = 3.4 if liv < 3 else 5.6
    m.scatola((x1 - x0, prof, h), (cx, cy, h / 2), ("mattoni", "#a34e3f"), smusso=0.03)
    m.tetto_piano(x1 - x0, prof, h, cx, cy, ("cemento", CEMENTO_S), bordo=CREMA)
    m.scatola((x1 - x0 + 0.06, 0.1, 0.5), (cx, fronte - 0.04, h - 0.5), CREMA, smusso=0.02)
    m.insegna((cx, fronte - 0.12, h - 0.5), 2.6, 0.42, fondo=SENAPE, bordo=ROSSO, cornice=MARRONE)
    for x in (x0 + 0.75, x1 - 0.75):
        m.finestra(x, 1.65, fronte, larghezza=1.0, altezza=1.25, persiane=None, cornice=CREMA)
    m.porta(cx, fronte, larghezza=0.9, colore=ROSSO_S)
    # manubrio dipinto sopra la porta
    _manubrio(m, (cx, fronte - 0.12, 2.55), 1.0, dischi=SCURO)
    # tettoia con il sacco da boxe
    tx = x1 + 1.05
    for y in (-2.1, 0.6):
        m.asta((tx + 0.85, y, 0.08), (tx + 0.85, y, 2.6), 0.06, LEGNO_S)
    m.scatola((2.0, 3.2, 0.1), (tx + 0.05, -0.75, 2.65), ("lamiera", ACCIAIO), rot=(-8, 0, 0), smusso=0.02)
    m.asta((tx + 0.85, -2.1, 2.55), (x1, -2.1, 2.55), 0.05, LEGNO_S)
    m.asta((tx + 0.3, -1.6, 2.55), (tx + 0.3, -1.6, 2.0), 0.015, SCURO, contorno=0)
    m.cilindro(0.24, 1.0, (tx + 0.3, -1.6, 1.45), ("tela", ROSSO), lati=10)
    m.sfera(0.24, (tx + 0.3, -1.6, 1.0), ("tela", ROSSO), scala=(1, 1, 0.4))
    # rastrelliera con bilanciere e kettlebell
    m.scatola((0.08, 0.08, 1.1), (tx - 0.1, -0.2, 0.63), ACCIAIO_S, smusso=0, contorno=0.012, metallo=0.5)
    m.scatola((0.08, 0.08, 1.1), (tx - 0.1, 0.6, 0.63), ACCIAIO_S, smusso=0, contorno=0.012, metallo=0.5)
    _manubrio(m, (tx - 0.05, 0.2, 1.15), 1.6, rot=90, dischi=ROSSO_S)
    for i, c in enumerate((SCURO, TEAL)):
        m.sfera(0.16, (tx + 0.5 + i * 0.4, 0.2, 0.25), c, liscio=True, contorno=0.012)
        m.cilindro(0.1, 0.03, (tx + 0.5 + i * 0.4, 0.2, 0.44), c, rot=(90, 0, 0), lati=8, contorno=0.01)
    m.cespuglio((x0 + 0.3, -2.1, 0.08), 0.35)
    if liv >= 2:
        # gomme da ribaltare e sbarra per le trazioni
        m.copertone((x0 + 0.9, -2.0, 0.24), 0.55, 0.35)
        m.copertone((-0.6, -2.05, 0.24), 0.45, 0.3)
        px = x1 + 1.55
        m.asta((px - 0.6, 1.6, 0.08), (px - 0.6, 1.6, 2.2), 0.05, ACCIAIO_S, metallo=0.5)
        m.asta((px + 0.4, 1.6, 0.08), (px + 0.4, 1.6, 2.2), 0.05, ACCIAIO_S, metallo=0.5)
        m.asta((px - 0.6, 1.6, 2.15), (px + 0.4, 1.6, 2.15), 0.035, CROMO, metallo=0.7)
    if liv >= 3:
        # secondo piano, canestro e muro d'arrampicata
        for x in (x0 + 0.75, cx, x1 - 0.75):
            m.finestra(x, 3.9, fronte, larghezza=0.8, altezza=0.8, persiane=None, cornice=CREMA)
        m.scatola((0.12, 1.2, 0.9), (x0 + 0.06, cy - 0.3, 3.3), BIANCO, smusso=0.02)
        m.cilindro(0.25, 0.04, (x0 - 0.25, cy - 0.3, 3.0), FUOCO, lati=12, contorno=0.012)
        holds = [(-0.6, 1.2), (0.3, 1.6), (-0.2, 2.2), (0.5, 2.7), (-0.5, 3.1), (0.1, 3.6), (-0.3, 4.2), (0.4, 4.6)]
        for i, (dy, z) in enumerate(holds):
            m.sfera(0.1, (x1 + 0.05, cy + dy, z), [ROSSO, SENAPE, TEAL, VERDE][i % 4], scala=(0.6, 1, 1),
                    contorno=0.01)
        m.bandiera((cx + 1.0, cy + 0.8, h), 1.4, colore=ROSSO, colore2=SENAPE)
    m.cima(h + (1.0 if liv < 3 else 1.6))
    return m


# ================================================================== BIBLIOTECA


@edificio("biblioteca")
def crea_biblioteca(liv):
    m = Modello("biblioteca_l%d" % liv)
    m.suolo(("erba", "#7da653"))
    fronte = -0.5
    x0, x1 = -2.75, 1.25
    cx = (x0 + x1) / 2
    prof = 2.8
    cy = fronte + prof / 2
    h = 3.6
    pietra = ("pietra", "#c9bb9c")
    # podio, corpo, cornicione
    m.scatola((x1 - x0 + 0.3, prof + 0.3, 0.45), (cx, cy, 0.3), pietra, smusso=0.03)
    m.scatola((x1 - x0, prof, h), (cx, cy, 0.5 + h / 2), ("intonaco", CREMA), smusso=0.03)
    m.scatola((x1 - x0 + 0.3, prof + 0.3, 0.25), (cx, cy, h + 0.62), CREMA_S, smusso=0.04)
    # pronao con colonne e timpano
    py = fronte - 0.85
    for k in range(4):
        x = cx - 1.35 + k * 0.9
        m.cilindro(0.17, 0.12, (x, py, 0.58), CREMA_S, lati=10)
        m.cilindro(0.15, 2.95, (x, py, 2.1), ("intonaco", BIANCO), lati=10)
        m.scatola((0.4, 0.4, 0.14), (x, py, 3.62), CREMA_S, smusso=0.03)
    m.scatola((3.4, 1.1, 0.12), (cx, fronte - 0.4, 0.48), pietra, smusso=0.02)
    for i in range(3):
        m.scatola((3.0 - i * 0.0, 0.32, 0.15), (cx, fronte - 1.05 - i * 0.28, 0.4 - i * 0.14), pietra, smusso=0.02)
    m.scatola((3.4, 1.2, 0.45), (cx, fronte - 0.45, 3.92), ("intonaco", CREMA), smusso=0.03)
    m.insegna((cx, fronte - 1.08, 3.92), 2.4, 0.36, fondo=CREMA, bordo=SENAPE_S, cornice=CREMA_S, testo=MARRONE)
    m.prisma(1.2, 3.6, 0.85, (cx, fronte - 0.45, 4.15), ("intonaco", CREMA), rot=(0, 0, 90))
    m.scatola((3.8, 0.14, 0.1), (cx, fronte - 1.05, 4.18), CREMA_S, smusso=0.02, contorno=0.015)
    m.cilindro(0.22, 0.06, (cx, fronte - 1.04, 4.5), SENAPE, rot=(90, 0, 0), lati=12, contorno=0.015)
    # portone e finestre alte
    m.porta(cx, fronte, larghezza=1.1, altezza=2.3, colore=("legno", LEGNO_S), vetro=False, gradino=False)
    for x in (x0 + 0.45, x1 - 0.45):
        m.finestra(x, 2.2, fronte, larghezza=0.55, altezza=1.5, persiane=None, cornice=CREMA_S)
        m.cilindro(0.29, 0.1, (x, fronte - 0.02, 3.0), CREMA_S, rot=(90, 0, 0), lati=12, contorno=0.015)
    # lampioni e cassetta per i libri
    for x in (cx - 1.9, cx + 1.9):
        m.asta((x, -2.35, 0.08), (x, -2.35, 2.0), 0.04, SCURO, metallo=0.5)
        m.sfera(0.17, (x, -2.35, 2.15), LUCE_CALDA, contorno=0.015, luce=2.0)
    m.scatola((0.5, 0.45, 0.85), (x1 + 0.6, -1.9, 0.5), ("lastre", TEAL), smusso=0.06)
    m.scatola((0.3, 0.05, 0.06), (x1 + 0.6, -2.14, 0.75), SCURO, smusso=0, contorno=0)
    m.cespuglio((x0 + 0.35, -1.8, 0.08), 0.35)
    if liv == 1:
        m.albero((x1 + 0.9, 1.0, 0.08), 3.0)
    if liv >= 2:
        # giardino di lettura: siepi, panchina, busto su piedistallo
        gx = x1 + 0.9
        m.scatola((0.4, 3.6, 0.6), (gx + 0.75, 0.0, 0.38), VERDE_S, smusso=0.12)
        m.scatola((0.5, 1.2, 0.08), (gx, 0.6, 0.48), ("legno", LEGNO), smusso=0.02)
        m.scatola((0.08, 1.2, 0.5), (gx + 0.24, 0.6, 0.78), ("legno", LEGNO), smusso=0.02)
        for dy in (0.1, 1.1):
            m.scatola((0.4, 0.06, 0.42), (gx, dy, 0.28), SCURO, smusso=0, contorno=0.012)
        m.scatola((0.4, 0.4, 1.0), (gx, -0.9, 0.58), pietra, smusso=0.03)
        m.scatola((0.45, 0.28, 0.25), (gx, -0.9, 1.2), ("pietra", BIANCO), smusso=0.08)
        m.sfera(0.17, (gx, -0.9, 1.5), ("pietra", BIANCO), scala=(0.9, 1, 1.1))
        m.albero((gx + 0.3, 1.8, 0.08), 2.6)
    if liv >= 3:
        # cupola con l'orologio
        dx, dy = cx, cy + 0.3
        m.cilindro(1.05, 0.9, (dx, dy, h + 1.2), ("intonaco", CREMA), lati=16)
        m.cilindro(1.12, 0.12, (dx, dy, h + 1.7), CREMA_S, lati=16)
        m.sfera(1.05, (dx, dy, h + 1.7), ("lamiera", "#5f9e8f"), scala=(1, 1, 0.75), dettaglio=2)
        m.cilindro(0.18, 0.5, (dx, dy, h + 2.65), CREMA_S, lati=8)
        m.sfera(0.15, (dx, dy, h + 3.0), SENAPE, liscio=True)
        m.cilindro(0.4, 0.06, (dx, dy - 1.05, h + 1.2), BIANCO, rot=(90, 0, 0), lati=16)
        m.cilindro(0.44, 0.04, (dx, dy - 1.03, h + 1.2), SENAPE, rot=(90, 0, 0), lati=16, contorno=0.015)
        m.asta((dx, dy - 1.1, h + 1.2), (dx, dy - 1.1, h + 1.48), 0.02, SCURO, contorno=0)
        m.asta((dx, dy - 1.1, h + 1.2), (dx + 0.18, dy - 1.1, h + 1.2), 0.02, SCURO, contorno=0)
    m.cima(h + (1.8 if liv < 3 else 3.6))
    return m


# ================================================================== TEATRO


@edificio("teatro")
def crea_teatro(liv):
    m = Modello("teatro_l%d" % liv)
    m.suolo(("lastre", "#b09e8a"))
    fronte = -0.6
    x0, x1 = -2.85, 1.9
    cx = (x0 + x1) / 2
    prof = 2.8
    cy = fronte + prof / 2
    h = 4.2
    muro = ("intonaco", "#d9877a")
    m.scatola((x1 - x0, prof, h), (cx, cy, h / 2), muro, smusso=0.03)
    # coronamento a gradoni art déco
    for i, (w, dz) in enumerate(((x1 - x0 + 0.1, 0.0), (2.8, 0.45), (1.4, 0.9))):
        m.scatola((w, 0.35, 0.5), (cx, fronte + 0.1, h + dz + 0.2), muro if i else ("intonaco", "#c97466"),
                  smusso=0.03)
        m.scatola((w + 0.08, 0.42, 0.08), (cx, fronte + 0.1, h + dz + 0.46), SENAPE, smusso=0.02, contorno=0.015)
    for x in (x0 + 0.15, x1 - 0.15, cx - 1.0, cx + 1.0):
        m.scatola((0.25, 0.12, h + 0.2), (x, fronte - 0.04, (h + 0.2) / 2), "#c97466", smusso=0.02)
    # pensilina della marquee con il nome
    mz = 2.75
    m.scatola((3.4 if liv == 1 else 4.0, 1.4, 0.5), (cx, fronte - 0.7, mz), ("lastre", SCURO), smusso=0.04)
    m.scatola((3.5 if liv == 1 else 4.1, 1.5, 0.08), (cx, fronte - 0.7, mz - 0.27), SENAPE, smusso=0.02,
              contorno=0.015)
    m.insegna((cx, fronte - 1.42, mz + 0.55), 2.8 if liv == 1 else 3.4, 0.62, fondo=CREMA, bordo=ROSSO,
              cornice=SCURO, lampadine=True)
    n = 12 if liv == 1 else 15
    larg = 3.3 if liv == 1 else 3.9
    for i in range(n):
        m.sfera(0.05, (cx - larg / 2 + i * larg / (n - 1), fronte - 1.42, mz - 0.18), LUCE_CALDA, contorno=0,
                luce=3.0)
    # porte, botteghino, locandine
    for x in (cx - 1.25, cx + 1.25):
        m.porta(x, fronte, larghezza=0.85, colore=ROSSO_S, cornice=SENAPE, gradino=False)
    m.scatola((0.9, 0.7, 1.4), (cx, fronte - 0.45, 0.8), ("legno", MARRONE), smusso=0.03)
    m.scatola((0.75, 0.05, 0.6), (cx, fronte - 0.81, 1.15), VETRO_ACCESO, smusso=0, contorno=0, luce=0.5)
    m.cilindro(0.5, 0.35, (cx, fronte - 0.45, 1.65), SENAPE, raggio_alto=0.1, lati=8, liscio=False)
    for x, c in ((x0 + 0.55, TEAL), (x1 - 0.55, VIOLA)):
        m.scatola((0.75, 0.08, 1.1), (x, fronte - 0.05, 1.55), SENAPE, smusso=0.02)
        m.scatola((0.6, 0.05, 0.95), (x, fronte - 0.1, 1.55), c, smusso=0, contorno=0)
        m.sfera(0.15, (x, fronte - 0.12, 1.7), CREMA, scala=(1, 0.3, 1), contorno=0.01)
        m.scatola((0.4, 0.03, 0.08), (x, fronte - 0.13, 1.3), CREMA, smusso=0, contorno=0)
    # tappeto rosso con i cordoni
    m.scatola((1.2, 1.9, 0.03), (cx, -1.65, 0.12), ("tela", ROSSO), smusso=0, contorno=0)
    for x in (cx - 0.8, cx + 0.8):
        for y in (-2.4, -1.4):
            m.asta((x, y, 0.08), (x, y, 0.9), 0.035, SENAPE, metallo=0.6, contorno=0.01)
            m.sfera(0.06, (x, y, 0.93), SENAPE, contorno=0.01)
        m.asta((x, -2.4, 0.82), (x, -1.4, 0.82), 0.025, ROSSO_S, contorno=0)
    if liv >= 2:
        # insegna verticale a bandiera con le lampadine
        vx = x1 - 0.3
        m.scatola((0.14, 0.8, 3.0), (vx, fronte - 0.45, h - 0.1), ("lastre", ROSSO_S), smusso=0.03)
        for i in range(7):
            for dy in (-0.8, -0.1):
                m.sfera(0.045, (vx - 0.09, fronte + dy, h - 1.5 + i * 0.45), LUCE_CALDA, contorno=0, luce=3.0)
        for i in range(5):
            m.cilindro(0.11, 0.04, (vx - 0.09, fronte - 0.45, h - 1.2 + i * 0.55), SENAPE, rot=(0, 90, 0), lati=10,
                       contorno=0.01, luce=1.0)
    if liv >= 3:
        # riflettori sul tetto con i fasci di luce e raggiera dorata
        for x, a in ((x0 + 0.4, 18), (x1 - 0.7, -18)):
            m.cilindro(0.3, 0.3, (x, cy + 0.5, h + 0.2), ACCIAIO_S, lati=8, metallo=0.5)
            m.faro((x, cy + 0.4, h + 0.75), (math.sin(math.radians(a)), -0.25, 1), raggio=0.3)
            d = (math.sin(math.radians(a)), -0.25, 1)
            m.cilindro(0.25, 6.0, (x + d[0] * 3.0, cy + 0.4 + d[1] * 3.0, h + 0.75 + 3.0), LUCE_CALDA,
                       raggio_alto=0.9, rot=geo.matrice_da_direzione(d), lati=10, alfa=0.18, luce=1.0)
        for i in range(9):
            a = math.radians(i * 22.5)
            m.scatola((0.08, 0.06, 0.55), (cx + 0.6 * math.cos(a), fronte + 0.05, h + 1.45 + 0.6 * math.sin(a)),
                      SENAPE, rot=(0, -math.degrees(a) + 90, 0), smusso=0, contorno=0.012, metallo=0.5)
        m.sfera(0.25, (cx, fronte + 0.05, h + 1.45), SENAPE, scala=(1, 0.4, 1), contorno=0.015)
    m.cima(h + (1.6 if liv < 3 else 2.4))
    return m
