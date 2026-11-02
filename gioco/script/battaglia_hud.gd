class_name BattagliaHud
extends CanvasLayer
## Interfaccia della battaglia: munizioni e ondate in alto, le carte della
## squadra in basso (salute, abilità, ritira), annunci ed esito finale.

signal abilita_richiesta(indice: int)
signal ritira_richiesto(indice: int)
signal ritirata_richiesta
signal cura_richiesta
signal torna_richiesto

const CREMA := Color("#f4e4c1")
const CREMA_S := Color("#e8d4a8")
const MARRONE := Color("#5b3a29")
const SCURO := Color("#1d1a22")
const SENAPE := Color("#e3b448")
const RUGGINE := Color("#a5552a")
const ROSSO := Color("#c0392b")
const TESTO := Color("#3b2a22")

var _munizioni: Label
var _medicine: Label
var _ondata: Label
var _carte: Array[Dictionary] = []
var _annuncio: Label
var _sottotitolo: Label
var _avviso: Label
var _tween_annuncio: Tween
var _tween_avviso: Tween
var _esito: PanelContainer
var _contenuto_esito: VBoxContainer
var _ondate := 2


func _stile(colore: Color, bordo: Color = Color.TRANSPARENT, raggio := 14, margine := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = colore
	if bordo.a > 0.0:
		s.border_color = bordo
		s.set_border_width_all(3)
	s.set_corner_radius_all(raggio)
	s.set_content_margin_all(margine)
	return s


func _etichetta(testo: String, dimensione: int, colore: Color) -> Label:
	var l := Label.new()
	l.text = testo
	l.add_theme_font_size_override("font_size", dimensione)
	l.add_theme_color_override("font_color", colore)
	return l


func _pulsante(testo: String, sfondo: Color, colore_testo: Color, dimensione := 17) -> Button:
	var b := Button.new()
	b.text = testo
	b.add_theme_font_size_override("font_size", dimensione)
	b.add_theme_stylebox_override("normal", _stile(sfondo, Color.TRANSPARENT, 10, 7))
	b.add_theme_stylebox_override("hover", _stile(sfondo.lightened(0.12), Color.TRANSPARENT, 10, 7))
	b.add_theme_stylebox_override("pressed", _stile(sfondo.darkened(0.15), Color.TRANSPARENT, 10, 7))
	b.add_theme_stylebox_override("focus", _stile(sfondo, Color.TRANSPARENT, 10, 7))
	b.add_theme_stylebox_override("disabled", _stile(Color("#4a4452"), Color.TRANSPARENT, 10, 7))
	for chiave in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(chiave, colore_testo)
	b.add_theme_color_override("font_disabled_color", Color("#9a93a3"))
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: Suoni.suona("clic", 0.03))
	return b


func _icona(risorsa: String) -> TextureRect:
	var icona := TextureRect.new()
	icona.texture = load(Bilanciamento.RISORSE[risorsa]["icona"])
	icona.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icona.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icona.custom_minimum_size = Vector2(30, 30)
	return icona


