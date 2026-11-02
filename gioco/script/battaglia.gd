extends Node3D
## La battaglia fuori dalle mura. La squadra avanza verso destra nel buio,
## gli zombie arrivano a ondate e si colpiscono toccandoli.

const DISTANZA_COMPARSA := 16.0
const PRIMO_PASSO := 4.0
const PASSO_TRA_ONDATE := 7.0
const VELOCITA_SQUADRA := 2.2
const DISTANZA_CONTATTO := 0.9
const SPAZIO_IN_FILA := 1.15
const RAGGIO_TOCCO := 85.0
const INTERVALLO_COMPARSE := 1.5

const COLORE_SFONDO := Color("#8c8a94")
const COLORE_TERRENO := Color("#15131a")
const COLORE_SAGOME := Color("#1a1820")

var _camera: Camera3D
var _hud: BattagliaHud
var _lanterna: OmniLight3D
var _cenere: CPUParticles3D
var _membri: Array[Dictionary] = []
var _zombie: Array[FiguraZombie] = []
var _da_generare: Array[String] = []
var _prossima_comparsa := 0.0
var _difficolta := 1
var _ondata := 0
var _ondate := 2
var _fronte := 0.0
var _meta := PRIMO_PASSO
var _stato := "cammina"
var _tempo := 0.0
var _uccisi := 0
var _camera_x := 5.0
var _scossa := 0.0
var _esito: Dictionary = {}
var _fuochi: Array[OmniLight3D] = []
var _casuale := RandomNumberGenerator.new()
var _materiale_sagome: StandardMaterial3D
## "zona" = liberare un lotto, "difesa" = respingere un attacco alle mura.
var _tipo := "zona"
var _riprendi_alle := 0.0
var _torrette: Array[Dictionary] = []
var _catturati := 0
const X_MURA := -3.8


func _ready() -> void:
	_casuale.randomize()
	Suoni.musica("battaglia")
	if StatoGioco.missione.is_empty():
		# Avviata da sola (per le prove): prima zona e primi tre cittadini.
		var ids: Array[String] = []
		for c in StatoGioco.cittadini:
			if ids.size() < 3:
				ids.append(c["id"])
		StatoGioco.prepara_missione(StatoGioco.lotto_da_liberare(), ids)
	_difficolta = int(StatoGioco.missione["difficolta"])
	_tipo = String(StatoGioco.missione.get("tipo", "zona"))
	_ondate = Bilanciamento.ondate_missione(_difficolta)
	if _tipo == "difesa":
		_ondate = Bilanciamento.ONDATE_ATTACCO
		_meta = 0.0
		_stato = "pausa"
		_riprendi_alle = 2.5
	_crea_ambiente()
	_crea_scenario()
	_crea_squadra()
	_crea_camera()
	_hud = BattagliaHud.new()
	add_child(_hud)
	var titolo := "DIFESA DELLE MURA" if _tipo == "difesa" else "ZONA INFESTATA"
	_hud.prepara(_membri, _difficolta, _ondate, titolo)
	_hud.abilita_richiesta.connect(_usa_abilita)
	_hud.ritira_richiesto.connect(func(i: int) -> void: _ritira(i))
	_hud.ritirata_richiesta.connect(_ritirata_generale)
	_hud.cura_richiesta.connect(_cura)
	_hud.torna_richiesto.connect(_torna)
	StatoGioco.notifica.connect(_hud.avviso)
	if _tipo == "difesa":
		_hud.annuncia("Gli zombie attaccano le mura!", "La squadra spara da sola: tocca per sparare più in fretta")
	else:
		_hud.annuncia("Fuori dalle mura", "La squadra spara da sola: tocca per sparare più in fretta")


# ------------------------------------------------------------------ ambiente


