class_name Guida
extends Node
## Guida per la prima partita: un riquadro in alto con cosa fare e una
## freccia che saltella sopra il lotto da toccare. Avanza da sola quando il
## giocatore fa la cosa giusta; si può saltare in ogni momento.

const PASSI := [
	{"testo": "Benvenuto, sindaco! La città è tutta da costruire. Tocca un lotto libero e costruisci un Deposito rottami: recupera i materiali per tutto il resto.",
			"bersaglio": "libero", "quando": "deposito_rottami"},
	{"testo": "Ora un Orto: i cittadini mangiano ogni minuto e senza cibo si intristiscono. Se non vuoi aspettare, i tappi finiscono subito i lavori.",
			"bersaglio": "libero", "quando": "orto"},
	{"testo": "E delle Case: ognuno ha bisogno di un letto. Ogni edificio finito fa salire la barra dell'esperienza della città.",
			"bersaglio": "libero", "quando": "case"},
	{"testo": "Gli edifici lavorano solo con qualcuno dentro: tocca il Deposito e assegna un cittadino (qui conta la Forza).",
			"bersaglio": "deposito_rottami", "quando": "lavoratore"},
	{"testo": "Quando sopra il Deposito compare l'icona dei materiali, toccalo per raccoglierli.",
			"bersaglio": "deposito_rottami", "quando": "raccolta"},
	{"testo": "Guarda chi vive in città: tocca «Cittadini» in alto.",
			"bersaglio": "cittadini", "quando": "cittadini"},
	{"testo": "Il cancello resta chiuso: chi bussa aspetta fuori, a sinistra. Tocca le mura per farlo entrare, oppure scegli un custode che decida per te.",
			"bersaglio": "mura", "avanti": true},
	{"testo": "Oltre i lotti liberi ci sono le zone infestate. Le squadre potranno uscire quando avrai un'Armeria, dal livello 2 della città.",
			"bersaglio": "bloccato", "avanti": true},
]

var _citta: Node3D
var _interfaccia: Interfaccia
var _riquadro: PanelContainer
var _testo: Label
var _numero: Label
var _avanti: Button
var _freccia: Label3D
var _tempo := 0.0


func prepara(citta: Node3D, interfaccia: Interfaccia) -> void:
	_citta = citta
	_interfaccia = interfaccia
	_crea_riquadro()
	_freccia = Label3D.new()
	_freccia.text = "▼"
	_freccia.font_size = 160
	_freccia.pixel_size = 0.008
	_freccia.modulate = Color("#e3b448")
	_freccia.outline_modulate = Color("#2b2230")
	_freccia.outline_size = 30
	_freccia.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_freccia.no_depth_test = true
	_freccia.render_priority = 5
	_citta.add_child(_freccia)
	StatoGioco.guida_cambiata.connect(_aggiorna)
	StatoGioco.raccolto.connect(func(_i: int, _r: String, _q: int) -> void: _evento("raccolta"))
	_interfaccia.pannello_aperto.connect(func() -> void: _evento("cittadini"))
	_aggiorna()


func _crea_riquadro() -> void:
	_riquadro = PanelContainer.new()
	# in basso, dove non copre le icone sopra gli edifici
	_riquadro.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_riquadro.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_riquadro.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_riquadro.offset_left = -340
	_riquadro.offset_right = 340
	_riquadro.offset_top = -24
	_riquadro.offset_bottom = -24
	_riquadro.add_theme_stylebox_override("panel", _interfaccia._stile(Color("#2b2230e6"), Color("#e3b448"), 14, 12))
	_riquadro.mouse_filter = Control.MOUSE_FILTER_STOP
	_interfaccia.add_child(_riquadro)
	var colonna := VBoxContainer.new()
	colonna.add_theme_constant_override("separation", 6)
	_riquadro.add_child(colonna)
	_numero = _interfaccia._etichetta("", 14, Color("#e3b448"))
	colonna.add_child(_numero)
	_testo = _interfaccia._etichetta("", 18, Color("#f4e4c1"))
	_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_testo.custom_minimum_size = Vector2(640, 0)
	colonna.add_child(_testo)
	var pulsanti := HBoxContainer.new()
	pulsanti.add_theme_constant_override("separation", 10)
	pulsanti.alignment = BoxContainer.ALIGNMENT_END
	_avanti = _interfaccia._pulsante("Ho capito", Color("#e3b448"), Color("#2b2230"), 15)
	_avanti.pressed.connect(func() -> void: _completato(StatoGioco.guida))
	pulsanti.add_child(_avanti)
	var salta := _interfaccia._pulsante("Salta la guida", Color("#463a4d"), Color("#f4e4c1"), 15)
	salta.pressed.connect(func() -> void: StatoGioco.imposta_guida(-1))
	pulsanti.add_child(salta)
	colonna.add_child(pulsanti)


