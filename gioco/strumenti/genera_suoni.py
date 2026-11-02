"""Rifugio - genera effetti sonori e musiche (solo numpy, nessun file esterno).

Uso:  python3 strumenti/genera_suoni.py      (dalla cartella del gioco)
Scrive i .wav in assets/suoni/. Tutto è sintetizzato: niente diritti da pagare.
"""

import os
import struct
import sys

import numpy as np

FREQ = 22050
CARTELLA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "suoni")
rng = np.random.default_rng(7)


def t(durata):
    return np.arange(int(durata * FREQ)) / FREQ


def inviluppo(n, attacco=0.005, rilascio=0.1, forma=1.0):
    e = np.ones(n)
    a = max(1, int(attacco * FREQ))
    r = max(1, int(rilascio * FREQ))
    e[:a] = np.linspace(0, 1, a)
    if r < n:
        e[-r:] *= np.linspace(1, 0, r) ** forma
    return e


def decadimento(n, tau):
    return np.exp(-np.arange(n) / FREQ / tau)


def nota(f):
    return 440.0 * 2 ** ((f - 69) / 12)


def rumore(n):
    return rng.uniform(-1, 1, n)


def passa_basso(x, taglio):
    """Filtro a un polo (abbastanza per smussare il rumore)."""
    a = np.exp(-2 * np.pi * taglio / FREQ)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def passa_basso_veloce(x, taglio, passaggi=2):
    """Media mobile ripetuta: un passa basso veloce senza cicli Python."""
    k = max(1, int(FREQ / taglio / 2))
    finestra = np.ones(k) / k
    for _ in range(passaggi):
        x = np.convolve(x, finestra, mode="same")
    return x


def piano_elettrico(f, durata, volume=0.3):
    tt = t(durata)
    s = np.sin(2 * np.pi * f * tt) + 0.35 * np.sin(2 * np.pi * 2 * f * tt) * decadimento(len(tt), 0.3)
    s += 0.12 * np.sin(2 * np.pi * 3.01 * f * tt) * decadimento(len(tt), 0.15)
    s *= 1 + 0.08 * np.sin(2 * np.pi * 5 * tt)  # tremolo da organo anni '50
    return volume * s * decadimento(len(tt), durata * 0.6) * inviluppo(len(tt), 0.008, 0.05)


def vibrafono(f, durata, volume=0.25):
    tt = t(durata)
    s = np.sin(2 * np.pi * f * tt) + 0.2 * np.sin(2 * np.pi * 4 * f * tt) * decadimento(len(tt), 0.2)
    s *= 1 + 0.3 * np.sin(2 * np.pi * 6 * tt)
    return volume * s * decadimento(len(tt), 0.5) * inviluppo(len(tt), 0.003, 0.05)


def basso(f, durata, volume=0.45):
    tt = t(durata)
    s = np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * 2 * f * tt)
    return volume * s * decadimento(len(tt), 0.35) * inviluppo(len(tt), 0.004, 0.04)


def spazzola(durata, volume=0.08):
    n = int(durata * FREQ)
    return volume * passa_basso_veloce(rumore(n), 5000, 1) * decadimento(n, 0.06)


def cassa(volume=0.5):
    tt = t(0.25)
    f = 110 * np.exp(-tt * 18) + 45
    fase = 2 * np.pi * np.cumsum(f) / FREQ
    return volume * np.sin(fase) * decadimento(len(tt), 0.09)


def mixa(traccia, suono, inizio_s, avvolgi=True):
    i = int(inizio_s * FREQ)
    n = len(suono)
    lung = len(traccia)
    if i + n <= lung:
        traccia[i:i + n] += suono
    else:
        parte = lung - i
        traccia[i:] += suono[:parte]
        if avvolgi:
            traccia[:n - parte] += suono[parte:]


def normalizza(x, picco=0.85):
    m = np.max(np.abs(x))
    return x * (picco / m) if m > 0 else x


