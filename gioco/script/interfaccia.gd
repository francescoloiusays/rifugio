class_name Interfaccia
extends CanvasLayer
## Barra delle risorse, scheda del lotto selezionato (con il menu di
## costruzione e i cantieri), avvisi a comparsa e suggerimento iniziale.

signal scheda_chiusa
signal costruisci_richiesto(id: String)
signal accelera_richiesto
signal raccogli_richiesto
signal pannello_aperto
signal vai_al_lotto(indice: int)

const CREMA := Color("#f4e4c1")
const CREMA_S := Color("#e8d4a8")
const MARRONE := Color("#5b3a29")
const SCURO := Color("#2b2230")
const SENAPE := Color("#e3b448")
const RUGGINE := Color("#a5552a")
const TESTO := Color("#3b2a22")
const GRIGIO := Color("#9c9184")

## Quanti edifici ancora bloccati mostrare nel menu, come anticipazione.
const ANTEPRIME_BLOCCATE := 2

var _valori_risorse := {}
var _etichetta_livello: Label
var _barra_esperienza: ProgressBar
var _scheda: PanelContainer
var _titolo: Label
var _sottotitolo: Label
var _corpo: Label
var _contenuto: VBoxContainer
var _scorri_scheda: ScrollContainer
var _interno_scheda: VBoxContainer
var _suggerimento: Label
var _avviso: Label
var _tween_avviso: Tween
var _indice := -1
var _stato_mostrato := ""
var _conto_cantiere: Label
var _barra_cantiere: ProgressBar
var _pulsante_accelera: Button
var _etichetta_abitanti: Button
var _pannello_cittadini: PanelContainer
var _elenco_cittadini: VBoxContainer
var _scelta_lavoratore := false
var _finestra: PanelContainer
var _titolo_finestra: Label
var _contenuto_finestra: VBoxContainer
var _testo_ultimo_salvataggio: Label
var _conferma_nuova := false
## Cittadini scelti per la prossima missione.
var _scelti: Array[String] = []
var _lotto_missione := -1
var _pulsante_attacco: Button
var _testo_attesa: Label
var _testo_produzione: Label
var _barra_raccolta: ProgressBar
var _pulsante_raccogli: Button
var _testo_fabbrica: Label
var _barra_fabbrica: ProgressBar
var _testo_appello: Label
var _barra_appello: ProgressBar


func _ready() -> void:
	layer = 10
	var radice := Control.new()
	radice.set_anchors_preset(Control.PRESET_FULL_RECT)
	radice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(radice)
	_crea_barra_risorse(radice)
	_crea_scheda(radice)
	_crea_suggerimento(radice)
	_crea_avviso(radice)
	_crea_pannello_cittadini(radice)
	_crea_finestra(radice)
	StatoGioco.risorse_cambiate.connect(_su_risorse_cambiate)
	StatoGioco.cittadini_cambiati.connect(_su_cittadini_cambiati)
	StatoGioco.sopravvissuto_arrivato.connect(_su_cittadini_cambiati)
	StatoGioco.attacco_risolto.connect(_mostra_esito_attacco)
	StatoGioco.pazienti_cambiati.connect(func() -> void:
		if _scheda.visible and _indice >= 0 and StatoGioco.lotti[_indice].get("edificio", "") == "ambulatorio":
			mostra_lotto(_indice))
	StatoGioco.attacco_cambiato.connect(func() -> void:
		if _indice == 0 and _scheda.visible:
			mostra_lotto(0))
	StatoGioco.livello_cambiato.connect(_su_livello_cambiato)
	StatoGioco.notifica.connect(mostra_avviso)
	StatoGioco.equipaggiamento_cambiato.connect(func() -> void:
		if _scheda.visible and _indice >= 0 and StatoGioco.fabbrica_qui(_indice) and not _scelta_lavoratore:
			mostra_lotto(_indice))
	aggiorna_risorse()
	aggiorna_livello()
	var ritorno := StatoGioco.riepilogo_ritorno
	if not ritorno.is_empty() and float(ritorno["assente"]) >= 30.0:
		_mostra_bentornato(ritorno)
	StatoGioco.riepilogo_ritorno = {}


# ------------------------------------------------------------------ stili


func _stile(colore: Color, bordo: Color = Color.TRANSPARENT, raggio := 14, margine := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = colore
	if bordo.a > 0.0:
		s.border_color = bordo
		s.set_border_width_all(4)
	s.set_corner_radius_all(raggio)
	s.set_content_margin_all(margine)
	return s


func _etichetta(testo: String, dimensione: int, colore: Color) -> Label:
	var l := Label.new()
	l.text = testo
	l.add_theme_font_size_override("font_size", dimensione)
	l.add_theme_color_override("font_color", colore)
	return l


## Etichetta per frasi lunghe: va a capo invece di allargare la scheda.
func _testo_lungo(testo: String, dimensione: int, colore: Color) -> Label:
	var l := _etichetta(testo, dimensione, colore)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# una larghezza fissa: senza, al primo calcolo andrebbe a capo a ogni
	# parola e la scheda risulterebbe altissima
	l.custom_minimum_size = Vector2(600, 0)
	return l


func _pulsante(testo: String, sfondo: Color, colore_testo: Color, dimensione := 18) -> Button:
	var b := Button.new()
	b.text = testo
	b.add_theme_font_size_override("font_size", dimensione)
	b.add_theme_stylebox_override("normal", _stile(sfondo, Color.TRANSPARENT, 10, 8))
	b.add_theme_stylebox_override("hover", _stile(sfondo.lightened(0.12), Color.TRANSPARENT, 10, 8))
	b.add_theme_stylebox_override("pressed", _stile(sfondo.darkened(0.15), Color.TRANSPARENT, 10, 8))
	b.add_theme_stylebox_override("focus", _stile(sfondo, Color.TRANSPARENT, 10, 8))
	b.add_theme_stylebox_override("disabled", _stile(CREMA_S, Color.TRANSPARENT, 10, 8))
	for chiave in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(chiave, colore_testo)
	b.add_theme_color_override("font_disabled_color", GRIGIO)
	b.pressed.connect(func() -> void: Suoni.suona("clic", 0.03))
	return b


func _barra_progresso(colore: Color, altezza := 12) -> ProgressBar:
	var barra := ProgressBar.new()
	barra.custom_minimum_size = Vector2(0, altezza)
	barra.show_percentage = false
	barra.add_theme_stylebox_override("background", _stile(Color("#463a4d"), Color.TRANSPARENT, 6, 0))
	barra.add_theme_stylebox_override("fill", _stile(colore, Color.TRANSPARENT, 6, 0))
	return barra


# ------------------------------------------------------------------ costruzione dell'interfaccia


func _crea_barra_risorse(radice: Control) -> void:
	var barra := PanelContainer.new()
	barra.set_anchors_preset(Control.PRESET_TOP_WIDE)
	barra.mouse_filter = Control.MOUSE_FILTER_STOP
	var stile := _stile(Color(SCURO, 0.92), Color.TRANSPARENT, 0, 10)
	stile.corner_radius_bottom_left = 16
	stile.corner_radius_bottom_right = 16
	stile.content_margin_left = 20
	stile.content_margin_right = 20
	barra.add_theme_stylebox_override("panel", stile)
	radice.add_child(barra)

	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 22)
	barra.add_child(riga)

	for id in Bilanciamento.RISORSE:
		var gruppo := HBoxContainer.new()
		gruppo.add_theme_constant_override("separation", 6)
		gruppo.tooltip_text = Bilanciamento.RISORSE[id]["nome"]
		gruppo.add_child(_icona(id, 34))
		var valore := _etichetta("0", 22, CREMA)
		gruppo.add_child(valore)
		_valori_risorse[id] = valore
		riga.add_child(gruppo)

	var spazio := Control.new()
	spazio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	riga.add_child(spazio)

	_pulsante_attacco = _pulsante("", Color("#c0392b"), CREMA, 18)
	_pulsante_attacco.visible = false
	_pulsante_attacco.pressed.connect(apri_difesa)
	riga.add_child(_pulsante_attacco)
	_etichetta_abitanti = _pulsante("", Color("#463a4d"), CREMA, 18)
	_etichetta_abitanti.tooltip_text = "Cittadini / posti letto. Tocca per vedere tutti."
	_etichetta_abitanti.pressed.connect(apri_cittadini)
	riga.add_child(_etichetta_abitanti)
	var menu := _pulsante("Menu", Color("#463a4d"), CREMA, 18)
	menu.tooltip_text = "Salvataggio e nuova partita"
	menu.pressed.connect(apri_menu)
	riga.add_child(menu)

	var colonna := VBoxContainer.new()
	colonna.add_theme_constant_override("separation", 2)
	_etichetta_livello = _etichetta("", 18, SENAPE)
	_etichetta_livello.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	colonna.add_child(_etichetta_livello)
	_barra_esperienza = _barra_progresso(SENAPE)
	_barra_esperienza.custom_minimum_size = Vector2(190, 12)
	colonna.add_child(_barra_esperienza)
	riga.add_child(colonna)


func _icona(risorsa: String, lato: int) -> TextureRect:
	var icona := TextureRect.new()
	icona.texture = load(Bilanciamento.RISORSE[risorsa]["icona"])
	icona.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icona.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icona.custom_minimum_size = Vector2(lato, lato)
	return icona


func _crea_scheda(radice: Control) -> void:
	_scheda = PanelContainer.new()
	_scheda.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_scheda.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_scheda.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_scheda.offset_left = -360
	_scheda.offset_right = 360
	_scheda.offset_top = -20
	_scheda.offset_bottom = -20
	_scheda.add_theme_stylebox_override("panel", _stile(CREMA, MARRONE, 18, 20))
	_scheda.visible = false
	radice.add_child(_scheda)

	var colonna := VBoxContainer.new()
	colonna.add_theme_constant_override("separation", 6)
	_scheda.add_child(colonna)

	var intestazione := HBoxContainer.new()
	_titolo = _etichetta("", 28, MARRONE)
	_titolo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intestazione.add_child(_titolo)
	var chiudi := _pulsante("Chiudi", MARRONE, CREMA)
	chiudi.pressed.connect(chiudi_scheda)
	intestazione.add_child(chiudi)
	colonna.add_child(intestazione)

	_sottotitolo = _etichetta("", 18, RUGGINE)
	colonna.add_child(_sottotitolo)
	# Il resto scorre se non sta nello schermo (schede lunghe, telefono in orizzontale).
	_scorri_scheda = ScrollContainer.new()
	_scorri_scheda.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	colonna.add_child(_scorri_scheda)
	_interno_scheda = VBoxContainer.new()
	_interno_scheda.add_theme_constant_override("separation", 6)
	_interno_scheda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scorri_scheda.add_child(_interno_scheda)
	_corpo = _etichetta("", 18, TESTO)
	_corpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_corpo.custom_minimum_size = Vector2(660, 0)
	_interno_scheda.add_child(_corpo)
	_contenuto = VBoxContainer.new()
	_contenuto.add_theme_constant_override("separation", 8)
	_interno_scheda.add_child(_contenuto)
	# la scheda segue il contenuto quando cambia (righe aggiunte, testi che vanno a capo)
	_interno_scheda.minimum_size_changed.connect(func() -> void:
		if _scheda.visible:
			_adatta_scheda.call_deferred())


