extends Node
## Tutti i numeri del gioco, presi dal documento di design (sezione "Bilanciamento").
## Cambiando i valori qui cambia il bilanciamento di tutto il gioco.

const CRESCITA_ESPERIENZA := 1.25   # ogni livello città richiede il 25% in più
const ESPERIENZA_BASE := 100.0
const CRESCITA_COSTO := 1.12        # ogni nuovo edificio costa il 12% in più (le Case non contano)
const CRESCITA_TEMPO := 1.10        # e richiede il 10% di tempo in più
const TEMPO_MASSIMO := 43200.0      # 12 ore
const MOLTIPLICATORE_COSTO_LIVELLO := [1.0, 2.0, 4.0]
const MOLTIPLICATORE_TEMPO_LIVELLO := [1.0, 2.0, 4.0]
const QUOTA_TAPPI_POTENZIAMENTO := 0.2
const BONUS_PRODUZIONE_LIVELLO := 1.25
const LIVELLO_MASSIMO_EDIFICIO := 3
## Le mura hanno tre livelli come gli edifici. Ogni livello aggiunge posti
## per le guardie e rende la difesa più forte (moltiplica la potenza delle
## difese automatiche e riduce il danno degli zombie nella difesa giocata).
const MURA_LIVELLI := [
	{"nome": "Palizzata", "guardie": 0, "difesa": 1.0},
	{"nome": "Palizzata rinforzata", "guardie": 1, "difesa": 1.35, "materiali": 250, "tappi": 40, "tempo": 600.0, "sblocco": 4},
	{"nome": "Fortezza", "guardie": 2, "difesa": 1.75, "materiali": 700, "tappi": 120, "tempo": 1800.0, "sblocco": 8},
]
## Un edificio appena finito dà almeno questa esperienza alla città:
## all'inizio, quando gli edifici costano poco, la barra sale in fretta.
const ESPERIENZA_MINIMA_COSTRUZIONE := 15
## Custode del cancello: esperienza per ogni decisione (più un extra se è
## giusta) e probabilità di riconoscere un tratto negativo (base + per punto
## di Intelligenza).
const ESPERIENZA_DECISIONE_CUSTODE := 3
const ESPERIENZA_DECISIONE_BUONA := 2
const CUSTODE_OCCHIO_BASE := 0.3
const CUSTODE_OCCHIO_PER_PUNTO := 0.08
## In battaglia la squadra spara anche da sola, ma più piano: il tempo di
## ricarica viene moltiplicato per questo valore. Toccando si spara al massimo.
const RITARDO_TIRO_AUTOMATICO := 2.0
## Portata del tiro automatico (metri davanti alla squadra).
const PORTATA_TIRO_AUTOMATICO := 11.0

const RISORSE := {
	"cibo": {"nome": "Cibo", "icona": "res://assets/icone/cibo.svg"},
	"materiali": {"nome": "Materiali", "icona": "res://assets/icone/materiali.svg"},
	"munizioni": {"nome": "Munizioni", "icona": "res://assets/icone/munizioni.svg"},
	"medicine": {"nome": "Medicine", "icona": "res://assets/icone/medicine.svg"},
	"tappi": {"nome": "Tappi", "icona": "res://assets/icone/tappi.svg"},
}