def scrivi(nome, x, picco=0.85):
    os.makedirs(CARTELLA, exist_ok=True)
    x = normalizza(np.asarray(x, float), picco)
    dati = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with open(os.path.join(CARTELLA, nome + ".wav"), "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 36 + len(dati)) + b"WAVE")
        f.write(b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, FREQ, FREQ * 2, 2, 16))
        f.write(b"data" + struct.pack("<I", len(dati)) + dati)
    print("%-16s %5.1f s" % (nome, len(x) / FREQ))


# ------------------------------------------------------------------ effetti


def clic():
    n = int(0.05 * FREQ)
    tt = t(0.05)
    return (0.6 * np.sin(2 * np.pi * 1800 * tt) + 0.4 * rumore(n)) * decadimento(n, 0.008)


def raccolta():
    # registratore di cassa: due note di campanello e un "cling"
    out = np.zeros(int(0.6 * FREQ))
    for k, (m, inizio) in enumerate(((84, 0.0), (88, 0.07), (91, 0.14))):
        mixa(out, vibrafono(nota(m), 0.45, 0.4), inizio, False)
    return out


def costruito():
    out = np.zeros(int(1.2 * FREQ))
    for m, inizio in ((72, 0.0), (76, 0.1), (79, 0.2), (84, 0.32)):
        mixa(out, piano_elettrico(nota(m), 0.8, 0.4), inizio, False)
        mixa(out, vibrafono(nota(m + 12), 0.6, 0.15), inizio, False)
    return out


def livello():
    out = np.zeros(int(1.8 * FREQ))
    for m, inizio in ((67, 0.0), (72, 0.12), (76, 0.24), (79, 0.36), (84, 0.5)):
        mixa(out, vibrafono(nota(m), 1.0, 0.4), inizio, False)
    mixa(out, piano_elettrico(nota(48), 1.3, 0.3), 0.5, False)
    mixa(out, piano_elettrico(nota(55), 1.3, 0.25), 0.5, False)
    return out


def notifica():
    out = np.zeros(int(0.5 * FREQ))
    mixa(out, vibrafono(nota(81), 0.4, 0.35), 0.0, False)
    mixa(out, vibrafono(nota(76), 0.4, 0.3), 0.09, False)
    return out


def sparo(pesante=False):
    durata = 0.6 if pesante else 0.35
    n = int(durata * FREQ)
    colpo = rumore(n) * decadimento(n, 0.09 if pesante else 0.045)
    colpo = passa_basso_veloce(colpo, 1800 if pesante else 3500, 1)
    tt = t(durata)
    botto = np.sin(2 * np.pi * (60 if pesante else 90) * tt * np.exp(-tt * 4)) * decadimento(n, 0.08)
    return colpo + (0.9 if pesante else 0.5) * botto


def colpo():
    n = int(0.18 * FREQ)
    tt = t(0.18)
    return (np.sin(2 * np.pi * 120 * tt * np.exp(-tt * 8)) + 0.5 * passa_basso_veloce(rumore(n), 900, 1)) * decadimento(n, 0.04)


def zombie(variante=0):
    durata = 1.3 + 0.3 * variante
    tt = t(durata)
    n = len(tt)
    base = 85 + 15 * variante + 12 * np.sin(2 * np.pi * 1.3 * tt)
    fase = 2 * np.pi * np.cumsum(base) / FREQ
    voce = np.sign(np.sin(fase)) * 0.4 + np.sin(fase) * 0.6
    # vocale "uuuh" -> "aaah" grezza: rumore filtrato che si apre
    rauco = passa_basso_veloce(rumore(n), 700, 2) * 2.5
    s = (voce + rauco) * (0.6 + 0.4 * np.sin(2 * np.pi * 3.5 * tt) ** 2)
    s = passa_basso_veloce(s, 1100, 1)
    return s * inviluppo(n, 0.15, 0.5, 1.5)