func _crea_suggerimento(radice: Control) -> void:
	_suggerimento = _etichetta("Trascina per muoverti nella città  ·  Tocca un lotto per i dettagli", 18, CREMA)
	var stile := _stile(Color(SCURO, 0.85), Color.TRANSPARENT, 20, 10)
	stile.content_margin_left = 22
	stile.content_margin_right = 22
	_suggerimento.add_theme_stylebox_override("normal", stile)
	_suggerimento.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_suggerimento.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_suggerimento.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_suggerimento.offset_top = -40
	_suggerimento.offset_bottom = -40
	_suggerimento.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radice.add_child(_suggerimento)


func _crea_avviso(radice: Control) -> void:
	_avviso = _etichetta("", 20, SCURO)
	var stile := _stile(SENAPE, MARRONE, 16, 12)
	stile.set_border_width_all(3)
	stile.content_margin_left = 24
	stile.content_margin_right = 24
	_avviso.add_theme_stylebox_override("normal", stile)
	_avviso.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_avviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_avviso.offset_top = 76
	_avviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avviso.modulate.a = 0.0
	radice.add_child(_avviso)


# ------------------------------------------------------------------ aggiornamenti


func mostra_avviso(testo: String) -> void:
	_avviso.text = testo
	if _tween_avviso:
		_tween_avviso.kill()
	_avviso.modulate.a = 0.0
	_avviso.position.y = 70
	_tween_avviso = create_tween()
	_tween_avviso.set_parallel(true)
	_tween_avviso.tween_property(_avviso, "modulate:a", 1.0, 0.2)
	_tween_avviso.tween_property(_avviso, "position:y", 80, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_avviso.chain().tween_interval(2.4)
	_tween_avviso.chain().tween_property(_avviso, "modulate:a", 0.0, 0.5)


func nascondi_suggerimento() -> void:
	if _suggerimento.visible and _suggerimento.modulate.a >= 1.0:
		var tween := create_tween()
		tween.tween_property(_suggerimento, "modulate:a", 0.0, 0.6)
		tween.tween_callback(_suggerimento.hide)


func aggiorna_risorse() -> void:
	var massimo := StatoGioco.capienza()
	for id in _valori_risorse:
		var valore: int = StatoGioco.risorse.get(id, 0)
		var etichetta: Label = _valori_risorse[id]
		etichetta.text = str(valore)
		var colore := CREMA
		if valore >= massimo:
			colore = SENAPE
		if id == "cibo" and StatoGioco.affamati():
			colore = Color("#ff7a6b")
		etichetta.add_theme_color_override("font_color", colore)
		etichetta.get_parent().tooltip_text = "%s: %d / %d" % [Bilanciamento.RISORSE[id]["nome"], valore, massimo]
	_etichetta_abitanti.text = "Cittadini %d/%d" % [StatoGioco.abitanti(), StatoGioco.posti_letto()]


func aggiorna_livello() -> void:
	_etichetta_livello.text = "LIVELLO CITTÀ %d" % StatoGioco.livello_citta
	_barra_esperienza.max_value = StatoGioco.esperienza_mancante()
	_barra_esperienza.value = StatoGioco.esperienza


func _su_risorse_cambiate() -> void:
	aggiorna_risorse()
	# La scheda di un edificio che produce si aggiorna da sola ogni frame:
	# rifarla da capo a ogni raccolta la farebbe sfarfallare.
	if _stato_mostrato != StatoGioco.COSTRUITO:
		_ridisegna_scheda()


func _su_cittadini_cambiati() -> void:
	aggiorna_risorse()
	if not _scelta_lavoratore:
		_ridisegna_scheda()
	if _pannello_cittadini.visible:
		_riempi_elenco_cittadini()


func _su_livello_cambiato() -> void:
	aggiorna_livello()
	_ridisegna_scheda()


## Se la scheda mostra un menu che dipende da risorse o livello, lo rifà.
func _ridisegna_scheda() -> void:
	if _scheda.visible and _indice >= 0:
		mostra_lotto(_indice)


func _aggiorna_pulsante_attacco() -> void:
	var mancano := StatoGioco.secondi_al_prossimo_attacco()
	if StatoGioco.attacco_pronto:
		_pulsante_attacco.visible = true
		_pulsante_attacco.text = "ATTACCO!  Difendi le mura"
		_pulsante_attacco.modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 150.0)
	elif mancano >= 0.0 and mancano <= Bilanciamento.PREAVVISO_ATTACCO:
		_pulsante_attacco.visible = true
		_pulsante_attacco.text = "Zombie in arrivo  %s" % Bilanciamento.formatta_conto(mancano)
		_pulsante_attacco.modulate.a = 1.0
	else:
		_pulsante_attacco.visible = false


func _process(_delta: float) -> void:
	_aggiorna_pulsante_attacco()
	if _finestra.visible and _testo_attesa != null:
		var resta := Bilanciamento.ATTESA_RISPOSTA - StatoGioco.attesa_attacco
		_testo_attesa.text = "Se non decidi, tra %s le difese si arrangiano da sole." % Bilanciamento.formatta_conto(maxf(0.0, resta))
		if not StatoGioco.attacco_pronto:
			_testo_attesa = null
	if _finestra.visible and _testo_ultimo_salvataggio != null:
		var fa := StatoGioco.adesso() - StatoGioco.ultimo_salvataggio
		_testo_ultimo_salvataggio.text = "Salvataggio automatico ogni 10 secondi e alla chiusura.\nUltimo salvataggio: %s fa." % Bilanciamento.formatta_tempo(fa)
	if _scheda.visible and _indice >= 0 and _testo_produzione != null:
		_aggiorna_produzione()
	if _scheda.visible and _indice >= 0 and _testo_fabbrica != null:
		_aggiorna_fabbrica()
	if _scheda.visible and _indice >= 0 and _testo_appello != null:
		_aggiorna_appello()
	if not _scheda.visible or _indice < 0 or _conto_cantiere == null:
		return
	if not StatoGioco.in_lavori(_indice):
		return
	_conto_cantiere.text = "Mancano %s" % Bilanciamento.formatta_conto(StatoGioco.secondi_rimanenti(_indice))
	_barra_cantiere.value = StatoGioco.avanzamento(_indice)
	var costo := StatoGioco.costo_accelerazione(_indice)
	_pulsante_accelera.text = "Finisci subito  ·  %d tappi" % costo
	_pulsante_accelera.disabled = int(StatoGioco.risorse["tappi"]) < costo


# ------------------------------------------------------------------ scheda del lotto


func _svuota_contenuto() -> void:
	for figlio in _contenuto.get_children():
		_contenuto.remove_child(figlio)
		figlio.queue_free()
	_conto_cantiere = null
	_barra_cantiere = null
	_pulsante_accelera = null
	_testo_produzione = null
	_barra_raccolta = null
	_pulsante_raccogli = null
	_testo_fabbrica = null
	_barra_fabbrica = null
	_testo_appello = null
	_barra_appello = null
	_scelta_lavoratore = false


func mostra_lotto(indice: int) -> void:
	_suggerimento.hide()
	_indice = indice
	var dati: Dictionary = StatoGioco.lotti[indice]
	var stato: String = dati["stato"]
	_stato_mostrato = stato
	_svuota_contenuto()
	_corpo.visible = true
	if stato == StatoGioco.MURA:
		_titolo.text = "Mura della città"
		_sottotitolo.text = "%s  ·  Livello %d di %d" % [StatoGioco.nome_lotto(0), StatoGioco.livello_mura(), Bilanciamento.LIVELLO_MASSIMO_EDIFICIO]
		_corpo.text = _testo_difese()
		if not StatoGioco.sopravvissuto.is_empty():
			_mostra_sopravvissuto()
		if StatoGioco.attacco_pronto:
			var difendi := _pulsante("Gli zombie sono alle mura: difendi la città!", Color("#c0392b"), CREMA)
			difendi.pressed.connect(apri_difesa)
			_contenuto.add_child(difendi)
		_crea_riquadro_custode()
		_crea_riquadro_lavoratori()
		_crea_riga_potenziamento(dati)
		var prossima := StatoGioco.lotto_da_liberare()
		if prossima >= 0 and StatoGioco.missioni_sbloccate():
			var esci := _pulsante("Esci dalle mura: libera la zona vicina (difficoltà %d)" % int(StatoGioco.lotti[prossima].get("difficolta", 1)), SENAPE, SCURO)
			esci.pressed.connect(func() -> void: vai_al_lotto.emit(prossima))
			_contenuto.add_child(esci)
		elif prossima >= 0:
			_contenuto.add_child(_testo_lungo("Le squadre potranno uscire dalle mura quando avrai un'Armeria (si sblocca al livello %d)." % int(Bilanciamento.EDIFICI["armeria"]["sblocco"]), 15, RUGGINE))
	elif stato == StatoGioco.LIBERO:
		_mostra_menu_costruzione()
	elif stato == StatoGioco.CANTIERE:
		_mostra_cantiere(dati)
	elif stato == StatoGioco.BLOCCATO:
		_titolo.text = "Zona infestata"
		_sottotitolo.text = "Difficoltà %d" % dati.get("difficolta", 1)
		_corpo.text = "Gli zombie hanno invaso questo lotto. Mandaci una squadra per liberarlo e allargare la città."
		if not StatoGioco.missioni_sbloccate():
			_corpo.text += "\nPrima serve un'Armeria: senza armi e munizioni una squadra là fuori non torna. Si costruisce dal livello %d della città." % int(Bilanciamento.EDIFICI["armeria"]["sblocco"])
		elif indice == StatoGioco.lotto_da_liberare():
			_mostra_preparazione_missione(indice)
		else:
			_corpo.text += "\nPrima va liberata la zona più vicina alla città."
	else:
		_mostra_edificio(dati)
	_scheda.visible = true
	_adatta_scheda.call_deferred()


## La scheda cresce con il contenuto fino a lasciare libera la barra in alto;
## oltre, il contenuto scorre.
func _adatta_scheda() -> void:
	if not is_instance_valid(_interno_scheda):
		return
	var alto := _interno_scheda.get_combined_minimum_size().y
	var massimo := get_viewport().get_visible_rect().size.y - 190.0
	_scorri_scheda.custom_minimum_size = Vector2(680, minf(alto, massimo))
	_scheda.reset_size()
	_scheda.offset_bottom = -20
	_scheda.offset_top = -20 - _scheda.get_combined_minimum_size().y


func _mostra_menu_costruzione() -> void:
	_titolo.text = "Lotto libero"
	_sottotitolo.text = "Scegli cosa costruire"
	_corpo.text = "Ogni nuovo edificio costa il %d%% in più del precedente (le Case non contano): finora %d." % [
			int(round((Bilanciamento.CRESCITA_COSTO - 1.0) * 100.0)), StatoGioco.edifici_per_costo()]
	var scorrimento := ScrollContainer.new()
	scorrimento.custom_minimum_size = Vector2(660, 236)
	scorrimento.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_contenuto.add_child(scorrimento)
	var elenco := VBoxContainer.new()
	elenco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elenco.add_theme_constant_override("separation", 6)
	scorrimento.add_child(elenco)

	var bloccati_mostrati := 0
	for id in Bilanciamento.EDIFICI:
		var sbloccato := StatoGioco.edificio_sbloccato(id)
		if not sbloccato:
			if bloccati_mostrati >= ANTEPRIME_BLOCCATE:
				continue
			bloccati_mostrati += 1
		elenco.add_child(_riga_edificio(id, sbloccato))


