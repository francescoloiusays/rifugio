extends Node
## Lo stato della partita: risorse, livello della città, lotti della strada
## e cantieri in corso.

signal risorse_cambiate
signal livello_cambiato
signal lotto_cambiato(indice: int)
signal notifica(testo: String)
signal raccolto(indice: int, risorsa: String, quantita: int)
signal cittadini_cambiati
signal sopravvissuto_arrivato
signal attacco_cambiato
signal attacco_risolto(esito: Dictionary)
signal pazienti_cambiati
signal equipaggiamento_cambiato
signal guida_cambiata
## Il custode del cancello ha deciso da solo chi far entrare.
signal custode_ha_deciso(accolto: bool)

## Stati possibili di un lotto
const MURA := "mura"
const COSTRUITO := "costruito"
const CANTIERE := "cantiere"
const LIBERO := "libero"
const BLOCCATO := "bloccato"

## Un tappo accelera di questi secondi un cantiere.
const SECONDI_PER_TAPPO := 10.0

const PERCORSO_SALVATAGGIO := "user://salvataggio.txt"
const VERSIONE_SALVATAGGIO := 1
const SECONDI_TRA_SALVATAGGI := 10.0
## A gioco chiuso i cittadini mangiano al massimo per questi minuti:
## così tornando dopo una notte la città non è morta di fame.
const MINUTI_PASTI_A_GIOCO_CHIUSO := 15

const RISORSE_INIZIALI := {
	"cibo": 60,
	"materiali": 170,
	"munizioni": 60,
	"medicine": 5,
	"tappi": 60,
}
## Lotti liberi tra le mura e la prima zona infestata, all'inizio della partita.
const LOTTI_LIBERI_INIZIALI := 8
## Secondi che il custode aspetta prima di decidere (il tempo di vedere chi bussa).
const SECONDI_DECISIONE_CUSTODE := 9.0

var risorse := RISORSE_INIZIALI.duplicate()
var livello_citta := 1
var esperienza := 40
var lotti: Array[Dictionary] = []
var cittadini: Array[Dictionary] = []
## Chi aspetta al cancello di essere accolto ({} se nessuno).
var sopravvissuto: Dictionary = {}
var _prossimo_arrivo := 0.0
var _ultimo_pasto := 0.0
var _ultimo_umore := 0.0
var _affamati := false
var _casuale := RandomNumberGenerator.new()
## Cosa è successo mentre il gioco era chiuso (vuoto se partita nuova).
var riepilogo_ritorno: Dictionary = {}
var ultimo_salvataggio := 0.0
var _salvataggio_attivo := true
## La missione in corso: lotto, difficoltà e squadra (vuota se non si combatte).
var missione: Dictionary = {}
## Quando arriva il prossimo attacco alla città (0 = sotto il livello 3).
var prossimo_attacco := 0.0
## Gli zombie sono alle mura e aspettano che qualcuno li affronti.
var attacco_pronto := false
var _attacco_iniziato_alle := 0.0
## Secondi di gioco passati da quando gli zombie sono alle mura: si contano
## con il tempo di gioco, così un rallentamento non fa scadere la scelta.
var attesa_attacco := 0.0
## Barcollanti catturati in cura all'Ambulatorio: {cittadino, progresso, in_cura}.
var pazienti: Array[Dictionary] = []
var _preavviso_dato := false
## Armi e vestiti fabbricati e non ancora indossati: {id, tipo, qualita}.
var equipaggiamento: Array[Dictionary] = []
## Sopravvissuti che hanno risposto a un appello della Radio e stanno arrivando.
var in_arrivo: Array[Dictionary] = []
## Passo della guida per la prima partita (-1 = finita o saltata).
var guida := -1
## Chi decide da solo chi entra in città (id del cittadino, "" = nessuno).
var custode := ""
var _sopravvissuto_dal := 0.0
var _prossimo_oggetto := 1


func _ready() -> void:
	_simboli_nel_font()
	if not carica():
		nuova_partita()


## Nel browser non ci sono i font del sistema: stelle, frecce e simboli
## (★ ▼ → « ») li prende da DejaVu Sans, incluso nel gioco.
func _simboli_nel_font() -> void:
	var simboli := load("res://assets/font/DejaVuSans-Bold.ttf") as Font
	var base := ThemeDB.fallback_font
	if simboli != null and base != null and not base.fallbacks.has(simboli):
		var elenco := base.fallbacks.duplicate()
		elenco.append(simboli)
		base.fallbacks = elenco


func nuova_partita() -> void:
	var ora := adesso()
	_casuale.randomize()
	risorse = RISORSE_INIZIALI.duplicate()
	livello_citta = 1
	esperienza = 25
	riepilogo_ritorno = {}
	prossimo_attacco = 0.0
	attacco_pronto = false
	_preavviso_dato = false
	missione = {}
	pazienti = []
	equipaggiamento = []
	in_arrivo = []
	guida = 0
	custode = ""
	_prossimo_oggetto = 1
	# Si parte da zero: solo le mura e una fila di lotti liberi su cui
	# costruire Deposito, Orto e Case. Le zone infestate vengono dopo.
	lotti = [{"stato": MURA, "livello": 1}]
	for i in LOTTI_LIBERI_INIZIALI:
		lotti.append({"stato": LIBERO})
	for i in 6:
		lotti.append({"stato": BLOCCATO, "difficolta": Bilanciamento.difficolta_zona(i)})
	_crea_cittadini_iniziali()
	sopravvissuto = {}
	_prossimo_arrivo = ora + Bilanciamento.SECONDI_TRA_ARRIVI
	_ultimo_pasto = ora
	_ultimo_umore = ora
	_affamati = false
	risorse_cambiate.emit()
	livello_cambiato.emit()
	salva()


## Solo per le simulazioni di bilanciamento: sposta in avanti l'orologio.
var scarto_tempo := 0.0


func adesso() -> float:
	return Time.get_unix_time_from_system() + scarto_tempo


## Gli edifici già costruiti più quelli in cantiere: è il numero che fa
## crescere costi e tempi del prossimo.
func edifici_costruiti() -> int:
	var n := 0
	for lotto in lotti:
		if lotto["stato"] == COSTRUITO or lotto["stato"] == CANTIERE:
			n += 1
	return n


## Gli edifici che fanno salire i costi: tutti tranne le Case, che servono
## solo a ospitare e non devono rendere più cari gli altri.
func edifici_per_costo() -> int:
	var n := 0
	for lotto in lotti:
		if (lotto["stato"] == COSTRUITO or lotto["stato"] == CANTIERE) and lotto.get("edificio", "") != "case":
			n += 1
	return n


func esperienza_mancante() -> int:
	return Bilanciamento.esperienza_per_livello(livello_citta)


func aggiungi_esperienza(punti: int) -> void:
	esperienza += punti
	var livello_prima := livello_citta
	while esperienza >= esperienza_mancante():
		esperienza -= esperienza_mancante()
		livello_citta += 1
	livello_cambiato.emit()
	if livello_citta > livello_prima:
		notifica.emit("La città sale al livello %d!" % livello_citta)


# ------------------------------------------------------------------ costruzione


func edificio_sbloccato(id: String) -> bool:
	return livello_citta >= Bilanciamento.EDIFICI[id]["sblocco"]


func costo_costruzione(id: String) -> int:
	if gratis(id):
		return 0
	return Bilanciamento.costo_costruzione(id, edifici_per_costo())


## Rete di sicurezza: se in città non c'è nessun Deposito rottami (o nessun
## Orto), il primo è gratis. Così una partita non resta mai bloccata senza
## materiali o senza cibo.
func gratis(id: String) -> bool:
	if id != "deposito_rottami" and id != "orto":
		return false
	for lotto in lotti:
		if lotto.get("edificio", "") == id and (lotto["stato"] == COSTRUITO or lotto["stato"] == CANTIERE):
			return false
	return true


func tempo_costruzione(id: String) -> float:
	return Bilanciamento.tempo_costruzione(id, edifici_per_costo())


## Restituisce "" se si può costruire, altrimenti il motivo.
func motivo_blocco(indice: int, id: String) -> String:
	if lotti[indice]["stato"] != LIBERO:
		return "Il lotto non è libero"
	if not edificio_sbloccato(id):
		return "Serve il livello %d" % Bilanciamento.EDIFICI[id]["sblocco"]
	var mancano := costo_costruzione(id) - int(risorse["materiali"])
	if mancano > 0:
		return "Mancano %d materiali" % mancano
	return ""


func costruisci(indice: int, id: String) -> bool:
	if motivo_blocco(indice, id) != "":
		return false
	var costo := costo_costruzione(id)
	var durata := tempo_costruzione(id)
	risorse["materiali"] -= costo
	lotti[indice] = {
		"stato": CANTIERE,
		"edificio": id,
		"inizio": adesso(),
		"durata": durata,
		"costo": costo,
	}
	risorse_cambiate.emit()
	lotto_cambiato.emit(indice)
	notifica.emit("Cantiere aperto: %s (%s)" % [Bilanciamento.EDIFICI[id]["nome"], Bilanciamento.formatta_tempo(durata)])
	salva()
	return true


## Lavori in corso su un lotto: un cantiere o un potenziamento.
func in_lavori(indice: int) -> bool:
	return lotti[indice]["stato"] == CANTIERE or lotti[indice].has("potenzia")


func _lavori(indice: int) -> Dictionary:
	var lotto := lotti[indice]
	if lotto["stato"] == CANTIERE:
		return lotto
	return lotto.get("potenzia", {})


func secondi_rimanenti(indice: int) -> float:
	var lavori := _lavori(indice)
	if lavori.is_empty():
		return 0.0
	return maxf(0.0, float(lavori["inizio"]) + float(lavori["durata"]) - adesso())