def esplosione():
    n = int(1.6 * FREQ)
    tt = t(1.6)
    boom = passa_basso_veloce(rumore(n), 260, 3) * 6 * decadimento(n, 0.45)
    tuono = np.sin(2 * np.pi * 45 * tt * np.exp(-tt)) * decadimento(n, 0.3)
    crepitio = passa_basso_veloce(rumore(n), 3000, 1) * decadimento(n, 0.08) * 0.6
    return boom + tuono + crepitio


def allarme():
    tt = t(2.4)
    f = 600 + 350 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.85 * tt - np.pi / 2))
    fase = 2 * np.pi * np.cumsum(f) / FREQ
    s = np.sin(fase) + 0.3 * np.sin(2 * fase)
    return s * inviluppo(len(tt), 0.05, 0.3)


def vittoria():
    out = np.zeros(int(2.2 * FREQ))
    for m, inizio, d in ((60, 0.0, 0.25), (64, 0.18, 0.25), (67, 0.36, 0.25), (72, 0.54, 1.4)):
        mixa(out, piano_elettrico(nota(m + 12), d + 0.6, 0.35), inizio, False)
        mixa(out, vibrafono(nota(m + 24), d + 0.4, 0.2), inizio, False)
    for m in (48, 55, 64):
        mixa(out, piano_elettrico(nota(m), 1.5, 0.22), 0.54, False)
    return out


def sconfitta():
    out = np.zeros(int(2.6 * FREQ))
    for m, inizio in ((67, 0.0), (66, 0.35), (65, 0.7), (64, 1.05)):
        mixa(out, piano_elettrico(nota(m), 1.2, 0.35), inizio, False)
    mixa(out, basso(nota(40), 1.4, 0.5), 1.05, False)
    return out


def radio():
    n = int(1.1 * FREQ)
    tt = t(1.1)
    statico = passa_basso_veloce(rumore(n), 4000, 1) * (0.3 + 0.7 * (rng.random(n) > 0.97)) * 0.5
    bip = np.sin(2 * np.pi * 1000 * tt) * ((tt % 0.25) < 0.08) * (tt > 0.4) * 0.6
    return (statico + bip) * inviluppo(n, 0.02, 0.15)


def martello():
    out = np.zeros(int(0.9 * FREQ))
    for inizio in (0.0, 0.3, 0.6):
        tt = t(0.25)
        n = len(tt)
        clink = (np.sin(2 * np.pi * 2100 * tt) + 0.6 * np.sin(2 * np.pi * 3170 * tt)) * decadimento(n, 0.05)
        mixa(out, clink * 0.6 + 0.3 * rumore(n) * decadimento(n, 0.01), inizio, False)
    return out


def porta():
    # bussano al cancello: tre colpi di legno
    out = np.zeros(int(0.9 * FREQ))
    for inizio in (0.0, 0.22, 0.44):
        tt = t(0.15)
        n = len(tt)
        mixa(out, (np.sin(2 * np.pi * 180 * tt) + 0.4 * passa_basso_veloce(rumore(n), 1200, 1)) * decadimento(n, 0.03),
             inizio, False)
    return out


# ------------------------------------------------------------------ musiche


