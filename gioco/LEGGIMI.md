# Rifugio – Tappe 1-15 in 3D

La strada della città con i modelli 3D cartoon creati in Blender: mura con torretta di guardia, Deposito rottami, Orto, Case, tre lotti liberi e le zone infestate che si fanno sempre più buie verso il confine. Luce del tramonto con ombre, lampioni, bidoni in fiamme che tremolano e lo skyline della città abbandonata sullo sfondo.

## Come aprirlo

1. Apri Godot 4.7 (o più recente), scegli **Importa** e seleziona `project.godot` in questa cartella.
2. Al primo avvio Godot importa i modelli `.glb` (ci mette qualche secondo).
3. Premi **F5** per avviare.

## Comandi

| Azione | Mouse / trackpad | Telefono |
| --- | --- | --- |
| Scorrere la città | Trascina, oppure scorri con due dita | Trascina |
| Zoom | Rotellina o pizzico sul trackpad | Pizzico con due dita |
| Dettagli di un lotto | Clic sul lotto | Tocco sul lotto |

## I modelli 3D

Ogni edificio ha **tre modelli, uno per livello** (`assets/modelli/<edificio>_l1.glb`, `_l2.glb`, `_l3.glb`): potenziando si vede cosa cambia, per esempio la Casa prende garage e mansarda al livello 2 e un secondo piano con la veranda al livello 3. Lo stile è low poly con texture dipinte (mattoni, assi di legno, lamiera arrugginita, tegole, cemento, tende a righe) e un contorno scuro da fumetto. Le texture sono in `assets/modelli/texture/` e sono condivise da tutti i modelli.

Per vederli tutti insieme apri `strumenti/vetrina.tscn` in Godot e premi **F6**: gli edifici sono in fila ai tre livelli. Trascina per scorrere, rotellina per lo zoom.

### Rigenerarli

I modelli nascono dagli script nella cartella `../blender/`:

| File | Contenuto |
| --- | --- |
| `crea_modelli.py` | Da lanciare: genera tutto |
| `rifugio_edifici.py` | I 15 edifici, livello per livello |
| `rifugio_altri.py` | Mura, lotto libero, zona infestata, cantiere, lampione |
| `rifugio_modello.py` | Il kit: forme, finestre, porte, tetti, insegne, casse, auto... e la palette |
| `rifugio_geometria.py` | Forme low poly, contorno, coordinate delle texture, esportazione .glb |
| `rifugio_texture.py` | Le texture dipinte, generate al volo |
| `rifugio_blender.py` | La parte che lavora dentro Blender |

Con Blender (crea anche `blender/modelli.blend` da ritoccare a mano e le anteprime in `blender/anteprime/`):

```
/Applications/Blender.app/Contents/MacOS/Blender --background --python ~/Desktop/rifugio/blender/crea_modelli.py
```

Senza Blender basta Python 3 con numpy (solo i .glb, più veloce):

```
python3 ~/Desktop/rifugio/blender/crea_modelli.py
```

Per rigenerare solo alcuni edifici: aggiungi `-- --solo case,orto` al comando di Blender, oppure `--solo case,orto` a quello di Python. Godot reimporta da solo i file cambiati.