func _crea_ambiente() -> void:
	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = COLORE_SFONDO
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color("#77748a")
	ambiente.ambient_light_energy = 0.45
	ambiente.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	ambiente.glow_enabled = true
	ambiente.glow_intensity = 0.5
	ambiente.glow_hdr_threshold = 1.1
	# Nebbia solo da lontano: il primo piano resta nero e netto, gli strati
	# lontani sbiadiscono nel grigio, come in Limbo e Inside.
	ambiente.fog_enabled = true
	ambiente.fog_mode = Environment.FOG_MODE_DEPTH
	ambiente.fog_light_color = COLORE_SFONDO
	ambiente.fog_density = 1.0
	ambiente.fog_depth_begin = 17.0
	ambiente.fog_depth_end = 70.0
	ambiente.fog_depth_curve = 0.8
	var mondo := WorldEnvironment.new()
	mondo.environment = ambiente
	add_child(mondo)

	var luna := DirectionalLight3D.new()
	luna.light_color = Color("#b9c4dd")
	luna.light_energy = 0.45
	luna.rotation_degrees = Vector3(-40, 30, 0)
	add_child(luna)

	_lanterna = OmniLight3D.new()
	_lanterna.light_color = Color("#ffc77a")
	_lanterna.light_energy = 1.8
	_lanterna.omni_range = 6.5
	add_child(_lanterna)

	# cenere che cade lentamente
	_cenere = CPUParticles3D.new()
	_cenere.amount = 140
	_cenere.lifetime = 9.0
	_cenere.preprocess = 9.0
	_cenere.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_cenere.emission_box_extents = Vector3(16, 0.5, 6)
	_cenere.direction = Vector3(-0.3, -1, 0)
	_cenere.spread = 20.0
	_cenere.initial_velocity_min = 0.3
	_cenere.initial_velocity_max = 0.7
	_cenere.gravity = Vector3(0, -0.15, 0)
	var granello := QuadMesh.new()
	granello.size = Vector2(0.05, 0.05)
	var materiale_cenere := StandardMaterial3D.new()
	materiale_cenere.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materiale_cenere.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	materiale_cenere.albedo_color = Color("#c9c5d1")
	materiale_cenere.disable_fog = true
	granello.material = materiale_cenere
	_cenere.mesh = granello
	add_child(_cenere)


func _sagoma() -> StandardMaterial3D:
	if _materiale_sagome == null:
		_materiale_sagome = StandardMaterial3D.new()
		_materiale_sagome.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materiale_sagome.albedo_color = COLORE_SAGOME
	return _materiale_sagome