func prepara(membri: Array[Dictionary], difficolta: int, ondate: int, titolo := "ZONA INFESTATA") -> void:
	layer = 10
	_ondate = ondate
	var radice := Control.new()
	radice.set_anchors_preset(Control.PRESET_FULL_RECT)
	radice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(radice)

	# barra in alto
	var barra := PanelContainer.new()
	barra.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var stile := _stile(Color(SCURO, 0.85), Color.TRANSPARENT, 0, 10)
	stile.corner_radius_bottom_left = 16
	stile.corner_radius_bottom_right = 16
	stile.content_margin_left = 20
	stile.content_margin_right = 20
	barra.add_theme_stylebox_override("panel", stile)
	radice.add_child(barra)
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 18)
	barra.add_child(riga)
	riga.add_child(_etichetta("%s  ·  DIFFICOLTÀ %d" % [titolo, difficolta], 18, SENAPE))
	_ondata = _etichetta("", 18, CREMA)
	riga.add_child(_ondata)
	var spazio := Control.new()
	spazio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	riga.add_child(spazio)
	riga.add_child(_icona("munizioni"))
	_munizioni = _etichetta("", 22, CREMA)
	riga.add_child(_munizioni)
	riga.add_child(_icona("medicine"))
	_medicine = _etichetta("", 22, CREMA)
	riga.add_child(_medicine)
	var ritirata := _pulsante("Ritirata", ROSSO, CREMA)
	ritirata.tooltip_text = "Tutta la squadra torna in città: la zona resta infestata"
	ritirata.pressed.connect(func() -> void: ritirata_richiesta.emit())
	riga.add_child(ritirata)

	# carte della squadra in basso
	var fila := HBoxContainer.new()
	fila.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	fila.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fila.grow_vertical = Control.GROW_DIRECTION_BEGIN
	fila.offset_top = -14
	fila.offset_bottom = -14
	fila.add_theme_constant_override("separation", 12)
	radice.add_child(fila)
	for i in membri.size():
		fila.add_child(_crea_carta(i, membri[i]))

	# annunci al centro
	_annuncio = _etichetta("", 46, CREMA)
	_annuncio.add_theme_color_override("font_outline_color", SCURO)
	_annuncio.add_theme_constant_override("outline_size", 14)
	_annuncio.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_annuncio.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_annuncio.offset_top = 150
	_annuncio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_annuncio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radice.add_child(_annuncio)
	_sottotitolo = _etichetta("", 22, SENAPE)
	_sottotitolo.add_theme_color_override("font_outline_color", SCURO)
	_sottotitolo.add_theme_constant_override("outline_size", 10)
	_sottotitolo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_sottotitolo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sottotitolo.offset_top = 214
	_sottotitolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sottotitolo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radice.add_child(_sottotitolo)
	_avviso = _etichetta("", 19, SCURO)
	_avviso.add_theme_stylebox_override("normal", _stile(SENAPE, MARRONE, 14, 10))
	_avviso.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_avviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_avviso.offset_top = 76
	_avviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avviso.modulate.a = 0.0
	radice.add_child(_avviso)

	# esito finale
	_esito = PanelContainer.new()
	_esito.set_anchors_preset(Control.PRESET_CENTER)
	_esito.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_esito.grow_vertical = Control.GROW_DIRECTION_BOTH
	_esito.custom_minimum_size = Vector2(560, 0)
	_esito.add_theme_stylebox_override("panel", _stile(CREMA, MARRONE, 18, 22))
	_esito.visible = false
	radice.add_child(_esito)
	_contenuto_esito = VBoxContainer.new()
	_contenuto_esito.add_theme_constant_override("separation", 10)
	_esito.add_child(_contenuto_esito)


func _crea_carta(indice: int, membro: Dictionary) -> PanelContainer:
	var dati: Dictionary = membro["dati"]
	var carta := PanelContainer.new()
	carta.custom_minimum_size = Vector2(250, 0)
	carta.add_theme_stylebox_override("panel", _stile(Color(SCURO, 0.88), Color("#4a4452"), 14, 10))
	var colonna := VBoxContainer.new()
	colonna.add_theme_constant_override("separation", 5)
	carta.add_child(colonna)
	var nome := _etichetta("%s %s" % [dati["nome"], dati["cognome"]], 17, CREMA)
	colonna.add_child(nome)
	var vita := ProgressBar.new()
	vita.custom_minimum_size = Vector2(0, 14)
	vita.show_percentage = false
	vita.max_value = 1.0
	vita.step = 0.0
	vita.add_theme_stylebox_override("background", _stile(Color("#3a2f3a"), Color.TRANSPARENT, 6, 0))
	var riempimento := _stile(Color("#7fc35a"), Color.TRANSPARENT, 6, 0)
	vita.add_theme_stylebox_override("fill", riempimento)
	colonna.add_child(vita)
	var stato := _etichetta("", 13, Color("#b9b2c2"))
	colonna.add_child(stato)
	var pulsanti := HBoxContainer.new()
	pulsanti.add_theme_constant_override("separation", 6)
	var stat: String = membro["abilita"]
	var abilita := _pulsante(Bilanciamento.ABILITA[stat]["nome"], SENAPE, SCURO, 16)
	abilita.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	abilita.tooltip_text = Bilanciamento.ABILITA[stat]["descrizione"]
	abilita.pressed.connect(func() -> void: abilita_richiesta.emit(indice))
	pulsanti.add_child(abilita)
	var ritira := _pulsante("Ritira", Color("#4a4452"), CREMA, 15)
	ritira.tooltip_text = "Lo rimanda in città prima che sia troppo tardi"
	ritira.pressed.connect(func() -> void: ritira_richiesto.emit(indice))
	pulsanti.add_child(ritira)
	colonna.add_child(pulsanti)
	_carte.append({"carta": carta, "vita": vita, "riempimento": riempimento, "stato": stato,
			"abilita": abilita, "ritira": ritira, "nome_abilita": Bilanciamento.ABILITA[stat]["nome"]})
	return carta


