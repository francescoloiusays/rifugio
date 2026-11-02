class_name FiguraZombie
extends Node3D
## Zombie a silhouette scura con gli occhi che brillano, nello stile di
## Limbo e Inside. Cammina verso la squadra (verso -X) con le braccia tese.

const COLORI := {
	"barcollante": Color("#17151b"),
	"corridore": Color("#1b1519"),
	"esplosivo": Color("#1a1f15"),
	"corazzato": Color("#16161b"),
	"colosso": Color("#110e13"),
}
const OCCHI := {
	"barcollante": Color("#ffd36b"),
	"corridore": Color("#ff9a4a"),
	"esplosivo": Color("#9cff5a"),
	"corazzato": Color("#ffd36b"),
	"colosso": Color("#ff4a3a"),
}
const SCALE := {"barcollante": 1.0, "corridore": 0.92, "esplosivo": 1.05, "corazzato": 1.1, "colosso": 2.2}

var tipo := "barcollante"
var vita := 20.0
var vita_max := 20.0
var danno := 5.0
var velocita := 1.0
var armatura := 0.0
var raggio := 0.35
var scala := 1.0
var stordito_fino := 0.0
var morto := false
## Barcollante abbattuto ma vivo: si può catturare con un tocco.
var a_terra := false
var a_terra_fino := 0.0
var _segno_cattura: Label3D
var cammina := false
var attacca := false

var _corpo: Node3D
var _gamba_sx: Node3D
var _gamba_dx: Node3D
var _braccio_sx: Node3D
var _braccio_dx: Node3D
var _testa: Node3D
var _materiale: StandardMaterial3D
var _materiale_occhi: StandardMaterial3D
var _colore := Color.BLACK
var _colore_occhi := Color.WHITE
var _barra: Node3D
var _riempimento: MeshInstance3D
var _fase := 0.0
var _lampo := 0.0
var _stordito := false


func prepara(nuovo_tipo: String, moltiplicatore: float, pos: Vector3, casuale: RandomNumberGenerator) -> void:
	tipo = nuovo_tipo
	var info: Dictionary = Bilanciamento.ZOMBIE[tipo]
	vita_max = float(info["vita"]) * moltiplicatore
	vita = vita_max
	danno = float(info["danno"]) * moltiplicatore
	velocita = Bilanciamento.LARGHEZZA_CAMPO / float(info["attraversa"]) * casuale.randf_range(0.9, 1.1)
	armatura = float(info.get("armatura", 0))
	scala = float(SCALE[tipo]) * casuale.randf_range(0.94, 1.06)
	raggio = 0.35 * scala
	position = pos
	rotation.y = -PI / 2.0
	_fase = casuale.randf() * TAU
	_colore = COLORI[tipo]
	_colore_occhi = OCCHI[tipo]
	_costruisci()
	scale = Vector3.ONE * scala