## sblocco = livello città, costo = materiali, tempo = secondi
const EDIFICI := {
	"deposito_rottami": {"nome": "Deposito rottami", "tipo": "Produzione", "statistica": "Forza", "produce": "materiali", "sblocco": 1, "costo": 30, "tempo": 10.0, "descrizione": "Recupera rottami utili per costruire ed espandere la città."},
	"orto": {"nome": "Orto", "tipo": "Produzione", "statistica": "Agilità", "produce": "cibo", "sblocco": 1, "costo": 40, "tempo": 10.0, "descrizione": "Cibo lento ma economico, coltivato sotto la serra."},
	"case": {"nome": "Case", "tipo": "Supporto", "statistica": "", "produce": "", "sblocco": 1, "costo": 50, "tempo": 10.0, "descrizione": "Più posti letto: la città può ospitare più cittadini."},
	"negozio": {"nome": "Negozio", "tipo": "Produzione", "statistica": "Carisma", "produce": "tappi", "sblocco": 2, "costo": 100, "tempo": 30.0, "descrizione": "Commercio con i viandanti, rende tappi."},
	"tavola_calda": {"nome": "Tavola calda", "tipo": "Produzione", "statistica": "Agilità", "produce": "cibo", "sblocco": 3, "costo": 120, "tempo": 30.0, "descrizione": "Cibo più veloce dell'orto."},
	"magazzino": {"nome": "Magazzino", "tipo": "Supporto", "statistica": "", "produce": "", "sblocco": 2, "costo": 150, "tempo": 45.0, "descrizione": "Più spazio per le risorse, anche a gioco chiuso."},
	"mura_torrette": {"nome": "Mura e torrette", "tipo": "Difesa", "statistica": "", "produce": "", "sblocco": 3, "costo": 150, "tempo": 60.0, "descrizione": "Aiutano durante gli attacchi alla città."},
	"armeria": {"nome": "Armeria", "tipo": "Produzione", "statistica": "Intelligenza", "produce": "munizioni", "sblocco": 2, "costo": 120, "tempo": 60.0, "descrizione": "Munizioni per le battaglie."},
	"ambulatorio": {"nome": "Ambulatorio", "tipo": "Produzione", "statistica": "Intelligenza", "produce": "medicine", "sblocco": 5, "costo": 250, "tempo": 90.0, "descrizione": "Medicine, cura dei feriti e degli zombie di livello 1."},
	"bar": {"nome": "Bar", "tipo": "Produzione", "statistica": "Carisma", "produce": "tappi", "sblocco": 6, "costo": 250, "tempo": 120.0, "descrizione": "Tappi e buon umore per i cittadini."},
	"officina": {"nome": "Officina", "tipo": "Produzione", "statistica": "Forza", "produce": "", "sblocco": 7, "costo": 300, "tempo": 120.0, "descrizione": "Fabbrica armi e vestiti per i cittadini."},
	"radio": {"nome": "Radio", "tipo": "Supporto", "statistica": "Carisma", "produce": "", "sblocco": 8, "costo": 400, "tempo": 180.0, "descrizione": "Trasmette appelli: i sopravvissuti arrivano più spesso e si può chiedere chi serve."},
	"palestra": {"nome": "Palestra", "tipo": "Supporto", "statistica": "Forza, Agilità", "produce": "", "sblocco": 10, "costo": 500, "tempo": 300.0, "descrizione": "Allena Forza e Agilità."},
	"biblioteca": {"nome": "Biblioteca", "tipo": "Supporto", "statistica": "Intelligenza", "produce": "", "sblocco": 12, "costo": 500, "tempo": 300.0, "descrizione": "Allena l'Intelligenza."},
	"teatro": {"nome": "Teatro", "tipo": "Supporto", "statistica": "Carisma", "produce": "", "sblocco": 14, "costo": 500, "tempo": 300.0, "descrizione": "Allena il Carisma."},
}

## Valori a difficoltà 1. Velocità = secondi per attraversare lo schermo.
const ZOMBIE := {
	"barcollante": {"nome": "Barcollante", "da_difficolta": 1, "vita": 20, "danno": 5, "attraversa": 20.0, "curabile": true},
	"corridore": {"nome": "Corridore", "da_difficolta": 2, "vita": 15, "danno": 4, "attraversa": 5.0, "curabile": false},
	"esplosivo": {"nome": "Esplosivo", "da_difficolta": 3, "vita": 30, "danno": 40, "attraversa": 14.0, "curabile": false},
	"corazzato": {"nome": "Corazzato", "da_difficolta": 5, "vita": 120, "danno": 10, "attraversa": 24.0, "curabile": false, "armatura": 5},
	"colosso": {"nome": "Colosso", "da_difficolta": 7, "vita": 450, "danno": 24, "attraversa": 40.0, "curabile": false},
}
const CRESCITA_ZOMBIE := 1.15
const DANNO_ARMA_BASE := 10
const VITA_CITTADINO_BASE := 100


func esperienza_per_livello(livello: int) -> int:
	return int(round(ESPERIENZA_BASE * pow(CRESCITA_ESPERIENZA, livello - 1)))


## Costo in materiali del prossimo edificio, dati gli edifici già costruiti.
func costo_costruzione(id: String, edifici_costruiti: int) -> int:
	return int(round(EDIFICI[id]["costo"] * pow(CRESCITA_COSTO, edifici_costruiti)))


