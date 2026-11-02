class_name FiguraCittadino
extends Node3D
## Omino cartoon di un cittadino: corpo a capsule con contorno scuro,
## cammina verso la sua destinazione e quando è fermo si dondola.

const VELOCITA := 2.4         # metri al secondo
const COLORE_CONTORNO := Color("#24181a")
const COLORE_PANTALONI := Color("#3b3346")

var dati: Dictionary = {}
var destinazione := Vector3.ZERO
var guarda_la_telecamera := true

var _corpo: Node3D
var _gamba_sx: Node3D
var _gamba_dx: Node3D
var _braccio_sx: Node3D
var _braccio_dx: Node3D
var _fase := 0.0
var _passo := 0.0
var _bolla: Label3D
## In battaglia: tiene il fucile, non si gira verso la telecamera.
var armato := false
var fermo := false
var _bocca: Node3D
var _fiammata: MeshInstance3D


func prepara(nuovi_dati: Dictionary, posizione_iniziale: Vector3) -> void:
	dati = nuovi_dati
	position = posizione_iniziale
	destinazione = posizione_iniziale
	_fase = randf() * TAU
	var aspetto: Dictionary = dati["aspetto"]
	scale = Vector3.ONE * float(aspetto["altezza"])
	_corpo = Node3D.new()
	add_child(_corpo)

	var vestito: Color = aspetto["vestito"]
	# Chi indossa un vestito dell'Officina si riconosce dal colore.
	var indossato: Dictionary = dati.get("vestito", {})
	if not indossato.is_empty() and Bilanciamento.VESTITI.has(indossato.get("tipo", "")):
		vestito = Color(Bilanciamento.VESTITI[indossato["tipo"]]["colore"])
	var pelle: Color = aspetto["pelle"]
	_gamba_sx = _arto(Vector3(-0.1, 0.62, 0), 0.085, 0.6, COLORE_PANTALONI)
	_gamba_dx = _arto(Vector3(0.1, 0.62, 0), 0.085, 0.6, COLORE_PANTALONI)
	_capsula(_corpo, Vector3(0, 0.98, 0), 0.22, 0.72, vestito)
	_braccio_sx = _arto(Vector3(-0.27, 1.22, 0), 0.07, 0.52, vestito.darkened(0.1))
	_braccio_dx = _arto(Vector3(0.27, 1.22, 0), 0.07, 0.52, vestito.darkened(0.1))
	_sfera(_corpo, Vector3(0, 1.5, 0), 0.19, pelle)
	# capelli: calotta sopra e dietro la testa
	var capelli := _sfera(_corpo, Vector3(0, 1.56, -0.03), 0.2, aspetto["capelli"])
	capelli.scale = Vector3(1.0, 0.75, 1.0)
	if dati.get("donna", false):
		_sfera(_corpo, Vector3(0, 1.43, -0.12), 0.15, aspetto["capelli"])
	# occhi
	for x in [-0.065, 0.065]:
		_sfera(_corpo, Vector3(x, 1.52, 0.17), 0.028, Color("#2b2230"), false)
	if aspetto.get("cappello", false):
		_cilindro(_corpo, Vector3(0, 1.69, 0), 0.25, 0.03, Color("#5b3a29"))
		_cilindro(_corpo, Vector3(0, 1.77, 0), 0.15, 0.15, Color("#5b3a29"))