func _riga_edificio(id: String, sbloccato: bool) -> Control:
	var info: Dictionary = Bilanciamento.EDIFICI[id]
	var pannello := PanelContainer.new()
	pannello.add_theme_stylebox_override("panel", _stile(CREMA_S if sbloccato else Color(CREMA_S, 0.45), Color.TRANSPARENT, 12, 10))
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 14)
	pannello.add_child(riga)

	var testi := VBoxContainer.new()
	testi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	testi.add_theme_constant_override("separation", 0)
	testi.add_child(_etichetta(info["nome"], 20, MARRONE if sbloccato else GRIGIO))
	var dettaglio: String = info["tipo"]
	if info["produce"] != "":
		dettaglio += "  ·  " + Bilanciamento.RISORSE[info["produce"]]["nome"].to_lower()
	if info["statistica"] != "":
		dettaglio += "  ·  " + info["statistica"]
	testi.add_child(_etichetta(dettaglio, 15, RUGGINE if sbloccato else GRIGIO))
	riga.add_child(testi)

	if not sbloccato:
		riga.add_child(_etichetta("Livello %d" % info["sblocco"], 17, GRIGIO))
		return pannello

	var costo := StatoGioco.costo_costruzione(id)
	var gruppo_costo := HBoxContainer.new()
	gruppo_costo.add_theme_constant_override("separation", 4)
	gruppo_costo.add_child(_icona("materiali", 24))
	var basta := int(StatoGioco.risorse["materiali"]) >= costo
	gruppo_costo.add_child(_etichetta("gratis" if costo == 0 else str(costo), 18, TESTO if basta else Color("#c0392b")))
	riga.add_child(gruppo_costo)
	var tempo := _etichetta(Bilanciamento.formatta_tempo(StatoGioco.tempo_costruzione(id)), 18, TESTO)
	tempo.custom_minimum_size = Vector2(62, 0)
	tempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	riga.add_child(tempo)

	var pulsante := _pulsante("Costruisci", SENAPE, SCURO)
	pulsante.custom_minimum_size = Vector2(120, 0)
	var motivo := StatoGioco.motivo_blocco(_indice, id)
	pulsante.disabled = motivo != ""
	pulsante.tooltip_text = motivo
	pulsante.pressed.connect(func() -> void: costruisci_richiesto.emit(id))
	riga.add_child(pulsante)
	return pannello


func _mostra_cantiere(dati: Dictionary) -> void:
	var info: Dictionary = Bilanciamento.EDIFICI[dati["edificio"]]
	_titolo.text = "Cantiere: %s" % info["nome"]
	_sottotitolo.text = "Lavori in corso"
	_corpo.text = info["descrizione"]
	_barra_cantiere = _barra_progresso(SENAPE, 18)
	_barra_cantiere.max_value = 1.0
	_barra_cantiere.step = 0.0
	_contenuto.add_child(_barra_cantiere)
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 12)
	_conto_cantiere = _etichetta("", 20, MARRONE)
	_conto_cantiere.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	riga.add_child(_conto_cantiere)
	_pulsante_accelera = _pulsante("", SENAPE, SCURO)
	_pulsante_accelera.pressed.connect(func() -> void: accelera_richiesto.emit())
	riga.add_child(_pulsante_accelera)
	_contenuto.add_child(riga)
	_process(0.0)


func _mostra_edificio(dati: Dictionary) -> void:
	var id: String = dati["edificio"]
	var info: Dictionary = Bilanciamento.EDIFICI[id]
	var livello: int = dati.get("livello", 1)
	_titolo.text = info["nome"]
	_sottotitolo.text = "%s  ·  Livello %d di %d" % [info["tipo"], livello, Bilanciamento.LIVELLO_MASSIMO_EDIFICIO]
	var righe := PackedStringArray([info["descrizione"]])
	if dati.get("danneggiato", false):
		righe.append("DANNEGGIATO dagli zombie: non produce finché non lo ripari.")
	if id == "mura_torrette":
		righe.append("Ogni livello aggiunge una torretta che spara da sola durante gli attacchi (%d in città)." % StatoGioco.torrette())
	if info["statistica"] != "":
		righe.append("Rende di più con: %s" % info["statistica"])
	if id == "case":
		righe.append("Posti letto: %d  ·  in città %d cittadini su %d posti" % [Bilanciamento.POSTI_PER_CASA * livello, StatoGioco.abitanti(), StatoGioco.posti_letto()])
	elif id == "radio":
		righe.append("Un sopravvissuto bussa ogni %s (senza Radio ogni %s)" % [Bilanciamento.formatta_tempo(StatoGioco.intervallo_arrivi()),
				Bilanciamento.formatta_tempo(Bilanciamento.SECONDI_TRA_ARRIVI)])
	elif id == "magazzino":
		righe.append("Ogni risorsa può arrivare a %d  ·  gli edifici tengono da parte %d cicli" % [StatoGioco.capienza(), StatoGioco.cicli_in_deposito()])
	_corpo.text = "\n".join(righe)
	_crea_riga_potenziamento(dati)
	if dati.get("danneggiato", false):
		var costo := StatoGioco.costo_riparazione(_indice)
		var ripara := _pulsante("Ripara  ·  %d materiali" % costo, Color("#c0392b"), CREMA)
		ripara.disabled = int(StatoGioco.risorse["materiali"]) < costo
		var indice := _indice
		ripara.pressed.connect(func() -> void: StatoGioco.ripara(indice))
		_contenuto.add_child(ripara)
	if Bilanciamento.produce(id):
		_crea_riquadro_produzione(id, livello)
		_crea_riquadro_lavoratori()
	if Bilanciamento.allena(id):
		_crea_riquadro_lavoratori()
	if Bilanciamento.fabbrica(id):
		_crea_riquadro_officina()
		_crea_riquadro_lavoratori()
	if id == "radio":
		_crea_riquadro_radio()
		_crea_riquadro_lavoratori()
	if id == "ambulatorio":
		_crea_riquadro_ambulatorio()
	_crea_riga_demolizione()


func _crea_riquadro_produzione(id: String, livello: int) -> void:
	var risorsa: String = info_risorsa(id)
	var pannello := PanelContainer.new()
	pannello.add_theme_stylebox_override("panel", _stile(CREMA_S, Color.TRANSPARENT, 12, 12))
	var colonna := VBoxContainer.new()
	colonna.add_theme_constant_override("separation", 6)
	pannello.add_child(colonna)
	var intestazione := HBoxContainer.new()
	intestazione.add_theme_constant_override("separation", 8)
	intestazione.add_child(_icona(risorsa, 26))
	var quantita := Bilanciamento.quantita_per_ciclo(id, livello)
	intestazione.add_child(_etichetta("%d %s ogni %s  ·  %.0f al minuto" % [quantita, Bilanciamento.RISORSE[risorsa]["nome"].to_lower(),
			Bilanciamento.formatta_tempo(Bilanciamento.durata_ciclo(id)), Bilanciamento.resa_al_minuto(id, livello)], 18, MARRONE))
	colonna.add_child(intestazione)
	_barra_raccolta = _barra_progresso(Color("#8fc96b"), 14)
	_barra_raccolta.max_value = 1.0
	_barra_raccolta.step = 0.0
	colonna.add_child(_barra_raccolta)
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 12)
	_testo_produzione = _etichetta("", 18, TESTO)
	_testo_produzione.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	riga.add_child(_testo_produzione)
	_pulsante_raccogli = _pulsante("Raccogli", SENAPE, SCURO)
	_pulsante_raccogli.custom_minimum_size = Vector2(150, 0)
	_pulsante_raccogli.pressed.connect(func() -> void: raccogli_richiesto.emit())
	riga.add_child(_pulsante_raccogli)
	colonna.add_child(riga)
	_contenuto.add_child(pannello)
	_aggiorna_produzione()


func info_risorsa(id: String) -> String:
	return Bilanciamento.EDIFICI[id]["produce"]


func _aggiorna_produzione() -> void:
	if not StatoGioco.produce(_indice):
		return
	var stato := StatoGioco.stato_produzione(_indice)
	_barra_raccolta.value = stato["avanzamento"]
	var testo := "Pronti: %d  (%d cicli su %d)" % [stato["pronto"], stato["cicli"], stato["massimo"]]
	if stato["pieno"]:
		testo += "  ·  pieno, raccogli!"
	else:
		testo += "  ·  prossimo tra %s" % Bilanciamento.formatta_conto(stato["secondi_al_prossimo"])
	if StatoGioco.lotti[_indice].get("danneggiato", false):
		testo = "Fermo: l'edificio è danneggiato, riparalo"
	elif stato["fermo"]:
		testo = "Fermo: assegna un lavoratore"
	else:
		testo += "  ·  velocità %d%%" % int(round(stato["velocita"] * 100.0))
	_testo_produzione.text = testo
	_pulsante_raccogli.disabled = stato["cicli"] <= 0
	_pulsante_raccogli.text = "Raccogli %d" % stato["pronto"] if stato["cicli"] > 0 else "Raccogli"


# ------------------------------------------------------------------ cittadini


func _colore_umore(umore: float) -> Color:
	if umore >= 70.0:
		return Color("#4f8a3a")
	if umore >= 40.0:
		return Color("#b8862b")
	return Color("#c0392b")


func _testo_tratto(cittadino: Dictionary) -> String:
	var tratto: String = cittadino["tratto"]
	if tratto == "":
		return ""
	return GeneratoreCittadini.TRATTI[tratto]["nome"]


func _colore_tratto(cittadino: Dictionary) -> Color:
	var tratto: String = cittadino["tratto"]
	if tratto == "":
		return GRIGIO
	match GeneratoreCittadini.TRATTI[tratto]["tipo"]:
		"negativo":
			return Color("#b5523b")
		"minore":
			return Color("#4f8a3a")
		_:
			return Color("#c98a12")


