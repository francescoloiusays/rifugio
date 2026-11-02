extends Node3D
## La città in 3D: cielo al tramonto, strada, lotti con i modelli di Blender,
## telecamera laterale che scorre e zooma, tocchi sui lotti.

const FOV := 22.0
const DISTANZA_MIN := 17.0
const DISTANZA_MAX := 44.0
const ALTEZZA_SGUARDO := 2.2      # altezza del punto guardato
const SOGLIA_TOCCO := 14.0        # pixel: sotto è un tocco, sopra un trascinamento
const ATTRITO := 5.0
const ZONE_ESTERNE := 2           # lotti infestati decorativi oltre le mura

const COLORE_SABBIA := Color("#a88a62")
const COLORE_MARCIAPIEDE := Color("#c9b490")
const COLORE_CORDOLO := Color("#9c9184")
const COLORE_ASFALTO := Color("#3f3a46")
const COLORE_STRISCE := Color("#e3b448")
const COLORE_PALAZZI := Color("#3b2a44")

var _camera: Camera3D
var _interfaccia: Interfaccia
var _lotti: Array[Lotto3D] = []
var _fuochi: Array[OmniLight3D] = []
var _selezionato := -1
var _distanza := 27.0
var _x := 6.4
var _x_min := 0.0
var _x_max := 0.0
var _trascinando := false
var _distanza_trascinata := 0.0
var _velocita := 0.0
var _tempo := 0.0
var _figure := {}                      # id cittadino -> FiguraCittadino
var _figura_ospite: FiguraCittadino    # chi aspetta al cancello
var _prossima_passeggiata := 0.0
var _casuale := RandomNumberGenerator.new()

## Chi bussa aspetta fuori, a sinistra del cancello chiuso: entra solo se
## viene accolto, e allora i battenti si aprono.
const PUNTO_CANCELLO := Vector3(-1.9, 0, 9.0)
const PUNTO_FUORI := Vector3(-14.0, 0, 9.2)
const PUNTO_DENTRO := Vector3(2.4, 0, 9.0)
## Il custode sta dentro, accanto al cancello.
const PUNTO_CUSTODE := Vector3(1.5, 0.08, 6.4)
## Le guardie stanno lungo la palizzata, ai due lati del cancello.
const POSTI_GUARDIE := [Vector3(1.7, 0.08, 5.5), Vector3(1.7, 0.08, 12.2), Vector3(2.3, 0.08, 4.6),
		Vector3(1.7, 0.08, 13.0), Vector3(2.3, 0.08, 3.7), Vector3(2.3, 0.08, 12.6), Vector3(1.7, 0.08, 2.8)]


func _ready() -> void:
	Suoni.musica("citta")
	_crea_ambiente()
	_crea_lotti()
	_crea_esterno()
	_crea_suolo()
	_crea_lampioni()
	_crea_skyline()
	_crea_camera()
	_interfaccia = Interfaccia.new()
	add_child(_interfaccia)
	_interfaccia.scheda_chiusa.connect(_deseleziona)
	var guida := Guida.new()
	add_child(guida)
	guida.prepara(self, _interfaccia)
	_interfaccia.costruisci_richiesto.connect(_su_costruisci)
	_interfaccia.accelera_richiesto.connect(_su_accelera)
	StatoGioco.lotto_cambiato.connect(_su_lotto_cambiato)
	StatoGioco.raccolto.connect(_su_raccolto)
	_interfaccia.raccogli_richiesto.connect(_su_raccogli)
	_interfaccia.vai_al_lotto.connect(func(indice: int) -> void:
		vai_a(indice * Lotto3D.LARGHEZZA, _distanza)
		seleziona(indice))
	StatoGioco.cittadini_cambiati.connect(_aggiorna_figure)
	StatoGioco.sopravvissuto_arrivato.connect(_aggiorna_figure)
	StatoGioco.custode_ha_deciso.connect(_su_decisione_custode)
	StatoGioco.attacco_cambiato.connect(_aggiorna_assedio)
	_aggiorna_assedio()
	_casuale.randomize()
	_aggiorna_figure()


# ------------------------------------------------------------------ scena