func avanzamento(indice: int) -> float:
	var lavori := _lavori(indice)
	if lavori.is_empty() or float(lavori["durata"]) <= 0.0:
		return 1.0
	return clampf(1.0 - secondi_rimanenti(indice) / float(lavori["durata"]), 0.0, 1.0)


func costo_accelerazione(indice: int) -> int:
	return maxi(1, ceili(secondi_rimanenti(indice) / SECONDI_PER_TAPPO))


func accelera(indice: int) -> bool:
	if not in_lavori(indice):
		return false
	var costo := costo_accelerazione(indice)
	if int(risorse["tappi"]) < costo:
		notifica.emit("Servono %d tappi per finire subito" % costo)
		return false
	risorse["tappi"] -= costo
	risorse_cambiate.emit()
	if lotti[indice]["stato"] == CANTIERE:
		_completa(indice)
	else:
		_completa_potenziamento(indice)
	return true


# ------------------------------------------------------------------ potenziamento


## Restituisce "" se si può potenziare, altrimenti il motivo.
func motivo_blocco_potenziamento(indice: int) -> String:
	var lotto := lotti[indice]
	if lotto["stato"] != COSTRUITO and lotto["stato"] != MURA:
		return "Non è un edificio"
	if in_lavori(indice):
		return "Lavori già in corso"
	if lotto.get("danneggiato", false):
		return "Prima va riparato"
	var livello := int(lotto.get("livello", 1))
	if livello >= Bilanciamento.LIVELLO_MASSIMO_EDIFICIO:
		return "Livello massimo"
	if lotto["stato"] == MURA:
		var serve := int(Bilanciamento.MURA_LIVELLI[livello]["sblocco"])
		if livello_citta < serve:
			return "Serve la città al livello %d" % serve
	var costo := costo_potenziamento(indice)
	if int(risorse["materiali"]) < int(costo["materiali"]):
		return "Mancano %d materiali" % (int(costo["materiali"]) - int(risorse["materiali"]))
	if int(risorse["tappi"]) < int(costo["tappi"]):
		return "Mancano %d tappi" % (int(costo["tappi"]) - int(risorse["tappi"]))
	return ""


func costo_potenziamento(indice: int) -> Dictionary:
	var lotto := lotti[indice]
	if lotto["stato"] == MURA:
		var prossimo: Dictionary = Bilanciamento.MURA_LIVELLI[int(lotto.get("livello", 1))]
		return {"materiali": int(prossimo["materiali"]), "tappi": int(prossimo["tappi"])}
	return Bilanciamento.costo_potenziamento(lotto["edificio"], edifici_per_costo(), int(lotto.get("livello", 1)) + 1)


func tempo_potenziamento(indice: int) -> float:
	var lotto := lotti[indice]
	if lotto["stato"] == MURA:
		return float(Bilanciamento.MURA_LIVELLI[int(lotto.get("livello", 1))]["tempo"])
	return Bilanciamento.tempo_potenziamento(lotto["edificio"], edifici_per_costo(), int(lotto.get("livello", 1)) + 1)


## Nome di quello che c'è su un lotto: un edificio o le mura.
func nome_lotto(indice: int) -> String:
	var lotto := lotti[indice]
	if lotto["stato"] == MURA:
		return Bilanciamento.MURA_LIVELLI[clampi(int(lotto.get("livello", 1)), 1, 3) - 1]["nome"]
	if lotto.has("edificio"):
		return Bilanciamento.EDIFICI[lotto["edificio"]]["nome"]
	return "Lotto"


func livello_mura() -> int:
	return clampi(int(lotti[0].get("livello", 1)), 1, Bilanciamento.LIVELLO_MASSIMO_EDIFICIO)


## Durante i lavori l'edificio si ferma: niente produzione né allenamento.
func potenzia(indice: int) -> bool:
	if motivo_blocco_potenziamento(indice) != "":
		return false
	var costo := costo_potenziamento(indice)
	var durata := tempo_potenziamento(indice)
	_fissa_produzione(indice)
	_fissa_allenamento(indice)
	risorse["materiali"] = int(risorse["materiali"]) - int(costo["materiali"])
	risorse["tappi"] = int(risorse["tappi"]) - int(costo["tappi"])
	var lotto := lotti[indice]
	lotto["potenzia"] = {"inizio": adesso(), "durata": durata, "livello": int(lotto.get("livello", 1)) + 1,
			"costo": int(costo["materiali"])}
	risorse_cambiate.emit()
	lotto_cambiato.emit(indice)
	notifica.emit("Lavori di potenziamento: %s (%s)" % [nome_lotto(indice), Bilanciamento.formatta_tempo(durata)])
	salva()
	return true


func _completa_potenziamento(indice: int) -> void:
	var lotto := lotti[indice]
	var lavori: Dictionary = lotto.get("potenzia", {})
	if lavori.is_empty():
		return
	_fissa_produzione(indice)
	_fissa_allenamento(indice)
	lotto["livello"] = int(lavori["livello"])
	lotto.erase("potenzia")
	var punti := maxi(1, int(round(int(lavori.get("costo", 0)) / 10.0)))
	lotto_cambiato.emit(indice)
	cittadini_cambiati.emit()
	Suoni.suona("costruito", 0.0)
	notifica.emit("%s ora è al livello %d!  +%d esperienza" % [nome_lotto(indice), lotto["livello"], punti])
	aggiungi_esperienza(punti)


func _completa(indice: int) -> void:
	var lotto := lotti[indice]
	var id: String = lotto["edificio"]
	# i primi edifici, che costano poco, valgono comunque un bel pezzo di barra
	var punti := maxi(Bilanciamento.ESPERIENZA_MINIMA_COSTRUZIONE, int(round(lotto.get("costo", 0) / 10.0)))
	lotti[indice] = {"stato": COSTRUITO, "edificio": id, "livello": 1, "eff": 0.0, "agg": adesso()}
	lotto_cambiato.emit(indice)
	Suoni.suona("costruito", 0.0)
	notifica.emit("%s completato!  +%d esperienza" % [Bilanciamento.EDIFICI[id]["nome"], punti])
	aggiungi_esperienza(punti)


func _process(delta: float) -> void:
	if attacco_pronto:
		attesa_attacco += minf(delta, 0.25)
	for i in lotti.size():
		if lotti[i]["stato"] == CANTIERE and secondi_rimanenti(i) <= 0.0:
			_completa(i)
		elif lotti[i].has("potenzia") and secondi_rimanenti(i) <= 0.0:
			_completa_potenziamento(i)
	_mangia()
	_aggiorna_umore()
	_arrivi()
	_decisione_custode()
	_cure_periodiche()
	_attacchi()
	if adesso() - ultimo_salvataggio >= SECONDI_TRA_SALVATAGGI:
		salva()


# ------------------------------------------------------------------ salvataggio