func tempo_costruzione(id: String, edifici_costruiti: int) -> float:
	return minf(EDIFICI[id]["tempo"] * pow(CRESCITA_TEMPO, edifici_costruiti), TEMPO_MASSIMO)


## Costo per portare un edificio al livello indicato (2 o 3).
func costo_potenziamento(id: String, edifici_costruiti: int, livello: int) -> Dictionary:
	var materiali := int(round(costo_costruzione(id, edifici_costruiti) * MOLTIPLICATORE_COSTO_LIVELLO[livello - 1]))
	return {"materiali": materiali, "tappi": int(round(materiali * QUOTA_TAPPI_POTENZIAMENTO))}


func tempo_potenziamento(id: String, edifici_costruiti: int, livello: int) -> float:
	return minf(tempo_costruzione(id, edifici_costruiti) * MOLTIPLICATORE_TEMPO_LIVELLO[livello - 1], TEMPO_MASSIMO)


## Secondi tra un attacco e l'altro; -1 se la città è ancora troppo piccola.
func intervallo_attacchi(livello: int) -> float:
	if livello < 3:
		return -1.0
	return maxf(1800.0, 21600.0 * pow(0.9, livello - 3))


func difficolta_attacchi(livello: int) -> int:
	return mini(10, ceili(livello / 3.0))


func zombie_per_ondata(difficolta: int) -> int:
	return 5 + 2 * difficolta


func posti_squadra(livello: int) -> int:
	if livello >= 20:
		return 5
	if livello >= 10:
		return 4
	return 3


func formatta_tempo(secondi: float) -> String:
	var s := int(round(secondi))
	if s < 60:
		return "%d s" % s
	if s < 3600:
		return "%d min" % int(round(s / 60.0))
	return ("%.1f h" % (s / 3600.0)).replace(".", ",")


## Conto alla rovescia: "0:42", "12:05", "1h 05m".
func formatta_conto(secondi: float) -> String:
	var s := int(ceil(secondi))
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	return "%d:%02d" % [s / 60, s % 60]


# ------------------------------------------------------------------ produzione (tappa 3)

## Quanto produce un edificio di livello 1 a ogni ciclo, e in quanti secondi.
const PRODUZIONE := {
	"deposito_rottami": {"quantita": 12, "ciclo": 40.0},
	"orto": {"quantita": 10, "ciclo": 45.0},
	"tavola_calda": {"quantita": 14, "ciclo": 35.0},
	"negozio": {"quantita": 5, "ciclo": 60.0},
	"bar": {"quantita": 6, "ciclo": 50.0},
	"armeria": {"quantita": 6, "ciclo": 60.0},
	"ambulatorio": {"quantita": 3, "ciclo": 90.0},
}
## Cicli che un edificio tiene da parte prima di fermarsi in attesa di raccolta.
const CICLI_IN_DEPOSITO := 3
const CICLI_IN_PIU_PER_MAGAZZINO := 2
## Capienza di ogni risorsa in città.
const CAPIENZA_BASE := 300
const CAPIENZA_PER_MAGAZZINO := 400
## La capienza cresce del 20% a ogni livello della città, così i costi
## crescenti di edifici e potenziamenti restano raggiungibili.
const CRESCITA_CAPIENZA := 1.25
## Ogni abitante mangia questa quantità di cibo al minuto.
const CIBO_PER_ABITANTE_AL_MINUTO := 1.0
const POSTI_PER_CASA := 4
const ABITANTI_INIZIALI := 4


func produce(id: String) -> bool:
	return PRODUZIONE.has(id) and EDIFICI[id]["produce"] != ""


## Quantità per ciclo: +25% a ogni livello dell'edificio.
func quantita_per_ciclo(id: String, livello: int) -> int:
	return int(round(PRODUZIONE[id]["quantita"] * pow(BONUS_PRODUZIONE_LIVELLO, livello - 1)))


func durata_ciclo(id: String) -> float:
	return PRODUZIONE[id]["ciclo"]


## Resa al minuto, per le schede.
func resa_al_minuto(id: String, livello: int) -> float:
	return quantita_per_ciclo(id, livello) * 60.0 / durata_ciclo(id)

## Ogni quanto un sopravvissuto bussa al cancello.
const SECONDI_TRA_ARRIVI := 150.0


