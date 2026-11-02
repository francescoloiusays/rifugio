class_name GeneratoreCittadini
extends RefCounted
## Crea nuovi cittadini: nome, rarità, statistiche, tratto e aspetto.
## Le probabilità seguono il documento di design.

const STATISTICHE := ["forza", "agilita", "intelligenza", "carisma"]
const NOMI_STATISTICHE := {"forza": "Forza", "agilita": "Agilità", "intelligenza": "Intelligenza", "carisma": "Carisma"}

const NOMI_M := ["Aldo", "Bruno", "Carlo", "Dino", "Enzo", "Franco", "Gino", "Luigi", "Mario", "Nello",
		"Otello", "Pietro", "Renato", "Sergio", "Tonino", "Ugo", "Vittorio", "Walter", "Fausto", "Rocco"]
const NOMI_F := ["Ada", "Bice", "Carla", "Delia", "Elsa", "Franca", "Gina", "Ines", "Lina", "Marisa",
		"Nella", "Olga", "Pina", "Rina", "Silvana", "Teresa", "Velia", "Wanda", "Zita", "Loretta"]
const COGNOMI := ["Rossi", "Bianchi", "Ferrari", "Esposito", "Romano", "Colombo", "Ricci", "Marino",
		"Greco", "Bruno", "Gallo", "Conti", "De Luca", "Mancini", "Costa", "Giordano", "Rizzo", "Lombardi",
		"Moretti", "Barbieri", "Fontana", "Santoro", "Mariani", "Rinaldi", "Caruso", "Ferri", "Bellini"]

## Tratti: tipo e probabilità dal documento di design.
const TRATTI := {
	"pigro": {"nome": "Pigro", "tipo": "negativo", "effetto": "Produce meno, ma il suo umore non scende mai"},
	"codardo": {"nome": "Codardo", "tipo": "negativo", "effetto": "In battaglia scappa quando la salute è bassa"},
	"chiacchierone": {"nome": "Chiacchierone", "tipo": "negativo", "effetto": "Distrae i colleghi, ma al bar rende di più"},
	"allegro": {"nome": "Allegro", "tipo": "minore", "effetto": "Alza un po' l'umore dei colleghi"},
	"parsimonioso": {"nome": "Parsimonioso", "tipo": "minore", "effetto": "Mangia la metà"},
	"studioso": {"nome": "Studioso", "tipo": "minore", "effetto": "Si allena più in fretta"},
	"stacanovista": {"nome": "Stacanovista", "tipo": "forte", "effetto": "Produce il 25% in più ovunque"},
	"coraggioso": {"nome": "Coraggioso", "tipo": "forte", "effetto": "Fa più danno quando è ferito e non scappa mai"},
	"fortunato": {"nome": "Fortunato", "tipo": "forte", "effetto": "Trova più bottino nelle missioni"},
}
## Su 100 cittadini: 50 senza tratto, 25 negativi, 18 positivi minori, 7 positivi forti.
const PROBABILITA_TRATTI := {"": 50, "negativo": 25, "minore": 18, "forte": 7}
## Rarità: comune 80%, raro 17%, leggendario 3%.
const RARITA := {
	"comune": {"nome": "Comune", "probabilita": 80, "min": 1, "max": 4, "colore": Color("#9c9184")},
	"raro": {"nome": "Raro", "probabilita": 17, "min": 2, "max": 6, "colore": Color("#4f9ad6")},
	"leggendario": {"nome": "Leggendario", "probabilita": 3, "min": 5, "max": 9, "colore": Color("#e3a32f")},
}

const PELLE := [Color("#f2d1b3"), Color("#e0b18c"), Color("#c68e65"), Color("#9c6644"), Color("#6f4630")]
const CAPELLI := [Color("#2b1e18"), Color("#5b3a29"), Color("#a8743f"), Color("#d9b26b"), Color("#b9b2a8"), Color("#8c3b2a")]
const VESTITI := [Color("#2f7f86"), Color("#e8836b"), Color("#e3b448"), Color("#8fc9b5"), Color("#c8473d"),
		Color("#6d5a8c"), Color("#4f7a3f"), Color("#3d5a80")]

static var _contatore := 0


static func _scegli_pesato(casuale: RandomNumberGenerator, pesi: Dictionary) -> String:
	var totale := 0
	for chiave in pesi:
		totale += int(pesi[chiave] if pesi[chiave] is int else pesi[chiave]["probabilita"])
	var estratto := casuale.randi_range(1, totale)
	for chiave in pesi:
		estratto -= int(pesi[chiave] if pesi[chiave] is int else pesi[chiave]["probabilita"])
		if estratto <= 0:
			return chiave
	return pesi.keys()[0]


static func crea(casuale: RandomNumberGenerator, rarita_forzata := "") -> Dictionary:
	_contatore += 1
	var donna := casuale.randf() < 0.5
	var nome: String = (NOMI_F if donna else NOMI_M)[casuale.randi_range(0, (NOMI_F if donna else NOMI_M).size() - 1)]
	var cognome: String = COGNOMI[casuale.randi_range(0, COGNOMI.size() - 1)]

	var rarita := rarita_forzata if rarita_forzata != "" else _scegli_pesato(casuale, RARITA)
	var limiti: Dictionary = RARITA[rarita]
	var statistiche := {}
	for stat in STATISTICHE:
		statistiche[stat] = casuale.randi_range(limiti["min"], limiti["max"])
	# Ogni cittadino ha un punto forte: una statistica sale di 1-2.
	var forte: String = STATISTICHE[casuale.randi_range(0, 3)]
	statistiche[forte] = mini(10, statistiche[forte] + casuale.randi_range(1, 2))

	var tipo_tratto := _scegli_pesato(casuale, PROBABILITA_TRATTI)
	var tratto := ""
	if tipo_tratto != "":
		var possibili: Array[String] = []
		for id in TRATTI:
			if TRATTI[id]["tipo"] == tipo_tratto:
				possibili.append(id)
		tratto = possibili[casuale.randi_range(0, possibili.size() - 1)]

	return {
		# Unico anche tra una sessione e l'altra: millisecondi dal 1970 + numero casuale.
		"id": "c%d_%d" % [int(Time.get_unix_time_from_system() * 1000.0), casuale.randi_range(0, 999999)],
		"nome": nome,
		"cognome": cognome,
		"donna": donna,
		"rarita": rarita,
		"statistiche": statistiche,
		"tratto": tratto,
		"livello": 1,
		"esperienza": 0,
		"umore": 70.0,
		"salute": 100,
		"lavoro": -1,
		"aspetto": {
			"pelle": PELLE[casuale.randi_range(0, PELLE.size() - 1)],
			"capelli": CAPELLI[casuale.randi_range(0, CAPELLI.size() - 1)],
			"vestito": VESTITI[casuale.randi_range(0, VESTITI.size() - 1)],
			"altezza": casuale.randf_range(0.92, 1.08),
			"cappello": casuale.randf() < 0.3,
		},
	}


static func nome_completo(cittadino: Dictionary) -> String:
	return "%s %s" % [cittadino["nome"], cittadino["cognome"]]


## "Forza" -> "forza", "Forza, Agilità" -> la prima.
static func chiave_statistica(nome: String) -> String:
	var primo := nome.split(",")[0].strip_edges()
	for chiave in NOMI_STATISTICHE:
		if NOMI_STATISTICHE[chiave] == primo:
			return chiave
	return ""