Nei modelli ci sono due segnaposti che il gioco legge da solo: `insegna_…` (dove scrivere il nome dell'edificio, con larghezza e colore del testo nel nome) e `cima` (sopra il tetto, dove vanno barre e icone). Se ritocchi un modello a mano in Blender, lasciali al loro posto.

## Com'è organizzato

| File | Contenuto |
| --- | --- |
| `script/citta_3d.gd` | La scena: cielo, luci, strada, skyline, telecamera, tocchi |
| `script/lotto_3d.gd` | Un lotto: modello del livello giusto, insegna, oscuramento, selezione |
| `strumenti/vetrina.tscn` | Tutti i modelli in fila, per guardarli |
| `script/bilanciamento.gd` | Tutti i numeri del gioco dal documento di design |
| `script/stato_gioco.gd` | Stato della partita: risorse, livello, lotti |
| `script/interfaccia.gd` | Barra delle risorse, schede, elenco cittadini |
| `script/generatore_cittadini.gd` | Nomi, rarità, statistiche, tratti e aspetto dei cittadini |
| `script/figura_cittadino.gd` | Gli omini 3D che camminano per la città e combattono |
| `script/battaglia.gd` | La battaglia: ambiente, ondate, colpi, abilità, esito |
| `script/battaglia_hud.gd` | Interfaccia della battaglia |
| `script/figura_zombie.gd` | Gli zombie a silhouette |

## Costruire (tappa 2)

1. Tocca un **lotto libero**: si apre il menu con gli edifici sbloccati al livello attuale della città, più un'anteprima dei prossimi.
2. Ogni riga mostra costo in materiali e tempo, presi dal bilanciamento: ogni nuovo edificio costa il 12% in più (le Case non contano) e richiede il 10% di tempo in più.
3. **Costruisci** apre un cantiere con barra di avanzamento e conto alla rovescia sopra il lotto.
4. Toccando il cantiere puoi **finire subito** spendendo tappi (1 tappo ogni 10 secondi rimanenti).
5. A fine lavori l'edificio compare e la città guadagna esperienza (un decimo del costo). Salendo di livello si sbloccano nuovi edifici.

I cantieri usano l'ora reale: continuano anche a gioco chiuso.

## Produrre e raccogliere (tappa 3)

- Gli edifici di produzione hanno una **barra verde** sopra il tetto che si riempie a ogni ciclo.
- Quando c'è qualcosa da raccogliere compare l'**icona della risorsa** che saltella, con la quantità pronta: **tocca l'edificio per raccogliere**. Un secondo tocco apre la scheda.
- Ogni edificio tiene da parte fino a 3 cicli, poi si ferma finché non raccogli. Ogni risorsa ha un massimo (300 all'inizio, cresce con il livello della città): la cifra in alto diventa gialla quando è al limite. Il Magazzino (dal livello 2) alza entrambi i limiti.
- La scheda di un edificio mostra resa al minuto, cicli pronti, tempo al prossimo ciclo e il pulsante **Raccogli**.
- I cittadini mangiano 1 cibo al minuto a testa. Se il cibo finisce la cifra diventa rossa e compare l'avviso "La città ha fame!".

I tempi usano l'ora reale: la produzione continua anche a gioco chiuso.

## Cittadini (tappa 4)

- Si parte con 4 cittadini: il più forte lavora al Deposito, il più agile all'Orto, gli altri passeggiano sul marciapiede.
- Ognuno ha **Forza, Agilità, Intelligenza, Carisma** (1-10), una **rarità** (comune, raro, leggendario: la barretta colorata), a volte un **tratto** e un **umore**.
- Il pulsante **Cittadini** in alto apre l'elenco completo.
- Nella scheda di un edificio, **Assegna un cittadino** mostra tutti in ordine di bravura per quel lavoro; **Togli** lo libera. Senza lavoratori l'edificio si ferma; più la statistica giusta è alta, più va veloce (la scheda mostra la velocità).
- Ogni 2 minuti e mezzo un **sopravvissuto** arriva al cancello con un "!" sopra la testa: tocca le mura per vederlo e accoglierlo (serve un posto letto libero: ogni Casa ne dà 4) o mandarlo via.

## Salvataggio (tappa 5)

- La partita si salva da sola ogni 10 secondi, quando chiudi il gioco e dopo ogni cantiere o nuovo cittadino. Riaprendo il gioco ritrovi la tua città.
- A gioco chiuso cantieri e produzione vanno avanti. I cittadini mangiano al massimo per 15 minuti di assenza, prima dalla dispensa e poi dal raccolto pronto nell'orto. Le cure in Ambulatorio vanno avanti.
- Se sei stato via più di 30 secondi, all'avvio compare **Bentornato, sindaco!** con il riepilogo: tempo passato, cantieri finiti, risorse da raccogliere, cibo mangiato, sopravvissuti al cancello.
- Il pulsante **Menu** in alto mostra l'ultimo salvataggio, permette di **salvare subito** e di iniziare una **nuova partita** (va toccato due volte, per sicurezza).
- Il salvataggio è il file `salvataggio.txt` nella cartella dati di Godot: su Mac in `~/Library/Application Support/Godot/app_userdata/Rifugio/`. Nella versione per browser resta salvato nel browser.

## Battaglie fuori dalle mura (tappa 6)

- Tocca le **mura** e poi **Esci dalle mura**, oppure tocca direttamente la **zona infestata** più vicina alla città.
- La scheda mostra ondate, tipi di zombie e ricompensa. Scegli fino a 3 cittadini (4 dal livello 10, 5 dal 20) e premi **Parti**.
- Fuori è buio e silenzioso: la squadra avanza, gli zombie arrivano da destra. **Tocca uno zombie per sparare**: spara il primo cittadino che ha ricaricato e ogni colpo costa una munizione. Senza munizioni si colpisce solo da vicino.
- In basso ogni cittadino ha la sua **abilità** (Spinta, Raffica, Cura o Grido, in base alla statistica migliore) e il pulsante **Ritira** per salvarlo prima che muoia. **Ritirata** in alto riporta a casa tutti.
- Attenzione agli **esplosivi** (verdastri): se arrivano addosso alla squadra feriscono tutti. Abbattili prima.
- Vincendo il lotto diventa libero, arriva il bottino e in fondo alla strada compare una nuova zona più difficile. Chi muore è perso per sempre; i feriti si curano subito con una medicina (dopo una vittoria) o guariscono piano piano in città.
- Puoi provare la battaglia anche da sola: in Godot apri `scene/battaglia.tscn` e premi **F6**.

## Attacchi alla città (tappa 7)

- Dal **livello 3** gli zombie attaccano le mura: il primo attacco arriva dopo 15 minuti, poi sempre più spesso man mano che la città cresce.
- Un minuto prima compare in alto **"Zombie in arrivo"** con il conto alla rovescia. Quando arrivano, gli zombie premono contro il cancello e il pulsante diventa **"ATTACCO! Difendi le mura"**.
- Tocca il pulsante (o le mura) e scegli: **Combatti** con una squadra davanti alle mura (3 ondate, si gioca come le missioni) oppure **Lascia fare alle difese**. Se non scegli entro un minuto, le difese si arrangiano da sole.
- **Guardie alle mura**: nella scheda delle mura puoi assegnare fino a 3 cittadini come guardie, come se fosse un lavoro. Difendono la città anche quando non giochi e sono la squadra proposta in caso di attacco. La scheda dice se le difese sono deboli, sufficienti o ottime.
- **Mura e torrette** (dal livello 3): ogni livello aggiunge una torretta che spara da sola.
- Se le mura cedono si perdono risorse e alcuni edifici restano **danneggiati**: anneriti, con il fumo e fermi. Toccali e premi **Ripara**.
- A gioco chiuso gli attacchi sono più deboli e li affrontano guardie e torrette; trovi il resoconto nel **Bentornato**.

## Ambulatorio e barcollanti (tappa 8)

- L'**Ambulatorio** si costruisce dal livello 5. Produce medicine e ha **2 letti per livello** per i barcollanti catturati.
- In battaglia, se in Ambulatorio c'è un letto libero, un **barcollante** quasi abbattuto cade a terra con la scritta **"+ CATTURA"**: toccalo entro 8 secondi per catturarlo. Se non lo tocchi, muore.
- Tornati in città, apri l'Ambulatorio: ogni barcollante si cura con **3 medicine**. La cura va più veloce con medici intelligenti; senza medici è lentissima.
- A cura finita il barcollante torna umano ed entra in città come cittadino (segnato **ex zombie**), se c'è un posto letto libero.
- Nella stessa scheda vedi i **feriti** della città: con l'Ambulatorio guariscono più in fretta, oppure li curi subito con 1 medicina.

## Potenziamento e allenamento (tappa 9)

- Nella scheda di ogni edificio c'è il **prossimo livello**: cosa migliora, quanto costa (materiali e tappi) e quanto dura. Premi **Potenzia**.
- Durante i lavori l'edificio ha un'impalcatura ed è fermo. Puoi **finire subito** con i tappi, come per i cantieri.
- Ogni livello dà un posto di lavoro in più e +25% di produzione; le Case danno 4 posti letto in più, il Magazzino più capienza, le Mura una torretta in più, l'Ambulatorio 2 letti in più. L'edificio cambia modello e la targhetta prende una stella.
- **Palestra** (livello 10), **Biblioteca** (12) e **Teatro** (14) allenano Forza/Agilità, Intelligenza e Carisma. Assegna gli allievi come per un lavoro: sotto ognuno vedi quale statistica sta salendo e quanto manca.
- Ogni punto richiede più tempo del precedente (da 3 a 4 servono 6 minuti). Gli edifici potenziati e il tratto Studioso allenano più in fretta. L'allenamento continua a gioco chiuso.
- Ogni risorsa ora può arrivare più in alto man mano che la città sale di livello.

## Officina ed equipaggiamento (tappa 10)

- L'**Officina** si costruisce dal livello 7. Assegna dei lavoratori (conta la Forza) e scegli cosa mettere sul **banco**: un'arma o un vestito, pagando materiali e tappi. Senza lavoratori il banco è fermo; il lavoro va avanti anche a gioco chiuso.
- Sopra l'Officina compare cosa sta fabbricando e quanto manca. Quando è pronto, l'oggetto va nel deposito.
- **Armi** (una per cittadino): Sparachiodi (rapido), Doppietta (lenta ma fortissima), Carabina e Mitra (Officina livello 2), Fucile di precisione (livello 3, fora la corazza dei Corazzati). Chi non ha niente usa la pistola arrugginita.
- **Vestiti** (uno per cittadino): Tuta da meccanico +Forza, Tuta da ginnastica +Agilità, Camice +Intelligenza, Completo elegante +Carisma (livello 2). Il vestito si vede addosso alla figura.
- La **qualità** è il livello dell'Officina: ★ ★★ ★★★. Ogni stella in più dà +15% di danno alle armi e +1 al vestito, e costa di più.
- Apri **Cittadini** e premi **Equipaggia**: vedi arma, vestito, danno per colpo e ricarica, e gli oggetti nel deposito da provare. Le statistiche alzate dal vestito sono in verde e contano nel lavoro e in battaglia; l'allenamento guarda quelle di base.
- Chi muore in battaglia perde anche arma e vestito: il resoconto dice cosa è rimasto sul campo.

## La Radio (tappa 11)

- La **Radio** (dal livello 8) ha degli operatori: conta il Carisma.
- Già solo costruirla fa arrivare i sopravvissuti più spesso: ogni livello di Radio accorcia l'attesa (da 2 minuti e mezzo a poco più di un minuto con la Radio al livello 3).
- Dalla sua scheda trasmetti un **appello**: «Chiunque sia là fuori» oppure gente forte, svelta, sveglia o simpatica. Costa tappi e dura qualche minuto (meno con operatori bravi); poi chi risponde arriva subito al cancello, con +2 nella statistica chiesta.
- Più la Radio è potenziata, più spesso risponde qualcuno di raro o leggendario.
- Attenzione: la radio la sentono anche gli zombie. Ogni appello fa arrivare prima il prossimo attacco (5 minuti prima).

## Rifiniture (tappa 12)

- **Guida per la prima partita**: in una partita nuova un riquadro in basso spiega cosa fare in 5 passi, con una freccia gialla sul lotto da toccare. Avanza da sola quando fai la cosa giusta; si salta con «Salta la guida» e si rivede dal **Menu**.
- **Musica e suoni**: un motivetto lounge anni '50 in città, un bordone cupo col battito del cuore fuori dalle mura; spari, zombie, esplosioni, allarme, registratore di cassa, campanelli. Tutto è sintetizzato da `strumenti/genera_suoni.py` (rilanciandolo si rigenerano i file in `assets/suoni/`). Dal **Menu** si spengono musica ed effetti.
- **Telefono**: zoom col pizzico, interfaccia più grande sugli schermi piccoli e, se lo tieni in verticale, l'invito a girarlo.
- Le schede troppo lunghe ora scorrono invece di uscire dallo schermo.

## Versione per browser (tappa 13)

La cartella `build/web/` contiene il gioco pronto per il browser (va su computer e telefono, Chrome e Safari).

**Provarlo sul Mac**: il browser non apre il gioco facendo doppio clic su `index.html`, serve un piccolo server. Da Terminale:

```
cd ~/Desktop/rifugio/gioco/build/web
python3 -m http.server 8000
```

poi apri http://localhost:8000 nel browser. Per provarlo sul telefono collegato allo stesso Wi‑Fi, apri `http://<indirizzo del Mac>:8000` (l'indirizzo è in Impostazioni di Sistema > Wi‑Fi > Dettagli).

**Pubblicarlo** (gratis) su itch.io: crea un progetto «HTML», carica lo zip della cartella `build/web`, spunta «This file will be played in the browser», dimensioni 1280×720, e attiva «Mobile friendly» in orizzontale. Va bene anche GitHub Pages: la build non usa i thread, quindi non servono impostazioni speciali del server.

**Rifarla da Godot** dopo una modifica: la prima volta installa i modelli di esportazione (Editor > Gestisci modelli di esportazione > Scarica e installa), poi Progetto > Esporta > Web > **Esporta progetto** in `build/web/index.html`.

Nel browser la partita si salva nel browser stesso: su un altro browser o dispositivo si ricomincia da capo.

## Bilanciamento (tappa 14)

Ho fatto giocare un giocatore simulato per una settimana di calendario, a gioco chiuso tra una sessione e l'altra. Con i numeri vecchi restava bloccato tra il livello 2 e il 5: senza munizioni non liberava zone, senza zone non aveva lotti, e il prossimo edificio costava più di quanto il magazzino potesse contenere. Cosa è cambiato:

- Si parte con 60 munizioni; l'**Armeria** e il **Magazzino** si sbloccano al livello 2 (l'Armeria costa 120).
- Le zone liberate danno 15 munizioni per livello di difficoltà, e anche respingere un attacco ne fa recuperare.
- Ogni nuovo edificio costa il 12% in più (prima 15%) e **le Case non contano**; la capienza cresce del 25% a livello della città e ogni livello di Magazzino aggiunge 400.
- La difficoltà delle zone sale di uno **ogni due zone**; gli zombie crescono del 15% per livello di difficoltà (prima 20%); il Colosso ha 450 di vita e 24 di danno.
- Ogni zona liberata dà 10 punti esperienza per livello di difficoltà (prima 20).
- Nuovo: **Demolisci**, in fondo alla scheda di ogni edificio (va toccato due volte). Libera il lotto e restituisce un quarto del costo; una Casa non si può abbattere se qualcuno resterebbe senza letto.
- Corretto un errore: due zombie esplosivi vicini che scoppiavano insieme bloccavano la battaglia.

Risultato: un giocatore occasionale (mezz'ora ogni 4 ore) arriva al Teatro, livello 14, in circa 3 giorni e mezzo; uno attivo in poco più di 2. Il dettaglio è nel documento di design. Le partite già iniziate tengono le zone che hanno, ma usano subito i numeri nuovi.

## Nuovo inizio, cancello e mura a livelli (tappa 15)

Dopo le prime partite giocate a mano:

- **Si parte da zero.** Nessun edificio già pronto: solo le mura e otto lotti liberi prima delle zone infestate. Si hanno 170 materiali e 60 tappi, abbastanza per costruire Deposito rottami, Orto e Case e per finirli subito con i tappi. Ogni edificio finito dà almeno 15 punti esperienza, così all'inizio la barra della città sale in fretta. La guida accompagna i primi passi (costruire, assegnare, raccogliere). Se in città non c'è nessun Deposito rottami (o nessun Orto), il primo è gratis: così la partita non resta mai bloccata senza materiali o senza cibo.
- **Le battaglie arrivano con l'Armeria.** Le squadre escono dalle mura, e gli zombie attaccano la città, solo quando c'è un'Armeria (si costruisce dal livello 2). Le zone infestate sono più lontane: prima ci sono otto lotti liberi.
- **Battaglie più giocabili.** La squadra spara da sola allo zombie più vicino, a metà velocità; toccando si spara alla massima velocità. Un tocco a vuoto colpisce lo zombie più vicino (mira assistita).
- **Il cancello resta chiuso.** Chi bussa aspetta fuori, a sinistra del cancello. Se lo accogli, i battenti si aprono, entra e si richiudono alle sue spalle. Se lo mandi via, se ne torna da dove è venuto.
- **Il custode del cancello.** Dalla scheda delle mura si sceglie un cittadino che decide da solo chi far entrare: rari e leggendari sempre (se c'è un letto), nessuno se mancano letti o cibo, e chi ha un tratto negativo viene respinto, se il custode se ne accorge (più Intelligenza, meno sviste). Ogni decisione gli dà esperienza e va nel suo curriculum (decisioni, accolti, mandati via, sviste): è il primo candidato a fare il sindaco nelle fasi successive.
- **Mura a tre livelli**: Palizzata, Palizzata rinforzata (dal livello 4 della città, 250 materiali e 40 tappi) e Fortezza (dal livello 8, 700 materiali e 120 tappi). Ogni livello ha il suo modello, un posto in più per le guardie e difese più forti: le difese automatiche rendono il 35% e poi il 75% in più, e nella difesa giocata gli zombie fanno meno danno.
- Chi non ha un letto è di cattivo umore: conviene costruire presto le Case.

Prove fatte: battaglie con tre cittadini medi senza armi, **senza mai toccare lo schermo**: vinte le difficoltà da 1 a 4, perse la 5 e la 6 (lì servono tocchi, armi dell'Officina e cittadini migliori). Nella simulazione di una settimana la città arriva al livello 2 in un minuto e al livello 3 in mezz'ora, senza blocchi.

**Per provarla subito:** la partita salvata è della versione vecchia. Apri Menu > Nuova partita (tocca due volte) per ricominciare da zero.

### Correzioni dopo la prova (tappa 15.1)

- **Assegnare i cittadini non funzionava**: toccando un pulsante che rifà la scheda (per esempio «+ Assegna un cittadino»), il rilascio del dito finiva sulla città dietro e chiudeva la scheda. Ora la città considera solo i tocchi cominciati su di lei. Lo stesso errore faceva saltare anche altre finestre.
- Le schede si ridimensionano da sole quando cambia il contenuto (niente più spazi vuoti o pulsanti spostati) e i testi lunghi vanno a capo.
- **Risoluzione**: il gioco si apre a finestra ingrandita (1600×900 se non si può ingrandire). In una finestra più piccola di 1280×720 l'interfaccia passa alla scala da telefono, così le scritte restano leggibili.
- Se lo provi da Godot e il gioco compare dentro l'editor, nella scheda «Gioco» (Game) disattiva «Incorpora il gioco alla prossima esecuzione» (Embed Game on Next Play) dal menu con i tre puntini: così si apre nella sua finestra, a piena risoluzione.

## Prossima tappa

Il prototipo della città è completo. Il prossimo passo, da progettare prima su carta, è il passaggio dalla città alla regione con il successore. Intanto conviene giocarlo davvero: i numeri della simulazione vanno confermati a mano.