## Riga con nome, rarità, tratto, statistiche e (opzionale) lavoro e umore.
## La statistica evidenziata è quella che conta nell'edificio scelto.
func _riga_cittadino(c: Dictionary, evidenzia := "", mostra_lavoro := true) -> HBoxContainer:
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 12)
	var colore_rarita: Color = GeneratoreCittadini.RARITA[c["rarita"]]["colore"]
	var bollino := Panel.new()
	bollino.custom_minimum_size = Vector2(10, 38)
	bollino.add_theme_stylebox_override("panel", _stile(colore_rarita, Color.TRANSPARENT, 5, 0))
	bollino.tooltip_text = GeneratoreCittadini.RARITA[c["rarita"]]["nome"]
	riga.add_child(bollino)

	var nomi := VBoxContainer.new()
	nomi.add_theme_constant_override("separation", -2)
	nomi.custom_minimum_size = Vector2(170, 0)
	nomi.add_child(_etichetta(GeneratoreCittadini.nome_completo(c), 18, MARRONE))
	var sotto := "Liv. %d" % c["livello"]
	if c["rarita"] != "comune":
		sotto += "  ·  " + GeneratoreCittadini.RARITA[c["rarita"]]["nome"]
	if float(c.get("salute", 100.0)) < 100.0:
		sotto += "  ·  ferito %d%%" % int(c["salute"])
	if c.get("ex_zombie", false):
		sotto += "  ·  ex zombie"
	if not c.get("arma", {}).is_empty():
		sotto += "  ·  " + Bilanciamento.nome_oggetto(c["arma"])
	var etichetta_sotto := _etichetta(sotto, 14, RUGGINE)
	nomi.add_child(etichetta_sotto)
	riga.add_child(nomi)

	var tratto := _etichetta(_testo_tratto(c), 14, _colore_tratto(c))
	tratto.custom_minimum_size = Vector2(100, 0)
	if c["tratto"] != "":
		tratto.tooltip_text = GeneratoreCittadini.TRATTI[c["tratto"]]["effetto"]
		tratto.mouse_filter = Control.MOUSE_FILTER_PASS
	riga.add_child(tratto)

	for stat in GeneratoreCittadini.STATISTICHE:
		var valore := Bilanciamento.stat(c, stat)
		var bonus := Bilanciamento.bonus_vestito(c, stat)
		var gruppo := VBoxContainer.new()
		gruppo.add_theme_constant_override("separation", -4)
		var sigla := _etichetta(GeneratoreCittadini.NOMI_STATISTICHE[stat].substr(0, 3).to_upper(), 11,
				MARRONE if stat == evidenzia else GRIGIO)
		sigla.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gruppo.add_child(sigla)
		var numero := _etichetta(str(valore), 18 if stat == evidenzia else 16, MARRONE if stat == evidenzia else TESTO)
		numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if bonus > 0:
			# il vestito alza la statistica: il numero è verde
			numero.add_theme_color_override("font_color", Color("#3f8a3a"))
			numero.tooltip_text = "%d + %d dal vestito (%s)" % [valore - bonus, bonus, Bilanciamento.nome_oggetto(c["vestito"])]
			numero.mouse_filter = Control.MOUSE_FILTER_PASS
		gruppo.add_child(numero)
		gruppo.custom_minimum_size = Vector2(34, 0)
		riga.add_child(gruppo)

	if mostra_lavoro:
		var lavoro: int = c["lavoro"]
		var testo_lavoro := "Senza lavoro"
		var custode: bool = c["id"] == StatoGioco.custode
		if custode:
			testo_lavoro = "Custode del cancello"
		elif lavoro >= 0:
			testo_lavoro = StatoGioco.nome_lavoro(lavoro)
		var etichetta_lavoro := _etichetta(testo_lavoro, 15, TESTO if lavoro >= 0 or custode else GRIGIO)
		etichetta_lavoro.custom_minimum_size = Vector2(130, 0)
		riga.add_child(etichetta_lavoro)
	var umore := _etichetta("Umore %d" % int(c["umore"]), 15, _colore_umore(c["umore"]))
	umore.custom_minimum_size = Vector2(84, 0)
	riga.add_child(umore)
	return riga


func _crea_riquadro_lavoratori() -> void:
	var pannello := PanelContainer.new()
	pannello.add_theme_stylebox_override("panel", _stile(CREMA_S, Color.TRANSPARENT, 12, 10))
	var colonna := VBoxContainer.new()
	colonna.add_theme_constant_override("separation", 4)
	pannello.add_child(colonna)
	var squadra := StatoGioco.lavoratori(_indice)
	var posti := StatoGioco.posti_di_lavoro(_indice)
	var guardie: bool = StatoGioco.lotti[_indice]["stato"] == StatoGioco.MURA
	var allievi := StatoGioco.allena_qui(_indice)
	var titolo := "Lavoratori %d di %d"
	if guardie:
		titolo = "Guardie alle mura %d di %d"
	elif allievi:
		titolo = "Allievi %d di %d  ·  ogni punto in più richiede più tempo"
	colonna.add_child(_etichetta(titolo % [squadra.size(), posti], 17, MARRONE))
	var stat := StatoGioco.statistica_per(_indice)
	for c in squadra:
		var allenata := StatoGioco.statistica_in_allenamento(c, _indice) if allievi else ""
		var riga := _riga_cittadino(c, allenata if allenata != "" else stat, false)
		riga.get_child(2).queue_free()  # il tratto è nell'elenco completo; qui serve spazio
		var togli := _pulsante("Togli", MARRONE, CREMA, 15)
		var id: String = c["id"]
		togli.pressed.connect(func() -> void: StatoGioco.assegna(id, -1))
		riga.add_child(togli)
		colonna.add_child(riga)
		if allievi:
			colonna.add_child(_riga_allenamento(c, allenata))
	if squadra.size() < posti:
		var assegna := _pulsante("+ Assegna un cittadino", SENAPE, SCURO, 16)
		assegna.pressed.connect(_mostra_scelta_lavoratore)
		colonna.add_child(assegna)
	_contenuto.add_child(pannello)


## Il custode del cancello: decide da solo chi entra e intanto fa esperienza.
## Un buon custode è il primo candidato a fare il sindaco.
func _crea_riquadro_custode() -> void:
	var pannello := PanelContainer.new()
	pannello.add_theme_stylebox_override("panel", _stile(CREMA_S, Color.TRANSPARENT, 12, 10))
	var colonna := VBoxContainer.new()
	colonna.add_theme_constant_override("separation", 4)
	pannello.add_child(colonna)
	var c := StatoGioco.custode_attuale()
	if c.is_empty():
		colonna.add_child(_etichetta("Custode del cancello: nessuno", 17, MARRONE))
		colonna.add_child(_testo_lungo("Per ora decidi tu chi entra. Un custode lo fa da solo: più è intelligente, meno si fa ingannare. Ogni decisione lo fa crescere, e un buon custode potrà diventare sindaco.", 14, TESTO))
		var scegli := _pulsante("+ Scegli un custode", SENAPE, SCURO, 16)
		scegli.pressed.connect(_mostra_scelta_custode)
		colonna.add_child(scegli)
	else:
		var cv := StatoGioco.curriculum_custode(c)
		colonna.add_child(_etichetta("Custode del cancello", 17, MARRONE))
		var riga := _riga_cittadino(c, "intelligenza", false)
		riga.get_child(2).queue_free()
		var cambia := _pulsante("Cambia", SENAPE, SCURO, 15)
		cambia.pressed.connect(_mostra_scelta_custode)
		riga.add_child(cambia)
		var togli := _pulsante("Togli", MARRONE, CREMA, 15)
		togli.pressed.connect(func() -> void: StatoGioco.togli_custode())
		riga.add_child(togli)
		colonna.add_child(riga)
		var buone := int(cv["decisioni"]) - int(cv["sviste"])
		var testo := "Livello %d  ·  %d decisioni: %d accolti, %d mandati via, %d sviste" % [
				int(c["livello"]), int(cv["decisioni"]), int(cv["accolti"]), int(cv["respinti"]), int(cv["sviste"])]
		if int(cv["decisioni"]) >= 5:
			testo += "  ·  giudizio %d%%" % int(round(100.0 * buone / float(cv["decisioni"])))
		colonna.add_child(_testo_lungo(testo, 14, RUGGINE))
	_contenuto.add_child(pannello)


func _mostra_scelta_custode() -> void:
	_svuota_contenuto()
	_scelta_lavoratore = true
	_corpo.text = "Chi fai stare al cancello? Conta l'Intelligenza: con 5 riconosce quasi sempre chi porterebbe guai. Lascia il lavoro che ha adesso."
	var scorrimento := ScrollContainer.new()
	scorrimento.custom_minimum_size = Vector2(660, 250)
	scorrimento.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var elenco := VBoxContainer.new()
	elenco.add_theme_constant_override("separation", 6)
	elenco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scorrimento.add_child(elenco)
	var ordinati := StatoGioco.cittadini.duplicate()
	ordinati.sort_custom(func(a, b) -> bool: return Bilanciamento.stat(a, "intelligenza") > Bilanciamento.stat(b, "intelligenza"))
	for c in ordinati:
		if c["id"] == StatoGioco.custode:
			continue
		var riga := _riga_cittadino(c, "intelligenza", true)
		riga.get_child(2).queue_free()
		var scegli := _pulsante("Scegli", SENAPE, SCURO, 15)
		var id: String = c["id"]
		scegli.pressed.connect(func() -> void:
			_scelta_lavoratore = false
			StatoGioco.nomina_custode(id)
			mostra_lotto(0))
		riga.add_child(scegli)
		elenco.add_child(riga)
	_contenuto.add_child(scorrimento)
	var indietro := _pulsante("Indietro", MARRONE, CREMA, 16)
	indietro.pressed.connect(func() -> void:
		_scelta_lavoratore = false
		mostra_lotto(0))
	_contenuto.add_child(indietro)
	_adatta_scheda.call_deferred()


## Sotto ogni allievo: quale statistica sta allenando e quanto manca.
func _riga_allenamento(c: Dictionary, stat: String) -> Control:
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 10)
	if stat == "":
		riga.add_child(_etichetta("      Al massimo: qui non ha più niente da imparare", 14, RUGGINE))
		return riga
	var valore := int(c["statistiche"][stat])
	var serve := StatoGioco.secondi_per_punto(c, stat)
	var fatto := float(c.get("allenamento", 0.0))
	var etichetta := _etichetta("      %s %d → %d" % [GeneratoreCittadini.NOMI_STATISTICHE[stat], valore, valore + 1], 14, MARRONE)
	etichetta.custom_minimum_size = Vector2(190, 0)
	riga.add_child(etichetta)
	var barra := _barra_progresso(Color("#4f9ad6"), 10)
	barra.max_value = serve
	barra.value = fatto
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	riga.add_child(barra)
	var velocita := StatoGioco.velocita_allievo(c, _indice)
	var testo := "in pausa" if velocita <= 0.0 else "tra %s" % _durata_leggibile((serve - fatto) / velocita)
	riga.add_child(_etichetta(testo, 14, RUGGINE))
	return riga


## Potenziamento: costo ed effetto del prossimo livello, o i lavori in corso.
func _crea_riga_potenziamento(dati: Dictionary) -> void:
	var mura: bool = dati["stato"] == StatoGioco.MURA
	var id: String = "mura" if mura else String(dati["edificio"])
	var livello := int(dati.get("livello", 1))
	if dati.has("potenzia"):
		_barra_cantiere = _barra_progresso(SENAPE, 16)
		_barra_cantiere.max_value = 1.0
		_barra_cantiere.step = 0.0
		var cosa := "le guardie restano al loro posto" if mura else "l'edificio è fermo"
		_contenuto.add_child(_etichetta("Lavori per il livello %d: %s" % [int(dati["potenzia"]["livello"]), cosa], 16, RUGGINE))
		_contenuto.add_child(_barra_cantiere)
		var riga_lavori := HBoxContainer.new()
		riga_lavori.add_theme_constant_override("separation", 12)
		_conto_cantiere = _etichetta("", 18, MARRONE)
		_conto_cantiere.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		riga_lavori.add_child(_conto_cantiere)
		_pulsante_accelera = _pulsante("", SENAPE, SCURO)
		_pulsante_accelera.pressed.connect(func() -> void: accelera_richiesto.emit())
		riga_lavori.add_child(_pulsante_accelera)
		_contenuto.add_child(riga_lavori)
		return
	if livello >= Bilanciamento.LIVELLO_MASSIMO_EDIFICIO:
		_contenuto.add_child(_etichetta("Livello massimo raggiunto ★★", 16, RUGGINE))
		return
	if mura:
		var serve := int(Bilanciamento.MURA_LIVELLI[livello]["sblocco"])
		if StatoGioco.livello_citta < serve:
			_contenuto.add_child(_testo_lungo("%s (livello %d): dalla città di livello %d" % [Bilanciamento.MURA_LIVELLI[livello]["nome"], livello + 1, serve], 15, GRIGIO))
			return
	var costo := StatoGioco.costo_potenziamento(_indice)
	var tempo := StatoGioco.tempo_potenziamento(_indice)
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 10)
	var testo := _etichetta("Livello %d: %s\n%d materiali, %d tappi, %s" % [livello + 1, _effetto_potenziamento(id),
			costo["materiali"], costo["tappi"], Bilanciamento.formatta_tempo(tempo)], 15, TESTO)
	testo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	riga.add_child(testo)
	var pulsante := _pulsante("Potenzia", SENAPE, SCURO)
	pulsante.custom_minimum_size = Vector2(130, 0)
	var motivo := StatoGioco.motivo_blocco_potenziamento(_indice)
	pulsante.disabled = motivo != ""
	pulsante.tooltip_text = motivo
	if motivo.begins_with("Manca"):
		pulsante.text = motivo
		pulsante.custom_minimum_size = Vector2(200, 0)
	var indice := _indice
	pulsante.pressed.connect(func() -> void: StatoGioco.potenzia(indice))
	riga.add_child(pulsante)
	_contenuto.add_child(riga)