## Un evento (raccolta, pannello aperto) chiude il passo che lo aspettava.
func _evento(nome: String) -> void:
	var passo := StatoGioco.guida
	if passo >= 0 and passo < PASSI.size() and PASSI[passo].get("quando", "") == nome:
		_completato(passo)


## C'è già (o è in costruzione) un edificio di questo tipo?
func _c_e(id: String) -> bool:
	for lotto in StatoGioco.lotti:
		if lotto.get("edificio", "") == id and (lotto["stato"] == StatoGioco.COSTRUITO or lotto["stato"] == StatoGioco.CANTIERE):
			return true
	return false


## I passi che si chiudono da soli quando la condizione è vera.
func _controlla_condizione(passo: int) -> bool:
	var quando: String = PASSI[passo].get("quando", "")
	if quando == "lavoratore":
		for c in StatoGioco.cittadini:
			if int(c["lavoro"]) >= 0:
				return true
		return false
	if Bilanciamento.EDIFICI.has(quando):
		return _c_e(quando)
	return false


func _completato(passo: int) -> void:
	if StatoGioco.guida != passo:
		return
	StatoGioco.imposta_guida(passo + 1 if passo + 1 < PASSI.size() else -1)
	if StatoGioco.guida == -1:
		StatoGioco.notifica.emit("Buona fortuna, sindaco! La guida si rivede dal Menu.")


func _aggiorna() -> void:
	var passo := StatoGioco.guida
	var attiva := passo >= 0 and passo < PASSI.size()
	_riquadro.visible = attiva
	_freccia.visible = false
	_interfaccia._etichetta_abitanti.modulate = Color.WHITE
	if not attiva:
		return
	_numero.text = "GUIDA  ·  %d di %d" % [passo + 1, PASSI.size()]
	_testo.text = PASSI[passo]["testo"]
	_avanti.visible = PASSI[passo].get("avanti", false)
	_sistema_riquadro.call_deferred()
	# la telecamera va dove c'è da guardare
	var indice := _lotto_bersaglio(PASSI[passo]["bersaglio"])
	if indice >= 0:
		_citta.vai_a(indice * Lotto3D.LARGHEZZA, _citta._distanza)


func _sistema_riquadro() -> void:
	_riquadro.reset_size()
	_riquadro.offset_bottom = -24
	_riquadro.offset_top = -24 - _riquadro.get_combined_minimum_size().y


## Indice del lotto da indicare (-1 = nessuno).
func _lotto_bersaglio(bersaglio: String) -> int:
	for i in StatoGioco.lotti.size():
		var lotto: Dictionary = StatoGioco.lotti[i]
		match bersaglio:
			"mura":
				if lotto["stato"] == StatoGioco.MURA:
					return i
			"libero":
				if lotto["stato"] == StatoGioco.LIBERO:
					return i
			"bloccato":
				if lotto["stato"] == StatoGioco.BLOCCATO:
					return i
			_:
				if lotto["stato"] == StatoGioco.COSTRUITO and lotto.get("edificio", "") == bersaglio:
					return i
	return -1


func _process(delta: float) -> void:
	_tempo += delta
	var passo := StatoGioco.guida
	if passo < 0 or passo >= PASSI.size():
		return
	# Con una scheda o una finestra aperta la guida si fa da parte.
	var occupato := _interfaccia.scheda_aperta() or _interfaccia.finestra_aperta() \
			or _interfaccia.pannello_cittadini_aperto()
	_riquadro.visible = not occupato
	if not occupato:
		_interfaccia._suggerimento.hide()
	# i passi di costruzione e assegnazione si chiudono da soli
	if _controlla_condizione(passo):
		_completato(passo)
		return
	var bersaglio: String = PASSI[passo]["bersaglio"]
	var pulsante: Button = _interfaccia._etichetta_abitanti
	pulsante.modulate = Color(1.0, 1.0, 1.0) if bersaglio != "cittadini" \
			else Color(1.0, 1.0, 1.0).lerp(Color("#ffd27a"), 0.5 + 0.5 * sin(_tempo * 6.0))
	var indice := _lotto_bersaglio(bersaglio)
	_freccia.visible = indice >= 0 and not occupato
	if indice >= 0:
		var x := indice * Lotto3D.LARGHEZZA
		# davanti alla facciata, all'altezza della porta: sopra il tetto ci sono già barre e icone
		_freccia.position = Vector3(x, 2.4 + absf(sin(_tempo * 3.5)) * 0.45, 3.6)