func _crea_ambiente() -> void:
	var cielo_mat := ProceduralSkyMaterial.new()
	cielo_mat.sky_top_color = Color("#2e2a4a")
	cielo_mat.sky_horizon_color = Color("#e3916a")
	cielo_mat.sky_curve = 0.12
	cielo_mat.ground_horizon_color = Color("#e3916a")
	cielo_mat.ground_bottom_color = Color("#3a2d3c")
	cielo_mat.sun_angle_max = 25.0
	cielo_mat.sun_curve = 0.08
	var cielo := Sky.new()
	cielo.sky_material = cielo_mat

	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_SKY
	ambiente.sky = cielo
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	ambiente.ambient_light_energy = 0.4
	ambiente.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	ambiente.tonemap_exposure = 0.82
	ambiente.adjustment_enabled = true
	ambiente.adjustment_contrast = 1.12
	ambiente.adjustment_saturation = 1.15
	ambiente.glow_enabled = true
	ambiente.glow_intensity = 0.35
	ambiente.glow_hdr_threshold = 1.3
	ambiente.fog_enabled = true
	ambiente.fog_light_color = Color("#6e4a66")
	ambiente.fog_density = 0.0045
	ambiente.fog_sky_affect = 0.0
	var mondo := WorldEnvironment.new()
	mondo.environment = ambiente
	add_child(mondo)

	var sole := DirectionalLight3D.new()
	sole.light_color = Color("#ffcf96")
	sole.light_energy = 1.1
	sole.rotation_degrees = Vector3(-32, -38, 0)
	sole.shadow_enabled = true
	sole.shadow_blur = 1.5
	sole.directional_shadow_max_distance = 70.0
	add_child(sole)