func _effetto_potenziamento(id: String) -> String:
	if id == "mura":
		var prossime: Dictionary = Bilanciamento.MURA_LIVELLI[StatoGioco.livello_mura()]
		return "%s, +1 guardia, difese più forti del %d%%" % [prossime["nome"],
				int(round((float(prossime["difesa"]) / float(Bilanciamento.MURA_LIVELLI[StatoGioco.livello_mura() - 1]["difesa"]) - 1.0) * 100.0))]
	if Bilanciamento.produce(id):
		var extra := ", +2 letti per i pazienti" if id == "ambulatorio" else ""
		return "+25% di produzione, +1 lavoratore" + extra
	if Bilanciamento.allena(id):
		return "allenamento +50% più veloce, +1 allievo"
	if id == "radio":
		var prossimo_radio := int(StatoGioco.lotti[_indice].get("livello", 1)) + 1
		var pesi: Dictionary = Bilanciamento.RARITA_APPELLO[prossimo_radio - 1]
		return "+1 operatore, sopravvissuti più frequenti, agli appelli rispondono rari il %d%% e leggendari il %d%%" % [pesi["raro"], pesi["leggendario"]]
	if Bilanciamento.fabbrica(id):
		var nuovi: PackedStringArray = []
		var prossimo := int(StatoGioco.lotti[_indice].get("livello", 1)) + 1
		for tipo in Bilanciamento.ARMI:
			if int(Bilanciamento.ARMI[tipo]["officina"]) == prossimo:
				nuovi.append(Bilanciamento.ARMI[tipo]["nome"])
		for tipo in Bilanciamento.VESTITI:
			if int(Bilanciamento.VESTITI[tipo]["officina"]) == prossimo:
				nuovi.append(Bilanciamento.VESTITI[tipo]["nome"])
		var testo := "+1 lavoratore, oggetti %s (armi +15%% di danno, vestiti +1)" % Bilanciamento.STELLE[prossimo]
		if not nuovi.is_empty():
			testo += ", nuovi: %s" % ", ".join(nuovi)
		return testo
	match id:
		"case":
			return "+%d posti letto" % Bilanciamento.POSTI_PER_CASA
		"magazzino":
			return "più capienza per ogni risorsa, +%d cicli tenuti dagli edifici" % Bilanciamento.CICLI_IN_PIU_PER_MAGAZZINO
		"mura_torrette":
			return "+1 torretta"
	return "edificio più grande e robusto"


## Elenco dei cittadini, dal più adatto al meno adatto per questo edificio.
func _mostra_scelta_lavoratore() -> void:
	var indice := _indice
	_svuota_contenuto()
	_scelta_lavoratore = true
	var stat := StatoGioco.statistica_per(indice)
	var allievi := StatoGioco.allena_qui(indice)
	_corpo.text = "Chi mandi a lavorare qui? Conta soprattutto: %s." % GeneratoreCittadini.NOMI_STATISTICHE[stat]
	if allievi:
		_corpo.text = "Chi mandi ad allenarsi? Qui sale %s: chi parte più basso migliora più in fretta." % Bilanciamento.EDIFICI[StatoGioco.lotti[indice]["edificio"]]["statistica"]
	var scorrimento := ScrollContainer.new()
	scorrimento.custom_minimum_size = Vector2(660, 250)
	scorrimento.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var elenco := VBoxContainer.new()
	elenco.add_theme_constant_override("separation", 6)
	elenco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scorrimento.add_child(elenco)
	var ordinati := StatoGioco.cittadini.duplicate()
	if allievi:
		ordinati.sort_custom(func(a, b) -> bool: return a["statistiche"][stat] < b["statistiche"][stat])
	else:
		ordinati.sort_custom(func(a, b) -> bool: return a["statistiche"][stat] > b["statistiche"][stat])
	for c in ordinati:
		if c["lavoro"] == indice:
			continue
		var riga := _riga_cittadino(c, stat, true)
		riga.get_child(2).queue_free()
		var scegli := _pulsante("Scegli", SENAPE, SCURO, 15)
		var id: String = c["id"]
		scegli.pressed.connect(func() -> void:
			_scelta_lavoratore = false
			StatoGioco.assegna(id, indice))
		riga.add_child(scegli)
		elenco.add_child(riga)
	_contenuto.add_child(scorrimento)
	var indietro := _pulsante("Indietro", MARRONE, CREMA, 16)
	indietro.pressed.connect(func() -> void: mostra_lotto(indice))
	_contenuto.add_child(indietro)
	_adatta_scheda.call_deferred()


func _mostra_preparazione_missione(indice: int) -> void:
	if _lotto_missione != indice:
		_lotto_missione = indice
		_scelti.clear()
	# toglie dalla scelta chi non c'è più
	_scelti.assign(_scelti.filter(func(id: String) -> bool: return not StatoGioco.trova_cittadino(id).is_empty()))
	var difficolta := int(StatoGioco.lotti[indice].get("difficolta", 1))
	var tipi: PackedStringArray = []
	for tipo in Bilanciamento.ZOMBIE:
		if int(Bilanciamento.ZOMBIE[tipo]["da_difficolta"]) <= difficolta:
			tipi.append(Bilanciamento.ZOMBIE[tipo]["nome"].to_lower())
	var bottino := Bilanciamento.bottino(difficolta)
	_corpo.text = "%d ondate da %d zombie: %s.\nRicompensa: il lotto, %d materiali, %d tappi, %d munizioni, %d cibo." % [
			Bilanciamento.ondate_missione(difficolta), Bilanciamento.zombie_per_ondata_missione(difficolta),
			", ".join(tipi), bottino["materiali"], bottino["tappi"], bottino["munizioni"], bottino["cibo"]]
	var posti := Bilanciamento.posti_squadra(StatoGioco.livello_citta)
	var intestazione := _etichetta("Scegli la squadra: %d di %d  ·  munizioni in città: %d" % [_scelti.size(), posti, StatoGioco.risorse["munizioni"]], 17, MARRONE)
	_contenuto.add_child(intestazione)
	var scorrimento := ScrollContainer.new()
	scorrimento.custom_minimum_size = Vector2(660, 150)
	scorrimento.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var elenco := VBoxContainer.new()
	elenco.add_theme_constant_override("separation", 5)
	elenco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scorrimento.add_child(elenco)
	var ordinati := StatoGioco.cittadini.duplicate()
	ordinati.sort_custom(func(a, b) -> bool: return a["statistiche"]["forza"] > b["statistiche"]["forza"])
	for c in ordinati:
		var id: String = c["id"]
		var scelto := id in _scelti
		var riga := _riga_cittadino(c, "forza", false)
		var pulsante := _pulsante("In squadra" if scelto else "Scegli", Color("#6fae99") if scelto else SENAPE, SCURO, 15)
		pulsante.custom_minimum_size = Vector2(104, 0)
		pulsante.disabled = not scelto and _scelti.size() >= posti
		pulsante.pressed.connect(func() -> void:
			if id in _scelti:
				_scelti.erase(id)
			elif _scelti.size() < posti:
				_scelti.append(id)
			mostra_lotto(indice))
		riga.add_child(pulsante)
		elenco.add_child(riga)
	_contenuto.add_child(scorrimento)
	var parti := _pulsante("Parti con %d" % _scelti.size() if not _scelti.is_empty() else "Scegli almeno un cittadino", Color("#c0392b"), CREMA, 18)
	parti.disabled = _scelti.is_empty()
	parti.pressed.connect(func() -> void:
		if StatoGioco.prepara_missione(indice, _scelti):
			StatoGioco.salva()
			get_tree().change_scene_to_file("res://scene/battaglia.tscn"))
	_contenuto.add_child(parti)


func _mostra_sopravvissuto() -> void:
	var c := StatoGioco.sopravvissuto
	var pannello := PanelContainer.new()
	pannello.add_theme_stylebox_override("panel", _stile(CREMA_S, SENAPE, 12, 12))
	var colonna := VBoxContainer.new()
	colonna.add_theme_constant_override("separation", 8)
	pannello.add_child(colonna)
	colonna.add_child(_etichetta("Un sopravvissuto aspetta fuori dal cancello", 18, RUGGINE))
	var chi_decide := StatoGioco.custode_attuale()
	if not chi_decide.is_empty():
		colonna.add_child(_testo_lungo("Il custode %s sta per decidere: puoi anticiparlo tu." % chi_decide["nome"], 15, MARRONE))
	colonna.add_child(_riga_cittadino(c, "", false))
	if c["tratto"] != "":
		colonna.add_child(_etichetta("%s: %s" % [_testo_tratto(c), GeneratoreCittadini.TRATTI[c["tratto"]]["effetto"]], 15, _colore_tratto(c)))
	var pulsanti := HBoxContainer.new()
	pulsanti.add_theme_constant_override("separation", 10)
	var accogli := _pulsante("Accogli", SENAPE, SCURO)
	accogli.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accogli.disabled = StatoGioco.posti_letto_liberi() <= 0
	if accogli.disabled:
		accogli.text = "Nessun posto letto: costruisci una Casa"
	accogli.pressed.connect(func() -> void: StatoGioco.accogli())
	pulsanti.add_child(accogli)
	var via := _pulsante("Manda via", MARRONE, CREMA)
	via.pressed.connect(func() -> void: StatoGioco.manda_via())
	pulsanti.add_child(via)
	colonna.add_child(pulsanti)
	_contenuto.add_child(pannello)


func _crea_pannello_cittadini(radice: Control) -> void:
	_pannello_cittadini = PanelContainer.new()
	_pannello_cittadini.set_anchors_preset(Control.PRESET_CENTER)
	_pannello_cittadini.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pannello_cittadini.grow_vertical = Control.GROW_DIRECTION_BOTH
	_pannello_cittadini.offset_left = -470
	_pannello_cittadini.offset_right = 470
	_pannello_cittadini.offset_top = -262
	_pannello_cittadini.offset_bottom = 270
	_pannello_cittadini.add_theme_stylebox_override("panel", _stile(CREMA, MARRONE, 18, 20))
	_pannello_cittadini.visible = false
	radice.add_child(_pannello_cittadini)
	var colonna := VBoxContainer.new()
	colonna.add_theme_constant_override("separation", 10)
	_pannello_cittadini.add_child(colonna)
	var intestazione := HBoxContainer.new()
	var titolo := _etichetta("Cittadini", 28, MARRONE)
	titolo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intestazione.add_child(titolo)
	var chiudi := _pulsante("Chiudi", MARRONE, CREMA)
	chiudi.pressed.connect(func() -> void: _pannello_cittadini.visible = false)
	intestazione.add_child(chiudi)
	colonna.add_child(intestazione)
	var scorrimento := ScrollContainer.new()
	scorrimento.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scorrimento.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_elenco_cittadini = VBoxContainer.new()
	_elenco_cittadini.add_theme_constant_override("separation", 6)
	_elenco_cittadini.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scorrimento.add_child(_elenco_cittadini)
	colonna.add_child(scorrimento)