func _pezzo(forma: Mesh, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = forma
	m.material_override = _sagoma()
	m.position = pos
	m.rotation_degrees = rot
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


func _scatola(dim: Vector3, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var forma := BoxMesh.new()
	forma.size = dim
	return _pezzo(forma, pos, rot)


func _cilindro(r_basso: float, r_alto: float, h: float, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var forma := CylinderMesh.new()
	forma.bottom_radius = r_basso
	forma.top_radius = r_alto
	forma.height = h
	forma.radial_segments = 8
	return _pezzo(forma, pos, rot)


func _albero(x: float, z: float, h: float) -> void:
	_cilindro(0.22 * h / 6.0, 0.08, h, Vector3(x, h / 2.0, z), Vector3(0, 0, _casuale.randf_range(-6, 6)))
	for k in _casuale.randi_range(2, 4):
		var altezza := h * _casuale.randf_range(0.45, 0.9)
		var lato := -1.0 if k % 2 == 0 else 1.0
		var lunghezza := h * _casuale.randf_range(0.25, 0.45)
		_cilindro(0.06, 0.02, lunghezza, Vector3(x + lato * lunghezza * 0.35, altezza, z), Vector3(0, 0, -lato * _casuale.randf_range(35, 60)))


func _rovina(x: float, z: float) -> void:
	var larghezza := _casuale.randf_range(3.0, 7.0)
	var altezza := _casuale.randf_range(4.0, 12.0)
	_scatola(Vector3(larghezza, altezza, 2.0), Vector3(x, altezza / 2.0, z))
	# cima spezzata
	_scatola(Vector3(larghezza * 0.6, 1.5, 2.0), Vector3(x - larghezza * 0.2, altezza + 0.4, z), Vector3(0, 0, _casuale.randf_range(-25, 25)))


## Il terreno, sagome a più profondità che la nebbia schiarisce e la zona
## infestata in fondo, nello stile di Limbo e Inside.
func _crea_scenario() -> void:
	var fine := PRIMO_PASSO + PASSO_TRA_ONDATE * (_ondate - 1)
	_scatola(Vector3(240, 2.0, 60), Vector3(40, -1.0, -10))
	# piani di profondità: vicino scuro, lontano quasi grigio
	for strato in [{"z": -5.0, "passo": 9.0}, {"z": -13.0, "passo": 7.0}, {"z": -26.0, "passo": 10.0}, {"z": -45.0, "passo": 14.0}]:
		var x := -30.0
		while x < fine + 60.0:
			if _casuale.randf() < 0.55:
				_albero(x, strato["z"], _casuale.randf_range(4.0, 8.5))
			else:
				_rovina(x, strato["z"] - 1.0)
			x += float(strato["passo"]) * _casuale.randf_range(0.7, 1.4)
	# ciuffi d'erba e sassi in primo piano
	var x2 := -20.0
	while x2 < fine + 40.0:
		_cilindro(0.18, 0.0, _casuale.randf_range(0.3, 0.7), Vector3(x2, 0.2, _casuale.randf_range(2.0, 4.0)))
		x2 += _casuale.randf_range(1.5, 4.0)
	# recinzione caduta lungo il percorso
	var x3 := 2.0
	while x3 < fine + 20.0:
		_scatola(Vector3(0.12, 1.4, 0.12), Vector3(x3, 0.6, -1.8), Vector3(0, 0, _casuale.randf_range(-15, 15)))
		x3 += 2.5
	if _tipo == "difesa":
		_crea_mura()
		return
	# la zona da liberare, con l'auto distrutta e il bidone in fiamme
	var zona: PackedScene = load("res://assets/modelli/lotto_bloccato.glb")
	if zona != null:
		var modello := zona.instantiate() as Node3D
		modello.position = Vector3(fine + 9.0, 0, -4.5)
		add_child(modello)
		_spegni_bagliori(modello)
		var fuoco := OmniLight3D.new()
		fuoco.light_color = Color("#ff8a2a")
		fuoco.light_energy = 2.0
		fuoco.omni_range = 5.0
		fuoco.position = modello.position + Vector3(-2.75, 1.5, -1.0)
		add_child(fuoco)
		_fuochi.append(fuoco)


## Il fuoco del modello di Blender è troppo forte in questa luce: lo attenua.
func _spegni_bagliori(nodo: Node) -> void:
	var istanza := nodo as MeshInstance3D
	if istanza != null and istanza.mesh != null:
		for superficie in istanza.mesh.get_surface_count():
			var materiale := istanza.get_active_material(superficie) as BaseMaterial3D
			if materiale != null and materiale.emission_enabled:
				var morbido := materiale.duplicate() as BaseMaterial3D
				morbido.emission_energy_multiplier = minf(materiale.emission_energy_multiplier, 1.2)
				istanza.set_surface_override_material(superficie, morbido)
	for figlio in nodo.get_children():
		_spegni_bagliori(figlio)


## In difesa la palizzata della città sta alle spalle della squadra, con la
## luce calda della città dietro e le torrette sopra.
func _crea_mura() -> void:
	var scena: PackedScene = load("res://assets/modelli/mura_l%d.glb" % StatoGioco.livello_mura())
	if scena != null:
		var mura := scena.instantiate() as Node3D
		mura.rotation_degrees.y = -90.0
		mura.position = Vector3(X_MURA, 0, -6.0)
		add_child(mura)
		_spegni_bagliori(mura)
	var citta := OmniLight3D.new()
	citta.light_color = Color("#ffb46b")
	citta.light_energy = 2.5
	citta.omni_range = 12.0
	citta.position = Vector3(X_MURA - 4.0, 4.0, 1.0)
	add_child(citta)
	var torretta_materiale := StandardMaterial3D.new()
	torretta_materiale.albedo_color = Color("#3c3c46")
	torretta_materiale.metallic = 0.5
	for k in StatoGioco.torrette():
		var base := MeshInstance3D.new()
		var forma := BoxMesh.new()
		forma.size = Vector3(0.7, 0.5, 0.7)
		base.mesh = forma
		base.material_override = torretta_materiale
		var posizione := Vector3(X_MURA + 0.3, 4.35, -1.0 - k * 1.6)
		base.position = posizione
		add_child(base)
		var canna := MeshInstance3D.new()
		var forma_canna := CylinderMesh.new()
		forma_canna.top_radius = 0.08
		forma_canna.bottom_radius = 0.1
		forma_canna.height = 0.9
		canna.mesh = forma_canna
		canna.material_override = torretta_materiale
		canna.rotation_degrees = Vector3(0, 0, -90)
		canna.position = posizione + Vector3(0.6, 0.1, 0)
		add_child(canna)
		_torrette.append({"bocca": posizione + Vector3(1.05, 0.1, 0), "pronta": 3.0 + k * 0.4})


## Le torrette sparano da sole allo zombie più vicino, senza munizioni.
func _spara_torrette() -> void:
	for torretta in _torrette:
		if _tempo < float(torretta["pronta"]):
			continue
		var bersaglio := _zombie_piu_vicino()
		if bersaglio == null or bersaglio.position.x - _fronte > 14.0:
			continue
		torretta["pronta"] = _tempo + Bilanciamento.CADENZA_TORRETTA
		_traccia(torretta["bocca"], bersaglio.global_position + Vector3(0, 1.0 * bersaglio.scala, 0))
		_colpisci_zombie(bersaglio, Bilanciamento.DANNO_TORRETTA)


func _crea_squadra() -> void:
	for id in StatoGioco.missione["squadra"]:
		var c := StatoGioco.trova_cittadino(id)
		if c.is_empty():
			continue
		var vita_max := Bilanciamento.vita_cittadino(c)
		var figura := FiguraCittadino.new()
		add_child(figura)
		figura.prepara(c, Vector3(_fronte - 3.0 - _membri.size() * SPAZIO_IN_FILA, 0, 0))
		figura.imbraccia_arma()
		figura.rotation.y = PI / 2.0
		_membri.append({
			"id": id,
			"dati": c,
			"figura": figura,
			"vita": vita_max * maxf(0.15, float(c.get("salute", 100.0)) / 100.0),
			"vita_max": vita_max,
			"pronto": 0.0,
			"abilita": Bilanciamento.statistica_abilita(c),
			"abilita_pronta": 3.0,
			"stato": "in_campo",
			"ultimo_colpo": -10.0,
		})


func _crea_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.far = 200.0
	add_child(_camera)
	_camera.make_current()
	_aggiorna_camera(1.0)


func _aggiorna_camera(delta: float) -> void:
	var obiettivo := _fronte + (4.0 if _tipo == "difesa" else 5.0)
	_camera_x = lerpf(_camera_x, obiettivo, minf(1.0, delta * 2.5))
	var tremolio := Vector3.ZERO
	if _scossa > 0.0:
		_scossa = maxf(0.0, _scossa - delta)
		tremolio = Vector3(_casuale.randf_range(-1, 1), _casuale.randf_range(-1, 1), 0) * _scossa * 0.4
	_camera.position = Vector3(_camera_x, 2.6, 14.0) + tremolio
	_camera.look_at(Vector3(_camera_x, 1.5, 0.0) + tremolio)
	_lanterna.position = Vector3(_fronte - 0.6, 2.6, 1.8)
	_cenere.position = Vector3(_camera_x, 9.0, 0.0)


# ------------------------------------------------------------------ svolgimento


func _process(delta: float) -> void:
	_tempo += delta
	match _stato:
		"cammina":
			_fronte = move_toward(_fronte, _meta, VELOCITA_SQUADRA * delta)
			if is_equal_approx(_fronte, _meta):
				_inizia_ondata()
		"combatte":
			_combatti()
			_spara_torrette()
			_tiro_automatico()
		"pausa":
			if _tempo >= _riprendi_alle:
				_inizia_ondata()
	_disponi_squadra()
	_aggiorna_zombie(delta)
	_aggiorna_camera(delta)
	for i in _fuochi.size():
		_fuochi[i].light_energy = 1.8 + 0.4 * sin(_tempo * 9.0 + i) + 0.2 * sin(_tempo * 23.0)
	_hud.aggiorna(_membri, _tempo, _ondata)


func _inizia_ondata() -> void:
	_ondata += 1
	_stato = "combatte"
	var ammessi := {}
	for tipo in Bilanciamento.PESI_ZOMBIE:
		if int(Bilanciamento.ZOMBIE[tipo]["da_difficolta"]) <= _difficolta:
			ammessi[tipo] = Bilanciamento.PESI_ZOMBIE[tipo]
	var totale := 0
	for tipo in ammessi:
		totale += int(ammessi[tipo])
	_da_generare.clear()
	var quanti := Bilanciamento.zombie_per_ondata(_difficolta) if _tipo == "difesa" else Bilanciamento.zombie_per_ondata_missione(_difficolta)
	for k in quanti:
		var estratto := _casuale.randi_range(1, totale)
		for tipo in ammessi:
			estratto -= int(ammessi[tipo])
			if estratto <= 0:
				_da_generare.append(tipo)
				break
	if _ondata == _ondate and _difficolta >= int(Bilanciamento.ZOMBIE["colosso"]["da_difficolta"]):
		_da_generare.append("colosso")
	_prossima_comparsa = _tempo + 1.0
	_hud.annuncia("Ondata %d di %d" % [_ondata, _ondate], "Arrivano %d zombie" % _da_generare.size())


func _combatti() -> void:
	if not _da_generare.is_empty() and _tempo >= _prossima_comparsa:
		var tipo: String = _da_generare.pop_front()
		var zombie := FiguraZombie.new()
		add_child(zombie)
		var profondita := _casuale.randf_range(-0.9, 0.7)
		zombie.prepara(tipo, Bilanciamento.moltiplicatore_zombie(_difficolta),
				Vector3(_fronte + DISTANZA_COMPARSA + _casuale.randf_range(0, 2), 0, profondita), _casuale)
		_zombie.append(zombie)
		if _casuale.randf() < 0.45:
			Suoni.suona("zombie_%d" % _casuale.randi_range(1, 3), 0.12)
		var intervallo := INTERVALLO_COMPARSE * (0.5 if tipo == "corridore" else 1.0)
		_prossima_comparsa = _tempo + intervallo * _casuale.randf_range(0.7, 1.3)
	_zombie.assign(_zombie.filter(func(z: FiguraZombie) -> bool: return is_instance_valid(z) and not z.morto))
	if _da_generare.is_empty() and _zombie.is_empty():
		if _ondata < _ondate and _tipo == "difesa":
			_riprendi_alle = _tempo + 4.0
			_stato = "pausa"
			_hud.annuncia("Ondata respinta", "Ne arrivano altri…")
		elif _ondata < _ondate:
			_meta = _fronte + PASSO_TRA_ONDATE
			_stato = "cammina"
			_hud.annuncia("Ondata respinta", "Avanti!")
		else:
			_fine(true)


func _in_campo() -> Array[Dictionary]:
	var elenco: Array[Dictionary] = []
	for m in _membri:
		if m["stato"] == "in_campo":
			elenco.append(m)
	return elenco


func _disponi_squadra() -> void:
	var k := 0
	for m in _membri:
		if m["stato"] != "in_campo":
			continue
		var figura: FiguraCittadino = m["figura"]
		figura.vai_a(Vector3(_fronte - k * SPAZIO_IN_FILA, 0, 0.15 * (k % 2)))
		if not figura.in_cammino():
			figura.rotation.y = lerp_angle(figura.rotation.y, PI / 2.0, 0.2)
		k += 1


func _aggiorna_zombie(delta: float) -> void:
	for z in _zombie:
		if not is_instance_valid(z) or z.morto:
			continue
		if z.a_terra:
			if _tempo >= z.a_terra_fino or _stato == "fine":
				z.muori()
				_uccisi += 1
			continue
		var stordito := _tempo < z.stordito_fino
		z.imposta_stordito(stordito)
		if stordito:
			z.cammina = false
			continue
		var contatto := _fronte + DISTANZA_CONTATTO + z.raggio
		if z.position.x > contatto + 0.02:
			z.position.x = maxf(contatto, z.position.x - z.velocita * delta)
			z.cammina = true
			continue
		z.cammina = false
		if _stato == "fine" or _in_campo().is_empty():
			continue
		if z.tipo == "esplosivo":
			_esplosione(z, true)
			continue
		z.attacca = true
		_ferisci(_in_campo()[0], z.danno * delta / _protezione_mura())


## In difesa la squadra combatte a ridosso delle mura: più sono robuste,
## meno male fanno gli zombie.
func _protezione_mura() -> float:
	if _tipo != "difesa":
		return 1.0
	return float(Bilanciamento.MURA_LIVELLI[StatoGioco.livello_mura() - 1]["difesa"])


func _ferisci(m: Dictionary, danno: float) -> void:
	if m["stato"] != "in_campo":
		return
	m["vita"] = float(m["vita"]) - danno
	var figura: FiguraCittadino = m["figura"]
	if _tempo - float(m["ultimo_colpo"]) > 0.35:
		m["ultimo_colpo"] = _tempo
		figura.ferito()
	var dati: Dictionary = m["dati"]
	if float(m["vita"]) <= 0.0:
		m["vita"] = 0.0
		m["stato"] = "morto"
		figura.cadi()
		_hud.avviso("%s è caduto" % dati["nome"])
		_controlla_squadra()
	elif dati["tratto"] == "codardo" and float(m["vita"]) < 0.3 * float(m["vita_max"]):
		_ritira(_membri.find(m), "%s scappa terrorizzato!" % dati["nome"])


func _controlla_squadra() -> void:
	if _stato != "fine" and _in_campo().is_empty():
		_fine(false)


## Un esplosivo che arriva addosso alla squadra (o muore vicino) scoppia:
## ferisce tutti e colpisce anche gli zombie attorno.
func _esplosione(z: FiguraZombie, colpisce_squadra: bool) -> void:
	if z.morto:
		return
	var centro := z.global_position + Vector3(0, 0.8, 0)
	# prima di tutto è morto: così due esplosivi vicini non scoppiano all'infinito
	z.muori(true)
	_uccisi += 1
	Suoni.suona("esplosione")
	if colpisce_squadra:
		for m in _in_campo():
			_ferisci(m, z.danno)
		_scossa = 0.45
	for altro in _zombie:
		if is_instance_valid(altro) and altro != z and not altro.morto and altro.position.distance_to(z.position) < 2.5:
			if altro.a_terra:
				altro.muori()
				_uccisi += 1
			else:
				_colpisci_zombie(altro, 25.0)
	_lampo_esplosione(centro)


func _lampo_esplosione(centro: Vector3) -> void:
	var luce := OmniLight3D.new()
	luce.light_color = Color("#9cff5a")
	luce.light_energy = 6.0
	luce.omni_range = 7.0
	luce.position = centro
	add_child(luce)
	var palla := MeshInstance3D.new()
	var forma := SphereMesh.new()
	forma.radius = 0.5
	forma.height = 1.0
	palla.mesh = forma
	var materiale := StandardMaterial3D.new()
	materiale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materiale.albedo_color = Color("#c8ff8a")
	materiale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materiale.disable_fog = true
	palla.material_override = materiale
	palla.position = centro
	add_child(palla)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(palla, "scale", Vector3.ONE * 4.0, 0.35)
	tween.tween_property(materiale, "albedo_color:a", 0.0, 0.35)
	tween.tween_property(luce, "light_energy", 0.0, 0.5)
	tween.chain().tween_callback(func() -> void:
		palla.queue_free()
		luce.queue_free())


# ------------------------------------------------------------------ tocchi e colpi


func _unhandled_input(event: InputEvent) -> void:
	if _stato == "fine":
		return
	if event is InputEventMouseButton:
		var tocco := event as InputEventMouseButton
		if tocco.pressed and tocco.button_index == MOUSE_BUTTON_LEFT:
			var z := _zombie_sotto(tocco.position)
			if z != null:
				if z.a_terra:
					cattura(z)
				else:
					spara_a(z)
			else:
				# mira assistita: toccando a vuoto si spara al più vicino
				spara_a(_zombie_piu_vicino())


## Senza toccare, la squadra spara da sola allo zombie più vicino, ma più
## piano (ricarica raddoppiata): toccare serve a sparare al massimo e a
## scegliere il bersaglio. Senza munizioni si difende solo da vicino.
func _tiro_automatico() -> void:
	var bersaglio := _zombie_piu_vicino()
	if bersaglio == null or bersaglio.position.x - _fronte > Bilanciamento.PORTATA_TIRO_AUTOMATICO:
		return
	if int(StatoGioco.risorse["munizioni"]) <= 0 and bersaglio.position.x - _fronte > Bilanciamento.PORTATA_CORPO_A_CORPO:
		return
	for i in _membri.size():
		var m: Dictionary = _membri[i]
		if m["stato"] != "in_campo" or _tempo < float(m["pronto"]) + float(m.get("attesa_auto", 0.0)):
			continue
		var ricarica := Bilanciamento.ricarica(m["dati"])
		m["attesa_auto"] = ricarica * (Bilanciamento.RITARDO_TIRO_AUTOMATICO - 1.0)
		if spara_a(bersaglio, i):
			bersaglio = _zombie_piu_vicino()
			if bersaglio == null:
				return
		else:
			m["pronto"] = _tempo + ricarica


func _zombie_sotto(punto: Vector2) -> FiguraZombie:
	var migliore: FiguraZombie = null
	var distanza_migliore := INF
	for z in _zombie:
		if not is_instance_valid(z) or z.morto:
			continue
		var centro := _camera.unproject_position(z.global_position + Vector3(0, 1.0 * z.scala, 0))
		var distanza := centro.distance_to(punto)
		if distanza < RAGGIO_TOCCO * sqrt(z.scala) and distanza < distanza_migliore:
			migliore = z
			distanza_migliore = distanza
	return migliore


func _zombie_piu_vicino() -> FiguraZombie:
	var migliore: FiguraZombie = null
	for z in _zombie:
		if is_instance_valid(z) and not z.morto and not z.a_terra and (migliore == null or z.position.x < migliore.position.x):
			migliore = z
	return migliore


## Chi spara: il primo della squadra che ha già ricaricato.
func _tiratore() -> int:
	var scelto := -1
	for i in _membri.size():
		var m: Dictionary = _membri[i]
		if m["stato"] != "in_campo" or float(m["pronto"]) > _tempo:
			continue
		if scelto < 0 or float(m["pronto"]) < float(_membri[scelto]["pronto"]):
			scelto = i
	return scelto


func spara_a(z: FiguraZombie, tiratore := -1, raffica := false) -> bool:
	if _stato == "fine" or z == null or not is_instance_valid(z) or z.morto:
		return false
	var i := tiratore if tiratore >= 0 else _tiratore()
	if i < 0:
		return false
	var m: Dictionary = _membri[i]
	if m["stato"] != "in_campo":
		return false
	var dati: Dictionary = m["dati"]
	var figura: FiguraCittadino = m["figura"]
	var con_munizioni := int(StatoGioco.risorse["munizioni"]) > 0
	var danno := 0.0
	if con_munizioni:
		StatoGioco.risorse["munizioni"] = int(StatoGioco.risorse["munizioni"]) - 1
		danno = Bilanciamento.danno_colpo(dati, float(m["vita"]) / float(m["vita_max"]))
		figura.spara()
		Suoni.suona("sparo_pesante" if float(Bilanciamento.info_arma(dati)["danno"]) >= 1.8 else "sparo")
		_traccia(figura.punto_di_fuoco(), z.global_position + Vector3(0, 1.0 * z.scala, 0))
	else:
		if z.position.x - _fronte > Bilanciamento.PORTATA_CORPO_A_CORPO:
			_hud.avviso("Munizioni finite: colpisci solo gli zombie vicini")
			return false
		danno = Bilanciamento.danno_corpo_a_corpo(dati)
		figura.colpisci_da_vicino()
		Suoni.suona("colpo")
	if not raffica:
		m["pronto"] = _tempo + Bilanciamento.ricarica(dati)
	_colpisci_zombie(z, danno, con_munizioni and Bilanciamento.arma_perforante(dati))
	return true


## perforante: il colpo ignora la corazza (fucile di precisione).
func _colpisci_zombie(z: FiguraZombie, danno: float, perforante := false) -> void:
	if z.morto:
		return
	if z.a_terra:
		# chi è già a terra muore solo per un'esplosione o allo scadere del tempo
		return
	z.vita -= maxf(1.0, danno - (0.0 if perforante else z.armatura))
	z.colpito()
	if z.tipo == "barcollante" and z.vita <= z.vita_max * Bilanciamento.SOGLIA_CATTURA and posti_cattura() > 0:
		z.vita = 1.0
		z.atterra(_tempo + Bilanciamento.SECONDI_A_TERRA)
		if not has_meta("spiegato_cattura"):
			set_meta("spiegato_cattura", true)
			_hud.avviso("Barcollante a terra: toccalo per catturarlo!")
		return
	if z.vita <= 0.0:
		if z.tipo == "esplosivo":
			# scoppia: se è vicino alla squadra la ferisce
			_esplosione(z, z.position.x - _fronte < 2.5)
		else:
			z.muori()
			_uccisi += 1


## Posti ancora liberi in Ambulatorio per i barcollanti di questa battaglia.
func posti_cattura() -> int:
	var a_terra := 0
	for z in _zombie:
		if is_instance_valid(z) and z.a_terra and not z.morto:
			a_terra += 1
	return StatoGioco.letti_pazienti_liberi() - _catturati - a_terra


func cattura(z: FiguraZombie) -> void:
	if z == null or not is_instance_valid(z) or not z.a_terra or z.morto or _stato == "fine":
		return
	z.catturato()
	_catturati += 1
	_hud.avviso("Barcollante catturato! Lo curerete in Ambulatorio")


## Scia luminosa del proiettile.
func _traccia(da: Vector3, a: Vector3) -> void:
	var scia := MeshInstance3D.new()
	var forma := BoxMesh.new()
	var lunghezza := da.distance_to(a)
	forma.size = Vector3(0.035, 0.035, lunghezza)
	scia.mesh = forma
	var materiale := StandardMaterial3D.new()
	materiale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materiale.albedo_color = Color("#ffe8a0")
	materiale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materiale.disable_fog = true
	scia.material_override = materiale
	add_child(scia)
	scia.global_position = (da + a) / 2.0
	scia.look_at(a, Vector3.UP)
	var tween := create_tween()
	tween.tween_property(materiale, "albedo_color:a", 0.0, 0.12)
	tween.tween_callback(scia.queue_free)


# ------------------------------------------------------------------ abilità e ritirata


func _usa_abilita(i: int) -> void:
	var m: Dictionary = _membri[i]
	if m["stato"] != "in_campo" or _tempo < float(m["abilita_pronta"]) or _stato == "fine":
		return
	var stat: String = m["abilita"]
	var dati: Dictionary = m["dati"]
	var valore := Bilanciamento.stat(dati, stat)
	match stat:
		"forza":
			for z in _zombie:
				if is_instance_valid(z) and not z.morto and not z.a_terra and z.position.x - _fronte < 6.0:
					z.respingi(2.5 + 0.25 * valore)
					z.stordisci(_tempo + 1.0)
			_scossa = 0.2
		"agilita":
			if int(StatoGioco.risorse["munizioni"]) <= 0:
				_hud.avviso("Servono munizioni per la raffica")
				return
			for k in 3 + valore / 3:
				get_tree().create_timer(0.12 * k).timeout.connect(func() -> void:
					spara_a(_zombie_piu_vicino(), i, true))
		"intelligenza":
			if int(StatoGioco.risorse["medicine"]) <= 0:
				_hud.avviso("Serve una medicina per curare")
				return
			StatoGioco.risorse["medicine"] = int(StatoGioco.risorse["medicine"]) - 1
			for altro in _in_campo():
				altro["vita"] = minf(float(altro["vita_max"]), float(altro["vita"]) + 15.0 + 3.0 * valore)
		"carisma":
			for z in _zombie:
				if is_instance_valid(z) and not z.morto:
					z.stordisci(_tempo + 1.5 + 0.25 * valore)
	m["abilita_pronta"] = _tempo + float(Bilanciamento.ABILITA[stat]["ricarica"])
	_hud.avviso("%s: %s!" % [dati["nome"], Bilanciamento.ABILITA[stat]["nome"]])
	StatoGioco.risorse_cambiate.emit()


func _ritira(i: int, messaggio := "") -> void:
	if i < 0 or i >= _membri.size():
		return
	var m: Dictionary = _membri[i]
	if m["stato"] != "in_campo":
		return
	m["stato"] = "ritirato"
	var figura: FiguraCittadino = m["figura"]
	figura.vai_a(Vector3(_fronte - 20.0, 0, 0.5))
	get_tree().create_timer(9.0).timeout.connect(func() -> void:
		if is_instance_valid(figura):
			figura.visible = false)
	var dati: Dictionary = m["dati"]
	_hud.avviso(messaggio if messaggio != "" else "%s torna in città" % dati["nome"])
	_controlla_squadra()


func _ritirata_generale() -> void:
	for i in _membri.size():
		if _membri[i]["stato"] == "in_campo":
			_membri[i]["stato"] = "ritirato"
			var figura: FiguraCittadino = _membri[i]["figura"]
			figura.vai_a(Vector3(_fronte - 20.0, 0, 0.5))
	_fine(false)


# ------------------------------------------------------------------ fine


func _fine(vinta: bool) -> void:
	if _stato == "fine":
		return
	_stato = "fine"
	Suoni.musica("")
	Suoni.suona("vittoria" if vinta else "sconfitta", 0.0)
	var morti: Array[String] = []
	var salute := {}
	for m in _membri:
		if m["stato"] == "morto":
			morti.append(m["id"])
		else:
			salute[m["id"]] = clampf(float(m["vita"]) / float(m["vita_max"]) * 100.0, 1.0, 100.0)
	if _tipo == "difesa":
		_esito = StatoGioco.concludi_difesa(vinta, morti, salute, _catturati)
	else:
		_esito = StatoGioco.concludi_missione(vinta, morti, salute, _catturati)
	_mostra_esito()


func _ids_feriti() -> Array:
	var ids: Array = []
	for ferito in _esito.get("feriti", []):
		var c := StatoGioco.trova_cittadino(ferito["id"])
		if not c.is_empty() and float(c["salute"]) < 100.0:
			ids.append(ferito["id"])
	return ids


func _mostra_esito() -> void:
	get_tree().create_timer(1.2 if _esito["vinta"] else 0.6).timeout.connect(func() -> void:
		_hud.mostra_esito(_esito, _uccisi, _ids_feriti().size()))


func _cura() -> void:
	var curati := StatoGioco.cura_feriti(_ids_feriti())
	if curati > 0:
		var rimasti: Array[Dictionary] = []
		for ferito in _esito["feriti"]:
			var c := StatoGioco.trova_cittadino(ferito["id"])
			if not c.is_empty() and float(c["salute"]) < 100.0:
				rimasti.append(ferito)
		_esito["feriti"] = rimasti
		_hud.avviso("Curati %d feriti" % curati)
	_hud.mostra_esito(_esito, _uccisi, _ids_feriti().size())


func _torna() -> void:
	get_tree().change_scene_to_file("res://scene/main.tscn")


## Per le prove automatiche.
func stato() -> String:
	return _stato


func zombie_vivi() -> Array[FiguraZombie]:
	return _zombie