func aggiorna(membri: Array[Dictionary], tempo: float, ondata: int) -> void:
	_munizioni.text = str(StatoGioco.risorse["munizioni"])
	_munizioni.add_theme_color_override("font_color", ROSSO.lightened(0.3) if int(StatoGioco.risorse["munizioni"]) <= 0 else CREMA)
	_medicine.text = str(StatoGioco.risorse["medicine"])
	_ondata.text = "Ondata %d di %d" % [maxi(ondata, 1), _ondate] if ondata > 0 else "In cammino…"
	for i in membri.size():
		var m: Dictionary = membri[i]
		var carta: Dictionary = _carte[i]
		var quota: float = clampf(float(m["vita"]) / float(m["vita_max"]), 0.0, 1.0)
		var vita: ProgressBar = carta["vita"]
		vita.value = quota
		var riempimento: StyleBoxFlat = carta["riempimento"]
		riempimento.bg_color = Color("#7fc35a") if quota > 0.5 else (Color("#e3b448") if quota > 0.25 else Color("#d0453a"))
		var stato: Label = carta["stato"]
		var abilita: Button = carta["abilita"]
		var ritira: Button = carta["ritira"]
		var pannello: PanelContainer = carta["carta"]
		match String(m["stato"]):
			"morto":
				stato.text = "Caduto"
				stato.add_theme_color_override("font_color", ROSSO.lightened(0.3))
				abilita.disabled = true
				ritira.disabled = true
				pannello.modulate = Color(1, 1, 1, 0.55)
			"ritirato":
				stato.text = "In salvo, torna in città"
				abilita.disabled = true
				ritira.disabled = true
				pannello.modulate = Color(1, 1, 1, 0.7)
			_:
				var pronto: float = float(m["abilita_pronta"]) - tempo
				stato.text = "Salute %d%%" % int(round(quota * 100.0))
				if pronto > 0.0:
					abilita.text = "%s  %d s" % [carta["nome_abilita"], ceili(pronto)]
					abilita.disabled = true
				else:
					abilita.text = carta["nome_abilita"]
					abilita.disabled = false


func annuncia(testo: String, sotto := "") -> void:
	_annuncio.text = testo
	_sottotitolo.text = sotto
	if _tween_annuncio:
		_tween_annuncio.kill()
	_annuncio.modulate.a = 1.0
	_sottotitolo.modulate.a = 1.0
	_tween_annuncio = create_tween().set_parallel(true)
	_tween_annuncio.tween_property(_annuncio, "modulate:a", 0.0, 0.8).set_delay(1.8)
	_tween_annuncio.tween_property(_sottotitolo, "modulate:a", 0.0, 0.8).set_delay(2.6)


func avviso(testo: String) -> void:
	_avviso.text = testo
	if _tween_avviso:
		_tween_avviso.kill()
	_avviso.modulate.a = 1.0
	_tween_avviso = create_tween()
	_tween_avviso.tween_interval(1.8)
	_tween_avviso.tween_property(_avviso, "modulate:a", 0.0, 0.5)