func _costruisci() -> void:
	_materiale = StandardMaterial3D.new()
	_materiale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materiale.albedo_color = _colore
	_materiale_occhi = StandardMaterial3D.new()
	_materiale_occhi.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materiale_occhi.albedo_color = _colore_occhi
	_materiale_occhi.disable_fog = true

	_corpo = Node3D.new()
	add_child(_corpo)
	var magro := 0.8 if tipo == "corridore" else 1.0
	_gamba_sx = _arto(Vector3(-0.11, 0.66, 0), 0.08 * magro, 0.66)
	_gamba_dx = _arto(Vector3(0.11, 0.66, 0), 0.08 * magro, 0.66)
	var busto := Node3D.new()
	busto.position = Vector3(0, 0.66, 0)
	# piegato in avanti: barcollante poco, corridore molto
	busto.rotation.x = 0.55 if tipo == "corridore" else 0.25
	_corpo.add_child(busto)
	if tipo == "esplosivo":
		var pancia := _sfera(busto, Vector3(0, 0.42, 0.06), 0.36)
		pancia.scale = Vector3(1.0, 1.05, 1.1)
		var bubbone := StandardMaterial3D.new()
		bubbone.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bubbone.albedo_color = Color("#6dbb3a")
		bubbone.disable_fog = true
		for p in [Vector3(0.15, 0.55, 0.33), Vector3(-0.2, 0.35, 0.3), Vector3(0.05, 0.25, 0.38)]:
			var punto := _sfera(busto, p, 0.06)
			punto.material_override = bubbone
	else:
		_capsula(busto, Vector3(0, 0.38, 0), 0.2 * magro, 0.72)
	if tipo == "corazzato":
		var lamiera := StandardMaterial3D.new()
		lamiera.albedo_color = Color("#3c3c46")
		lamiera.metallic = 0.6
		lamiera.roughness = 0.5
		var petto := _scatola(busto, Vector3(0, 0.42, 0.16), Vector3(0.42, 0.42, 0.08))
		petto.material_override = lamiera
		var spalla := _scatola(busto, Vector3(0.24, 0.66, 0), Vector3(0.16, 0.1, 0.3))
		spalla.material_override = lamiera
	_testa = Node3D.new()
	_testa.position = Vector3(0, 0.88, 0.08)
	busto.add_child(_testa)
	_sfera(_testa, Vector3.ZERO, 0.17)
	if tipo == "corazzato":
		var elmo := _scatola(_testa, Vector3(0, 0.08, 0), Vector3(0.38, 0.2, 0.38))
		var metallo := StandardMaterial3D.new()
		metallo.albedo_color = Color("#3c3c46")
		metallo.metallic = 0.6
		elmo.material_override = metallo
	for x in [-0.065, 0.065]:
		var occhio := _sfera(_testa, Vector3(x, 0.01, 0.15), 0.035)
		occhio.material_override = _materiale_occhi
	_braccio_sx = _arto_su(busto, Vector3(-0.27, 0.68, 0), 0.065 * magro, 0.6)
	_braccio_dx = _arto_su(busto, Vector3(0.27, 0.68, 0), 0.065 * magro, 0.6)
	_crea_barra()