func apri_cittadini() -> void:
	chiudi_scheda()
	_suggerimento.hide()
	_riempi_elenco_cittadini()
	_pannello_cittadini.visible = true
	pannello_aperto.emit()


func _riempi_elenco_cittadini() -> void:
	for figlio in _elenco_cittadini.get_children():
		figlio.queue_free()
	var riepilogo := "%d cittadini, %d posti letto  ·  mangiano %s cibo al minuto" % [
			StatoGioco.abitanti(), StatoGioco.posti_letto(), str(snappedf(StatoGioco.consumo_al_minuto(), 0.5))]
	if not StatoGioco.equipaggiamento.is_empty():
		var quanti := StatoGioco.equipaggiamento.size()
		riepilogo += "  ·  %d %s dell'Officina da assegnare" % [quanti, "oggetto" if quanti == 1 else "oggetti"]
	_elenco_cittadini.add_child(_etichetta(riepilogo, 16, RUGGINE))
	var con_officina := StatoGioco.livelli_di("officina") > 0 or not StatoGioco.equipaggiamento.is_empty()
	for c in StatoGioco.cittadini:
		var pannello := PanelContainer.new()
		pannello.add_theme_stylebox_override("panel", _stile(CREMA_S, Color.TRANSPARENT, 10, 8))
		var riga := _riga_cittadino(c)
		if con_officina:
			var equip := _pulsante("Equipaggia", SENAPE, SCURO, 14)
			var id: String = c["id"]
			equip.pressed.connect(func() -> void: apri_equipaggiamento(id))
			riga.add_child(equip)
		pannello.add_child(riga)
		_elenco_cittadini.add_child(pannello)


# ------------------------------------------------------------------ finestre: menu e bentornato


func _crea_finestra(radice: Control) -> void:
	_finestra = PanelContainer.new()
	_finestra.set_anchors_preset(Control.PRESET_CENTER)
	_finestra.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_finestra.grow_vertical = Control.GROW_DIRECTION_BOTH
	_finestra.custom_minimum_size = Vector2(560, 0)
	_finestra.add_theme_stylebox_override("panel", _stile(CREMA, MARRONE, 18, 22))
	_finestra.visible = false
	radice.add_child(_finestra)
	var colonna := VBoxContainer.new()
	colonna.add_theme_constant_override("separation", 12)
	_finestra.add_child(colonna)
	var intestazione := HBoxContainer.new()
	_titolo_finestra = _etichetta("", 28, MARRONE)
	_titolo_finestra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intestazione.add_child(_titolo_finestra)
	var chiudi := _pulsante("Chiudi", MARRONE, CREMA)
	chiudi.pressed.connect(chiudi_finestra)
	intestazione.add_child(chiudi)
	colonna.add_child(intestazione)
	_contenuto_finestra = VBoxContainer.new()
	_contenuto_finestra.add_theme_constant_override("separation", 10)
	colonna.add_child(_contenuto_finestra)


func _apri_finestra(titolo: String) -> VBoxContainer:
	chiudi_scheda()
	_pannello_cittadini.visible = false
	_suggerimento.hide()
	for figlio in _contenuto_finestra.get_children():
		_contenuto_finestra.remove_child(figlio)
		figlio.queue_free()
	_testo_ultimo_salvataggio = null
	_testo_attesa = null
	_titolo_finestra.text = titolo
	_finestra.visible = true
	# Si ridimensiona sul nuovo contenuto quando è stato aggiunto.
	_finestra.call_deferred("reset_size")
	return _contenuto_finestra


func chiudi_finestra() -> void:
	_finestra.visible = false
	_testo_ultimo_salvataggio = null
	_testo_attesa = null
	_conferma_nuova = false


func finestra_aperta() -> bool:
	return _finestra.visible


func _durata_leggibile(secondi: float) -> String:
	if secondi >= 86400.0:
		var giorni := int(secondi / 86400.0)
		return "1 giorno" if giorni == 1 else "%d giorni" % giorni
	if secondi >= 3600.0:
		var ore := int(secondi / 3600.0)
		var minuti := int(fmod(secondi, 3600.0) / 60.0)
		return "%d h %d min" % [ore, minuti] if minuti > 0 else "%d h" % ore
	return Bilanciamento.formatta_tempo(secondi)


func _mostra_bentornato(ritorno: Dictionary) -> void:
	var contenuto := _apri_finestra("Bentornato, sindaco!")
	contenuto.add_child(_etichetta("Sei stato via %s. Ecco cosa è successo in città:" % _durata_leggibile(ritorno["assente"]), 18, RUGGINE))
	var righe: Array[String] = []
	for nome in ritorno["cantieri"]:
		righe.append("Cantiere finito: %s" % nome)
	var pronti: Dictionary = ritorno["pronti"]
	for risorsa in pronti:
		righe.append("Pronti da raccogliere: %d %s" % [pronti[risorsa], Bilanciamento.RISORSE[risorsa]["nome"].to_lower()])
	if int(ritorno["cibo"]) > 0:
		var testo := "I cittadini hanno mangiato %d cibo" % ritorno["cibo"]
		if int(ritorno["dal_raccolto"]) > 0:
			testo += " (%d presi direttamente dall'orto)" % ritorno["dal_raccolto"]
		righe.append(testo)
	if ritorno["fame"]:
		righe.append("Il cibo non è bastato: la città ha fame!")
	if ritorno["sopravvissuto"]:
		righe.append("Un sopravvissuto aspetta al cancello")
	for attacco in ritorno.get("attacchi", []):
		righe.append(_riassunto_attacco(attacco))
	for progresso in ritorno.get("allenati", []):
		righe.append("Allenamento: %s" % progresso)
	for nome in ritorno.get("curati", []):
		righe.append("%s è guarito in Ambulatorio ed è entrato in città" % nome)
	for nome in ritorno.get("fabbricati", []):
		righe.append("Pronto in Officina: %s" % nome)
	for nome in ritorno.get("appelli", []):
		righe.append("%s ha risposto alla Radio e sta arrivando al cancello" % nome)
	if righe.is_empty():
		righe.append("Tutto tranquillo.")
	for riga in righe:
		var etichetta := _etichetta("•  " + riga, 18, Color("#c0392b") if riga.begins_with("Il cibo") else TESTO)
		etichetta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etichetta.custom_minimum_size = Vector2(560, 0)
		contenuto.add_child(etichetta)
	var via := _pulsante("Torna in città", SENAPE, SCURO, 20)
	via.pressed.connect(chiudi_finestra)
	contenuto.add_child(via)


func apri_menu() -> void:
	var contenuto := _apri_finestra("Partita")
	_conferma_nuova = false
	var info := _etichetta("Città di livello %d  ·  %d cittadini  ·  %d edifici" % [
			StatoGioco.livello_citta, StatoGioco.abitanti(), StatoGioco.edifici_costruiti()], 18, RUGGINE)
	contenuto.add_child(info)
	_testo_ultimo_salvataggio = _etichetta("", 17, TESTO)
	contenuto.add_child(_testo_ultimo_salvataggio)
	var salva := _pulsante("Salva ora", SENAPE, SCURO, 18)
	salva.pressed.connect(func() -> void:
		if StatoGioco.salva():
			mostra_avviso("Partita salvata"))
	contenuto.add_child(salva)
	var audio := HBoxContainer.new()
	audio.add_theme_constant_override("separation", 10)
	var musica := _pulsante("Musica: %s" % ("sì" if Suoni.musica_attiva else "no"), CREMA_S, MARRONE, 17)
	musica.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	musica.pressed.connect(func() -> void:
		Suoni.imposta_musica(not Suoni.musica_attiva)
		musica.text = "Musica: %s" % ("sì" if Suoni.musica_attiva else "no"))
	audio.add_child(musica)
	var effetti := _pulsante("Effetti sonori: %s" % ("sì" if Suoni.effetti_attivi else "no"), CREMA_S, MARRONE, 17)
	effetti.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effetti.pressed.connect(func() -> void:
		Suoni.imposta_effetti(not Suoni.effetti_attivi)
		effetti.text = "Effetti sonori: %s" % ("sì" if Suoni.effetti_attivi else "no"))
	audio.add_child(effetti)
	contenuto.add_child(audio)
	var guida := _pulsante("Rivedi la guida", CREMA_S, MARRONE, 17)
	guida.pressed.connect(func() -> void:
		chiudi_finestra()
		StatoGioco.ricomincia_guida())
	contenuto.add_child(guida)
	var nuova := _pulsante("Nuova partita", MARRONE, CREMA, 18)
	nuova.pressed.connect(func() -> void:
		if not _conferma_nuova:
			_conferma_nuova = true
			nuova.text = "Sicuro? La città attuale verrà cancellata  ·  tocca di nuovo"
			nuova.add_theme_stylebox_override("normal", _stile(Color("#c0392b"), Color.TRANSPARENT, 10, 8))
			return
		StatoGioco.cancella_e_ricomincia()
		get_tree().reload_current_scene())
	contenuto.add_child(nuova)


# ------------------------------------------------------------------ attacchi


# ------------------------------------------------------------------ ambulatorio


func _crea_riquadro_ambulatorio() -> void:
	var pannello := PanelContainer.new()
	pannello.add_theme_stylebox_override("panel", _stile(CREMA_S, Color.TRANSPARENT, 12, 10))
	var colonna := VBoxContainer.new()
	colonna.add_theme_constant_override("separation", 6)
	pannello.add_child(colonna)

	# barcollanti in cura
	var letti := StatoGioco.letti_pazienti()
	colonna.add_child(_etichetta("Pazienti: %d letti su %d  ·  velocità della cura %d%%" % [
			StatoGioco.pazienti.size(), letti, int(round(StatoGioco.velocita_cura() * 100.0))], 17, MARRONE))
	if StatoGioco.pazienti.is_empty():
		var vuoto := _etichetta("Nessun paziente. In battaglia, quando un barcollante cade a terra, toccalo per catturarlo: qui tornerà umano.", 15, RUGGINE)
		vuoto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vuoto.custom_minimum_size = Vector2(620, 0)
		colonna.add_child(vuoto)
	for k in StatoGioco.pazienti.size():
		var p: Dictionary = StatoGioco.pazienti[k]
		var riga := HBoxContainer.new()
		riga.add_theme_constant_override("separation", 10)
		var guarito := float(p["progresso"]) >= Bilanciamento.LAVORO_CURA_ZOMBIE
		var nome := _etichetta(GeneratoreCittadini.nome_completo(p["cittadino"]) if guarito else "Barcollante n. %d" % (k + 1), 17, TESTO)
		nome.custom_minimum_size = Vector2(170, 0)
		riga.add_child(nome)
		var barra := _barra_progresso(Color("#6fae99"), 14)
		barra.max_value = Bilanciamento.LAVORO_CURA_ZOMBIE
		barra.value = float(p["progresso"])
		barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		riga.add_child(barra)
		if guarito:
			riga.add_child(_etichetta("Guarito: serve un posto letto", 15, Color("#c0392b")))
		elif p["in_cura"]:
			riga.add_child(_etichetta("guarisce tra %s" % _durata_leggibile(StatoGioco.secondi_alla_guarigione(k)), 15, RUGGINE))
		else:
			var inizia := _pulsante("Cura  ·  %d medicine" % Bilanciamento.MEDICINE_CURA_ZOMBIE, Color("#6fae99"), SCURO, 15)
			inizia.disabled = int(StatoGioco.risorse["medicine"]) < Bilanciamento.MEDICINE_CURA_ZOMBIE
			inizia.pressed.connect(func() -> void: StatoGioco.inizia_cura(k))
			riga.add_child(inizia)
		colonna.add_child(riga)

	# cittadini feriti
	var feriti := StatoGioco.feriti()
	if not feriti.is_empty():
		colonna.add_child(_etichetta("Feriti in città: guariscono da soli, qui più in fretta", 17, MARRONE))
		for c in feriti:
			var riga := HBoxContainer.new()
			riga.add_theme_constant_override("separation", 10)
			var nome := _etichetta(GeneratoreCittadini.nome_completo(c), 17, TESTO)
			nome.custom_minimum_size = Vector2(170, 0)
			riga.add_child(nome)
			var barra := _barra_progresso(Color("#d0453a"), 14)
			barra.max_value = 100.0
			barra.value = float(c["salute"])
			barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			riga.add_child(barra)
			var cura := _pulsante("Cura  ·  1 medicina", Color("#6fae99"), SCURO, 15)
			cura.disabled = int(StatoGioco.risorse["medicine"]) <= 0
			var id: String = c["id"]
			cura.pressed.connect(func() -> void:
				StatoGioco.cura_feriti([id])
				mostra_lotto(_indice))
			riga.add_child(cura)
			colonna.add_child(riga)
	_contenuto.add_child(pannello)