func mostra_esito(esito: Dictionary, uccisi: int, feriti_da_curare: int) -> void:
	for figlio in _contenuto_esito.get_children():
		_contenuto_esito.remove_child(figlio)
		figlio.queue_free()
	var vinta: bool = esito["vinta"]
	var difesa: bool = esito.get("tipo", "zona") == "difesa"
	var titolo := ("Città difesa!" if vinta else "Le mura hanno ceduto") if difesa else ("Zona liberata!" if vinta else "Missione fallita")
	_contenuto_esito.add_child(_etichetta(titolo, 30, MARRONE))
	var righe: Array[String] = []
	righe.append("Zombie abbattuti: %d" % uccisi)
	if difesa:
		if vinta:
			var ricompensa: Dictionary = esito["bottino"]
			var pezzi: PackedStringArray = []
			for risorsa in ricompensa:
				if int(ricompensa[risorsa]) > 0:
					pezzi.append("%d %s" % [ricompensa[risorsa], Bilanciamento.RISORSE[risorsa]["nome"].to_lower()])
			if not pezzi.is_empty():
				righe.append("Recuperati dai caduti: " + ", ".join(pezzi))
			righe.append("Esperienza della città: +%d" % esito["esperienza"])
		else:
			for nome in esito["danneggiati"]:
				righe.append("Danneggiato: %s" % nome)
			var perse: Dictionary = esito["perse"]
			for risorsa in perse:
				righe.append("Perse: %d %s" % [perse[risorsa], Bilanciamento.RISORSE[risorsa]["nome"].to_lower()])
	elif vinta:
		righe.append("Il lotto ora è libero: si può costruire")
		var bottino: Dictionary = esito["bottino"]
		var pezzi: PackedStringArray = []
		for risorsa in bottino:
			if int(bottino[risorsa]) > 0:
				pezzi.append("%d %s" % [bottino[risorsa], Bilanciamento.RISORSE[risorsa]["nome"].to_lower()])
		if not pezzi.is_empty():
			righe.append("Bottino: " + ", ".join(pezzi))
		righe.append("Esperienza della città: +%d" % esito["esperienza"])
		if esito["sopravvissuto"]:
			righe.append("Un sopravvissuto vi ha seguito fino al cancello")
	else:
		righe.append("La zona resta infestata. Riprova con una squadra più forte.")
	if difesa and not vinta:
		righe.append("Gli edifici danneggiati non producono finché non li ripari.")
	if int(esito.get("catturati", 0)) > 0:
		righe.append("Barcollanti catturati: %d (curali in Ambulatorio)" % esito["catturati"])
	for nome in esito["morti"]:
		righe.append("Caduto: %s" % nome)
	for ferito in esito["feriti"]:
		righe.append("Ferito: %s (salute %d%%)" % [ferito["nome"], ferito["salute"]])
	for riga in righe:
		var colore := ROSSO if riga.begins_with("Caduto") or riga.begins_with("Danneggiato") or riga.begins_with("Perse") else TESTO
		_contenuto_esito.add_child(_etichetta("•  " + riga, 18, colore))
	if vinta and feriti_da_curare > 0:
		var medicine := int(StatoGioco.risorse["medicine"])
		var cura := _pulsante("Cura i feriti  ·  %d medicine" % mini(feriti_da_curare, medicine), Color("#6fae99"), SCURO, 18)
		cura.disabled = medicine <= 0
		if medicine <= 0:
			cura.text = "Nessuna medicina per curare i feriti"
		cura.pressed.connect(func() -> void: cura_richiesta.emit())
		_contenuto_esito.add_child(cura)
	elif not vinta and not esito["feriti"].is_empty():
		_contenuto_esito.add_child(_etichetta("I feriti guariranno piano piano in città.", 16, RUGGINE))
	var torna := _pulsante("Torna in città", SENAPE, SCURO, 20)
	torna.pressed.connect(func() -> void: torna_richiesto.emit())
	_contenuto_esito.add_child(torna)
	_esito.visible = true
	_esito.call_deferred("reset_size")