func _materiale(colore: Color, ruvido := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colore
	m.roughness = ruvido
	return m


func _scatola(dim: Vector3, pos: Vector3, colore: Color, ombra := true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dim
	var istanza := MeshInstance3D.new()
	istanza.mesh = mesh
	istanza.material_override = _materiale(colore)
	istanza.position = pos
	if not ombra:
		istanza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(istanza)
	return istanza


func _crea_suolo() -> void:
	var sinistra := _x_min - 40.0
	var destra := _x_max + 40.0
	var larghezza := destra - sinistra
	var centro := (sinistra + destra) / 2.0
	_scatola(Vector3(larghezza + 200.0, 0.2, 120), Vector3(centro, -0.1, -56.8), COLORE_SABBIA, false)
	_scatola(Vector3(larghezza, 0.2, 2.2), Vector3(centro, -0.02, 4.3), COLORE_MARCIAPIEDE, false)
	_scatola(Vector3(larghezza, 0.22, 0.25), Vector3(centro, -0.01, 5.4), COLORE_CORDOLO, false)
	# carreggiata: il cancello delle mura sta al centro (z = 9.2)
	_scatola(Vector3(larghezza, 0.2, 7.6), Vector3(centro, -0.16, 9.2), COLORE_ASFALTO, false)
	var x := sinistra
	while x < destra:
		_scatola(Vector3(2.0, 0.02, 0.22), Vector3(x, -0.05, 9.2), COLORE_STRISCE, false)
		x += 4.5
	# marciapiede e terreno dall'altro lato della strada
	_scatola(Vector3(larghezza, 0.22, 0.25), Vector3(centro, -0.01, 13.05), COLORE_CORDOLO, false)
	_scatola(Vector3(larghezza, 0.2, 1.6), Vector3(centro, -0.02, 13.95), COLORE_MARCIAPIEDE, false)
	_scatola(Vector3(larghezza + 200.0, 0.2, 40), Vector3(centro, -0.1, 34.7), COLORE_SABBIA, false)
	# giunti del marciapiede
	x = sinistra
	while x < destra:
		_scatola(Vector3(0.05, 0.02, 2.2), Vector3(x, 0.085, 4.3), COLORE_CORDOLO, false)
		x += 1.6


func _crea_lotti() -> void:
	for i in StatoGioco.lotti.size():
		var lotto := Lotto3D.new()
		add_child(lotto)
		lotto.prepara(i, StatoGioco.lotti[i])
		_lotti.append(lotto)
		if lotto.chiave_modello() == "bloccato":
			_aggiungi_fuoco(lotto.position)
	_x_min = 0.0
	_x_max = (StatoGioco.lotti.size() - 1) * Lotto3D.LARGHEZZA


## Oltre le mura: zone infestate decorative, sempre più buie.
func _crea_esterno() -> void:
	for k in ZONE_ESTERNE:
		var zona := Lotto3D.new()
		add_child(zona)
		zona.prepara(-(k + 1), {"stato": StatoGioco.BLOCCATO, "difficolta": 6 + k * 2})
		zona.position.z = -0.5
		_aggiungi_fuoco(zona.position)


func _aggiungi_fuoco(origine: Vector3) -> void:
	var luce := OmniLight3D.new()
	luce.light_color = Color("#ff8a2a")
	luce.light_energy = 1.6
	luce.omni_range = 5.0
	luce.position = origine + Vector3(-2.75, 1.5, 1.0)
	add_child(luce)
	_fuochi.append(luce)


func _crea_lampioni() -> void:
	var scena: PackedScene = load("res://assets/modelli/lampione.glb")
	var i := 1
	while i < StatoGioco.lotti.size():
		var stato: String = StatoGioco.lotti[i]["stato"]
		if stato != StatoGioco.BLOCCATO:
			var lampione := scena.instantiate() as Node3D
			lampione.position = Vector3(i * Lotto3D.LARGHEZZA + Lotto3D.LARGHEZZA / 2.0, 0.08, 4.6)
			lampione.rotation_degrees.y = 90.0
			add_child(lampione)
			var luce := OmniLight3D.new()
			luce.light_color = Color("#ffd98a")
			luce.light_energy = 1.2
			luce.omni_range = 6.0
			luce.position = lampione.position + Vector3(0, 3.3, -0.6)
			add_child(luce)
		i += 2


func _crea_skyline() -> void:
	var casuale := RandomNumberGenerator.new()
	casuale.seed = 11
	var materiale_finestre := StandardMaterial3D.new()
	materiale_finestre.albedo_color = Color("#e3b448")
	materiale_finestre.emission_enabled = true
	materiale_finestre.emission = Color("#e3b448")
	materiale_finestre.emission_energy_multiplier = 0.6
	var x := _x_min - 90.0
	while x < _x_max + 90.0:
		var larghezza := casuale.randf_range(7.0, 16.0)
		var altezza := casuale.randf_range(8.0, 24.0)
		var z := casuale.randf_range(-95.0, -75.0)
		var palazzo := _scatola(Vector3(larghezza, altezza, 6.0), Vector3(x, altezza / 2.0, z),
				COLORE_PALAZZI.darkened(casuale.randf_range(0.0, 0.25)))
		palazzo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for _f in casuale.randi_range(0, 5):
			var finestra := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(1.1, 1.4, 0.1)
			finestra.mesh = mesh
			finestra.material_override = materiale_finestre
			finestra.position = Vector3(x + casuale.randf_range(-larghezza / 2.5, larghezza / 2.5),
					casuale.randf_range(2.0, altezza - 1.5), z + 3.05)
			add_child(finestra)
		x += larghezza + casuale.randf_range(0.5, 3.0)


func _crea_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.far = 300.0
	add_child(_camera)
	_camera.make_current()
	_aggiorna_camera()


func _aggiorna_camera() -> void:
	_x = clampf(_x, _x_min + 3.5, _x_max + Lotto3D.LARGHEZZA * 0.6)
	_distanza = clampf(_distanza, DISTANZA_MIN, DISTANZA_MAX)
	var alzo := 0.1 + (_distanza - DISTANZA_MIN) * 0.007
	_camera.position = Vector3(_x, ALTEZZA_SGUARDO + _distanza * alzo, _distanza + 1.0)
	_camera.look_at(Vector3(_x, ALTEZZA_SGUARDO, 1.0))


# ------------------------------------------------------------------ input


func _metri_per_pixel() -> float:
	var altezza_vista := get_viewport().get_visible_rect().size.y
	return 2.0 * _distanza * tan(deg_to_rad(FOV / 2.0)) / altezza_vista


func _process(delta: float) -> void:
	_tempo += delta
	if _luce_allarme != null:
		_luce_allarme.light_energy = 2.0 + 1.5 * sin(_tempo * 6.0)
	for zombie in _assedianti:
		if is_instance_valid(zombie):
			zombie.attacca = true
	_passeggiate()
	if not _trascinando and absf(_velocita) > 0.05:
		_x += _velocita * delta
		_velocita *= exp(-ATTRITO * delta)
		_aggiorna_camera()
	for i in _fuochi.size():
		_fuochi[i].light_energy = 1.4 + 0.35 * sin(_tempo * 9.0 + i * 1.7) + 0.2 * sin(_tempo * 23.0 + i)


## Dita appoggiate sullo schermo (indice -> posizione), per lo zoom col pizzico.
var _dita := {}
var _distanza_dita := 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var tocco := event as InputEventScreenTouch
		if tocco.pressed:
			_dita[tocco.index] = tocco.position
		else:
			_dita.erase(tocco.index)
		if _dita.size() >= 2:
			# con due dita non si trascina e non si tocca: si zooma
			_trascinando = false
			_distanza_trascinata = 9999.0
			_velocita = 0.0
			_distanza_dita = _distanza_tra_le_dita()
		return
	if event is InputEventScreenDrag:
		var trascina := event as InputEventScreenDrag
		_dita[trascina.index] = trascina.position
		if _dita.size() >= 2:
			var nuova := _distanza_tra_le_dita()
			if _distanza_dita > 10.0 and nuova > 10.0:
				_distanza *= _distanza_dita / nuova
				_aggiorna_camera()
			_distanza_dita = nuova
		return
	if _dita.size() >= 2:
		return
	if event is InputEventMouseButton:
		var pulsante := event as InputEventMouseButton
		match pulsante.button_index:
			MOUSE_BUTTON_LEFT:
				if pulsante.pressed:
					_trascinando = true
					_distanza_trascinata = 0.0
					_velocita = 0.0
				else:
					# Conta solo un tocco cominciato sulla città: se il dito si è
					# appoggiato su un pulsante (che magari nel frattempo è sparito
					# perché la scheda si è rifatta), il rilascio non deve finire
					# sugli edifici dietro e chiudere la scheda.
					var cominciato_qui := _trascinando
					_trascinando = false
					if cominciato_qui and _distanza_trascinata < SOGLIA_TOCCO:
						_tocca(pulsante.position)
			MOUSE_BUTTON_WHEEL_UP:
				if pulsante.pressed:
					_distanza -= 1.6
					_aggiorna_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				if pulsante.pressed:
					_distanza += 1.6
					_aggiorna_camera()
			MOUSE_BUTTON_WHEEL_LEFT:
				if pulsante.pressed:
					_x -= 1.0
					_aggiorna_camera()
			MOUSE_BUTTON_WHEEL_RIGHT:
				if pulsante.pressed:
					_x += 1.0
					_aggiorna_camera()
	elif event is InputEventMouseMotion and _trascinando:
		var movimento := event as InputEventMouseMotion
		_distanza_trascinata += movimento.relative.length()
		var spostamento := -movimento.relative.x * _metri_per_pixel()
		_x += spostamento
		_aggiorna_camera()
		var dt := maxf(get_process_delta_time(), 0.001)
		_velocita = clampf(lerpf(_velocita, spostamento / dt, 0.5), -60.0, 60.0)
		if _distanza_trascinata >= SOGLIA_TOCCO:
			_interfaccia.nascondi_suggerimento()
	elif event is InputEventMagnifyGesture:
		var gesto := event as InputEventMagnifyGesture
		_distanza /= gesto.factor
		_aggiorna_camera()
	elif event is InputEventPanGesture:
		var pan := event as InputEventPanGesture
		_x += pan.delta.x * 0.4
		_aggiorna_camera()


func _distanza_tra_le_dita() -> float:
	var punti := _dita.values()
	return (punti[0] as Vector2).distance_to(punti[1] as Vector2)


func _tocca(posizione_schermo: Vector2) -> void:
	var origine := _camera.project_ray_origin(posizione_schermo)
	var direzione := _camera.project_ray_normal(posizione_schermo)
	# Piano verticale delle facciate.
	var piano := Plane(Vector3(0, 0, 1), 1.5)
	var punto = piano.intersects_ray(origine, direzione)
	if punto == null or punto.y < -0.5 or punto.y > 8.0:
		_interfaccia.chiudi_scheda()
		return
	var indice := int(floor((punto.x + Lotto3D.LARGHEZZA / 2.0) / Lotto3D.LARGHEZZA))
	if indice < 0 or indice >= _lotti.size():
		_interfaccia.chiudi_scheda()
		return
	# Se l'edificio ha qualcosa da raccogliere, il tocco raccoglie;
	# un secondo tocco apre la scheda.
	if _lotti[indice].ha_produzione_pronta() and StatoGioco.raccogli(indice) > 0:
		return
	seleziona(indice)


func seleziona(indice: int) -> void:
	if _selezionato >= 0:
		_lotti[_selezionato].imposta_selezione(false)
	_selezionato = indice
	_lotti[indice].imposta_selezione(true)
	_lotti[indice].rimbalza()
	_interfaccia.mostra_lotto(indice)


func _deseleziona() -> void:
	if _selezionato >= 0:
		_lotti[_selezionato].imposta_selezione(false)
	_selezionato = -1


# ------------------------------------------------------------------ costruzione


func _su_costruisci(id: String) -> void:
	if _selezionato >= 0:
		StatoGioco.costruisci(_selezionato, id)


func _su_raccogli() -> void:
	if _selezionato >= 0:
		StatoGioco.raccogli(_selezionato)


func _su_raccolto(indice: int, risorsa: String, quantita: int) -> void:
	_lotti[indice].mostra_guadagno(risorsa, quantita)


func _su_accelera() -> void:
	if _selezionato >= 0:
		StatoGioco.accelera(_selezionato)


## Un lotto ha cambiato stato: sostituisce il suo modello con una piccola animazione.
func _su_lotto_cambiato(indice: int) -> void:
	var vecchio := _lotti[indice]
	var nuovo := Lotto3D.new()
	add_child(nuovo)
	nuovo.prepara(indice, StatoGioco.lotti[indice])
	nuovo.compari()
	_lotti[indice] = nuovo
	vecchio.queue_free()
	if indice == _selezionato:
		nuovo.imposta_selezione(true)
		_interfaccia.mostra_lotto(indice)


# ------------------------------------------------------------------ cittadini in 3D


func _ultimo_lotto_della_citta() -> int:
	var ultimo := 0
	for i in StatoGioco.lotti.size():
		if StatoGioco.lotti[i]["stato"] != StatoGioco.BLOCCATO:
			ultimo = i
	return ultimo


func _punto_sul_marciapiede() -> Vector3:
	var x_max := _ultimo_lotto_della_citta() * Lotto3D.LARGHEZZA + 2.0
	return Vector3(_casuale.randf_range(2.5, x_max), 0.08, _casuale.randf_range(4.1, 5.0))


## Dove deve stare un lavoratore: davanti al suo edificio, uno accanto all'altro.
func _posto_di_lavoro(cittadino: Dictionary) -> Vector3:
	var indice: int = cittadino["lavoro"]
	var squadra := StatoGioco.lavoratori(indice)
	var posizione := 0
	for k in squadra.size():
		if squadra[k]["id"] == cittadino["id"]:
			posizione = k
	if indice == 0:
		# Le guardie stanno lungo la palizzata, lasciando libero il cancello.
		return POSTI_GUARDIE[posizione % POSTI_GUARDIE.size()]
	var scarto := (posizione - (squadra.size() - 1) / 2.0) * 0.9
	return Vector3(indice * Lotto3D.LARGHEZZA + 1.6 + scarto, 0.08, 3.75)


func _aggiorna_figure() -> void:
	var presenti := {}
	for c in StatoGioco.cittadini:
		presenti[c["id"]] = true
		var figura: FiguraCittadino = _figure.get(c["id"])
		if figura == null:
			if _figura_ospite != null and _figura_ospite.dati["id"] == c["id"]:
				# Il sopravvissuto accolto: il cancello si apre, entra e si richiude.
				figura = _figura_ospite
				figura.mostra_bolla("")
				_figura_ospite = null
				_fai_entrare(figura, c)
			else:
				figura = FiguraCittadino.new()
				add_child(figura)
				var partenza := _posto_di_lavoro(c) if c["lavoro"] >= 0 else _punto_sul_marciapiede()
				figura.prepara(c, partenza)
			_figure[c["id"]] = figura
		figura.dati = c
		if figura.ha_tappe():
			pass   # sta ancora attraversando il cancello
		elif c["id"] == StatoGioco.custode:
			figura.vai_a(PUNTO_CUSTODE)
		elif c["lavoro"] >= 0:
			figura.vai_a(_posto_di_lavoro(c))
		elif figura.position.z < 4.0 or figura.position.x < 2.0:
			figura.vai_a(_punto_sul_marciapiede())
	for id in _figure.keys():
		if not presenti.has(id):
			_figure[id].queue_free()
			_figure.erase(id)
	# Sopravvissuto al cancello
	var ospite := StatoGioco.sopravvissuto
	if not ospite.is_empty() and _figura_ospite == null:
		_figura_ospite = FiguraCittadino.new()
		add_child(_figura_ospite)
		_figura_ospite.prepara(ospite, PUNTO_FUORI)
		_figura_ospite.vai_a(PUNTO_CANCELLO)
		_figura_ospite.mostra_bolla("!")
	elif ospite.is_empty() and _figura_ospite != null:
		# Mandato via: se ne torna da dove è venuto.
		var uscente := _figura_ospite
		_figura_ospite = null
		uscente.mostra_bolla("")
		uscente.vai_a(PUNTO_FUORI)
		get_tree().create_timer(6.0).timeout.connect(uscente.queue_free)


## I cittadini senza lavoro passeggiano sul marciapiede.
func _passeggiate() -> void:
	if _tempo < _prossima_passeggiata:
		return
	_prossima_passeggiata = _tempo + 1.5
	for c in StatoGioco.cittadini:
		if c["lavoro"] >= 0 or c["id"] == StatoGioco.custode:
			continue
		var figura: FiguraCittadino = _figure.get(c["id"])
		if figura != null and figura.ha_tappe():
			continue
		if figura != null and not figura.in_cammino() and _casuale.randf() < 0.35:
			figura.vai_a(_punto_sul_marciapiede())


## Il sopravvissuto accolto: si aprono i battenti, attraversa il cancello,
## poi va al suo posto e il cancello si richiude alle sue spalle.
func _fai_entrare(figura: FiguraCittadino, c: Dictionary) -> void:
	var mura := _lotti[0]
	mura.apri_cancello(true)
	var arrivo := _posto_di_lavoro(c) if c["lavoro"] >= 0 else _punto_sul_marciapiede()
	figura.percorri([PUNTO_CANCELLO + Vector3(0.3, 0, 0), PUNTO_DENTRO, arrivo], 0.7)
	get_tree().create_timer(4.2).timeout.connect(func() -> void:
		if is_instance_valid(mura):
			mura.apri_cancello(false))


## Il custode ha deciso: un cenno con la testa (o un no) sopra di lui.
func _su_decisione_custode(accolto: bool) -> void:
	var figura: FiguraCittadino = _figure.get(StatoGioco.custode)
	if figura == null:
		return
	figura.mostra_bolla("✓" if accolto else "✗")
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if is_instance_valid(figura):
			figura.mostra_bolla(""))


## Durante un attacco gli zombie premono contro il cancello, fuori dalle mura.
var _assedianti: Array[FiguraZombie] = []
var _luce_allarme: OmniLight3D


func _aggiorna_assedio() -> void:
	if StatoGioco.attacco_pronto and _assedianti.is_empty():
		var tipi := ["barcollante", "barcollante", "corridore", "barcollante", "esplosivo", "barcollante", "corazzato"]
		for k in 7:
			var zombie := FiguraZombie.new()
			add_child(zombie)
			var tipo: String = tipi[k]
			if int(Bilanciamento.ZOMBIE[tipo]["da_difficolta"]) > StatoGioco.difficolta_attacco():
				tipo = "barcollante"
			zombie.prepara(tipo, 1.0, Vector3(-2.2 - k * 0.9 - _casuale.randf() * 0.6, 0.0, 7.8 + _casuale.randf_range(0.0, 2.6)), _casuale)
			zombie.rotation.y = PI / 2.0   # verso il cancello, cioè verso destra
			zombie.cammina = true
			_assedianti.append(zombie)
		_luce_allarme = OmniLight3D.new()
		_luce_allarme.light_color = Color("#ff5a3c")
		_luce_allarme.omni_range = 9.0
		_luce_allarme.position = Vector3(-1.5, 4.0, 8.5)
		add_child(_luce_allarme)
	elif not StatoGioco.attacco_pronto and not _assedianti.is_empty():
		for zombie in _assedianti:
			if is_instance_valid(zombie):
				zombie.queue_free()
		_assedianti.clear()
		if _luce_allarme != null:
			_luce_allarme.queue_free()
			_luce_allarme = null


## Usato dalle prove automatiche per posizionare la vista.
func vai_a(x: float, distanza: float) -> void:
	_x = x
	_distanza = distanza
	_aggiorna_camera()