# ------------------------------------------------------------------ battaglie (tappa 6)

## Metri di campo che gli zombie percorrono nel tempo "attraversa" della tabella.
const LARGHEZZA_CAMPO := 18.0
const DANNO_COLPO_BASE := 6.0
const DANNO_PER_FORZA := 1.0
const DANNO_CORPO_A_CORPO := 4.0
const PORTATA_CORPO_A_CORPO := 3.5
const RICARICA_BASE := 1.2
const RICARICA_PER_AGILITA := 0.06
const RICARICA_MINIMA := 0.45
## Quanto spesso compare ogni tipo (tra quelli ammessi dalla difficoltà).
const PESI_ZOMBIE := {"barcollante": 6, "corridore": 3, "esplosivo": 2, "corazzato": 1}
## Abilità attive: ognuno usa quella della sua statistica migliore.
const ABILITA := {
	"forza": {"nome": "Spinta", "ricarica": 12.0, "descrizione": "Respinge e stordisce gli zombie vicini"},
	"agilita": {"nome": "Raffica", "ricarica": 10.0, "descrizione": "Una raffica di colpi sui più vicini"},
	"intelligenza": {"nome": "Cura", "ricarica": 15.0, "descrizione": "Cura tutta la squadra (1 medicina)"},
	"carisma": {"nome": "Grido", "ricarica": 14.0, "descrizione": "Stordisce tutti gli zombie"},
}


func vita_cittadino(c: Dictionary) -> float:
	return VITA_CITTADINO_BASE * (0.8 + 0.04 * stat(c, "forza"))


## quota_vita: da 0 a 1. Il Coraggioso colpisce più forte quando è ferito.
## L'arma moltiplica il danno: ogni livello di Officina in più vale ×1,15.
func danno_colpo(c: Dictionary, quota_vita: float) -> float:
	var danno := (DANNO_COLPO_BASE + DANNO_PER_FORZA * stat(c, "forza")) * moltiplicatore_arma(c)
	if c["tratto"] == "coraggioso" and quota_vita < 0.5:
		danno *= 1.5
	return danno


func danno_corpo_a_corpo(c: Dictionary) -> float:
	return DANNO_CORPO_A_CORPO + 0.5 * stat(c, "forza")


func ricarica(c: Dictionary) -> float:
	var base := maxf(RICARICA_MINIMA, RICARICA_BASE - RICARICA_PER_AGILITA * stat(c, "agilita"))
	return base * float(info_arma(c).get("ricarica", 1.0))


func statistica_abilita(c: Dictionary) -> String:
	var migliore := "forza"
	for nome in ["forza", "agilita", "intelligenza", "carisma"]:
		if stat(c, nome) > stat(c, migliore):
			migliore = nome
	return migliore


const DIFFICOLTA_MASSIMA := 10


## Difficoltà della zona infestata numero k (0 = la prima oltre i lotti iniziali):
## sale di uno ogni due zone, così la squadra ha il tempo di rinforzarsi.
func difficolta_zona(k: int) -> int:
	return mini(DIFFICOLTA_MASSIMA, 1 + maxi(0, k) / 2)


func ondate_missione(difficolta: int) -> int:
	return 2 + difficolta / 3


func zombie_per_ondata_missione(difficolta: int) -> int:
	return 3 + difficolta


func moltiplicatore_zombie(difficolta: int) -> float:
	return pow(CRESCITA_ZOMBIE, difficolta - 1)


## Esperienza per la città a ogni zona liberata, per punto di difficoltà.
const ESPERIENZA_MISSIONE := 10


func bottino(difficolta: int) -> Dictionary:
	return {"materiali": 25 * difficolta, "tappi": 4 * difficolta, "munizioni": 15 * difficolta, "cibo": 10 * difficolta}


# ------------------------------------------------------------------ attacchi alla città (tappa 7)

