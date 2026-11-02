extends Node3D
## Vetrina dei modelli: mette in fila i modelli come nella strada del gioco.
## Da Godot: apri strumenti/vetrina.tscn e premi F6 (mostra tutti gli edifici
## ai tre livelli; trascina per scorrere, rotellina per lo zoom).
## Da riga di comando:  -- modelli=case_l1,case_l2 foto=/percorso.png distanza=24

const LARGHEZZA := 6.4
var _camera: Camera3D
var _x := 0.0
var _distanza := 27.0
var _x_max := 0.0
var _trascina := false


func _ready() -> void:
	var argomenti := {}
	for a in OS.get_cmdline_user_args():
		var parti := a.split("=", true, 1)
		if parti.size() == 2:
			argomenti[parti[0]] = parti[1]
	var nomi: PackedStringArray
	if argomenti.has("modelli"):
		nomi = argomenti["modelli"].split(",")
	else:
		for f in DirAccess.get_files_at("res://assets/modelli"):
			if f.ends_with("_l1.glb") or f.ends_with("_l2.glb") or f.ends_with("_l3.glb"):
				nomi.append(f.get_basename())
	_ambiente()
	var i := 0
	for nome in nomi:
		if nome == "-":
			i += 1
			continue
		var scena: PackedScene = load("res://assets/modelli/%s.glb" % nome)
		var modello := scena.instantiate() as Node3D
		modello.position = Vector3(i * float(argomenti.get("passo", str(LARGHEZZA))), 0, 0)
		modello.rotation_degrees.y = float(argomenti.get("ruota", "0"))
		add_child(modello)
		# apri=gradi: ruota i battenti del cancello (anta_sx / anta_dx)
		var apri := float(argomenti.get("apri", "0")) * (i % 2)
		for anta in modello.find_children("anta_*", "Node3D", true, false):
			anta.rotation_degrees.y = apri if String(anta.name).begins_with("anta_sx") else -apri
		var cartello := Label3D.new()
		cartello.text = nome
		cartello.font_size = 40
		cartello.pixel_size = 0.008
		cartello.outline_size = 14
		cartello.position = Vector3(modello.position.x, 0.3, 3.9)
		add_child(cartello)
		_scrivi_insegna(modello)
		i += 1
	_x_max = (i - 1) * float(argomenti.get("passo", str(LARGHEZZA)))
	_camera = Camera3D.new()
	_camera.fov = float(argomenti.get("fov", "22"))
	add_child(_camera)
	_distanza = float(argomenti.get("distanza", "27"))
	_x = float(argomenti.get("x", str(_x_max / 2.0)))
	_aggiorna_camera(float(argomenti.get("altezza", "2.2")), float(argomenti.get("alzo", "0")))
	if argomenti.has("foto"):
		for k in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(argomenti["foto"])
		get_tree().quit()


func _aggiorna_camera(sguardo := 2.2, alzo := 0.0) -> void:
	var bersaglio := Vector3(_x, sguardo, 0.0)
	var dir := Vector3(0, 0.22 + alzo, 1).normalized()
	_camera.position = bersaglio + dir * _distanza
	_camera.look_at(bersaglio)


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton:
		if evento.button_index == MOUSE_BUTTON_LEFT:
			_trascina = evento.pressed
		elif evento.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distanza = maxf(8.0, _distanza - 1.5)
		elif evento.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distanza = minf(60.0, _distanza + 1.5)
		_aggiorna_camera()
	elif evento is InputEventMouseMotion and _trascina:
		_x = clampf(_x - evento.relative.x * 0.03, 0.0, _x_max)
		_aggiorna_camera()


## Scrive il nome sull'insegna dove il modello ha il segnaposto "insegna_wNNN".
func _scrivi_insegna(modello: Node) -> void:
	for nodo in modello.find_children("insegna_w*", "", true, false):
		var n := nodo as Node3D
		var scritta := Label3D.new()
		scritta.text = "INSEGNA"
		scritta.modulate = Color("#5b3a29")
		scritta.outline_size = 0
		scritta.font_size = 48
		scritta.pixel_size = 0.005
		scritta.shaded = true
		n.add_child(scritta)
		scritta.rotation_degrees.y = 0.0


func _ambiente() -> void:
	var cielo_mat := ProceduralSkyMaterial.new()
	cielo_mat.sky_top_color = Color("#2e2a4a")
	cielo_mat.sky_horizon_color = Color("#e3916a")
	cielo_mat.sky_curve = 0.12
	cielo_mat.ground_horizon_color = Color("#e3916a")
	cielo_mat.ground_bottom_color = Color("#3a2d3c")
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
	var suolo := MeshInstance3D.new()
	var forma := BoxMesh.new()
	forma.size = Vector3(400, 0.2, 60)
	suolo.mesh = forma
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#a88a62")
	suolo.material_override = m
	suolo.position = Vector3(0, -0.1, -20)
	add_child(suolo)
	var marciapiede := MeshInstance3D.new()
	var f2 := BoxMesh.new()
	f2.size = Vector3(400, 0.12, 2.0)
	marciapiede.mesh = f2
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color("#c9b490")
	marciapiede.material_override = m2
	marciapiede.position = Vector3(0, 0.0, 4.6)
	add_child(marciapiede)
	var strada := MeshInstance3D.new()
	var f3 := BoxMesh.new()
	f3.size = Vector3(400, 0.1, 8.0)
	strada.mesh = f3
	var m3 := StandardMaterial3D.new()
	m3.albedo_color = Color("#3f3a46")
	strada.material_override = m3
	strada.position = Vector3(0, -0.02, 9.6)
	add_child(strada)