func _testo_difese() -> String:
	var righe := PackedStringArray()
	righe.append("Il cancello resta chiuso: si apre solo per chi viene accolto. Da qui partono le squadre e qui si respingono gli attacchi.")
	if StatoGioco.livello_citta < 3 or not StatoGioco.missioni_sbloccate():
		righe.append("Gli zombie cominceranno ad attaccare dal livello 3 della città, quando avrai un'Armeria.")
		return "\n".join(righe)
	var stima := StatoGioco.stima_difesa()
	var giudizio := "assenti: senza guardie né torrette la città è indifesa"
	if stima >= 1.5:
		giudizio = "ottime"
	elif stima >= 1.0:
		giudizio = "sufficienti"
	elif stima > 0.0:
		giudizio = "deboli: aggiungi guardie forti o costruisci torrette"
	righe.append("Difese %s  ·  torrette: %d  ·  mura ×%.2f  ·  attacchi di difficoltà %d" % [giudizio, StatoGioco.torrette(),
			float(Bilanciamento.MURA_LIVELLI[StatoGioco.livello_mura() - 1]["difesa"]), StatoGioco.difficolta_attacco()])
	if not StatoGioco.attacco_pronto:
		righe.append("Prossimo attacco tra %s." % _durata_leggibile(StatoGioco.secondi_al_prossimo_attacco()))
	return "\n".join(righe)


func _riassunto_attacco(esito: Dictionary) -> String:
	var quando := "Mentre eri via, un attacco" if esito.get("a_gioco_chiuso", false) else "Un attacco"
	if esito["vinta"]:
		return "%s è stato respinto dalle difese" % quando
	var pezzi := PackedStringArray()
	if not esito["danneggiati"].is_empty():
		pezzi.append("danneggiato: " + ", ".join(PackedStringArray(esito["danneggiati"])))
	var perse: Dictionary = esito["perse"]
	var risorse_perse := PackedStringArray()
	for risorsa in perse:
		risorse_perse.append("%d %s" % [perse[risorsa], Bilanciamento.RISORSE[risorsa]["nome"].to_lower()])
	if not risorse_perse.is_empty():
		pezzi.append("perse " + ", ".join(risorse_perse))
	if pezzi.is_empty():
		return "%s ha sfondato le mura, senza danni gravi" % quando
	var dettagli := "; ".join(pezzi)
	return "%s ha sfondato le mura. %s." % [quando, dettagli.substr(0, 1).to_upper() + dettagli.substr(1)]


func apri_difesa() -> void:
	if not StatoGioco.attacco_pronto:
		return
	var contenuto := _apri_finestra("Gli zombie attaccano!")
	var difficolta := StatoGioco.difficolta_attacco()
	contenuto.add_child(_etichetta("%d ondate da %d zombie, difficoltà %d. Le torrette (%d) sparano da sole." % [
			Bilanciamento.ONDATE_ATTACCO, Bilanciamento.zombie_per_ondata(difficolta), difficolta, StatoGioco.torrette()], 17, RUGGINE))
	if _scelti.is_empty() or _lotto_missione != -2:
		_lotto_missione = -2
		_scelti.clear()
		for guardia in StatoGioco.lavoratori(0):
			_scelti.append(guardia["id"])
	_scelti.assign(_scelti.filter(func(id: String) -> bool: return not StatoGioco.trova_cittadino(id).is_empty()))
	var posti := StatoGioco.posti_guardie()
	contenuto.add_child(_etichetta("Chi combatte davanti alle mura? %d di %d  ·  munizioni: %d" % [_scelti.size(), posti, StatoGioco.risorse["munizioni"]], 17, MARRONE))
	var scorrimento := ScrollContainer.new()
	scorrimento.custom_minimum_size = Vector2(640, 170)
	scorrimento.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var elenco := VBoxContainer.new()
	elenco.add_theme_constant_override("separation", 5)
	elenco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scorrimento.add_child(elenco)
	var ordinati := StatoGioco.cittadini.duplicate()
	ordinati.sort_custom(func(a, b) -> bool: return a["statistiche"]["forza"] > b["statistiche"]["forza"])
	for c in ordinati:
		var id: String = c["id"]
		var scelto := id in _scelti
		var riga := _riga_cittadino(c, "forza", false)
		riga.get_child(2).queue_free()
		var pulsante := _pulsante("Combatte" if scelto else "Scegli", Color("#6fae99") if scelto else SENAPE, SCURO, 15)
		pulsante.custom_minimum_size = Vector2(96, 0)
		pulsante.disabled = not scelto and _scelti.size() >= posti
		pulsante.pressed.connect(func() -> void:
			if id in _scelti:
				_scelti.erase(id)
			elif _scelti.size() < posti:
				_scelti.append(id)
			apri_difesa())
		riga.add_child(pulsante)
		elenco.add_child(riga)
	contenuto.add_child(scorrimento)
	var combatti := _pulsante("Combatti con %d" % _scelti.size() if not _scelti.is_empty() else "Scegli almeno un cittadino", Color("#c0392b"), CREMA, 18)
	combatti.disabled = _scelti.is_empty()
	combatti.pressed.connect(func() -> void:
		if StatoGioco.prepara_difesa(_scelti):
			StatoGioco.salva()
			get_tree().change_scene_to_file("res://scene/battaglia.tscn"))
	contenuto.add_child(combatti)
	var stima := StatoGioco.stima_difesa()
	var automatica := _pulsante("Lascia fare alle difese  (%s)" % ("dovrebbero farcela" if stima >= 1.0 else "rischioso"), Color("#4a4452"), CREMA, 16)
	automatica.pressed.connect(func() -> void:
		var esito := StatoGioco.risolvi_attacco_automatico(false)
		_mostra_esito_attacco(esito))
	contenuto.add_child(automatica)
	_testo_attesa = _etichetta("", 15, RUGGINE)
	contenuto.add_child(_testo_attesa)


func _mostra_esito_attacco(esito: Dictionary) -> void:
	var contenuto := _apri_finestra("Attacco respinto!" if esito["vinta"] else "Le mura hanno ceduto")
	var righe: Array[String] = []
	if esito["vinta"]:
		righe.append("Guardie e torrette hanno tenuto lontani gli zombie.")
		var bottino: Dictionary = esito["bottino"]
		var pezzi := PackedStringArray()
		for risorsa in bottino:
			if int(bottino[risorsa]) > 0:
				pezzi.append("%d %s" % [bottino[risorsa], Bilanciamento.RISORSE[risorsa]["nome"].to_lower()])
		if not pezzi.is_empty():
			righe.append("Recuperati dai caduti: " + ", ".join(pezzi))
		if int(esito["esperienza"]) > 0:
			righe.append("Esperienza della città: +%d" % esito["esperienza"])
	else:
		righe.append("Le difese non sono bastate: gli zombie sono entrati in città.")
		for nome in esito["danneggiati"]:
			righe.append("Danneggiato: %s (non produce finché non lo ripari)" % nome)
		var perse: Dictionary = esito["perse"]
		for risorsa in perse:
			righe.append("Perse: %d %s" % [perse[risorsa], Bilanciamento.RISORSE[risorsa]["nome"].to_lower()])
		righe.append("Metti più guardie alle mura e costruisci Mura e torrette.")
	for ferito in esito["feriti"]:
		righe.append("Ferito: %s (salute %d%%)" % [ferito["nome"], ferito["salute"]])
	for riga in righe:
		var colore := Color("#c0392b") if riga.begins_with("Danneggiato") or riga.begins_with("Perse") else TESTO
		var etichetta := _etichetta("•  " + riga, 17, colore)
		etichetta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etichetta.custom_minimum_size = Vector2(560, 0)
		contenuto.add_child(etichetta)
	var ok := _pulsante("Torna in città", SENAPE, SCURO, 18)
	ok.pressed.connect(chiudi_finestra)
	contenuto.add_child(ok)


func pannello_cittadini_aperto() -> bool:
	return _pannello_cittadini.visible


func chiudi_scheda() -> void:
	if _scheda.visible:
		_scheda.visible = false
		_indice = -1
		_conferma_demolizione = -1
		_svuota_contenuto()
		scheda_chiusa.emit()


func scheda_aperta() -> bool:
	return _scheda.visible


# ------------------------------------------------------------------ officina ed equipaggiamento (tappa 10)


## Il banco dell'Officina: cosa sta fabbricando oppure cosa può fabbricare.
func _crea_riquadro_officina() -> void:
	var indice := _indice
	var pannello := PanelContainer.new()
	pannello.add_theme_stylebox_override("panel", _stile(CREMA_S, Color.TRANSPARENT, 12, 12))
	var colonna := VBoxContainer.new()
	colonna.add_theme_constant_override("separation", 6)
	pannello.add_child(colonna)
	var qualita := StatoGioco.qualita_officina(indice)
	var stato := StatoGioco.stato_fabbrica(indice)
	if not stato.is_empty():
		colonna.add_child(_etichetta("Sul banco: %s  ·  %s" % [Bilanciamento.nome_oggetto(stato["oggetto"]),
				Bilanciamento.effetto_oggetto(stato["oggetto"]["tipo"], int(stato["oggetto"]["qualita"]))], 18, MARRONE))
		_barra_fabbrica = _barra_progresso(SENAPE, 14)
		_barra_fabbrica.max_value = 1.0
		_barra_fabbrica.step = 0.0
		colonna.add_child(_barra_fabbrica)
		_testo_fabbrica = _etichetta("", 17, TESTO)
		colonna.add_child(_testo_fabbrica)
		_aggiorna_fabbrica()
	else:
		var titolo := "Banco libero: cosa fabbrichiamo?  Qualità %s (il livello dell'Officina)" % Bilanciamento.STELLE[qualita]
		colonna.add_child(_etichetta(titolo, 17, MARRONE))
		var scorrimento := ScrollContainer.new()
		scorrimento.custom_minimum_size = Vector2(660, 150)
		scorrimento.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var elenco := VBoxContainer.new()
		elenco.add_theme_constant_override("separation", 4)
		elenco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scorrimento.add_child(elenco)
		var velocita := StatoGioco.velocita(indice)
		for tipo in StatoGioco.oggetti_fabbricabili(indice):
			var info := Bilanciamento.info_oggetto({"tipo": tipo})
			var costo := Bilanciamento.costo_oggetto(tipo, qualita)
			var lavoro := Bilanciamento.lavoro_oggetto(tipo, qualita)
			var riga := HBoxContainer.new()
			riga.add_theme_constant_override("separation", 10)
			var tempo := "senza lavoratori è fermo" if velocita <= 0.0 else Bilanciamento.formatta_tempo(lavoro / velocita)
			var testo := _etichetta("%s  ·  %s\n%s  ·  %d materiali, %d tappi, %s" % [info["nome"],
					"Arma" if Bilanciamento.e_arma(tipo) else "Vestito", Bilanciamento.effetto_oggetto(tipo, qualita),
					costo["materiali"], costo["tappi"], tempo], 15, TESTO)
			testo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if info.has("descrizione"):
				testo.tooltip_text = info["descrizione"]
				testo.mouse_filter = Control.MOUSE_FILTER_PASS
			riga.add_child(testo)
			var motivo := StatoGioco.motivo_blocco_fabbrica(indice, tipo)
			var fabbrica := _pulsante("Fabbrica" if motivo == "" else motivo, SENAPE, SCURO, 15)
			fabbrica.custom_minimum_size = Vector2(150, 0)
			fabbrica.disabled = motivo != ""
			fabbrica.pressed.connect(func() -> void:
				if StatoGioco.inizia_fabbrica(indice, tipo):
					mostra_lotto(indice))
			riga.add_child(fabbrica)
			elenco.add_child(riga)
		colonna.add_child(scorrimento)
	if not StatoGioco.equipaggiamento.is_empty():
		var nomi: PackedStringArray = []
		for oggetto in StatoGioco.equipaggiamento:
			nomi.append(Bilanciamento.nome_oggetto(oggetto))
		var deposito := _etichetta("Pronti da assegnare: %s" % ", ".join(nomi), 15, RUGGINE)
		deposito.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		deposito.custom_minimum_size = Vector2(600, 0)
		colonna.add_child(deposito)
		var vai := _pulsante("Equipaggia i cittadini", MARRONE, CREMA, 15)
		vai.pressed.connect(apri_cittadini)
		colonna.add_child(vai)
	_contenuto.add_child(pannello)