const ONDATE_ATTACCO := 3
## Le sentinelle avvisano un minuto prima.
const PREAVVISO_ATTACCO := 60.0
## Se nessuno risponde, dopo un minuto si difendono da sole.
const ATTESA_RISPOSTA := 60.0
## Il primo attacco arriva 15 minuti dopo aver raggiunto il livello 3.
const PRIMO_ATTACCO := 900.0
const MAX_ATTACCHI_A_GIOCO_CHIUSO := 2
## Secondi che ogni ondata impiega ad arrivare alle mura (difesa automatica).
const DURATA_ONDATA := 25.0
const DANNO_TORRETTA := 12.0
const CADENZA_TORRETTA := 1.5
const MAX_TORRETTE := 5
## Con una sconfitta piena si perde il 30% delle risorse e fino a 3 edifici
## vengono danneggiati; a gioco chiuso la metà, e al massimo 1 edificio.
const QUOTA_RISORSE_PERSE := 0.3
const EDIFICI_DANNEGGIATI := 3
## Riparare costa metà del costo base dell'edificio per ogni livello.
const COSTO_RIPARAZIONE := 0.5


func vita_media_zombie(difficolta: int) -> float:
	var somma := 0.0
	var pesi := 0
	for tipo in PESI_ZOMBIE:
		if int(ZOMBIE[tipo]["da_difficolta"]) <= difficolta:
			somma += float(ZOMBIE[tipo]["vita"]) * int(PESI_ZOMBIE[tipo])
			pesi += int(PESI_ZOMBIE[tipo])
	return somma / maxi(1, pesi) * moltiplicatore_zombie(difficolta)


## Chi respinge un attacco recupera anche le munizioni lasciate dagli zombie.
func ricompensa_difesa(difficolta: int) -> Dictionary:
	return {"materiali": 15 * difficolta, "tappi": 3 * difficolta, "munizioni": 10 * difficolta}


# ------------------------------------------------------------------ ambulatorio (tappa 8)

## Ogni livello di Ambulatorio dà questi letti per i barcollanti da curare.
const LETTI_PER_LIVELLO_AMBULATORIO := 2
## Secondi di lavoro per curare un barcollante (con un medico da 5 di Intelligenza).
const LAVORO_CURA_ZOMBIE := 300.0
const MEDICINE_CURA_ZOMBIE := 3
## Senza medici la cura va avanti lo stesso, ma lentissima.
const VELOCITA_CURA_SENZA_MEDICI := 0.25
## Un barcollante sotto questa quota di vita cade a terra e si può catturare.
const SOGLIA_CATTURA := 0.35
const SECONDI_A_TERRA := 8.0


# ------------------------------------------------------------------ allenamento (tappa 9)

## Cosa allena ogni edificio. La Palestra allena la più bassa tra Forza e Agilità.
const ALLENAMENTO := {
	"palestra": ["forza", "agilita"],
	"biblioteca": ["intelligenza"],
	"teatro": ["carisma"],
}
## Secondi per salire di un punto, moltiplicati per il valore attuale
## (da 3 a 4 servono 6 minuti, da 8 a 9 sedici).
const SECONDI_PER_PUNTO := 120.0
const STATISTICA_MASSIMA := 10


func allena(id: String) -> bool:
	return ALLENAMENTO.has(id)


## L'Officina non produce risorse: fabbrica armi e vestiti.
func fabbrica(id: String) -> bool:
	return id == "officina"


## Edifici dove si assegnano cittadini (lavoratori o allievi).
func ha_lavoratori(id: String) -> bool:
	return produce(id) or allena(id) or fabbrica(id) or id == "radio"


## Velocità di allenamento: +50% per ogni livello dell'edificio, +50% per lo Studioso.
func velocita_allenamento(livello: int, studioso: bool) -> float:
	return (1.0 + 0.5 * (livello - 1)) * (1.5 if studioso else 1.0)


# ------------------------------------------------------------------ equipaggiamento (tappa 10)

## Armi: un cittadino senza arma usa la pistola di serie. Il danno si
## moltiplica per "danno" e per 1,15 a ogni livello di qualità; la ricarica
## si moltiplica per "ricarica" (sotto 1 = spara più in fretta, e consuma più
## munizioni). "officina" è il livello di Officina che serve per fabbricarla.
const ARMA_DI_SERIE := {"nome": "Pistola arrugginita", "danno": 1.0, "ricarica": 1.0,
		"descrizione": "Quella che hanno tutti", "colore": "#3a2c24", "lunghezza": 0.45}
