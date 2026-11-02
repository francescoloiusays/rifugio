"""Rifugio - il "kit di costruzione": forme di base e pezzi ricorrenti.

Ogni metodo aggiunge parti al modello. Colori: una tinta '#rrggbb' oppure una
texture come ('mattoni', '#b8573e'). Coordinate in metri, Z in alto,
facciata verso -Y. Il lotto è largo 6.4 m: gli edifici stanno tra x = -3.0 e
3.0 e tra y = -2.6 (davanti) e 2.4 (dietro).
"""

import math
import random

import numpy as np

import rifugio_geometria as geo
from rifugio_geometria import CONTORNO

# ------------------------------------------------------------------ palette (sRGB)

CREMA = "#f4e4c1"
CREMA_S = "#e2cda0"
MENTA = "#8fc9b5"
MENTA_S = "#6fae99"
SALMONE = "#e8836b"
SALMONE_S = "#c9644f"
SENAPE = "#e3b448"
SENAPE_S = "#c4952f"
TEAL = "#2f7f86"
TEAL_S = "#22606a"
CELESTE = "#9cc9d9"
MARRONE = "#5b3a29"
LEGNO = "#a8744a"
LEGNO_S = "#7a4e33"
LEGNO_C = "#c79a6a"
RUGGINE = "#b8602f"
RUGGINE_S = "#8a4423"
ROSSO = "#d0453a"
ROSSO_S = "#a3322b"
VERDE = "#6aa84f"
VERDE_S = "#4d8a3a"
VERDE_SCURO = "#3f6b35"
OLIVA = "#7d7a45"
ACCIAIO = "#9aa3ab"
ACCIAIO_S = "#6d757d"
CROMO = "#d8dde2"
GOMMA = "#2c2a31"
BIANCO = "#fbf3e2"
SABBIA = "#c9ad7c"
CEMENTO = "#a39d96"
CEMENTO_S = "#7d7780"
MATTONE = "#b8573e"
MATTONE_S = "#94432f"
VIOLA = "#7a4f86"
ROSA = "#e88fae"
LUCE_CALDA = "#ffd98a"
LUCE_FREDDA = "#bfefff"
NEON_ROSA = "#ff6fae"
NEON_AZZURRO = "#6fe6ff"
FUOCO = "#ff8a2a"
SCURO = "#2b2230"
VETRO_SPENTO = "#4d6470"
VETRO_ACCESO = "#f2b55e"