func _mesh(genitore: Node3D, forma: Mesh, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = forma
	m.material_override = _materiale
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	genitore.add_child(m)
	return m


func _capsula(genitore: Node3D, pos: Vector3, r: float, h: float) -> MeshInstance3D:
	var forma := CapsuleMesh.new()
	forma.radius = r
	forma.height = maxf(h, r * 2.0)
	forma.radial_segments = 12
	forma.rings = 3
	return _mesh(genitore, forma, pos)


func _sfera(genitore: Node3D, pos: Vector3, r: float) -> MeshInstance3D:
	var forma := SphereMesh.new()
	forma.radius = r
	forma.height = r * 2.0
	forma.radial_segments = 12
	forma.rings = 6
	return _mesh(genitore, forma, pos)


func _scatola(genitore: Node3D, pos: Vector3, dim: Vector3) -> MeshInstance3D:
	var forma := BoxMesh.new()
	forma.size = dim
	return _mesh(genitore, forma, pos)


func _arto(perno: Vector3, r: float, lunghezza: float) -> Node3D:
	return _arto_su(_corpo, perno, r, lunghezza)


func _arto_su(genitore: Node3D, perno: Vector3, r: float, lunghezza: float) -> Node3D:
	var giunto := Node3D.new()
	giunto.position = perno
	genitore.add_child(giunto)
	_capsula(giunto, Vector3(0, -lunghezza / 2.0, 0), r, lunghezza)
	return giunto


func _crea_barra() -> void:
	_barra = Node3D.new()
	_barra.position = Vector3(0, 2.05, 0)
	_barra.rotation.y = PI / 2.0   # compensa la rotazione dello zombie: la barra guarda la telecamera
	_barra.visible = false
	add_child(_barra)
	var fondo := MeshInstance3D.new()
	var forma_fondo := BoxMesh.new()
	forma_fondo.size = Vector3(0.8, 0.09, 0.02)
	fondo.mesh = forma_fondo
	var m_fondo := StandardMaterial3D.new()
	m_fondo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_fondo.albedo_color = Color("#2b0f10")
	m_fondo.disable_fog = true
	fondo.material_override = m_fondo
	_barra.add_child(fondo)
	_riempimento = MeshInstance3D.new()
	var forma := BoxMesh.new()
	forma.size = Vector3(0.76, 0.06, 0.03)
	_riempimento.mesh = forma
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("#d0453a")
	m.disable_fog = true
	_riempimento.material_override = m
	_barra.add_child(_riempimento)


func colpito() -> void:
	_lampo = 1.0
	_barra.visible = true
	var quota := clampf(vita / vita_max, 0.0, 1.0)
	_riempimento.scale.x = maxf(quota, 0.001)
	_riempimento.position.x = -0.38 * (1.0 - quota)
	if tipo != "colosso" and tipo != "corazzato":
		position.x += 0.12


func respingi(metri: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "position:x", position.x + metri / maxf(1.0, scala), 0.25).set_ease(Tween.EASE_OUT)


func stordisci(fino: float) -> void:
	stordito_fino = maxf(stordito_fino, fino)


func atterra(fino: float) -> void:
	a_terra = true
	a_terra_fino = fino
	cammina = false
	_barra.visible = false
	var caduta := create_tween()
	caduta.tween_property(_corpo, "rotation:x", 1.2, 0.3).set_ease(Tween.EASE_IN)
	caduta.parallel().tween_property(_corpo, "position:y", -0.35, 0.3)
	_segno_cattura = Label3D.new()
	_segno_cattura.text = "+ CATTURA"
	_segno_cattura.font_size = 56
	_segno_cattura.pixel_size = 0.008 / maxf(scala, 0.1)
	_segno_cattura.outline_size = 18
	_segno_cattura.modulate = Color("#9cf5b0")
	_segno_cattura.outline_modulate = Color("#123018")
	_segno_cattura.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_segno_cattura.no_depth_test = true
	_segno_cattura.render_priority = 4
	_segno_cattura.position = Vector3(0, 1.3, 0)
	add_child(_segno_cattura)


## Portato via dalla squadra: sparisce in un lampo verde.
func catturato() -> void:
	if morto:
		return
	morto = true
	if _segno_cattura != null:
		_segno_cattura.text = "CATTURATO!"
	_materiale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materiale_occhi.albedo_color = Color("#9cf5b0")
	var tween := create_tween()
	tween.tween_property(_materiale, "albedo_color", Color(0.6, 1.0, 0.7, 0.0), 0.8)
	if _segno_cattura != null:
		tween.parallel().tween_property(_segno_cattura, "position:y", 2.2, 0.8)
		tween.parallel().tween_property(_segno_cattura, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)


func muori(esplode := false) -> void:
	if morto:
		return
	morto = true
	_barra.visible = false
	_materiale_occhi.albedo_color = Color(0.2, 0.2, 0.2)
	_materiale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var tween := create_tween()
	if esplode:
		tween.tween_property(self, "scale", Vector3.ONE * scala * 1.4, 0.08)
		tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.12)
	else:
		# cade all'indietro, lontano dalla squadra, e svanisce nel buio
		tween.tween_property(_corpo, "rotation:x", -1.45, 0.35).set_ease(Tween.EASE_IN)
		tween.tween_property(_materiale, "albedo_color:a", 0.0, 0.7).set_delay(0.3)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	if morto:
		return
	if a_terra:
		if _segno_cattura != null:
			_segno_cattura.position.y = 1.3 + absf(sin(Time.get_ticks_msec() / 200.0)) * 0.15
		_materiale_occhi.albedo_color = Color("#6fa8ff")
		return
	_fase += delta * (velocita * 2.5 + 2.0)
	var stordito := _stordito
	var ampiezza := 0.5 if cammina else 0.08
	var oscillazione := sin(_fase) * ampiezza
	_gamba_sx.rotation.x = oscillazione
	_gamba_dx.rotation.x = -oscillazione
	var colpo := sin(_fase * 2.5) * 0.35 if attacca else sin(_fase) * 0.12
	_braccio_sx.rotation.x = -PI / 2.0 + 0.2 + colpo
	_braccio_dx.rotation.x = -PI / 2.0 + 0.2 - colpo
	if tipo == "barcollante":
		_corpo.rotation.z = sin(_fase * 0.5) * 0.14
	if stordito:
		_corpo.rotation.z = sin(_fase * 6.0) * 0.08
		_braccio_sx.rotation.x = -0.4
		_braccio_dx.rotation.x = -0.3
	_testa.rotation.z = sin(_fase * 0.7) * 0.2
	if _lampo > 0.0:
		_lampo = maxf(0.0, _lampo - delta * 7.0)
		_materiale.albedo_color = _colore.lerp(Color(0.85, 0.82, 0.88), _lampo)
	_materiale_occhi.albedo_color = Color("#6fa8ff") if stordito else _colore_occhi
	attacca = false


func imposta_stordito(valore: bool) -> void:
	_stordito = valore