const ARMI := {
	"sparachiodi": {"nome": "Sparachiodi", "danno": 0.9, "ricarica": 0.65, "officina": 1, "materiali": 80, "tappi": 10,
			"lavoro": 150.0, "descrizione": "Leggero e rapido: tanti colpi, tante munizioni",
			"colore": "#e3b448", "lunghezza": 0.55},
	"doppietta": {"nome": "Doppietta", "danno": 1.9, "ricarica": 1.6, "officina": 1, "materiali": 100, "tappi": 12,
			"lavoro": 180.0, "descrizione": "Lenta ma devastante", "colore": "#7a4e33", "lunghezza": 0.85},
	"carabina": {"nome": "Carabina", "danno": 1.4, "ricarica": 0.95, "officina": 2, "materiali": 180, "tappi": 25,
			"lavoro": 300.0, "descrizione": "Precisa e affidabile", "colore": "#5b3a29", "lunghezza": 0.95},
	"mitra": {"nome": "Mitra", "danno": 0.95, "ricarica": 0.45, "officina": 2, "materiali": 220, "tappi": 30,
			"lavoro": 360.0, "descrizione": "Una pioggia di piombo (e di munizioni)", "colore": "#2c2a31",
			"lunghezza": 0.7},
	"fucile_precisione": {"nome": "Fucile di precisione", "danno": 2.6, "ricarica": 1.7, "perforante": true,
			"officina": 3, "materiali": 350, "tappi": 50, "lavoro": 600.0,
			"descrizione": "Fora anche le corazze", "colore": "#2f7f86", "lunghezza": 1.15},
}
## Vestiti: alzano una statistica di tanti punti quanto la qualità (+1, +2, +3).
const VESTITI := {
	"tuta_meccanico": {"nome": "Tuta da meccanico", "statistica": "forza", "officina": 1, "materiali": 60, "tappi": 8,
			"lavoro": 120.0, "colore": "#3f6fa3"},
	"tuta_ginnastica": {"nome": "Tuta da ginnastica", "statistica": "agilita", "officina": 1, "materiali": 60,
			"tappi": 8, "lavoro": 120.0, "colore": "#d0453a"},
	"camice": {"nome": "Camice", "statistica": "intelligenza", "officina": 1, "materiali": 60, "tappi": 8,
			"lavoro": 120.0, "colore": "#f4f1e6"},
	"completo": {"nome": "Completo elegante", "statistica": "carisma", "officina": 2, "materiali": 120, "tappi": 20,
			"lavoro": 240.0, "colore": "#2b2230"},
}
const MOLTIPLICATORE_DANNO_QUALITA := 1.15
## Qualità più alta: costa il 50% in più e richiede il 50% di lavoro in più per livello.
const COSTO_PER_QUALITA := 0.5
const STELLE := ["", "★", "★★", "★★★"]


func info_oggetto(oggetto: Dictionary) -> Dictionary:
	var tipo: String = oggetto.get("tipo", "")
	if ARMI.has(tipo):
		return ARMI[tipo]
	if VESTITI.has(tipo):
		return VESTITI[tipo]
	return {}


func e_arma(tipo: String) -> bool:
	return ARMI.has(tipo)


func nome_oggetto(oggetto: Dictionary) -> String:
	var info := info_oggetto(oggetto)
	if info.is_empty():
		return "?"
	return "%s %s" % [info["nome"], STELLE[clampi(int(oggetto.get("qualita", 1)), 1, 3)]]


## Cosa fa un oggetto, in breve, per le schede.
func effetto_oggetto(tipo: String, qualita: int) -> String:
	if ARMI.has(tipo):
		var a: Dictionary = ARMI[tipo]
		var danno := float(a["danno"]) * pow(MOLTIPLICATORE_DANNO_QUALITA, qualita - 1)
		var testo := "Danno ×%s  ·  %s" % [str(snappedf(danno, 0.01)), _testo_cadenza(float(a["ricarica"]))]
		if a.get("perforante", false):
			testo += "  ·  fora le corazze"
		return testo
	if VESTITI.has(tipo):
		var stat_vestito: String = VESTITI[tipo]["statistica"]
		return "+%d %s" % [qualita, GeneratoreCittadini.NOMI_STATISTICHE[stat_vestito]]
	return ""


func _testo_cadenza(ricarica_arma: float) -> String:
	if ricarica_arma < 0.8:
		return "spara molto in fretta"
	if ricarica_arma < 1.0:
		return "spara un po' più in fretta"
	if ricarica_arma > 1.3:
		return "lenta a ricaricare"
	return "cadenza normale"