func _materiale(colore: Color, contorno := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colore
	m.roughness = 0.85
	if contorno:
		var bordo := StandardMaterial3D.new()
		bordo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bordo.albedo_color = COLORE_CONTORNO
		bordo.cull_mode = BaseMaterial3D.CULL_FRONT
		bordo.grow = true
		bordo.grow_amount = 0.025
		m.next_pass = bordo
	return m


func _capsula(genitore: Node3D, pos: Vector3, raggio: float, altezza: float, colore: Color) -> MeshInstance3D:
	var forma := CapsuleMesh.new()
	forma.radius = raggio
	forma.height = altezza
	forma.radial_segments = 16
	forma.rings = 4
	var m := MeshInstance3D.new()
	m.mesh = forma
	m.material_override = _materiale(colore)
	m.position = pos
	genitore.add_child(m)
	return m


func _sfera(genitore: Node3D, pos: Vector3, raggio: float, colore: Color, contorno := true) -> MeshInstance3D:
	var forma := SphereMesh.new()
	forma.radius = raggio
	forma.height = raggio * 2.0
	forma.radial_segments = 16
	forma.rings = 8
	var m := MeshInstance3D.new()
	m.mesh = forma
	m.material_override = _materiale(colore, contorno)
	m.position = pos
	genitore.add_child(m)
	return m


func _cilindro(genitore: Node3D, pos: Vector3, raggio: float, altezza: float, colore: Color) -> MeshInstance3D:
	var forma := CylinderMesh.new()
	forma.top_radius = raggio
	forma.bottom_radius = raggio
	forma.height = altezza
	forma.radial_segments = 16
	var m := MeshInstance3D.new()
	m.mesh = forma
	m.material_override = _materiale(colore)
	m.position = pos
	genitore.add_child(m)
	return m


## Arto con il perno in alto (anca o spalla), così può oscillare.
func _arto(perno: Vector3, raggio: float, lunghezza: float, colore: Color) -> Node3D:
	var giunto := Node3D.new()
	giunto.position = perno
	_corpo.add_child(giunto)
	_capsula(giunto, Vector3(0, -lunghezza / 2.0, 0), raggio, lunghezza, colore)
	return giunto


## Fumetto sopra la testa (per esempio "!" per chi aspetta al cancello).
func mostra_bolla(testo: String) -> void:
	if _bolla == null:
		_bolla = Label3D.new()
		_bolla.font_size = 72
		_bolla.pixel_size = 0.01
		_bolla.outline_size = 20
		_bolla.modulate = Color("#e3b448")
		_bolla.outline_modulate = Color("#2b2230")
		_bolla.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bolla.no_depth_test = true
		_bolla.render_priority = 3
		_bolla.position = Vector3(0, 2.25, 0)
		add_child(_bolla)
	_bolla.text = testo
	_bolla.visible = testo != ""


func vai_a(punto: Vector3) -> void:
	destinazione = punto
	_tappe.clear()


## Cammina passando per più punti, uno dopo l'altro (per attraversare il
## cancello senza tagliare la palizzata). attesa: secondi di sosta prima di partire.
var _tappe: Array[Vector3] = []
var _riparte_alle := 0.0


func percorri(punti: Array, attesa := 0.0) -> void:
	_tappe.clear()
	for p in punti:
		_tappe.append(p)
	destinazione = position
	_riparte_alle = _fase + attesa


func ha_tappe() -> bool:
	return not _tappe.is_empty()


func in_cammino() -> bool:
	return position.distance_to(destinazione) > 0.05


func _process(delta: float) -> void:
	if fermo:
		return
	_fase += delta
	var verso := destinazione - position
	verso.y = 0.0
	if verso.length() <= 0.05 and not _tappe.is_empty() and _fase >= _riparte_alle:
		destinazione = _tappe.pop_front()
		verso = destinazione - position
		verso.y = 0.0
	var cammina := verso.length() > 0.05
	if cammina:
		var passo := minf(verso.length(), VELOCITA * delta)
		position += verso.normalized() * passo
		_passo += delta * 9.0
		var angolo := atan2(verso.x, verso.z)
		rotation.y = lerp_angle(rotation.y, angolo, minf(1.0, delta * 10.0))
	else:
		_passo = 0.0
		if guarda_la_telecamera:
			rotation.y = lerp_angle(rotation.y, 0.0, minf(1.0, delta * 5.0))
	var oscillazione := sin(_passo) * (0.6 if cammina else 0.0)
	_gamba_sx.rotation.x = oscillazione
	_gamba_dx.rotation.x = -oscillazione
	_braccio_sx.rotation.x = -oscillazione * 0.8
	_braccio_dx.rotation.x = oscillazione * 0.8
	# rimbalzo del passo, o un leggero dondolio da fermo
	if cammina:
		_corpo.position.y = absf(sin(_passo)) * 0.06
	else:
		_corpo.position.y = 0.0
		_corpo.rotation.z = sin(_fase * 1.6) * 0.04
	if armato:
		_braccio_dx.rotation.x = -1.45
		_braccio_sx.rotation.x = -1.2
	if _bolla != null and _bolla.visible:
		_bolla.position.y = 2.25 + absf(sin(_fase * 3.0)) * 0.15



# ------------------------------------------------------------------ battaglia


func imbraccia_arma() -> void:
	armato = true
	guarda_la_telecamera = false
	# forma e colore dipendono dall'arma fabbricata in Officina
	var arma := Bilanciamento.info_arma(dati)
	var lunghezza := float(arma.get("lunghezza", 0.8))
	var fucile := MeshInstance3D.new()
	var forma := BoxMesh.new()
	forma.size = Vector3(0.07, 0.09, lunghezza)
	fucile.mesh = forma
	fucile.material_override = _materiale(Color(arma.get("colore", "#3a2c24")))
	fucile.position = Vector3(0.12, 1.2, 0.02 + lunghezza / 2.0)
	_corpo.add_child(fucile)
	var calcio := MeshInstance3D.new()
	var forma_calcio := BoxMesh.new()
	forma_calcio.size = Vector3(0.08, 0.16, 0.14)
	calcio.mesh = forma_calcio
	calcio.material_override = _materiale(Color("#5b3a29"))
	calcio.position = Vector3(0.12, 1.14, 0.06)
	_corpo.add_child(calcio)
	_bocca = Node3D.new()
	_bocca.position = Vector3(0.12, 1.21, 0.06 + lunghezza)
	_corpo.add_child(_bocca)
	_fiammata = MeshInstance3D.new()
	var sfera := SphereMesh.new()
	sfera.radius = 0.13
	sfera.height = 0.26
	_fiammata.mesh = sfera
	var luce := StandardMaterial3D.new()
	luce.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	luce.albedo_color = Color("#ffe08a")
	luce.disable_fog = true
	_fiammata.material_override = luce
	_fiammata.visible = false
	_bocca.add_child(_fiammata)


func punto_di_fuoco() -> Vector3:
	return _bocca.global_position if _bocca != null else global_position + Vector3(0, 1.2, 0)


## Fiammata alla bocca del fucile.
func spara() -> void:
	if _fiammata == null:
		return
	_fiammata.visible = true
	_fiammata.scale = Vector3.ONE * randf_range(0.8, 1.3)
	get_tree().create_timer(0.06).timeout.connect(func() -> void:
		if is_instance_valid(_fiammata):
			_fiammata.visible = false)
	_corpo.position.x = 0.0
	var rinculo := create_tween()
	rinculo.tween_property(_corpo, "position:z", -0.08, 0.04)
	rinculo.tween_property(_corpo, "position:z", 0.0, 0.1)


## Colpo corpo a corpo: uno scatto in avanti.
func colpisci_da_vicino() -> void:
	var scatto := create_tween()
	scatto.tween_property(_corpo, "position:z", 0.35, 0.07)
	scatto.tween_property(_corpo, "position:z", 0.0, 0.15)


func ferito() -> void:
	var colpo := create_tween()
	colpo.tween_property(_corpo, "scale", Vector3(1.12, 0.9, 1.12), 0.05)
	colpo.tween_property(_corpo, "scale", Vector3.ONE, 0.12)


func cadi() -> void:
	fermo = true
	mostra_bolla("")
	var caduta := create_tween()
	caduta.tween_property(_corpo, "rotation:x", -PI / 2.0, 0.4).set_ease(Tween.EASE_IN)
	caduta.parallel().tween_property(_corpo, "position:y", 0.15, 0.4)