def musica_citta():
    """Lounge anni '50 un po' ironico: Do - La- - Fa - Sol, 100 bpm, 16 battute in loop."""
    bpm = 100
    beat = 60 / bpm
    battute = 16
    durata = battute * 4 * beat
    out = np.zeros(int(durata * FREQ))
    accordi = [(48, [60, 64, 67, 71]), (45, [60, 64, 69, 72]), (41, [60, 65, 69, 72]), (43, [59, 62, 67, 71])]
    melodia = [
        [76, None, 79, 77, 76, None, 74, None], [72, None, 76, None, 69, None, None, None],
        [77, None, 76, 74, 72, None, 74, 76], [74, None, None, None, 71, 72, 74, None],
        [79, None, 81, 79, 76, None, 72, None], [76, None, 74, 72, 69, None, None, None],
        [72, 74, 77, None, 76, 74, 72, None], [74, None, 71, None, 67, None, None, None],
    ]
    for b in range(battute):
        radice, voci = accordi[b % 4]
        inizio = b * 4 * beat
        # piano: accordo sul 1 e sul "e" del 2 (stile swing)
        for colpo, d in ((0.0, 1.4), (1.66, 0.9), (2.0, 1.0)):
            for v in voci:
                mixa(out, piano_elettrico(nota(v), d * beat + 0.3, 0.09), inizio + colpo * beat)
        # basso camminante
        passi = [radice, radice + 4, radice + 7, radice + 9] if b % 2 == 0 else [radice + 12, radice + 9, radice + 7, radice + 4]
        for k, m in enumerate(passi):
            mixa(out, basso(nota(m), beat * 0.95, 0.35), inizio + k * beat)
        # batteria: spazzole swing, cassa leggera
        for k in range(4):
            mixa(out, spazzola(beat * 0.6, 0.05 if k % 2 == 0 else 0.08), inizio + k * beat)
            mixa(out, spazzola(beat * 0.3, 0.035), inizio + (k + 0.66) * beat)
        mixa(out, cassa(0.25), inizio)
        mixa(out, cassa(0.18), inizio + 2 * beat)
        # vibrafono con la melodia, solo nella seconda metà del giro
        if b >= 8 or b % 4 >= 2:
            frase = melodia[b % 8]
            for k, m in enumerate(frase):
                if m is not None:
                    mixa(out, vibrafono(nota(m), beat * 1.2, 0.16), inizio + k * beat / 2)
    return out


def musica_battaglia():
    """Buio, fuori dalle mura: bordone grave che respira, battito, vento."""
    durata = 32.0
    tt = t(durata)
    n = len(tt)
    lfo = 0.5 + 0.5 * np.sin(2 * np.pi * tt / durata * 2)
    bordone = np.zeros(n)
    for f, v in ((41.2, 0.5), (41.6, 0.4), (61.7, 0.25), (82.4, 0.15), (98.0, 0.08 * 1.0)):
        bordone += v * np.sin(2 * np.pi * f * tt + rng.random() * 6.28)
    bordone *= 0.6 + 0.4 * lfo
    vento = passa_basso_veloce(rumore(n), 500, 3) * 3.0
    vento *= 0.3 + 0.7 * (0.5 + 0.5 * np.sin(2 * np.pi * tt / durata * 4 + 1.0))
    out = bordone + vento * 0.35
    # battito del cuore ogni 1,1 s
    for k in range(int(durata / 1.1)):
        mixa(out, cassa(0.5), k * 1.1)
        mixa(out, cassa(0.3), k * 1.1 + 0.28)
    # note di carillon stonato, rade
    for k, (m, quando) in enumerate(((75, 4.0), (74, 4.6), (70, 12.0), (69, 20.5), (75, 21.1), (63, 28.0))):
        mixa(out, vibrafono(nota(m) * 1.004, 2.5, 0.12), quando)
    # dissolvenza circolare: inizio e fine si raccordano
    return out


def main():
    effetti = {
        "clic": clic(), "raccolta": raccolta(), "costruito": costruito(), "livello": livello(),
        "notifica": notifica(), "sparo": sparo(), "sparo_pesante": sparo(True), "colpo": colpo(),
        "zombie_1": zombie(0), "zombie_2": zombie(1), "zombie_3": zombie(2), "esplosione": esplosione(),
        "allarme": allarme(), "vittoria": vittoria(), "sconfitta": sconfitta(), "radio": radio(),
        "martello": martello(), "porta": porta(),
    }
    for nome, x in effetti.items():
        scrivi(nome, x)
    if "--senza-musica" not in sys.argv:
        scrivi("musica_citta", musica_citta(), 0.7)
        scrivi("musica_battaglia", musica_battaglia(), 0.7)


if __name__ == "__main__":
    main()