class Modello:
    def __init__(self, nome):
        self.nome = nome
        self.parti = []
        self.segnaposti = []  # (nome, posizione, angolo attorno a Z in gradi)
        self._materiali = {}
        self.casuale = random.Random(nome)
        self.gruppi = {}           # nome -> perno: parti che il gioco può muovere (ante, bracci)
        self._gruppo = None

    # ---- materiali

    def _mat(self, colore, ruvido=0.85, metallo=0.0, luce=0.0, alfa=1.0):
        m = geo.Materiale(colore, ruvido, metallo, luce, alfa)
        return self._materiali.setdefault(m.chiave, m)

    def _aggiungi(self, forma, colore, pos, rot, contorno, ruvido, metallo, luce, alfa, parte, scala_uv=1.0,
                  uv_ruota=False):
        if alfa < 1:
            contorno = 0
        p = geo.Parte(parte, forma, self._mat(colore, ruvido, metallo, luce, alfa), pos, rot, contorno, scala_uv,
                      uv_ruota)
        p.gruppo = self._gruppo
        self.parti.append(p)
        return p

    # ---- forme di base

    def scatola(self, dim, pos, colore, rot=(0, 0, 0), smusso=0.05, contorno=CONTORNO, ruvido=0.85, metallo=0.0,
                luce=0.0, alfa=1.0, parte="scatola", scala_uv=1.0, uv_ruota=False):
        return self._aggiungi(geo.forma_scatola(*dim, smusso), colore, pos, rot, contorno, ruvido, metallo, luce,
                              alfa, parte, scala_uv, uv_ruota)

    def cilindro(self, raggio, altezza, pos, colore, rot=(0, 0, 0), raggio_alto=None, lati=12, liscio=True,
                 contorno=CONTORNO, ruvido=0.8, metallo=0.0, luce=0.0, alfa=1.0, parte="cilindro", scala=None):
        forma = geo.forma_cilindro(raggio, raggio if raggio_alto is None else raggio_alto, altezza, lati, liscio)
        if scala is not None:
            forma.v = forma.v * np.asarray(scala, float)
        return self._aggiungi(forma, colore, pos, rot, contorno, ruvido, metallo, luce, alfa, parte)

    def sfera(self, raggio, pos, colore, scala=(1, 1, 1), rot=(0, 0, 0), dettaglio=None, liscio=False,
              contorno=CONTORNO, ruvido=0.9, luce=0.0, alfa=1.0, parte="sfera"):
        if dettaglio is None:
            dettaglio = 0 if raggio * max(scala) < 0.13 else 1
        forma = geo.forma_sfera(raggio, dettaglio, liscio)
        forma.v = forma.v * np.asarray(scala, float)
        return self._aggiungi(forma, colore, pos, rot, contorno, ruvido, 0.0, luce, alfa, parte)

    def prisma(self, larghezza, profondita, altezza, pos, colore, rot=(0, 0, 0), contorno=CONTORNO, ruvido=0.85,
               parte="timpano"):
        return self._aggiungi(geo.forma_prisma(larghezza, profondita, altezza), colore, pos, rot, contorno, ruvido,
                              0.0, 0.0, 1.0, parte)

    def profilo(self, punti, profondita, pos, colore, rot=(0, 0, 0), liscio=False, contorno=CONTORNO, ruvido=0.85,
                metallo=0.0, luce=0.0, parte="profilo"):
        return self._aggiungi(geo.forma_profilo(punti, profondita, liscio), colore, pos, rot, contorno, ruvido,
                              metallo, luce, 1.0, parte)

    def tronco(self, base, cima, altezza, pos, colore, rot=(0, 0, 0), contorno=CONTORNO, ruvido=0.85, metallo=0.0,
               parte="tronco"):
        return self._aggiungi(geo.forma_tronco(base, cima, altezza), colore, pos, rot, contorno, ruvido, metallo,
                              0.0, 1.0, parte)

    def asta(self, p0, p1, raggio, colore, lati=6, contorno=0.02, metallo=0.0, ruvido=0.7, luce=0.0, parte="asta"):
        p0 = np.asarray(p0, float)
        p1 = np.asarray(p1, float)
        d = p1 - p0
        forma = geo.forma_cilindro(raggio, raggio, float(np.linalg.norm(d)), lati, True)
        return self._aggiungi(forma, colore, (p0 + p1) / 2, geo.matrice_da_direzione(d), contorno, ruvido, metallo,
                              luce, 1.0, parte)

    def inizia_gruppo(self, nome, perno):
        """Le parti aggiunte da qui a fine_gruppo() diventano un nodo che ruota attorno al perno."""
        self.gruppi[nome] = tuple(perno)
        self._gruppo = nome

    def fine_gruppo(self):
        self._gruppo = None

    def segnaposto(self, nome, pos, angolo=0.0):
        self.segnaposti.append((nome, tuple(pos), angolo))

    def cima(self, z, x=0.0, y=0.0):
        """Dove il gioco mette barre e icone (sopra il tetto)."""
        self.segnaposto("cima", (x, y, z))

    # ---- pezzi ricorrenti

    def suolo(self, colore, larghezza=6.1, profondita=5.2, y=-0.1, spessore=0.08):
        """Piazzola del lotto: il terreno del cortile."""
        self.scatola((larghezza, profondita, spessore), (0, y, spessore / 2), colore, smusso=0.03, contorno=0,
                     parte="suolo")

    def vialetto(self, x, y0, y1, larghezza=1.0, colore=("lastre", CEMENTO)):
        self.scatola((larghezza, y1 - y0, 0.06), (x, (y0 + y1) / 2, 0.1), colore, smusso=0.02, contorno=0,
                     parte="vialetto")

    def finestra(self, x, z, fronte, larghezza=0.8, altezza=0.9, persiane=TEAL, accesa=True, cornice=BIANCO,
                 croce=True, davanzale=True, lato=None, tenda=None):
        """Finestra sulla facciata (piano y = fronte). Con lato=-1/1 va sul fianco (piano x = fronte)."""
        def P(a, b, c):  # a: lungo il muro, b: sporgenza verso l'esterno, c: altezza
            if lato is None:
                return (x + a, fronte - b, c)
            return (fronte + lato * b, x + a * (-lato), c)

        def D(a, b, c):
            return (a, b, c) if lato is None else (b, a, c)

        s = 0.06
        self.scatola(D(larghezza + 2 * s + 0.04, 0.1, s), P(0, 0.02, z + altezza / 2 + s / 2), cornice, smusso=0.015,
                     contorno=0.018, parte="cornice")
        self.scatola(D(larghezza + 2 * s + 0.04, 0.1, s), P(0, 0.02, z - altezza / 2 - s / 2), cornice, smusso=0.015,
                     contorno=0.018, parte="cornice")
        for k in (-1, 1):
            self.scatola(D(s, 0.1, altezza), P(k * (larghezza / 2 + s / 2), 0.02, z), cornice, smusso=0.015,
                         contorno=0.018, parte="cornice")
        vetro = VETRO_ACCESO if accesa else VETRO_SPENTO
        self.scatola(D(larghezza, 0.04, altezza), P(0, -0.01, z), vetro, smusso=0, contorno=0, ruvido=0.2,
                     luce=0.45 if accesa else 0.0, parte="vetro")
        if tenda:
            self.scatola(D(larghezza * 0.42, 0.03, altezza * 0.95), P(-larghezza * 0.29, 0.0, z), tenda, smusso=0,
                         contorno=0, parte="tenda")
            self.scatola(D(larghezza * 0.42, 0.03, altezza * 0.95), P(larghezza * 0.29, 0.0, z), tenda, smusso=0,
                         contorno=0, parte="tenda")
        if croce:
            self.scatola(D(0.05, 0.05, altezza), P(0, 0.01, z), cornice, smusso=0, contorno=0.012, parte="croce")
            self.scatola(D(larghezza, 0.05, 0.05), P(0, 0.01, z + altezza * 0.1), cornice, smusso=0, contorno=0.012,
                         parte="croce")
        if davanzale:
            self.scatola(D(larghezza + 0.3, 0.2, 0.07), P(0, 0.08, z - altezza / 2 - 0.09), cornice, smusso=0.02,
                         contorno=0.018, parte="davanzale")
        if persiane:
            for k in (-1, 1):
                self.scatola(D(larghezza * 0.42, 0.06, altezza + 0.08), P(k * (larghezza * 0.71 + s), 0.04, z),
                             persiane, smusso=0.02, contorno=0.018, parte="persiana")
                for i in range(4):
                    zz = z - altezza / 2 + (i + 0.6) * altezza / 4.2
                    self.scatola(D(larghezza * 0.36, 0.03, 0.035), P(k * (larghezza * 0.71 + s), 0.08, zz),
                                 persiane, smusso=0, contorno=0, ruvido=0.6, parte="lamella")

    def porta(self, x, fronte, larghezza=0.95, altezza=1.95, colore=TEAL, cornice=BIANCO, vetro=True, maniglia=True,
              gradino=True, lato=None):
        def P(a, b, c):
            if lato is None:
                return (x + a, fronte - b, c)
            return (fronte + lato * b, x + a * (-lato), c)

        def D(a, b, c):
            return (a, b, c) if lato is None else (b, a, c)

        self.scatola(D(larghezza + 0.2, 0.12, altezza + 0.1), P(0, 0.0, altezza / 2 + 0.1), cornice, smusso=0.02,
                     contorno=0.02, parte="stipite")
        self.scatola(D(larghezza, 0.1, altezza), P(0, 0.05, altezza / 2 + 0.12), colore, smusso=0.02, contorno=0.015,
                     parte="porta")
        if vetro:
            self.scatola(D(larghezza * 0.55, 0.04, altezza * 0.3), P(0, 0.1, altezza * 0.72), VETRO_ACCESO, smusso=0,
                         contorno=0.012, luce=0.45, parte="vetro_porta")
        else:
            for zz in (0.35, 0.68):
                self.scatola(D(larghezza * 0.7, 0.03, altezza * 0.24), P(0, 0.1, altezza * zz + 0.12), colore,
                             smusso=0.01, contorno=0.012, parte="pannello")
        if maniglia:
            self.sfera(0.05, P(larghezza * 0.36, 0.13, altezza * 0.48 + 0.12), SENAPE, contorno=0, parte="pomello")
        if gradino:
            self.scatola(D(larghezza + 0.5, 0.45, 0.14), P(0, 0.22, 0.13), ("cemento", CEMENTO), smusso=0.03,
                         contorno=0.02, parte="gradino")

    def tetto_falde(self, larghezza, profondita, altezza, base, colore, sporgenza=0.3, spessore=0.14,
                    colmo=None, timpano=None):
        """Tetto a capanna: colmo lungo X, falde verso -Y e +Y. base = (x, y, z) della gronda."""
        bx, by, bz = base
        if timpano:
            self.prisma(larghezza, profondita, altezza, (bx, by, bz), timpano)
        s = math.hypot(profondita / 2, altezza)
        angolo = math.degrees(math.atan2(altezza, profondita / 2))
        lunghezza = s + sporgenza
        for lato in (-1, 1):
            uy, uz = lato * (profondita / 2) / s, -altezza / s
            ny, nz = lato * altezza / s, (profondita / 2) / s
            cy = uy * lunghezza / 2 + ny * spessore / 2
            cz = altezza + uz * lunghezza / 2 + nz * spessore / 2
            self.scatola((larghezza + 2 * sporgenza, lunghezza, spessore), (bx, by + cy, bz + cz), colore,
                         rot=(-lato * angolo, 0, 0), smusso=0.03, parte="falda")
        self.scatola((larghezza + 2 * sporgenza + 0.05, 0.22, 0.16), (bx, by, bz + altezza + spessore * 0.8),
                     colmo or colore, smusso=0.04, parte="colmo")

    def tetto_piano(self, larghezza, profondita, z, x=0.0, y=0.0, colore=("cemento", CEMENTO_S), bordo=BIANCO,
                    altezza_bordo=0.28):
        self.scatola((larghezza + 0.2, profondita + 0.2, 0.14), (x, y, z + 0.07), colore, smusso=0.03,
                     parte="tetto")
        for dy, w, d in ((-(profondita / 2 + 0.05), larghezza + 0.3, 0.12), ((profondita / 2 + 0.05), larghezza + 0.3, 0.12)):
            self.scatola((w, d, altezza_bordo), (x, y + dy, z + altezza_bordo / 2 + 0.07), bordo, smusso=0.03,
                         parte="parapetto")
        for dx in (-(larghezza / 2 + 0.05), larghezza / 2 + 0.05):
            self.scatola((0.12, profondita + 0.2, altezza_bordo), (x + dx, y, z + altezza_bordo / 2 + 0.07), bordo,
                         smusso=0.03, parte="parapetto")

    def insegna(self, pos, larghezza, altezza, angolo=0.0, fondo=CREMA, bordo=ROSSO, cornice=MARRONE,
                lampadine=False, sostegni=None, testo=None):
        """Tabella per il nome: il testo lo scrive il gioco nel segnaposto 'insegna'."""
        x, y, z = pos
        a = math.radians(angolo)

        def P(dx, dy, dz):
            return (x + dx * math.cos(a) - dy * math.sin(a), y + dx * math.sin(a) + dy * math.cos(a), z + dz)

        rot = (0, 0, angolo)
        self.scatola((larghezza + 0.16, 0.1, altezza + 0.16), P(0, 0.03, 0), cornice, rot=rot, smusso=0.04,
                     parte="insegna_cornice")
        self.scatola((larghezza, 0.06, altezza), P(0, -0.03, 0), fondo, rot=rot, smusso=0.01, contorno=0,
                     parte="insegna")
        b = 0.045
        for dx, dz, w, h in ((0, altezza / 2 - 0.07, larghezza - 0.1, b), (0, -altezza / 2 + 0.07, larghezza - 0.1, b),
                             (-larghezza / 2 + 0.07, 0, b, altezza - 0.1), (larghezza / 2 - 0.07, 0, b, altezza - 0.1)):
            self.scatola((w, 0.03, h), P(dx, -0.065, dz), bordo, rot=rot, smusso=0, contorno=0, parte="insegna_bordo")
        if lampadine:
            n = max(4, int(larghezza / 0.28))
            for i in range(n + 1):
                for dz in (altezza / 2 + 0.08, -altezza / 2 - 0.08):
                    self.sfera(0.045, P(-larghezza / 2 + i * larghezza / n, -0.06, dz), LUCE_CALDA, contorno=0,
                               luce=2.5, parte="lampadina")
        if sostegni == "pali":
            for dx in (-larghezza * 0.35, larghezza * 0.35):
                self.asta(P(dx, 0.06, -z), P(dx, 0.06, -altezza / 2), 0.05, ACCIAIO_S, metallo=0.6)
        if testo is None:
            chiaro = sum(geo.tex.rgb(fondo if isinstance(fondo, str) else fondo[1])) > 1.2
            testo = MARRONE if chiaro else CREMA
        self.segnaposto("insegna_w%03d_h%03d_t%s" % (round(larghezza * 100 - 16), round(altezza * 100),
                                                     testo.lstrip("#")), P(0, -0.09, 0), angolo)

    def neon(self, punti, colore=NEON_ROSA, raggio=0.035):
        for p0, p1 in zip(punti[:-1], punti[1:]):
            self.asta(p0, p1, raggio, colore, contorno=0, luce=3.0, parte="neon")

    def tenda(self, x, fronte, larghezza, z, profondita=0.9, caduta=0.45, colori=(ROSSO, BIANCO), smerlo=True):
        """Tendone a strisce inclinato sopra una vetrina."""
        angolo = math.degrees(math.atan2(caduta, profondita))
        lung = math.hypot(caduta, profondita)
        self.scatola((larghezza, lung, 0.06), (x, fronte - profondita / 2, z - caduta / 2),
                     ("righe", colori[0], colori[1]), rot=(-angolo, 0, 0), smusso=0.02, contorno=0.02,
                     parte="tendone")
        if smerlo:
            n = max(3, int(larghezza / 0.32))
            for i in range(n):
                xx = x - larghezza / 2 + (i + 0.5) * larghezza / n
                self.profilo([(-larghezza / n / 2, 0), (larghezza / n / 2, 0), (larghezza / n / 2 * 0.7, -0.12),
                              (0, -0.17), (-larghezza / n / 2 * 0.7, -0.12)], 0.05,
                             (xx, fronte - profondita - 0.01, z - caduta), colori[i % 2], contorno=0.015,
                             parte="smerlo")
        for k in (-1, 1):
            self.asta((x + k * (larghezza / 2 - 0.05), fronte, z + 0.05),
                      (x + k * (larghezza / 2 - 0.05), fronte - profondita, z - caduta), 0.025, ACCIAIO_S, metallo=0.6)

    def cassa(self, pos, lato=0.6, rot=0, colore=LEGNO):
        x, y, z = pos
        self.scatola((lato, lato, lato), (x, y, z + lato / 2), ("legno", colore), rot=(0, 0, rot), smusso=0.03,
                     parte="cassa")
        a = math.radians(rot)
        for s in (-1, 1):
            dx, dy = -math.sin(a) * s * (lato / 2 + 0.01), math.cos(a) * s * (lato / 2 + 0.01)
            self.scatola((lato * 0.95, 0.04, 0.09), (x + dx, y + dy, z + lato * 0.85), LEGNO_S, rot=(0, 0, rot),
                         smusso=0, contorno=0, parte="cassa_rinforzo")
            self.scatola((lato * 0.95, 0.04, 0.09), (x + dx, y + dy, z + lato * 0.15), LEGNO_S, rot=(0, 0, rot),
                         smusso=0, contorno=0, parte="cassa_rinforzo")

    def barile(self, pos, colore=RUGGINE, altezza=0.85, raggio=0.3, simbolo=None, rot=(0, 0, 0)):
        x, y, z = pos
        self.cilindro(raggio, altezza, (x, y, z + altezza / 2), ("metallo", colore), lati=12, rot=rot, parte="barile")
        if rot == (0, 0, 0):
            for zz in (0.2, 0.8):
                self.cilindro(raggio + 0.02, 0.05, (x, y, z + altezza * zz), colore, lati=12, contorno=0,
                              parte="cerchio")
            if simbolo:
                self.cilindro(raggio * 0.5, 0.02, (x, y - raggio - 0.005, z + altezza * 0.5), simbolo, rot=(90, 0, 0),
                              lati=10, contorno=0, parte="simbolo")

    def sacchi(self, x0, x1, y, file=2, colore=("tela", SABBIA), rot=0, z=0.0):
        a = math.radians(rot)
        for f in range(file):
            n = max(1, int((x1 - x0) / 0.58) - f)
            for i in range(n):
                t = x0 + 0.3 + f * 0.29 + i * 0.58
                self.scatola((0.6, 0.4, 0.3), (t * math.cos(a) - y * math.sin(a) if rot else t,
                                               t * math.sin(a) + y * math.cos(a) if rot else y, z + 0.15 + f * 0.27),
                             colore, rot=(0, 0, rot + self.casuale.uniform(-7, 7)), smusso=0.11, parte="sacco")

    def cespuglio(self, pos, r=0.45, colore=VERDE):
        x, y, z = pos
        self.sfera(r, (x, y, z + r * 0.7), colore, scala=(1, 0.9, 0.8), parte="cespuglio")
        self.sfera(r * 0.7, (x + r * 0.6, y + 0.05, z + r * 0.5), VERDE_S, scala=(1, 0.9, 0.85), parte="cespuglio")

    def albero(self, pos, altezza=3.2, colore=VERDE, secco=False):
        x, y, z = pos
        self.cilindro(0.14, altezza * 0.55, (x, y, z + altezza * 0.27), LEGNO_S, raggio_alto=0.09, lati=7,
                      parte="tronco")
        if secco:
            for ang, inc in ((20, 40), (150, 35), (260, 45)):
                a = math.radians(ang)
                p0 = (x, y, z + altezza * 0.45)
                p1 = (x + math.cos(a) * 0.8, y + math.sin(a) * 0.8, z + altezza * 0.45 + 0.8)
                self.asta(p0, p1, 0.06, LEGNO_S)
            return
        self.sfera(altezza * 0.3, (x, y, z + altezza * 0.72), colore, scala=(1, 1, 0.9), parte="chioma")
        self.sfera(altezza * 0.2, (x + altezza * 0.18, y - 0.1, z + altezza * 0.62), VERDE_S, parte="chioma")
        self.sfera(altezza * 0.18, (x - altezza * 0.17, y + 0.05, z + altezza * 0.85), colore, parte="chioma")

    def staccionata(self, x0, x1, y, altezza=0.75, colore=BIANCO):
        n = max(2, int((x1 - x0) / 0.3))
        for i in range(n + 1):
            x = x0 + (x1 - x0) * i / n
            self.scatola((0.11, 0.06, altezza), (x, y, altezza / 2), colore, smusso=0.02, contorno=0.018,
                         parte="paletto")
            self.tronco((0.11, 0.06), (0, 0), 0.1, (x, y, altezza), colore, contorno=0.018, parte="punta")
        for z in (altezza * 0.3, altezza * 0.75):
            self.scatola((x1 - x0, 0.04, 0.07), ((x0 + x1) / 2, y + 0.05, z), colore, smusso=0.01, contorno=0.015,
                         parte="traversa")

    def rete(self, x0, x1, y, altezza=1.6, colore=ACCIAIO_S):
        """Recinzione di rete metallica: pali + rete semitrasparente."""
        n = max(1, int((x1 - x0) / 1.4))
        for i in range(n + 1):
            x = x0 + (x1 - x0) * i / n
            self.cilindro(0.04, altezza, (x, y, altezza / 2), colore, lati=6, metallo=0.6, contorno=0.015)
        self.scatola((x1 - x0, 0.02, altezza * 0.92), ((x0 + x1) / 2, y, altezza * 0.5), "#8d969e", smusso=0,
                     alfa=0.35, ruvido=0.5, parte="rete")
        self.cilindro(0.03, x1 - x0, ((x0 + x1) / 2, y, altezza), colore, rot=(0, 90, 0), lati=6, contorno=0.015)

    def lampada_muro(self, x, fronte, z, colore=SCURO, lato=None):
        p = (x, fronte - 0.18, z) if lato is None else (fronte + lato * 0.18, x, z)
        self.scatola((0.08, 0.36, 0.05) if lato is None else (0.36, 0.08, 0.05),
                     (p[0], p[1] + 0.1, z + 0.12) if lato is None else (p[0] - lato * 0.1, p[1], z + 0.12), colore,
                     smusso=0, contorno=0.015, metallo=0.5)
        self.cilindro(0.15, 0.12, (p[0], p[1], z + 0.08), colore, raggio_alto=0.05, lati=8, metallo=0.5,
                      contorno=0.015)
        self.sfera(0.08, (p[0], p[1], z - 0.02), LUCE_CALDA, contorno=0, luce=3.0)

    def luci_filo(self, p0, p1, n=8, cedimento=0.3, colori=(LUCE_CALDA, NEON_ROSA, LUCE_CALDA, NEON_AZZURRO)):
        p0 = np.asarray(p0, float)
        p1 = np.asarray(p1, float)
        precedente = p0
        for i in range(1, n + 1):
            t = i / n
            p = p0 + (p1 - p0) * t
            p[2] -= cedimento * 4 * t * (1 - t)
            self.asta(precedente, p, 0.012, SCURO, contorno=0, lati=4)
            if i < n:
                self.sfera(0.06, (p[0], p[1], p[2] - 0.07), colori[i % len(colori)], contorno=0, luce=3.0,
                           parte="lampadina")
            precedente = p

    def cisterna(self, pos, raggio=0.7, altezza=1.1, gambe=1.4, colore=("metallo", ACCIAIO), tetto=ROSSO):
        x, y, z = pos
        for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            self.asta((x + dx * raggio * 0.75, y + dy * raggio * 0.75, z), (x + dx * raggio * 0.6, y + dy * raggio * 0.6,
                                                                              z + gambe), 0.05, LEGNO_S)
        self.asta((x - raggio * 0.7, y - raggio * 0.7, z + 0.2), (x + raggio * 0.65, y - raggio * 0.65, z + gambe - 0.1),
                  0.03, LEGNO_S)
        self.cilindro(raggio, altezza, (x, y, z + gambe + altezza / 2), colore, lati=12)
        self.cilindro(raggio + 0.1, 0.45, (x, y, z + gambe + altezza + 0.22), tetto, raggio_alto=0.05, lati=12)
        for zz in (0.25, 0.75):
            self.cilindro(raggio + 0.025, 0.06, (x, y, z + gambe + altezza * zz), ACCIAIO_S, lati=12, contorno=0,
                          metallo=0.6)

    def condizionatore(self, pos, lato=None):
        x, y, z = pos
        self.scatola((0.7, 0.5, 0.45), (x, y, z + 0.22), ("lastre", CROMO), smusso=0.04, metallo=0.3)
        self.cilindro(0.17, 0.04, (x, y - 0.26, z + 0.22), SCURO, rot=(90, 0, 0), lati=10, contorno=0)

    def pannello_solare(self, pos, larghezza=1.2, profondita=0.8, inclinazione=25):
        x, y, z = pos
        self.asta((x, y, z), (x, y, z + 0.35), 0.04, ACCIAIO_S, metallo=0.6)
        self.scatola((larghezza, profondita, 0.05), (x, y, z + 0.4), "#2a3f6b", rot=(inclinazione, 0, 0), smusso=0.01,
                     ruvido=0.25, metallo=0.3)
        self.scatola((larghezza + 0.06, profondita + 0.06, 0.03), (x, y, z + 0.37), CROMO, rot=(inclinazione, 0, 0),
                     smusso=0.01, contorno=0.015, metallo=0.5)

    def comignolo(self, pos, altezza=0.9, colore=("mattoni", MATTONE)):
        x, y, z = pos
        self.scatola((0.45, 0.45, altezza), (x, y, z + altezza / 2), colore, smusso=0.02)
        self.scatola((0.58, 0.58, 0.1), (x, y, z + altezza + 0.05), CEMENTO_S, smusso=0.02)

    def scala_pioli(self, base, altezza, colore=ACCIAIO_S, angolo=0.0):
        x, y, z = base
        a = math.radians(angolo)
        ux, uy = math.cos(a), math.sin(a)
        for s in (-0.2, 0.2):
            self.asta((x + ux * s, y + uy * s, z), (x + ux * s, y + uy * s, z + altezza), 0.025, colore, metallo=0.5)
        for i in range(int(altezza / 0.3)):
            zz = z + 0.2 + i * 0.3
            self.asta((x - ux * 0.2, y - uy * 0.2, zz), (x + ux * 0.2, y + uy * 0.2, zz), 0.018, colore, metallo=0.5,
                      contorno=0)

    def antenna(self, pos, altezza=2.0, colore=ACCIAIO_S):
        x, y, z = pos
        self.asta((x, y, z), (x, y, z + altezza), 0.03, colore, metallo=0.6)
        for i, w in enumerate((0.9, 0.7, 0.5)):
            zz = z + altezza * (0.6 + i * 0.15)
            self.asta((x - w / 2, y, zz), (x + w / 2, y, zz), 0.015, colore, metallo=0.6, contorno=0)

    def bidone_fuoco(self, pos):
        x, y, z = pos
        self.barile(pos, colore=RUGGINE_S, altezza=0.8, raggio=0.28)
        self.cilindro(0.2, 0.35, (x, y, z + 0.95), FUOCO, raggio_alto=0.02, lati=6, liscio=False, luce=4.0)
        self.cilindro(0.12, 0.25, (x + 0.06, y, z + 1.08), LUCE_CALDA, raggio_alto=0.0, lati=5, liscio=False, luce=5.0)

    def copertone(self, pos, raggio=0.38, larghezza=0.25, rot=(0, 0, 0)):
        x, y, z = pos
        self.cilindro(raggio, larghezza, (x, y, z), GOMMA, rot=rot, lati=12, ruvido=0.95, parte="gomma")
        r = geo.matrice_rotazione(rot)
        asse = r @ np.array([0, 0, 1.0])
        for s in (-1, 1):
            self.cilindro(raggio * 0.45, 0.02, tuple(np.array(pos) + asse * s * larghezza / 2), ACCIAIO_S, rot=rot,
                          lati=10, contorno=0, metallo=0.5)

    def mucchio_rottami(self, centro, raggio=1.0, altezza=0.9, n=10):
        x, y, z = centro
        cas = self.casuale
        self.tronco((raggio * 2, raggio * 1.6), (raggio * 0.5, raggio * 0.4), altezza * 0.6, (x, y, z),
                    ("ghiaia", "#857a70"), parte="mucchio")
        colori = [("lamiera", ACCIAIO), ("metallo", RUGGINE), ("lastre", MENTA_S), ("metallo", TEAL),
                  ("lamiera", RUGGINE_S), ("lastre", SENAPE)]
        for i in range(n):
            a = cas.uniform(0, 2 * math.pi)
            d = cas.uniform(0.1, raggio * 0.75)
            zz = z + altezza * 0.6 * (1 - d / raggio) + 0.05
            dim = (cas.uniform(0.25, 0.7), cas.uniform(0.2, 0.5), cas.uniform(0.05, 0.25))
            self.scatola(dim, (x + math.cos(a) * d, y + math.sin(a) * d * 0.8, zz), colori[i % len(colori)],
                         rot=(cas.uniform(-35, 35), cas.uniform(-35, 35), cas.uniform(0, 180)), smusso=0.02,
                         contorno=0.018, metallo=0.3, parte="rottame")

    # ---- veicoli e macchinari

    def auto(self, pos, colore=TEAL, rot=0, rottame=False, lunghezza=2.9):
        """Berlina anni '50 lungo X. rottame: senza ruote, ammaccata e arrugginita."""
        x, y, z = pos
        a = math.radians(rot)

        def P(dx, dy, dz):
            return (x + dx * math.cos(a) - dy * math.sin(a), y + dx * math.sin(a) + dy * math.cos(a), z + dz)

        tinta = ("metallo", colore) if not rottame else ("lamiera", colore)
        inclina = (4, -3, 0) if rottame else (0, 0, 0)
        base = 0.22 if rottame else 0.38
        L = lunghezza
        self.scatola((L, 1.3, 0.5), P(0, 0, base + 0.25), tinta, rot=(inclina[0], inclina[1], rot), smusso=0.12,
                     metallo=0.3, parte="carrozzeria")
        self.tronco((L * 0.5, 1.15), (L * 0.36, 1.0), 0.45, P(-0.1, 0, base + 0.5), tinta,
                    rot=(inclina[0], inclina[1], rot), metallo=0.3, parte="abitacolo")
        vetro = VETRO_SPENTO
        for s in (-1, 1):
            self.scatola((L * 0.36, 0.03, 0.28), P(-0.1, s * 0.56, base + 0.74), vetro, rot=(s * 8 + inclina[0], 0, rot),
                         smusso=0, contorno=0, ruvido=0.2)
        self.scatola((0.06, 0.95, 0.3), P(-0.1 - L * 0.215, 0, base + 0.73), vetro, rot=(0, -30, rot), smusso=0,
                     contorno=0, ruvido=0.2)
        self.scatola((0.08, 1.32, 0.12), P(L / 2, 0, base + 0.15), CROMO, rot=(0, 0, rot), smusso=0.03,
                     metallo=0.8, ruvido=0.3, contorno=0.015)
        self.scatola((0.08, 1.32, 0.12), P(-L / 2, 0, base + 0.15), CROMO, rot=(0, 0, rot), smusso=0.03,
                     metallo=0.8, ruvido=0.3, contorno=0.015)
        for s in (-1, 1):
            self.sfera(0.1, P(L / 2, s * 0.45, base + 0.36), LUCE_CALDA if not rottame else VETRO_SPENTO,
                       contorno=0.012, luce=0.8 if not rottame else 0.0)
        if not rottame:
            for dx in (-L * 0.32, L * 0.32):
                for s in (-1, 1):
                    self.copertone(P(dx, s * 0.6, 0.36), 0.34, 0.24, rot=(90, 0, rot))
        else:
            self.copertone(P(L * 0.32, -0.6, 0.3), 0.34, 0.24, rot=(90, 0, rot))
            for dx in (-L * 0.32,):
                self.cilindro(0.1, 0.4, P(dx, -0.4, 0.12), ("metallo", RUGGINE), rot=(90, 0, rot), lati=6)

    def furgone(self, pos, colore=BIANCO, rot=0, fascia=ROSSO, croce=False):
        x, y, z = pos
        a = math.radians(rot)

        def P(dx, dy, dz):
            return (x + dx * math.cos(a) - dy * math.sin(a), y + dx * math.sin(a) + dy * math.cos(a), z + dz)

        self.scatola((2.2, 1.45, 1.55), P(-0.4, 0, 1.2), ("lastre", colore), rot=(0, 0, rot), smusso=0.1)
        self.scatola((1.0, 1.4, 1.0), P(1.15, 0, 0.92), ("lastre", colore), rot=(0, 0, rot), smusso=0.12)
        self.tronco((0.6, 1.3), (0.2, 1.25), 0.45, P(1.0, 0, 1.4), ("lastre", colore), rot=(0, 0, rot))
        self.scatola((2.25, 1.47, 0.22), P(-0.4, 0, 1.15), fascia, rot=(0, 0, rot), smusso=0.02, contorno=0)
        self.scatola((1.02, 1.42, 0.22), P(1.15, 0, 1.0), fascia, rot=(0, 0, rot), smusso=0.02, contorno=0)
        self.scatola((0.04, 1.2, 0.38), P(1.42, 0, 1.6), VETRO_SPENTO, rot=(0, -24, rot), smusso=0, contorno=0)
        for s in (-1, 1):
            self.scatola((0.5, 0.03, 0.35), P(1.1, s * 0.72, 1.55), VETRO_SPENTO, rot=(0, 0, rot), smusso=0, contorno=0)
        if croce:
            for s in (-1, 1):
                self.scatola((0.5, 0.03, 0.14), P(-0.4, s * 0.74, 1.55), ROSSO, rot=(0, 0, rot), smusso=0, contorno=0)
                self.scatola((0.14, 0.03, 0.5), P(-0.4, s * 0.74, 1.55), ROSSO, rot=(0, 0, rot), smusso=0, contorno=0)
            self.scatola((0.3, 1.0, 0.14), P(0.5, 0, 2.05), ROSSO, rot=(0, 0, rot), smusso=0.03, luce=1.5)
        for dx in (-1.0, 1.1):
            for s in (-1, 1):
                self.copertone(P(dx, s * 0.68, 0.36), 0.36, 0.25, rot=(90, 0, rot))
        self.scatola((0.08, 1.45, 0.14), P(1.66, 0, 0.6), CROMO, rot=(0, 0, rot), smusso=0.03, metallo=0.8,
                     contorno=0.015)

    def faro(self, pos, direzione=(0, -1, 0.4), raggio=0.22):
        """Riflettore su palo corto, puntato nella direzione data."""
        x, y, z = pos
        d = np.asarray(direzione, float)
        d /= np.linalg.norm(d)
        r = geo.matrice_da_direzione(d)
        self.cilindro(raggio, raggio * 1.4, (x, y, z), ("metallo", SCURO), rot=r, lati=10, metallo=0.5)
        self.cilindro(raggio * 0.85, 0.04, tuple(np.array(pos) + d * raggio * 0.72), LUCE_FREDDA, rot=r, lati=10,
                      contorno=0, luce=4.0)

    def bandiera(self, pos, altezza=2.4, colore=ROSSO, colore2=CREMA):
        x, y, z = pos
        self.asta((x, y, z), (x, y, z + altezza), 0.035, ACCIAIO_S, metallo=0.6)
        self.sfera(0.06, (x, y, z + altezza + 0.04), SENAPE, contorno=0.01)
        self.scatola((0.9, 0.03, 0.55), (x + 0.47, y, z + altezza - 0.32), ("righe", colore, colore2), smusso=0,
                     contorno=0.012, rot=(0, 0, -8))