func _aggiorna_fabbrica() -> void:
	var stato := StatoGioco.stato_fabbrica(_indice)
	if stato.is_empty():
		# appena finito: la scheda torna alla scelta del prossimo oggetto
		_testo_fabbrica = null
		mostra_lotto(_indice)
		return
	_barra_fabbrica.value = stato["quota"]
	if StatoGioco.lotti[_indice].get("danneggiato", false):
		_testo_fabbrica.text = "Fermo: l'Officina è danneggiata, riparala"
	elif float(stato["secondi"]) < 0.0:
		_testo_fabbrica.text = "Fermo: assegna un lavoratore"
	else:
		_testo_fabbrica.text = "Pronto tra %s  ·  velocità %d%%" % [Bilanciamento.formatta_conto(stato["secondi"]),
				int(round(float(stato["velocita"]) * 100.0))]


## Arma e vestito di un cittadino, con gli oggetti del deposito da provare.
func apri_equipaggiamento(id: String) -> void:
	var c := StatoGioco.trova_cittadino(id)
	if c.is_empty():
		return
	var contenuto := _apri_finestra("Equipaggiamento")
	contenuto.add_child(_riga_cittadino(c, "", false))
	for slot in ["arma", "vestito"]:
		var riga := HBoxContainer.new()
		riga.add_theme_constant_override("separation", 10)
		var oggetto: Dictionary = c.get(slot, {})
		var testo := ""
		if oggetto.is_empty():
			testo = "Arma: %s (di serie)" % Bilanciamento.ARMA_DI_SERIE["nome"] if slot == "arma" \
					else "Vestito: abiti di tutti i giorni"
		else:
			testo = "%s: %s  ·  %s" % ["Arma" if slot == "arma" else "Vestito", Bilanciamento.nome_oggetto(oggetto),
					Bilanciamento.effetto_oggetto(oggetto["tipo"], int(oggetto["qualita"]))]
		var etichetta := _etichetta(testo, 17, MARRONE)
		etichetta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		riga.add_child(etichetta)
		if not oggetto.is_empty():
			var togli := _pulsante("Togli", MARRONE, CREMA, 15)
			var quale: String = slot
			togli.pressed.connect(func() -> void:
				StatoGioco.togli_equipaggiamento(id, quale)
				apri_equipaggiamento(id))
			riga.add_child(togli)
		contenuto.add_child(riga)
	contenuto.add_child(_etichetta("Danno per colpo: %d  ·  ricarica %s s" % [int(round(Bilanciamento.danno_colpo(c, 1.0))),
			str(snappedf(Bilanciamento.ricarica(c), 0.01))], 15, RUGGINE))
	if StatoGioco.equipaggiamento.is_empty():
		var vuoto := _etichetta("Nel deposito non c'è niente: fabbrica armi e vestiti in Officina." if StatoGioco.livelli_di("officina") > 0
				else "Costruisci un'Officina (livello 7) per fabbricare armi e vestiti.", 16, GRIGIO)
		contenuto.add_child(vuoto)
	else:
		contenuto.add_child(_etichetta("Nel deposito", 17, MARRONE))
		var scorrimento := ScrollContainer.new()
		scorrimento.custom_minimum_size = Vector2(560, mini(240, 46 * StatoGioco.equipaggiamento.size()))
		scorrimento.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var elenco := VBoxContainer.new()
		elenco.add_theme_constant_override("separation", 4)
		elenco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scorrimento.add_child(elenco)
		for oggetto in StatoGioco.equipaggiamento:
			var riga := HBoxContainer.new()
			riga.add_theme_constant_override("separation", 10)
			var etichetta := _etichetta("%s  ·  %s" % [Bilanciamento.nome_oggetto(oggetto),
					Bilanciamento.effetto_oggetto(oggetto["tipo"], int(oggetto["qualita"]))], 16, TESTO)
			etichetta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			riga.add_child(etichetta)
			var usa := _pulsante("Usa", SENAPE, SCURO, 15)
			var id_oggetto: String = oggetto["id"]
			usa.pressed.connect(func() -> void:
				StatoGioco.equipaggia(id, id_oggetto)
				apri_equipaggiamento(id))
			riga.add_child(usa)
			elenco.add_child(riga)
		contenuto.add_child(scorrimento)
	var indietro := _pulsante("Torna ai cittadini", MARRONE, CREMA, 16)
	indietro.pressed.connect(func() -> void:
		chiudi_finestra()
		apri_cittadini())
	contenuto.add_child(indietro)


# ------------------------------------------------------------------ radio (tappa 11)


func _crea_riquadro_radio() -> void:
	var indice := _indice
	var livello := int(StatoGioco.lotti[indice].get("livello", 1))
	var pannello := PanelContainer.new()
	pannello.add_theme_stylebox_override("panel", _stile(CREMA_S, Color.TRANSPARENT, 12, 12))
	var colonna := VBoxContainer.new()
	colonna.add_theme_constant_override("separation", 6)
	pannello.add_child(colonna)
	var stato := StatoGioco.stato_appello(indice)
	if not stato.is_empty():
		var tipo: String = stato["appello"]["tipo"]
		colonna.add_child(_etichetta("IN ONDA  ·  %s" % Bilanciamento.APPELLI[tipo]["nome"], 18, Color("#c0392b")))
		colonna.add_child(_etichetta(Bilanciamento.APPELLI[tipo]["testo"], 15, TESTO))
		_barra_appello = _barra_progresso(Color("#c0392b"), 14)
		_barra_appello.max_value = 1.0
		_barra_appello.step = 0.0
		colonna.add_child(_barra_appello)
		_testo_appello = _etichetta("", 17, TESTO)
		colonna.add_child(_testo_appello)
		_aggiorna_appello()
	else:
		var pesi: Dictionary = Bilanciamento.RARITA_APPELLO[livello - 1]
		colonna.add_child(_etichetta("Trasmetti un appello: risponde qualcuno (raro il %d%%, leggendario il %d%%)" % [pesi["raro"], pesi["leggendario"]], 17, MARRONE))
		colonna.add_child(_etichetta("Attenzione: la radio la sentono anche gli zombie, il prossimo attacco arriva prima.", 14, RUGGINE))
		var velocita := StatoGioco.velocita(indice)
		for tipo in Bilanciamento.APPELLI:
			var riga := HBoxContainer.new()
			riga.add_theme_constant_override("separation", 10)
			var dettaglio := "chi capita" if tipo == "" else "+%d in %s" % [Bilanciamento.BONUS_APPELLO, GeneratoreCittadini.NOMI_STATISTICHE[tipo]]
			var tempo := "senza operatori è ferma" if velocita <= 0.0 else Bilanciamento.formatta_tempo(Bilanciamento.LAVORO_APPELLO / velocita)
			var testo := _etichetta("%s  ·  %s  ·  %d tappi, %s" % [Bilanciamento.APPELLI[tipo]["nome"], dettaglio,
					Bilanciamento.costo_appello(livello, tipo), tempo], 15, TESTO)
			testo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			riga.add_child(testo)
			var motivo := StatoGioco.motivo_blocco_appello(indice, tipo)
			var trasmetti := _pulsante("Trasmetti" if motivo == "" else motivo, SENAPE, SCURO, 15)
			trasmetti.custom_minimum_size = Vector2(150, 0)
			trasmetti.disabled = motivo != ""
			var scelto: String = tipo
			trasmetti.pressed.connect(func() -> void:
				if StatoGioco.inizia_appello(indice, scelto):
					mostra_lotto(indice))
			riga.add_child(trasmetti)
			colonna.add_child(riga)
	if not StatoGioco.in_arrivo.is_empty():
		colonna.add_child(_etichetta("In arrivo dopo un appello: %d" % StatoGioco.in_arrivo.size(), 15, RUGGINE))
	_contenuto.add_child(pannello)


func _aggiorna_appello() -> void:
	var stato := StatoGioco.stato_appello(_indice)
	if stato.is_empty():
		_testo_appello = null
		mostra_lotto(_indice)
		return
	_barra_appello.value = stato["quota"]
	if StatoGioco.lotti[_indice].get("danneggiato", false):
		_testo_appello.text = "Muta: la Radio è danneggiata, riparala"
	elif float(stato["secondi"]) < 0.0:
		_testo_appello.text = "Ferma: assegna un operatore"
	else:
		_testo_appello.text = "Qualcuno risponderà tra %s  ·  velocità %d%%" % [Bilanciamento.formatta_conto(stato["secondi"]),
				int(round(float(stato["velocita"]) * 100.0))]



# ------------------------------------------------------------------ demolire (tappa 14)

var _conferma_demolizione := -1


func _crea_riga_demolizione() -> void:
	var indice := _indice
	var motivo := StatoGioco.motivo_blocco_demolizione(indice)
	var confermare := _conferma_demolizione == indice
	var testo := "Demolisci  ·  recuperi %d materiali" % StatoGioco.recupero_demolizione(indice)
	if confermare:
		testo = "Sicuro? L'edificio sparisce  ·  tocca di nuovo per demolire"
	var pulsante := _pulsante(testo, Color("#c0392b") if confermare else CREMA_S, CREMA if confermare else GRIGIO, 15)
	pulsante.disabled = motivo != ""
	pulsante.tooltip_text = motivo
	pulsante.pressed.connect(func() -> void:
		if _conferma_demolizione != indice:
			_conferma_demolizione = indice
			mostra_lotto(indice)
			return
		_conferma_demolizione = -1
		if StatoGioco.demolisci(indice):
			mostra_lotto(indice))
	_contenuto.add_child(pulsante)