func costo_oggetto(tipo: String, qualita: int) -> Dictionary:
	var info: Dictionary = ARMI[tipo] if ARMI.has(tipo) else VESTITI[tipo]
	var fattore := 1.0 + COSTO_PER_QUALITA * (qualita - 1)
	return {"materiali": int(round(float(info["materiali"]) * fattore)), "tappi": int(round(float(info["tappi"]) * fattore))}


## Secondi di lavoro con una squadra a velocità 1 (un fabbro da 5 di Forza).
func lavoro_oggetto(tipo: String, qualita: int) -> float:
	var info: Dictionary = ARMI[tipo] if ARMI.has(tipo) else VESTITI[tipo]
	return float(info["lavoro"]) * (1.0 + COSTO_PER_QUALITA * (qualita - 1))


func info_arma(c: Dictionary) -> Dictionary:
	var arma: Dictionary = c.get("arma", {})
	if arma.is_empty() or not ARMI.has(arma.get("tipo", "")):
		return ARMA_DI_SERIE
	return ARMI[arma["tipo"]]


func moltiplicatore_arma(c: Dictionary) -> float:
	var arma: Dictionary = c.get("arma", {})
	var info := info_arma(c)
	var qualita := int(arma.get("qualita", 1)) if not arma.is_empty() else 1
	return float(info["danno"]) * pow(MOLTIPLICATORE_DANNO_QUALITA, qualita - 1)


func arma_perforante(c: Dictionary) -> bool:
	return bool(info_arma(c).get("perforante", false))


## Bonus del vestito su una statistica.
func bonus_vestito(c: Dictionary, nome: String) -> int:
	var vestito: Dictionary = c.get("vestito", {})
	if vestito.is_empty() or not VESTITI.has(vestito.get("tipo", "")):
		return 0
	return int(vestito.get("qualita", 1)) if VESTITI[vestito["tipo"]]["statistica"] == nome else 0


## Statistica effettiva: quella del cittadino più il vestito. L'allenamento
## guarda solo quella di base.
func stat(c: Dictionary, nome: String) -> int:
	return int(c["statistiche"].get(nome, 1)) + bonus_vestito(c, nome)


# ------------------------------------------------------------------ radio (tappa 11)

## Ogni livello di Radio in città accorcia l'attesa tra un sopravvissuto e l'altro.
const RADIO_ARRIVI_PIU_FREQUENTI := 0.3
## Appello: secondi di lavoro con operatori a velocità 1 (uno da 5 di Carisma), tappi per livello di Radio.
const LAVORO_APPELLO := 240.0
const TAPPI_APPELLO := 10
## Il segnale lo sentono anche gli zombie: l'attacco successivo arriva prima.
const ANTICIPO_ATTACCO_APPELLO := 300.0
## Chi si può chiamare: "" = chiunque; altrimenti la statistica forte richiesta.
const APPELLI := {
	"": {"nome": "Chiunque sia là fuori", "testo": "«Qui Rifugio: c'è posto per tutti.»"},
	"forza": {"nome": "Gente forte", "testo": "«Cerchiamo braccia robuste per i rottami.»"},
	"agilita": {"nome": "Gente svelta", "testo": "«Serve chi corre più degli zombie.»"},
	"intelligenza": {"nome": "Gente sveglia", "testo": "«Medici, tecnici, professori: fatevi sentire.»"},
	"carisma": {"nome": "Gente simpatica", "testo": "«Il bar è aperto: portate il buon umore.»"},
}
## Rarità di chi risponde a un appello, per livello della Radio (comune, raro, leggendario).
const RARITA_APPELLO := [
	{"comune": 70, "raro": 25, "leggendario": 5},
	{"comune": 55, "raro": 37, "leggendario": 8},
	{"comune": 40, "raro": 48, "leggendario": 12},
]
## Chi risponde a un appello mirato ha +2 nella statistica chiesta.
const BONUS_APPELLO := 2


func intervallo_arrivi(livelli_radio: int) -> float:
	return SECONDI_TRA_ARRIVI / (1.0 + RADIO_ARRIVI_PIU_FREQUENTI * livelli_radio)


func costo_appello(livello_radio: int, tipo: String) -> int:
	return TAPPI_APPELLO * livello_radio * (1 if tipo == "" else 2)