func salva() -> bool:
	if not _salvataggio_attivo:
		return false
	var dati := {
		"versione": VERSIONE_SALVATAGGIO,
		"salvato_alle": adesso(),
		"risorse": risorse,
		"livello_citta": livello_citta,
		"esperienza": esperienza,
		"lotti": lotti,
		"cittadini": cittadini,
		"sopravvissuto": sopravvissuto,
		"prossimo_arrivo": _prossimo_arrivo,
		"ultimo_pasto": _ultimo_pasto,
		"affamati": _affamati,
		"prossimo_attacco": prossimo_attacco,
		"pazienti": pazienti,
		"equipaggiamento": equipaggiamento,
		"prossimo_oggetto": _prossimo_oggetto,
		"in_arrivo": in_arrivo,
		"guida": guida,
		"custode": custode,
	}
	# Scrive prima su un file temporaneo: se il gioco si chiude a metà,
	# il salvataggio vecchio resta intatto.
	var temporaneo := PERCORSO_SALVATAGGIO + ".tmp"
	var file := FileAccess.open(temporaneo, FileAccess.WRITE)
	if file == null:
		push_warning("Impossibile salvare: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(var_to_str(dati))
	file.close()
	var cartella := DirAccess.open("user://")
	if cartella == null or cartella.rename(temporaneo.get_file(), PERCORSO_SALVATAGGIO.get_file()) != OK:
		push_warning("Impossibile completare il salvataggio")
		return false
	ultimo_salvataggio = adesso()
	return true


func carica() -> bool:
	if not FileAccess.file_exists(PERCORSO_SALVATAGGIO):
		return false
	var dati = str_to_var(FileAccess.get_file_as_string(PERCORSO_SALVATAGGIO))
	if typeof(dati) != TYPE_DICTIONARY or int(dati.get("versione", 0)) != VERSIONE_SALVATAGGIO:
		push_warning("Salvataggio illeggibile o di un'altra versione: si parte da capo")
		return false
	_casuale.randomize()
	var ora := adesso()
	risorse = RISORSE_INIZIALI.duplicate()
	for chiave in dati["risorse"]:
		risorse[chiave] = int(dati["risorse"][chiave])
	livello_citta = int(dati["livello_citta"])
	esperienza = int(dati["esperienza"])
	lotti.assign(dati["lotti"])
	cittadini.assign(dati["cittadini"])
	sopravvissuto = dati["sopravvissuto"]
	_prossimo_arrivo = float(dati["prossimo_arrivo"])
	_affamati = bool(dati["affamati"])
	_ultimo_umore = ora
	prossimo_attacco = float(dati.get("prossimo_attacco", 0.0))
	pazienti.assign(dati.get("pazienti", []))
	equipaggiamento.assign(dati.get("equipaggiamento", []))
	_prossimo_oggetto = int(dati.get("prossimo_oggetto", 1))
	in_arrivo.assign(dati.get("in_arrivo", []))
	guida = int(dati.get("guida", -1))
	custode = String(dati.get("custode", ""))
	if trova_cittadino(custode).is_empty():
		custode = ""
	var fabbricati_via := _avanza_officine(maxf(0.0, ora - float(dati["salvato_alle"])), false)
	var appelli_via := _avanza_radio(maxf(0.0, ora - float(dati["salvato_alle"])), false)
	var curati_via := _avanza_cure(maxf(0.0, ora - float(dati["salvato_alle"])), false)
	var allenati_via := _allena_tutti(maxf(0.0, ora - float(dati["salvato_alle"])), false)
	attacco_pronto = false
	_preavviso_dato = false
	var minuti := clampi(int(floor((ora - float(dati["ultimo_pasto"])) / 60.0)), 0, MINUTI_PASTI_A_GIOCO_CHIUSO)
	var pasti := _pasti_a_gioco_chiuso(minuti)
	_ultimo_pasto = ora
	var attacchi := _attacchi_a_gioco_chiuso()
	riepilogo_ritorno = _calcola_riepilogo(maxf(0.0, ora - float(dati["salvato_alle"])), pasti)
	riepilogo_ritorno["attacchi"] = attacchi
	riepilogo_ritorno["curati"] = curati_via
	riepilogo_ritorno["allenati"] = allenati_via
	riepilogo_ritorno["fabbricati"] = fabbricati_via
	riepilogo_ritorno["appelli"] = appelli_via
	ultimo_salvataggio = ora
	return true


## Cosa troverà il giocatore al ritorno: si calcola prima che i cantieri
## si completino e che i cittadini mangino.
## A gioco chiuso i cittadini mangiano prima dalla dispensa e poi, se non
## basta, dal raccolto già pronto negli edifici che producono cibo.
func _pasti_a_gioco_chiuso(minuti: int) -> Dictionary:
	var fabbisogno := int(ceil(consumo_al_minuto() * minuti))
	var dalla_dispensa := mini(fabbisogno, int(risorse["cibo"]))
	risorse["cibo"] -= dalla_dispensa
	var manca := fabbisogno - dalla_dispensa
	var dal_raccolto := 0
	for i in lotti.size():
		if manca <= 0:
			break
		if not produce(i):
			continue
		var stato := stato_produzione(i)
		if stato["risorsa"] != "cibo" or stato["cicli"] <= 0:
			continue
		var quantita: int = stato["quantita"]
		var cicli := mini(stato["cicli"], ceili(manca / float(quantita)))
		var ciclo := Bilanciamento.durata_ciclo(lotti[i]["edificio"])
		lotti[i]["eff"] = _lavoro_accumulato(i) - cicli * ciclo
		lotti[i]["agg"] = adesso()
		var preso := cicli * quantita
		var mangiato := mini(preso, manca)
		manca -= mangiato
		dal_raccolto += mangiato
		risorse["cibo"] = mini(int(risorse["cibo"]) + preso - mangiato, capienza())
	if fabbisogno > 0:
		_affamati = manca > 0
	return {"mangiato": fabbisogno - manca, "dal_raccolto": dal_raccolto, "fame": manca > 0}


func _calcola_riepilogo(assente: float, pasti: Dictionary) -> Dictionary:
	var cantieri: Array[String] = []
	var pronti := {}
	for i in lotti.size():
		var lotto := lotti[i]
		if lotto["stato"] == CANTIERE and secondi_rimanenti(i) <= 0.0:
			cantieri.append(Bilanciamento.EDIFICI[lotto["edificio"]]["nome"])
		elif lotto.has("potenzia") and secondi_rimanenti(i) <= 0.0:
			cantieri.append("%s al livello %d" % [nome_lotto(i), lotto["potenzia"]["livello"]])
		elif produce(i):
			var stato := stato_produzione(i)
			if stato["pronto"] > 0:
				pronti[stato["risorsa"]] = int(pronti.get(stato["risorsa"], 0)) + int(stato["pronto"])
	return {
		"assente": assente,
		"cantieri": cantieri,
		"pronti": pronti,
		"cibo": pasti["mangiato"],
		"dal_raccolto": pasti["dal_raccolto"],
		"fame": pasti["fame"],
		"sopravvissuto": not sopravvissuto.is_empty() or adesso() >= _prossimo_arrivo,
	}


func cancella_e_ricomincia() -> void:
	if FileAccess.file_exists(PERCORSO_SALVATAGGIO):
		DirAccess.remove_absolute(PERCORSO_SALVATAGGIO)
	nuova_partita()


func _notification(cosa: int) -> void:
	match cosa:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			salva()


func _exit_tree() -> void:
	salva()


# ------------------------------------------------------------------ cittadini


func _crea_cittadini_iniziali() -> void:
	cittadini.clear()
	for i in Bilanciamento.ABITANTI_INIZIALI:
		cittadini.append(GeneratoreCittadini.crea(_casuale, "raro" if i == 0 else "comune"))
	# I primi due lavorano subito: il più forte al deposito, il più agile all'orto.
	var forte := _migliore_per("forza", [])
	assegna(forte["id"], 1, false)
	var agile := _migliore_per("agilita", [forte["id"]])
	assegna(agile["id"], 2, false)
	cittadini_cambiati.emit()


func _migliore_per(stat: String, esclusi: Array) -> Dictionary:
	var migliore: Dictionary = {}
	for c in cittadini:
		if c["id"] in esclusi:
			continue
		if migliore.is_empty() or c["statistiche"][stat] > migliore["statistiche"][stat]:
			migliore = c
	return migliore


func trova_cittadino(id: String) -> Dictionary:
	for c in cittadini:
		if c["id"] == id:
			return c
	return {}


func abitanti() -> int:
	return cittadini.size()


func lavoratori(indice: int) -> Array[Dictionary]:
	var elenco: Array[Dictionary] = []
	for c in cittadini:
		if c["lavoro"] == indice:
			elenco.append(c)
	return elenco


func posti_di_lavoro(indice: int) -> int:
	var lotto := lotti[indice]
	if lotto["stato"] == MURA:
		return posti_guardie()
	if lotto["stato"] != COSTRUITO:
		return 0
	if not Bilanciamento.ha_lavoratori(lotto["edificio"]):
		return 0
	return int(lotto.get("livello", 1))


## Guardie alle mura: crescono con la città e con il livello delle mura.
func posti_guardie() -> int:
	return Bilanciamento.posti_squadra(livello_citta) + int(Bilanciamento.MURA_LIVELLI[livello_mura() - 1]["guardie"])


func statistica_per(indice: int) -> String:
	if lotti[indice]["stato"] == MURA:
		return "forza"
	return GeneratoreCittadini.chiave_statistica(Bilanciamento.EDIFICI[lotti[indice]["edificio"]]["statistica"])


## Quanto rende un cittadino in un edificio: 1.0 = un cittadino con 5 nella
## statistica giusta. Tratti e umore lo spostano.
func contributo(cittadino: Dictionary, indice: int) -> float:
	var stat := statistica_per(indice)
	var valore := 0.4 + Bilanciamento.stat(cittadino, stat) * 0.12
	match cittadino["tratto"]:
		"stacanovista":
			valore *= 1.25
		"pigro":
			valore *= 0.8
		"chiacchierone":
			if lotti[indice]["edificio"] == "bar":
				valore *= 1.2
	valore *= 0.8 + float(cittadino["umore"]) / 250.0
	return valore


## Velocità di produzione: somma dei contributi; ogni chiacchierone toglie il
## 10% ai colleghi. Zero lavoratori = edificio fermo.
func nome_lavoro(indice: int) -> String:
	if indice < 0:
		return "Senza lavoro"
	if lotti[indice]["stato"] == MURA:
		return "Guardia alle mura"
	return Bilanciamento.EDIFICI[lotti[indice]["edificio"]]["nome"]


func velocita(indice: int) -> float:
	if lotti[indice].get("danneggiato", false) or lotti[indice].has("potenzia"):
		return 0.0
	var squadra := lavoratori(indice)
	var totale := 0.0
	for c in squadra:
		var parte := contributo(c, indice)
		for altro in squadra:
			if altro != c and altro["tratto"] == "chiacchierone" and lotti[indice]["edificio"] != "bar":
				parte *= 0.9
		totale += parte
	return totale


## Assegna un cittadino a un edificio (-1 = nessun lavoro).
func assegna(id: String, indice: int, avvisa := true) -> bool:
	var cittadino := trova_cittadino(id)
	if cittadino.is_empty():
		return false
	if indice >= 0 and lavoratori(indice).size() >= posti_di_lavoro(indice):
		if avvisa:
			notifica.emit("Non ci sono posti liberi: potenzia l'edificio per averne di più")
		return false
	var vecchio: int = cittadino["lavoro"]
	if vecchio >= 0:
		_fissa_produzione(vecchio)
	if indice >= 0:
		_fissa_produzione(indice)
		if id == custode:
			custode = ""
	cittadino["lavoro"] = indice
	cittadini_cambiati.emit()
	if avvisa and indice >= 0:
		notifica.emit("%s ora lavora a: %s" % [cittadino["nome"], nome_lavoro(indice)])
	return true


## I sopravvissuti arrivano al cancello a intervalli regolari.
func _arrivi() -> void:
	if not sopravvissuto.is_empty():
		return
	if not in_arrivo.is_empty():
		# chi ha risposto alla Radio non aspetta il suo turno
		sopravvissuto = in_arrivo.pop_front()
		_sopravvissuto_dal = adesso()
		sopravvissuto_arrivato.emit()
		notifica.emit("%s ha sentito la Radio ed è al cancello!" % GeneratoreCittadini.nome_completo(sopravvissuto))
		return
	if adesso() < _prossimo_arrivo:
		return
	sopravvissuto = GeneratoreCittadini.crea(_casuale)
	_sopravvissuto_dal = adesso()
	sopravvissuto_arrivato.emit()
	notifica.emit("Un sopravvissuto bussa al cancello!")


## Secondi tra un arrivo e l'altro: la Radio li accorcia.
func intervallo_arrivi() -> float:
	return Bilanciamento.intervallo_arrivi(livelli_di("radio"))


func posti_letto_liberi() -> int:
	return posti_letto() - cittadini.size()


func accogli(avvisa := true) -> bool:
	if sopravvissuto.is_empty():
		return false
	if posti_letto_liberi() <= 0:
		notifica.emit("Non c'è posto: costruisci una Casa")
		return false
	cittadini.append(sopravvissuto)
	if avvisa:
		notifica.emit("%s entra in città!" % GeneratoreCittadini.nome_completo(sopravvissuto))
	sopravvissuto = {}
	_prossimo_arrivo = adesso() + intervallo_arrivi()
	cittadini_cambiati.emit()
	sopravvissuto_arrivato.emit()
	risorse_cambiate.emit()
	salva()
	return true


func manda_via() -> void:
	sopravvissuto = {}
	_prossimo_arrivo = adesso() + intervallo_arrivi()
	sopravvissuto_arrivato.emit()


# ------------------------------------------------------------------ custode del cancello


func custode_attuale() -> Dictionary:
	return trova_cittadino(custode) if custode != "" else {}


## Affida il cancello a un cittadino: lascia il lavoro che aveva e da ora
## decide lui chi entra. Ogni decisione gli dà esperienza.
func nomina_custode(id: String) -> bool:
	var c := trova_cittadino(id)
	if c.is_empty():
		return false
	assegna(id, -1, false)
	custode = id
	if not c.has("custode"):
		c["custode"] = {"decisioni": 0, "accolti": 0, "respinti": 0, "sviste": 0}
	_sopravvissuto_dal = adesso()
	notifica.emit("%s ora è il custode del cancello" % GeneratoreCittadini.nome_completo(c))
	cittadini_cambiati.emit()
	salva()
	return true


func togli_custode() -> void:
	if custode == "":
		return
	custode = ""
	cittadini_cambiati.emit()


## Il curriculum del custode: quante decisioni, quante buone.
func curriculum_custode(c: Dictionary) -> Dictionary:
	return c.get("custode", {"decisioni": 0, "accolti": 0, "respinti": 0, "sviste": 0})


## Cosa farebbe il custode con chi bussa: {accogli, motivo, svista}.
## I tratti negativi li riconosce con l'Intelligenza; rari e leggendari li
## prende sempre, se c'è un letto.
func valuta_sopravvissuto(c: Dictionary, chi_decide: Dictionary, casuale := _casuale) -> Dictionary:
	var prezioso: bool = c.get("rarita", "comune") != "comune"
	if posti_letto_liberi() <= 0:
		return {"accogli": false, "motivo": "non ci sono letti liberi", "svista": false}
	if prezioso:
		return {"accogli": true, "motivo": "è un %s, non si lascia fuori" % GeneratoreCittadini.RARITA[c["rarita"]]["nome"].to_lower(), "svista": false}
	if _affamati:
		return {"accogli": false, "motivo": "in città manca il cibo", "svista": false}
	var tratto: String = c.get("tratto", "")
	if tratto != "" and GeneratoreCittadini.TRATTI[tratto]["tipo"] == "negativo":
		var occhio := clampf(Bilanciamento.CUSTODE_OCCHIO_BASE + Bilanciamento.CUSTODE_OCCHIO_PER_PUNTO * Bilanciamento.stat(chi_decide, "intelligenza"), 0.0, 0.95)
		if casuale.randf() < occhio:
			return {"accogli": false, "motivo": "ha capito che è %s" % GeneratoreCittadini.TRATTI[tratto]["nome"].to_lower(), "svista": false}
		return {"accogli": true, "motivo": "non si è accorto che è %s" % GeneratoreCittadini.TRATTI[tratto]["nome"].to_lower(), "svista": true}
	return {"accogli": true, "motivo": "sembra una brava persona", "svista": false}


func _decisione_custode() -> void:
	if custode == "" or sopravvissuto.is_empty() or not missione.is_empty():
		return
	if adesso() - _sopravvissuto_dal < SECONDI_DECISIONE_CUSTODE:
		return
	var chi := custode_attuale()
	if chi.is_empty():
		custode = ""
		return
	var ospite := sopravvissuto
	var nome := GeneratoreCittadini.nome_completo(ospite)
	var scelta := valuta_sopravvissuto(ospite, chi)
	var cv := curriculum_custode(chi)
	cv["decisioni"] = int(cv["decisioni"]) + 1
	var punti := Bilanciamento.ESPERIENZA_DECISIONE_CUSTODE
	if scelta["svista"]:
		cv["sviste"] = int(cv["sviste"]) + 1
	else:
		punti += Bilanciamento.ESPERIENZA_DECISIONE_BUONA
	if scelta["accogli"]:
		cv["accolti"] = int(cv["accolti"]) + 1
		accogli(false)
	else:
		cv["respinti"] = int(cv["respinti"]) + 1
		manda_via()
	chi["custode"] = cv
	_esperienza_cittadino(chi, punti)
	notifica.emit("Il custode %s %s %s: %s" % [chi["nome"], "fa entrare" if scelta["accogli"] else "manda via", nome, scelta["motivo"]])
	custode_ha_deciso.emit(bool(scelta["accogli"]))
	cittadini_cambiati.emit()


## Ogni 5 secondi l'umore di ognuno si avvicina al suo valore ideale.
func _aggiorna_umore() -> void:
	var ora := adesso()
	if ora - _ultimo_umore < 5.0:
		return
	_ultimo_umore = ora
	var c_e_il_bar := livelli_di("bar") > 0
	var senza_letto := posti_letto() < cittadini.size()
	for i in lotti.size():
		if produce(i):
			_fissa_produzione(i)
	for c in cittadini:
		var obiettivo := 55.0
		var lavoro: int = c["lavoro"]
		if c["id"] == custode:
			obiettivo += 12.0
		elif lavoro >= 0:
			obiettivo += 5.0
			if Bilanciamento.stat(c, statistica_per(lavoro)) >= 5:
				obiettivo += 15.0
			for collega in lavoratori(lavoro):
				if collega != c and collega["tratto"] == "allegro":
					obiettivo += 8.0
		else:
			obiettivo -= 10.0
		if c["tratto"] == "allegro":
			obiettivo += 5.0
		if c_e_il_bar:
			obiettivo += 10.0
		if _affamati:
			obiettivo -= 30.0
		if senza_letto:
			obiettivo -= 15.0
		# I feriti guariscono piano piano da soli (circa 1 punto ogni 25 secondi).
		# con l'Ambulatorio molto più in fretta.
		c["salute"] = minf(100.0, float(c.get("salute", 100.0)) + 0.2 * (1 + 2 * livelli_di("ambulatorio")))
		var umore := float(c["umore"])
		umore = move_toward(umore, clampf(obiettivo, 0.0, 100.0), 1.0)
		if c["tratto"] == "pigro":
			umore = maxf(umore, 60.0)
		c["umore"] = umore


var _ultima_cura := 0.0


func _cure_periodiche() -> void:
	var ora := adesso()
	if _ultima_cura <= 0.0:
		_ultima_cura = ora
		return
	if ora - _ultima_cura < 1.0:
		return
	var passati := ora - _ultima_cura
	_ultima_cura = ora
	if not pazienti.is_empty():
		_avanza_cure(passati)
	_allena_tutti(passati)
	_avanza_officine(passati)
	_avanza_radio(passati)


# ------------------------------------------------------------------ allenamento


func allena_qui(indice: int) -> bool:
	var lotto := lotti[indice]
	return lotto["stato"] == COSTRUITO and Bilanciamento.allena(lotto["edificio"])


## Quale statistica allena questo cittadino in questo edificio (vuoto se è al massimo).
func statistica_in_allenamento(c: Dictionary, indice: int) -> String:
	var scelta := ""
	for stat in Bilanciamento.ALLENAMENTO[lotti[indice]["edificio"]]:
		var valore := int(c["statistiche"][stat])
		if valore >= Bilanciamento.STATISTICA_MASSIMA:
			continue
		if scelta == "" or valore < int(c["statistiche"][scelta]):
			scelta = stat
	return scelta


func secondi_per_punto(c: Dictionary, stat: String) -> float:
	return Bilanciamento.SECONDI_PER_PUNTO * int(c["statistiche"][stat])


func velocita_allievo(c: Dictionary, indice: int) -> float:
	var lotto := lotti[indice]
	if lotto.get("danneggiato", false) or lotto.has("potenzia"):
		return 0.0
	return Bilanciamento.velocita_allenamento(int(lotto.get("livello", 1)), c["tratto"] == "studioso")


## Il progresso di chi si allena è tenuto nel cittadino; qui non serve
## salvare niente prima dei cambi, ma la funzione resta per simmetria.
func _fissa_allenamento(_indice: int) -> void:
	pass


## Fa avanzare l'allenamento di tutti gli allievi. Restituisce i progressi
## come testi ("Aldo Rossi: Forza 5").
func _allena_tutti(secondi: float, avvisa := true) -> Array:
	var progressi: Array = []
	for c in cittadini:
		var indice := int(c["lavoro"])
		if indice < 0 or indice >= lotti.size() or not allena_qui(indice):
			continue
		var resto := secondi * velocita_allievo(c, indice)
		while resto > 0.0:
			var stat := statistica_in_allenamento(c, indice)
			if stat == "":
				break
			var serve := secondi_per_punto(c, stat) - float(c.get("allenamento", 0.0))
			if resto < serve:
				c["allenamento"] = float(c.get("allenamento", 0.0)) + resto
				break
			resto -= serve
			c["allenamento"] = 0.0
			c["statistiche"][stat] = int(c["statistiche"][stat]) + 1
			var testo := "%s: %s %d" % [GeneratoreCittadini.nome_completo(c), GeneratoreCittadini.NOMI_STATISTICHE[stat], c["statistiche"][stat]]
			progressi.append(testo)
			if avvisa:
				notifica.emit("%s sale a %d in %s!" % [c["nome"], c["statistiche"][stat], GeneratoreCittadini.NOMI_STATISTICHE[stat]])
	if not progressi.is_empty():
		cittadini_cambiati.emit()
	return progressi


func _guadagna_esperienza(indice: int, punti: int) -> void:
	for c in lavoratori(indice):
		_esperienza_cittadino(c, punti)
	cittadini_cambiati.emit()


func _esperienza_cittadino(c: Dictionary, punti: int) -> void:
	c["esperienza"] = int(c["esperienza"]) + punti
	while int(c["esperienza"]) >= 10 * int(c["livello"]):
		c["esperienza"] = int(c["esperienza"]) - 10 * int(c["livello"])
		c["livello"] = int(c["livello"]) + 1
		notifica.emit("%s sale al livello %d" % [c["nome"], c["livello"]])


func rimuovi_cittadino(id: String) -> void:
	if id == custode:
		custode = ""
	for k in cittadini.size():
		if cittadini[k]["id"] == id:
			var lavoro := int(cittadini[k]["lavoro"])
			if lavoro >= 0:
				_fissa_produzione(lavoro)
			cittadini.remove_at(k)
			break
	cittadini_cambiati.emit()


# ------------------------------------------------------------------ missioni


## Le squadre escono dalle mura solo quando c'è un'Armeria che le arma.
func missioni_sbloccate() -> bool:
	return livelli_di("armeria") > 0


## La zona infestata più vicina alla città: è l'unica che si può liberare.
func lotto_da_liberare() -> int:
	for i in lotti.size():
		if lotti[i]["stato"] == BLOCCATO:
			return i
	return -1


func prepara_missione(indice: int, squadra: Array) -> bool:
	if indice < 0 or squadra.is_empty() or not missioni_sbloccate():
		return false
	missione = {"lotto": indice, "difficolta": int(lotti[indice].get("difficolta", 1)), "squadra": squadra.duplicate()}
	return true


## Chiude la missione: i caduti sono persi per sempre, i sopravvissuti
## tornano con la salute che avevano. Con una vittoria il lotto si libera.
## Chi torna dalla battaglia: i caduti escono dalla città, gli altri
## tengono la salute che avevano.
func _rientro_squadra(vinta: bool, difficolta: int, morti: Array, salute: Dictionary) -> Dictionary:
	var nomi_morti: Array[String] = []
	for id in morti:
		var caduto := trova_cittadino(id)
		if not caduto.is_empty():
			# Armi e vestiti restano sul campo con chi cade.
			var persi: PackedStringArray = []
			for slot in ["arma", "vestito"]:
				if not caduto.get(slot, {}).is_empty():
					persi.append(Bilanciamento.nome_oggetto(caduto[slot]))
			var nome := GeneratoreCittadini.nome_completo(caduto)
			if not persi.is_empty():
				nome += " (perso: %s)" % ", ".join(persi)
			nomi_morti.append(nome)
			rimuovi_cittadino(id)
	var feriti: Array[Dictionary] = []
	var reduci: Array[Dictionary] = []
	for id in salute:
		var c := trova_cittadino(id)
		if c.is_empty():
			continue
		reduci.append(c)
		c["salute"] = clampf(float(salute[id]), 1.0, 100.0)
		if float(c["salute"]) < 100.0:
			feriti.append({"id": id, "nome": GeneratoreCittadini.nome_completo(c), "salute": int(c["salute"])})
	return {"tipo": "zona", "vinta": vinta, "difficolta": difficolta, "morti": nomi_morti, "feriti": feriti,
			"reduci": reduci, "bottino": {}, "esperienza": 0, "sopravvissuto": false,
			"danneggiati": [], "perse": {}, "catturati": 0}


## I barcollanti catturati tornano in città con chi è sopravvissuto.
func _porta_catturati(esito: Dictionary, salute: Dictionary, catturati: int) -> void:
	if catturati > 0 and not salute.is_empty():
		esito["catturati"] = aggiungi_pazienti(catturati)


func concludi_missione(vinta: bool, morti: Array, salute: Dictionary, catturati := 0) -> Dictionary:
	var difficolta := int(missione.get("difficolta", 1))
	var indice := int(missione.get("lotto", -1))
	var esito := _rientro_squadra(vinta, difficolta, morti, salute)
	_porta_catturati(esito, salute, catturati)
	var reduci: Array[Dictionary] = []
	reduci.assign(esito["reduci"])
	if vinta and indice >= 0 and lotti[indice]["stato"] == BLOCCATO:
		lotti[indice] = {"stato": LIBERO}
		# Oltre l'ultima zona ne compare una nuova: ogni due zone la difficoltà sale di uno.
		var ultima := 0
		var zone := 0
		for lotto in lotti:
			if lotto["stato"] == BLOCCATO:
				ultima = maxi(ultima, int(lotto.get("difficolta", 1)))
		for k in range(1, lotti.size()):
			if lotti[k]["stato"] != MURA:
				zone += 1
		var nuova := maxi(ultima, Bilanciamento.difficolta_zona(zone - LOTTI_LIBERI_INIZIALI))
		lotti.append({"stato": BLOCCATO, "difficolta": mini(Bilanciamento.DIFFICOLTA_MASSIMA, nuova)})
		var fortuna := 1.0
		var carisma := 0
		for c in reduci:
			if c["tratto"] == "fortunato":
				fortuna = 1.5
			carisma = maxi(carisma, Bilanciamento.stat(c, "carisma"))
			_esperienza_cittadino(c, 5 * difficolta)
		var bottino: Dictionary = Bilanciamento.bottino(difficolta)
		for risorsa in bottino:
			var quanto := int(round(int(bottino[risorsa]) * fortuna))
			quanto = mini(quanto, spazio_libero(risorsa))
			risorse[risorsa] = int(risorse[risorsa]) + quanto
			esito["bottino"][risorsa] = quanto
		# Con un po' di carisma, qualcuno incontrato fuori vi segue in città.
		if sopravvissuto.is_empty() and _casuale.randf() < 0.25 + 0.05 * carisma:
			sopravvissuto = GeneratoreCittadini.crea(_casuale)
			esito["sopravvissuto"] = true
			sopravvissuto_arrivato.emit()
		esito["esperienza"] = Bilanciamento.ESPERIENZA_MISSIONE * difficolta
		aggiungi_esperienza(Bilanciamento.ESPERIENZA_MISSIONE * difficolta)
		lotto_cambiato.emit(indice)
	missione = {}
	esito.erase("reduci")
	cittadini_cambiati.emit()
	risorse_cambiate.emit()
	salva()
	return esito


# ------------------------------------------------------------------ attacchi alla città


func _intervallo_attacchi() -> float:
	return Bilanciamento.intervallo_attacchi(livello_citta)


func difficolta_attacco() -> int:
	return Bilanciamento.difficolta_attacchi(livello_citta)


func torrette() -> int:
	return mini(Bilanciamento.MAX_TORRETTE, livelli_di("mura_torrette"))


func secondi_al_prossimo_attacco() -> float:
	if prossimo_attacco <= 0.0:
		return -1.0
	return maxf(0.0, prossimo_attacco - adesso())


## Avvisi e arrivo degli zombie. Durante una missione l'attacco aspetta.
func _attacchi() -> void:
	# gli attacchi cominciano dal livello 3, e solo quando c'è un'Armeria
	if livello_citta < 3 or not missioni_sbloccate():
		return
	var ora := adesso()
	if prossimo_attacco <= 0.0:
		prossimo_attacco = ora + Bilanciamento.PRIMO_ATTACCO
		notifica.emit("Da ora gli zombie possono attaccare: metti delle guardie alle mura!")
		attacco_cambiato.emit()
		return
	if not missione.is_empty():
		if not attacco_pronto and prossimo_attacco < ora + Bilanciamento.PREAVVISO_ATTACCO:
			prossimo_attacco = ora + Bilanciamento.PREAVVISO_ATTACCO
		return
	if not attacco_pronto:
		if not _preavviso_dato and ora >= prossimo_attacco - Bilanciamento.PREAVVISO_ATTACCO:
			_preavviso_dato = true
			notifica.emit("Le sentinelle: zombie in arrivo tra un minuto!")
			attacco_cambiato.emit()
		if ora >= prossimo_attacco:
			attacco_pronto = true
			_attacco_iniziato_alle = ora
			attesa_attacco = 0.0
			notifica.emit("Gli zombie attaccano le mura!")
			attacco_cambiato.emit()
	elif attesa_attacco >= Bilanciamento.ATTESA_RISPOSTA:
		var esito := risolvi_attacco_automatico(false)
		attacco_risolto.emit(esito)


func _chiudi_attacco(da: float) -> void:
	attacco_pronto = false
	_preavviso_dato = false
	prossimo_attacco = da + _intervallo_attacchi()
	attacco_cambiato.emit()


## Quanto reggono le difese da sole: oltre 1 respingono l'attacco.
func stima_difesa(a_gioco_chiuso := false) -> float:
	var difficolta := difficolta_attacco()
	var ondate := 1 if a_gioco_chiuso else Bilanciamento.ONDATE_ATTACCO
	var zombie := ondate * Bilanciamento.zombie_per_ondata(difficolta)
	var vita := zombie * Bilanciamento.vita_media_zombie(difficolta) * (0.5 if a_gioco_chiuso else 1.0)
	var colpi_necessari := zombie * 2
	var munizioni := minf(1.0, int(risorse["munizioni"]) / float(maxi(1, colpi_necessari)))
	var potenza := 0.0
	for guardia in lavoratori(0):
		var danno := Bilanciamento.danno_colpo(guardia, 1.0) / Bilanciamento.ricarica(guardia)
		potenza += danno * (munizioni + (1.0 - munizioni) * 0.4) * float(guardia.get("salute", 100.0)) / 100.0
	potenza += torrette() * Bilanciamento.DANNO_TORRETTA / Bilanciamento.CADENZA_TORRETTA
	# mura più robuste: gli zombie restano fuori più a lungo
	potenza *= float(Bilanciamento.MURA_LIVELLI[livello_mura() - 1]["difesa"])
	return potenza * Bilanciamento.DURATA_ONDATA * ondate / maxf(1.0, vita)


## Le difese affrontano l'attacco da sole: guardie e torrette contro gli
## zombie, senza morti. A gioco chiuso l'attacco è più breve e più debole.
func risolvi_attacco_automatico(a_gioco_chiuso: bool, alle := -1.0) -> Dictionary:
	var difficolta := difficolta_attacco()
	var forza := stima_difesa(a_gioco_chiuso)
	var vinta := forza >= 1.0
	var guardie := lavoratori(0)
	var esito := {"tipo": "difesa", "automatica": true, "a_gioco_chiuso": a_gioco_chiuso, "vinta": vinta,
			"difficolta": difficolta, "morti": [], "feriti": [], "bottino": {}, "esperienza": 0,
			"sopravvissuto": false, "danneggiati": [], "perse": {}}
	if not guardie.is_empty():
		var zombie := (1 if a_gioco_chiuso else Bilanciamento.ONDATE_ATTACCO) * Bilanciamento.zombie_per_ondata(difficolta)
		risorse["munizioni"] = int(risorse["munizioni"]) - mini(int(risorse["munizioni"]), int(zombie * 1.2))
	if vinta:
		var ricompensa := Bilanciamento.ricompensa_difesa(difficolta)
		for risorsa in ricompensa:
			var quanto := mini(int(ricompensa[risorsa]) / 2, spazio_libero(risorsa))
			risorse[risorsa] = int(risorse[risorsa]) + quanto
			esito["bottino"][risorsa] = quanto
		esito["esperienza"] = 10 * difficolta
		aggiungi_esperienza(10 * difficolta)
		for guardia in guardie:
			_esperienza_cittadino(guardia, 3 * difficolta)
	else:
		var quota := clampf(1.0 - forza, 0.0, 1.0)
		var meta := 0.5 if a_gioco_chiuso else 1.0
		_conseguenze_sconfitta(esito, quota * meta, 1 if a_gioco_chiuso else Bilanciamento.EDIFICI_DANNEGGIATI)
		for guardia in guardie:
			guardia["salute"] = maxf(5.0, float(guardia["salute"]) - quota * 40.0)
			esito["feriti"].append({"id": guardia["id"], "nome": GeneratoreCittadini.nome_completo(guardia), "salute": int(guardia["salute"])})
	_chiudi_attacco(alle if alle > 0.0 else adesso())
	cittadini_cambiati.emit()
	risorse_cambiate.emit()
	salva()
	return esito


## Una parte delle risorse va persa e alcuni edifici restano danneggiati.
func _conseguenze_sconfitta(esito: Dictionary, quota: float, max_edifici: int) -> void:
	for risorsa in risorse:
		var perso := int(round(int(risorse[risorsa]) * Bilanciamento.QUOTA_RISORSE_PERSE * quota))
		if perso > 0:
			risorse[risorsa] = int(risorse[risorsa]) - perso
			esito["perse"][risorsa] = perso
	var candidati: Array[int] = []
	for i in lotti.size():
		if lotti[i]["stato"] == COSTRUITO and not lotti[i].get("danneggiato", false):
			candidati.append(i)
	candidati.shuffle()
	var quanti := mini(candidati.size(), ceili(quota * max_edifici))
	for k in quanti:
		var i := candidati[k]
		_fissa_produzione(i)
		lotti[i]["danneggiato"] = true
		esito["danneggiati"].append(Bilanciamento.EDIFICI[lotti[i]["edificio"]]["nome"])
		lotto_cambiato.emit(i)


func _attacchi_a_gioco_chiuso() -> Array:
	var esiti := []
	var ora := adesso()
	while prossimo_attacco > 0.0 and prossimo_attacco <= ora and esiti.size() < Bilanciamento.MAX_ATTACCHI_A_GIOCO_CHIUSO:
		esiti.append(risolvi_attacco_automatico(true, prossimo_attacco))
	if prossimo_attacco > 0.0 and prossimo_attacco <= ora:
		prossimo_attacco = ora + _intervallo_attacchi()
	return esiti


func prepara_difesa(squadra: Array) -> bool:
	if not attacco_pronto or squadra.is_empty():
		return false
	missione = {"tipo": "difesa", "lotto": 0, "difficolta": difficolta_attacco(), "squadra": squadra.duplicate()}
	return true


func concludi_difesa(vinta: bool, morti: Array, salute: Dictionary, catturati := 0) -> Dictionary:
	var difficolta := int(missione.get("difficolta", 1))
	var esito := _rientro_squadra(vinta, difficolta, morti, salute)
	_porta_catturati(esito, salute, catturati)
	esito["tipo"] = "difesa"
	if vinta:
		var ricompensa := Bilanciamento.ricompensa_difesa(difficolta)
		for risorsa in ricompensa:
			var quanto := mini(int(ricompensa[risorsa]), spazio_libero(risorsa))
			risorse[risorsa] = int(risorse[risorsa]) + quanto
			esito["bottino"][risorsa] = quanto
		for c in esito["reduci"]:
			_esperienza_cittadino(c, 4 * difficolta)
		esito["esperienza"] = 15 * difficolta
		aggiungi_esperienza(15 * difficolta)
	else:
		_conseguenze_sconfitta(esito, 1.0, Bilanciamento.EDIFICI_DANNEGGIATI)
	esito.erase("reduci")
	missione = {}
	_chiudi_attacco(adesso())
	cittadini_cambiati.emit()
	risorse_cambiate.emit()
	salva()
	return esito


func costo_riparazione(indice: int) -> int:
	var lotto := lotti[indice]
	return int(round(Bilanciamento.EDIFICI[lotto["edificio"]]["costo"] * Bilanciamento.COSTO_RIPARAZIONE * int(lotto.get("livello", 1))))


func ripara(indice: int) -> bool:
	if not lotti[indice].get("danneggiato", false):
		return false
	var costo := costo_riparazione(indice)
	if int(risorse["materiali"]) < costo:
		notifica.emit("Servono %d materiali per riparare" % costo)
		return false
	risorse["materiali"] = int(risorse["materiali"]) - costo
	_fissa_produzione(indice)
	lotti[indice].erase("danneggiato")
	notifica.emit("%s riparato!" % Bilanciamento.EDIFICI[lotti[indice]["edificio"]]["nome"])
	risorse_cambiate.emit()
	lotto_cambiato.emit(indice)
	salva()
	return true


# ------------------------------------------------------------------ ambulatorio


func letti_pazienti() -> int:
	return Bilanciamento.LETTI_PER_LIVELLO_AMBULATORIO * livelli_di("ambulatorio")


func letti_pazienti_liberi() -> int:
	return maxi(0, letti_pazienti() - pazienti.size())


## Velocità della cura: somma del lavoro dei medici in tutti gli ambulatori.
func velocita_cura() -> float:
	var totale := 0.0
	for i in lotti.size():
		if lotti[i]["stato"] == COSTRUITO and lotti[i]["edificio"] == "ambulatorio":
			totale += velocita(i)
	return maxf(totale, Bilanciamento.VELOCITA_CURA_SENZA_MEDICI)


## I barcollanti catturati arrivano in Ambulatorio. Ognuno è già un futuro
## cittadino, ma il suo nome si scopre solo a cura finita.
func aggiungi_pazienti(quanti: int) -> int:
	var arrivati := mini(quanti, letti_pazienti_liberi())
	for k in arrivati:
		var futuro := GeneratoreCittadini.crea(_casuale)
		futuro["ex_zombie"] = true
		futuro["umore"] = 50.0
		pazienti.append({"cittadino": futuro, "progresso": 0.0, "in_cura": false})
	if arrivati > 0:
		pazienti_cambiati.emit()
	return arrivati


func inizia_cura(k: int) -> bool:
	if k < 0 or k >= pazienti.size() or pazienti[k]["in_cura"]:
		return false
	if int(risorse["medicine"]) < Bilanciamento.MEDICINE_CURA_ZOMBIE:
		notifica.emit("Servono %d medicine per iniziare la cura" % Bilanciamento.MEDICINE_CURA_ZOMBIE)
		return false
	risorse["medicine"] = int(risorse["medicine"]) - Bilanciamento.MEDICINE_CURA_ZOMBIE
	pazienti[k]["in_cura"] = true
	notifica.emit("La cura è cominciata")
	risorse_cambiate.emit()
	pazienti_cambiati.emit()
	salva()
	return true


func secondi_alla_guarigione(k: int) -> float:
	var resta := Bilanciamento.LAVORO_CURA_ZOMBIE - float(pazienti[k]["progresso"])
	return maxf(0.0, resta / velocita_cura())


## Fa avanzare le cure di "secondi" di tempo reale. Chi guarisce entra in
## città se c'è un posto letto, altrimenti aspetta pronto in Ambulatorio.
func _avanza_cure(secondi: float, avvisa := true) -> Array:
	var nomi: Array = []
	var velocita := velocita_cura()
	for p in pazienti:
		if p["in_cura"]:
			p["progresso"] = minf(Bilanciamento.LAVORO_CURA_ZOMBIE, float(p["progresso"]) + secondi * velocita)
	for k in range(pazienti.size() - 1, -1, -1):
		var p := pazienti[k]
		if float(p["progresso"]) < Bilanciamento.LAVORO_CURA_ZOMBIE or posti_letto_liberi() <= 0:
			continue
		var nuovo: Dictionary = p["cittadino"]
		cittadini.append(nuovo)
		pazienti.remove_at(k)
		nomi.append(GeneratoreCittadini.nome_completo(nuovo))
		if avvisa:
			notifica.emit("%s è guarito: ora è un cittadino!" % GeneratoreCittadini.nome_completo(nuovo))
	if not nomi.is_empty():
		cittadini_cambiati.emit()
		pazienti_cambiati.emit()
	return nomi


func guariti_senza_letto() -> int:
	var n := 0
	for p in pazienti:
		if float(p["progresso"]) >= Bilanciamento.LAVORO_CURA_ZOMBIE:
			n += 1
	return n


func feriti() -> Array[Dictionary]:
	var elenco: Array[Dictionary] = []
	for c in cittadini:
		if float(c.get("salute", 100.0)) < 100.0:
			elenco.append(c)
	return elenco


## Dopo una vittoria i feriti si curano subito: 1 medicina a testa.
func cura_feriti(ids: Array) -> int:
	var curati := 0
	for id in ids:
		var c := trova_cittadino(id)
		if c.is_empty() or float(c["salute"]) >= 100.0 or int(risorse["medicine"]) <= 0:
			continue
		risorse["medicine"] = int(risorse["medicine"]) - 1
		c["salute"] = 100.0
		curati += 1
	cittadini_cambiati.emit()
	risorse_cambiate.emit()
	salva()
	return curati


# ------------------------------------------------------------------ produzione


## Somma dei livelli degli edifici costruiti di un tipo.
func livelli_di(id: String) -> int:
	var totale := 0
	for lotto in lotti:
		if lotto["stato"] == COSTRUITO and lotto["edificio"] == id:
			totale += int(lotto.get("livello", 1))
	return totale


func capienza() -> int:
	var base := Bilanciamento.CAPIENZA_BASE + Bilanciamento.CAPIENZA_PER_MAGAZZINO * livelli_di("magazzino")
	return int(round(base * pow(Bilanciamento.CRESCITA_CAPIENZA, livello_citta - 1) / 10.0)) * 10


func posti_letto() -> int:
	return Bilanciamento.POSTI_PER_CASA * livelli_di("case")


func cicli_in_deposito() -> int:
	return Bilanciamento.CICLI_IN_DEPOSITO + Bilanciamento.CICLI_IN_PIU_PER_MAGAZZINO * livelli_di("magazzino")


func spazio_libero(risorsa: String) -> int:
	return maxi(0, capienza() - int(risorse[risorsa]))


func produce(indice: int) -> bool:
	var lotto := lotti[indice]
	return lotto["stato"] == COSTRUITO and Bilanciamento.produce(lotto["edificio"])


## Secondi di "lavoro effettivo" accumulati: crescono con la velocità della
## squadra e si fermano quando l'edificio è pieno.
func _lavoro_accumulato(indice: int) -> float:
	var lotto := lotti[indice]
	var ciclo := Bilanciamento.durata_ciclo(lotto["edificio"])
	var trascorso := maxf(0.0, adesso() - float(lotto.get("agg", adesso())))
	var eff := float(lotto.get("eff", 0.0)) + trascorso * velocita(indice)
	return minf(eff, cicli_in_deposito() * ciclo)


## Va chiamata prima di cambiare la squadra o l'umore: salva il lavoro fatto
## fino ad ora con la velocità vecchia.
func _fissa_produzione(indice: int) -> void:
	if not produce(indice):
		return
	lotti[indice]["eff"] = _lavoro_accumulato(indice)
	lotti[indice]["agg"] = adesso()


## Situazione della produzione di un edificio: cicli pronti, avanzamento del
## ciclo in corso (0-1), velocità e se si è fermato.
func stato_produzione(indice: int) -> Dictionary:
	var lotto := lotti[indice]
	var id: String = lotto["edificio"]
	var ciclo := Bilanciamento.durata_ciclo(id)
	var eff := _lavoro_accumulato(indice)
	var massimo := cicli_in_deposito()
	var cicli := mini(int(floor(eff / ciclo + 0.0001)), massimo)
	var pieno := cicli >= massimo
	var resto := 0.0 if pieno else eff - cicli * ciclo
	var vel := velocita(indice)
	var quantita := Bilanciamento.quantita_per_ciclo(id, int(lotto.get("livello", 1)))
	var al_prossimo := 0.0
	if not pieno and vel > 0.0:
		al_prossimo = (ciclo - resto) / vel
	return {
		"risorsa": Bilanciamento.EDIFICI[id]["produce"],
		"cicli": cicli,
		"massimo": massimo,
		"quantita": quantita,
		"pronto": cicli * quantita,
		"avanzamento": 1.0 if pieno else resto / ciclo,
		"pieno": pieno,
		"velocita": vel,
		"fermo": vel <= 0.0,
		"secondi_al_prossimo": al_prossimo,
	}


## Raccoglie quello che l'edificio ha prodotto, nei limiti del magazzino.
## Restituisce la quantità raccolta (0 se non c'era niente o il magazzino è pieno).
func raccogli(indice: int) -> int:
	if not produce(indice):
		return 0
	var stato := stato_produzione(indice)
	if stato["cicli"] <= 0:
		return 0
	var risorsa: String = stato["risorsa"]
	var libero := spazio_libero(risorsa)
	if libero <= 0:
		notifica.emit("Magazzino pieno: %s al massimo (%d)" % [Bilanciamento.RISORSE[risorsa]["nome"].to_lower(), capienza()])
		return 0
	var quantita: int = stato["quantita"]
	var presi := mini(stato["cicli"], int(floor(libero / float(quantita))))
	var ottenuto := presi * quantita
	if presi == 0:
		# C'è spazio per meno di un ciclo: si riempie fino all'orlo e il ciclo si consuma.
		presi = 1
		ottenuto = libero
	risorse[risorsa] += ottenuto
	var ciclo := Bilanciamento.durata_ciclo(lotti[indice]["edificio"])
	lotti[indice]["eff"] = _lavoro_accumulato(indice) - presi * ciclo
	lotti[indice]["agg"] = adesso()
	risorse_cambiate.emit()
	raccolto.emit(indice, risorsa, ottenuto)
	_guadagna_esperienza(indice, presi)
	if ottenuto < presi * quantita:
		notifica.emit("Magazzino pieno: costruisci un Magazzino per tenere di più")
	return ottenuto


## Ogni minuto gli abitanti mangiano. Senza cibo la città ha fame.
func _mangia() -> void:
	var ora := adesso()
	var minuti := int(floor((ora - _ultimo_pasto) / 60.0))
	if minuti <= 0:
		return
	_ultimo_pasto += minuti * 60.0
	var fabbisogno := int(ceil(consumo_al_minuto() * minuti))
	if int(risorse["cibo"]) >= fabbisogno:
		risorse["cibo"] -= fabbisogno
		_affamati = false
	else:
		risorse["cibo"] = 0
		if not _affamati:
			notifica.emit("La città ha fame! Raccogli cibo dall'orto")
		_affamati = true
	risorse_cambiate.emit()


func affamati() -> bool:
	return _affamati


## Cibo consumato al minuto da tutta la città (i parsimoniosi mangiano la metà).
func consumo_al_minuto() -> float:
	var totale := 0.0
	for c in cittadini:
		totale += Bilanciamento.CIBO_PER_ABITANTE_AL_MINUTO * (0.5 if c["tratto"] == "parsimonioso" else 1.0)
	return totale


# ------------------------------------------------------------------ officina ed equipaggiamento (tappa 10)


func fabbrica_qui(indice: int) -> bool:
	var lotto := lotti[indice]
	return lotto["stato"] == COSTRUITO and Bilanciamento.fabbrica(lotto["edificio"])


## La qualità di ciò che esce dall'Officina è il suo livello.
func qualita_officina(indice: int) -> int:
	return int(lotti[indice].get("livello", 1))


## Gli oggetti che questa Officina sa fare (gli altri arrivano potenziandola).
func oggetti_fabbricabili(indice: int) -> Array[String]:
	var livello := qualita_officina(indice)
	var elenco: Array[String] = []
	for tipo in Bilanciamento.ARMI:
		if int(Bilanciamento.ARMI[tipo]["officina"]) <= livello:
			elenco.append(tipo)
	for tipo in Bilanciamento.VESTITI:
		if int(Bilanciamento.VESTITI[tipo]["officina"]) <= livello:
			elenco.append(tipo)
	return elenco


func motivo_blocco_fabbrica(indice: int, tipo: String) -> String:
	var lotto := lotti[indice]
	if lotto.has("lavorazione"):
		return "Il banco è occupato"
	if lotto.has("potenzia"):
		return "Officina in potenziamento"
	var costo := Bilanciamento.costo_oggetto(tipo, qualita_officina(indice))
	if int(risorse["materiali"]) < int(costo["materiali"]):
		return "Servono %d materiali" % costo["materiali"]
	if int(risorse["tappi"]) < int(costo["tappi"]):
		return "Servono %d tappi" % costo["tappi"]
	return ""


func inizia_fabbrica(indice: int, tipo: String) -> bool:
	if not fabbrica_qui(indice) or motivo_blocco_fabbrica(indice, tipo) != "":
		return false
	var qualita := qualita_officina(indice)
	var costo := Bilanciamento.costo_oggetto(tipo, qualita)
	risorse["materiali"] = int(risorse["materiali"]) - int(costo["materiali"])
	risorse["tappi"] = int(risorse["tappi"]) - int(costo["tappi"])
	lotti[indice]["lavorazione"] = {"tipo": tipo, "qualita": qualita, "lavoro": Bilanciamento.lavoro_oggetto(tipo, qualita),
			"fatto": 0.0}
	risorse_cambiate.emit()
	lotto_cambiato.emit(indice)
	Suoni.suona("martello")
	notifica.emit("L'Officina si mette al lavoro: %s" % Bilanciamento.nome_oggetto({"tipo": tipo, "qualita": qualita}))
	salva()
	return true


## Quota del lavoro fatto (0..1) e secondi che mancano alla velocità attuale (-1 = fermo).
func stato_fabbrica(indice: int) -> Dictionary:
	var lavorazione: Dictionary = lotti[indice].get("lavorazione", {})
	if lavorazione.is_empty():
		return {}
	var v := velocita(indice)
	var manca := float(lavorazione["lavoro"]) - float(lavorazione["fatto"])
	return {"oggetto": lavorazione, "quota": float(lavorazione["fatto"]) / float(lavorazione["lavoro"]),
			"secondi": manca / v if v > 0.0 else -1.0, "velocita": v}


## Fa avanzare il lavoro di tutte le officine. Restituisce i nomi di ciò che è pronto.
func _avanza_officine(secondi: float, avvisa := true) -> Array:
	var pronti: Array = []
	for i in lotti.size():
		var lavorazione: Dictionary = lotti[i].get("lavorazione", {})
		if lavorazione.is_empty():
			continue
		lavorazione["fatto"] = float(lavorazione["fatto"]) + secondi * velocita(i)
		if float(lavorazione["fatto"]) < float(lavorazione["lavoro"]):
			continue
		var oggetto := {"id": "o%d" % _prossimo_oggetto, "tipo": lavorazione["tipo"], "qualita": int(lavorazione["qualita"])}
		_prossimo_oggetto += 1
		equipaggiamento.append(oggetto)
		lotti[i].erase("lavorazione")
		pronti.append(Bilanciamento.nome_oggetto(oggetto))
		lotto_cambiato.emit(i)
		if avvisa:
			Suoni.suona("costruito", 0.0)
			notifica.emit("Pronto in Officina: %s! Equipaggialo dall'elenco dei cittadini" % Bilanciamento.nome_oggetto(oggetto))
	if not pronti.is_empty():
		equipaggiamento_cambiato.emit()
	return pronti


## Fa indossare a un cittadino un oggetto del deposito: quello che aveva
## nello stesso posto torna nel deposito.
func equipaggia(id_cittadino: String, id_oggetto: String) -> bool:
	var c := trova_cittadino(id_cittadino)
	if c.is_empty():
		return false
	for k in equipaggiamento.size():
		var oggetto := equipaggiamento[k]
		if oggetto["id"] != id_oggetto:
			continue
		var slot := "arma" if Bilanciamento.e_arma(oggetto["tipo"]) else "vestito"
		equipaggiamento.remove_at(k)
		if not c.get(slot, {}).is_empty():
			equipaggiamento.append(c[slot])
		c[slot] = oggetto
		notifica.emit("%s ora ha: %s" % [c["nome"], Bilanciamento.nome_oggetto(oggetto)])
		equipaggiamento_cambiato.emit()
		cittadini_cambiati.emit()
		salva()
		return true
	return false


func togli_equipaggiamento(id_cittadino: String, slot: String) -> void:
	var c := trova_cittadino(id_cittadino)
	if c.is_empty() or c.get(slot, {}).is_empty():
		return
	equipaggiamento.append(c[slot])
	c.erase(slot)
	equipaggiamento_cambiato.emit()
	cittadini_cambiati.emit()
	salva()


# ------------------------------------------------------------------ radio (tappa 11)


func radio_qui(indice: int) -> bool:
	var lotto := lotti[indice]
	return lotto["stato"] == COSTRUITO and lotto["edificio"] == "radio"


func motivo_blocco_appello(indice: int, tipo: String) -> String:
	var lotto := lotti[indice]
	if lotto.has("appello"):
		return "Già in onda"
	if lotto.has("potenzia"):
		return "Radio in potenziamento"
	var costo := Bilanciamento.costo_appello(int(lotto.get("livello", 1)), tipo)
	if int(risorse["tappi"]) < costo:
		return "Servono %d tappi" % costo
	return ""


func inizia_appello(indice: int, tipo: String) -> bool:
	if not radio_qui(indice) or motivo_blocco_appello(indice, tipo) != "":
		return false
	risorse["tappi"] = int(risorse["tappi"]) - Bilanciamento.costo_appello(int(lotti[indice].get("livello", 1)), tipo)
	lotti[indice]["appello"] = {"tipo": tipo, "lavoro": Bilanciamento.LAVORO_APPELLO, "fatto": 0.0}
	# Anche gli zombie ascoltano la radio.
	if prossimo_attacco > 0.0 and not attacco_pronto:
		prossimo_attacco = maxf(adesso() + Bilanciamento.PREAVVISO_ATTACCO + 30.0,
				prossimo_attacco - Bilanciamento.ANTICIPO_ATTACCO_APPELLO)
	risorse_cambiate.emit()
	lotto_cambiato.emit(indice)
	Suoni.suona("radio", 0.0)
	notifica.emit("In onda: %s" % Bilanciamento.APPELLI[tipo]["testo"])
	salva()
	return true


func stato_appello(indice: int) -> Dictionary:
	var appello: Dictionary = lotti[indice].get("appello", {})
	if appello.is_empty():
		return {}
	var v := velocita(indice)
	var manca := float(appello["lavoro"]) - float(appello["fatto"])
	return {"appello": appello, "quota": float(appello["fatto"]) / float(appello["lavoro"]),
			"secondi": manca / v if v > 0.0 else -1.0, "velocita": v}


## Chi risponde a un appello: rarità migliore con la Radio potenziata e,
## se l'appello era mirato, forte nella statistica chiesta.
func _risponde_all_appello(tipo: String, livello_radio: int) -> Dictionary:
	var pesi: Dictionary = Bilanciamento.RARITA_APPELLO[clampi(livello_radio, 1, 3) - 1]
	var rarita := GeneratoreCittadini._scegli_pesato(_casuale, pesi)
	var nuovo := GeneratoreCittadini.crea(_casuale, rarita)
	if tipo != "":
		var massimo := 0
		for nome in GeneratoreCittadini.STATISTICHE:
			massimo = maxi(massimo, int(nuovo["statistiche"][nome]))
		nuovo["statistiche"][tipo] = mini(Bilanciamento.STATISTICA_MASSIMA, maxi(massimo, int(nuovo["statistiche"][tipo])) + Bilanciamento.BONUS_APPELLO)
	nuovo["dalla_radio"] = true
	return nuovo


func _avanza_radio(secondi: float, avvisa := true) -> Array:
	var nomi: Array = []
	for i in lotti.size():
		var appello: Dictionary = lotti[i].get("appello", {})
		if appello.is_empty():
			continue
		appello["fatto"] = float(appello["fatto"]) + secondi * velocita(i)
		if float(appello["fatto"]) < float(appello["lavoro"]):
			continue
		var nuovo := _risponde_all_appello(appello["tipo"], int(lotti[i].get("livello", 1)))
		in_arrivo.append(nuovo)
		lotti[i].erase("appello")
		nomi.append(GeneratoreCittadini.nome_completo(nuovo))
		lotto_cambiato.emit(i)
		if avvisa:
			notifica.emit("Qualcuno ha risposto alla Radio: sta arrivando al cancello")
	return nomi


# ------------------------------------------------------------------ guida (tappa 12)


func imposta_guida(passo: int) -> void:
	guida = passo
	guida_cambiata.emit()
	salva()


func ricomincia_guida() -> void:
	imposta_guida(0)


# ------------------------------------------------------------------ demolire (tappa 14)

## Si recupera un quarto di quello che costerebbe costruirlo oggi.
const QUOTA_RECUPERO_DEMOLIZIONE := 0.25


func motivo_blocco_demolizione(indice: int) -> String:
	var lotto := lotti[indice]
	if lotto["stato"] != COSTRUITO:
		return "Non c'è niente da demolire"
	if lotto.has("potenzia") or lotto.has("lavorazione") or lotto.has("appello"):
		return "Ci sono lavori in corso"
	if lotto["edificio"] == "case" and posti_letto() - Bilanciamento.POSTI_PER_CASA * int(lotto.get("livello", 1)) < cittadini.size():
		return "Senza questa Casa qualcuno resterebbe senza letto"
	return ""


func recupero_demolizione(indice: int) -> int:
	return int(round(costo_costruzione(lotti[indice]["edificio"]) * QUOTA_RECUPERO_DEMOLIZIONE))


## Abbatte un edificio e libera il lotto per costruire altro.
func demolisci(indice: int) -> bool:
	if motivo_blocco_demolizione(indice) != "":
		return false
	var nome: String = Bilanciamento.EDIFICI[lotti[indice]["edificio"]]["nome"]
	var recupero := mini(recupero_demolizione(indice), spazio_libero("materiali"))
	for c in lavoratori(indice):
		c["lavoro"] = -1
	lotti[indice] = {"stato": LIBERO}
	risorse["materiali"] = int(risorse["materiali"]) + recupero
	lotto_cambiato.emit(indice)
	cittadini_cambiati.emit()
	risorse_cambiate.emit()
	notifica.emit("%s demolito: recuperati %d materiali" % [nome, recupero])
	salva()
	return true
