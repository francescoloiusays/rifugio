class_name Lotto3D
extends Node3D
## Un lotto della strada in 3D: carica il modello fatto in Blender, scrive
## l'insegna e gestisce selezione e oscuramento delle zone infestate.

const LARGHEZZA := 6.4

const CARTELLA_MODELLI := "res://assets/modelli/"
## Modelli dei lotti che non sono edifici. Gli edifici hanno un modello per
## livello: <edificio>_l1.glb, _l2.glb, _l3.glb (generati da blender/crea_modelli.py).
const MODELLI_SPECIALI := {
	"libero": "lotto_libero",
	"bloccato": "lotto_bloccato",
	"cantiere": "cantiere",
}
## Modello usato per gli edifici che non ne hanno ancora uno proprio.
const MODELLO_PROVVISORIO := "res://assets/modelli/case_l1.glb"

const COLORE_INSEGNA := Color("#5b3a29")
const COLORE_SELEZIONE := Color(1.0, 0.85, 0.45)

var indice := 0
var dati: Dictionary = {}
var _radice: Node3D
var _mesh: Array[GeometryInstance3D] = []
var _evidenziatore: MeshInstance3D
var _barra: Node3D
var _riempimento: MeshInstance3D
var _conto: Label3D
var _produzione: Node3D
var _barra_produzione: MeshInstance3D
var _icona_pronta: Sprite3D
var _numero_pronto: Label3D
var _scritta_officina: Label3D
var _tempo := 0.0
var _cima := -1.0                     # altezza del tetto letta dal segnaposto "cima"


func prepara(nuovo_indice: int, nuovi_dati: Dictionary) -> void:
	indice = nuovo_indice
	dati = nuovi_dati
	position = Vector3(indice * LARGHEZZA, 0, 0)
	_radice = Node3D.new()
	add_child(_radice)

	var chiave := chiave_modello()
	if chiave == "mura":
		# Le mura attraversano la strada: il modello è lungo l'asse X e va
		# ruotato perché la palizzata vada dal fondo verso la telecamera,
		# con il lato della città rivolto a destra e il cancello sulla carreggiata.
		_radice.rotation_degrees.y = 90.0
	var percorso := percorso_modello()
	var provvisorio := percorso == ""
	if provvisorio:
		percorso = MODELLO_PROVVISORIO
	var scena: PackedScene = load(percorso)
	var modello := scena.instantiate()
	_radice.add_child(modello)
	_raccogli_mesh(modello)
	var livello := int(dati.get("livello", 1))
	# Senza un modello per ogni livello, gli edifici potenziati sono solo un po' più grandi.
	if dati["stato"] == StatoGioco.COSTRUITO and modello is Node3D and not percorso.ends_with("_l%d.glb" % livello):
		(modello as Node3D).scale = Vector3.ONE * (1.0 + 0.06 * (livello - 1))
	_leggi_segnaposti(modello, chiave, provvisorio)

	if dati["stato"] == StatoGioco.COSTRUITO:
		_aggiungi_targhetta()
	if dati["stato"] == StatoGioco.BLOCCATO:
		_oscura(dati.get("difficolta", 1))
	if dati.get("danneggiato", false):
		_mostra_danni()
	if dati["stato"] == StatoGioco.CANTIERE or dati.has("potenzia"):
		_crea_avanzamento()
	if dati.has("potenzia") and dati["stato"] != StatoGioco.MURA:
		_aggiungi_impalcatura()
	if provvisorio:
		_aggiungi_nome_provvisorio()
	if dati["stato"] == StatoGioco.COSTRUITO and StatoGioco.produce(indice) and not dati.has("potenzia"):
		_crea_indicatore_produzione()
	if (dati.has("lavorazione") or dati.has("appello")) and not dati.has("potenzia"):
		_crea_scritta_officina()


## Apre o chiude i battenti del cancello (solo per le mura): ruotano
## verso l'esterno attorno ai cardini.
var _tween_cancello: Tween
var cancello_aperto := false


func apri_cancello(aperto: bool, durata := 0.9) -> void:
	if dati.get("stato", "") != StatoGioco.MURA or aperto == cancello_aperto:
		return
	cancello_aperto = aperto
	if _tween_cancello != null:
		_tween_cancello.kill()
	_tween_cancello = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for anta in find_children("anta_*", "Node3D", true, false):
		var verso := 1.0 if String(anta.name).begins_with("anta_sx") else -1.0
		_tween_cancello.tween_property(anta, "rotation:y", deg_to_rad(80.0) * verso if aperto else 0.0, durata)
	Suoni.suona("porta", 0.1, -4.0)


func chiave_modello() -> String:
	var stato: String = dati["stato"]
	if stato == StatoGioco.MURA:
		return "mura"
	if stato == StatoGioco.LIBERO:
		return "libero"
	if stato == StatoGioco.BLOCCATO:
		return "bloccato"
	if stato == StatoGioco.CANTIERE:
		return "cantiere"
	return dati["edificio"]


## Il file .glb da caricare per questo lotto ("" se l'edificio non ha ancora un modello).
func percorso_modello() -> String:
	var chiave := chiave_modello()
	if MODELLI_SPECIALI.has(chiave):
		return CARTELLA_MODELLI + MODELLI_SPECIALI[chiave] + ".glb"
	if chiave == "mura":
		# palizzata, palizzata rinforzata, fortezza
		return CARTELLA_MODELLI + "mura_l%d.glb" % clampi(int(dati.get("livello", 1)), 1, 3)
	var livello := clampi(int(dati.get("livello", 1)), 1, Bilanciamento.LIVELLO_MASSIMO_EDIFICIO)
	for l in range(livello, 0, -1):
		var percorso := CARTELLA_MODELLI + "%s_l%d.glb" % [chiave, l]
		if ResourceLoader.exists(percorso):
			return percorso
	if ResourceLoader.exists(CARTELLA_MODELLI + chiave + ".glb"):
		return CARTELLA_MODELLI + chiave + ".glb"
	return ""


## I modelli hanno dei nodi vuoti che fanno da segnaposto:
## "insegna_w<larghezza cm>_h<altezza cm>_t<colore>" dove scrivere il nome,
## "cima" sopra il tetto, dove vanno barre e icone.
func _leggi_segnaposti(modello: Node, chiave: String, provvisorio: bool) -> void:
	var regola := RegEx.new()
	regola.compile("w(\\d+)_h(\\d+)(?:_t([0-9a-fA-F]{6}))?")
	for nodo in modello.find_children("*", "Node3D", true, false):
		var nome := String(nodo.name)
		if nome.begins_with("cima"):
			_cima = _posizione_nel_lotto(nodo).y
		elif nome.begins_with("insegna") and not provvisorio:
			var trovato := regola.search(nome)
			if trovato == null:
				continue
			var colore := COLORE_INSEGNA
			if trovato.get_string(3) != "":
				colore = Color("#" + trovato.get_string(3))
			_scrivi_insegna(nodo, chiave, float(trovato.get_string(1)) / 100.0,
					float(trovato.get_string(2)) / 100.0, colore)


func _posizione_nel_lotto(nodo: Node) -> Vector3:
	var trasformazione := Transform3D.IDENTITY
	var corrente := nodo
	while corrente != null and corrente != self:
		if corrente is Node3D:
			trasformazione = (corrente as Node3D).transform * trasformazione
		corrente = corrente.get_parent()
	return trasformazione.origin


func _raccogli_mesh(nodo: Node) -> void:
	if nodo is GeometryInstance3D:
		_mesh.append(nodo)
		_ammorbidisci_luci(nodo as GeometryInstance3D)
	for figlio in nodo.get_children():
		_raccogli_mesh(figlio)


## Le luci forti di Blender (fuoco, lampadine) in Godot risultano bruciate:
## le riporta a un'intensità più morbida.
func _ammorbidisci_luci(geometria: GeometryInstance3D) -> void:
	var istanza := geometria as MeshInstance3D
	if istanza == null or istanza.mesh == null:
		return
	for superficie in istanza.mesh.get_surface_count():
		var materiale := istanza.get_active_material(superficie) as BaseMaterial3D
		if materiale != null and materiale.emission_enabled and materiale.emission_energy_multiplier > 1.5:
			var morbido := materiale.duplicate() as BaseMaterial3D
			morbido.emission_energy_multiplier = 1.5
			istanza.set_surface_override_material(superficie, morbido)


func _testo_insegna(chiave: String) -> String:
	match chiave:
		"mura":
			return "INGRESSO"
		"libero":
			return "LOTTO\nLIBERO"
		"cantiere":
			return "LAVORI\nIN CORSO"
		_:
			return Bilanciamento.EDIFICI[chiave]["nome"].to_upper()


func _scrivi_insegna(segnaposto: Node, chiave: String, larghezza: float, altezza_tabella: float, colore: Color) -> void:
	var scritta := Label3D.new()
	scritta.text = _testo_insegna(chiave)
	scritta.modulate = colore
	scritta.outline_size = 0
	scritta.font_size = 64 if chiave == "libero" else 48
	scritta.pixel_size = 0.005
	scritta.width = larghezza / scritta.pixel_size
	scritta.autowrap_mode = TextServer.AUTOWRAP_OFF
	scritta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scritta.line_spacing = -8
	scritta.shaded = true
	scritta.position.z = 0.01
	# Riduce il testo se è più largo o più alto della tabella.
	var font := scritta.font if scritta.font else ThemeDB.fallback_font
	var righe := scritta.text.split("\n")
	var larghezza_testo := 0.0
	for riga in righe:
		larghezza_testo = maxf(larghezza_testo, font.get_string_size(riga, HORIZONTAL_ALIGNMENT_LEFT, -1, scritta.font_size).x)
	var altezza_testo := font.get_height(scritta.font_size) * righe.size()
	var fattore := minf(larghezza / scritta.pixel_size / maxf(larghezza_testo, 1.0),
			altezza_tabella * 0.8 / scritta.pixel_size / maxf(altezza_testo, 1.0))
	if fattore < 1.0:
		scritta.pixel_size *= fattore
	segnaposto.add_child(scritta)


func _aggiungi_targhetta() -> void:
	var targhetta := Label3D.new()
	var livello := int(dati.get("livello", 1))
	targhetta.text = "Liv. %d %s" % [livello, "★".repeat(livello - 1)] if livello > 1 else "Liv. 1"
	targhetta.font_size = 40
	targhetta.pixel_size = 0.008
	targhetta.modulate = Color("#2b2230")
	targhetta.outline_modulate = Color("#e3b448")
	targhetta.outline_size = 22
	targhetta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	targhetta.no_depth_test = true
	targhetta.position = Vector3(-LARGHEZZA * 0.36, 0.35, 3.75)
	_radice.add_child(targhetta)


## Più la zona è lontana, più è buia: scurisce i colori dei materiali
## (tranne quelli che emettono luce, come il fuoco).
func _oscura(difficolta: int) -> void:
	var quanto := clampf(0.3 + difficolta * 0.08, 0.0, 0.85)
	var tinta := Color(0.42, 0.38, 0.55)
	for mesh in _mesh:
		var istanza := mesh as MeshInstance3D
		if istanza == null or istanza.mesh == null:
			continue
		for superficie in istanza.mesh.get_surface_count():
			var originale := istanza.get_active_material(superficie) as BaseMaterial3D
			if originale == null or originale.emission_enabled:
				continue
			var scuro := originale.duplicate() as BaseMaterial3D
			scuro.albedo_color = (originale.albedo_color * tinta).lerp(Color(0.05, 0.04, 0.08), quanto)
			scuro.albedo_color.a = originale.albedo_color.a
			istanza.set_surface_override_material(superficie, scuro)


## Edificio danneggiato dagli zombie: annerito, fumo che sale e un cartello.
func _mostra_danni() -> void:
	for mesh in _mesh:
		var istanza := mesh as MeshInstance3D
		if istanza == null or istanza.mesh == null:
			continue
		for superficie in istanza.mesh.get_surface_count():
			var originale := istanza.get_active_material(superficie) as BaseMaterial3D
			if originale == null or originale.emission_enabled:
				continue
			var bruciato := originale.duplicate() as BaseMaterial3D
			bruciato.albedo_color = originale.albedo_color.lerp(Color(0.16, 0.12, 0.1), 0.45)
			bruciato.albedo_color.a = originale.albedo_color.a
			istanza.set_surface_override_material(superficie, bruciato)
	var fumo := CPUParticles3D.new()
	fumo.amount = 24
	fumo.lifetime = 4.0
	fumo.preprocess = 4.0
	fumo.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fumo.emission_box_extents = Vector3(1.2, 0.2, 0.8)
	fumo.direction = Vector3(0.2, 1, 0)
	fumo.spread = 12.0
	fumo.initial_velocity_min = 0.6
	fumo.initial_velocity_max = 1.1
	fumo.gravity = Vector3.ZERO
	fumo.scale_amount_min = 0.6
	fumo.scale_amount_max = 1.4
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.4))
	curva.add_point(Vector2(1, 1.6))
	fumo.scale_amount_curve = curva
	var nuvola := SphereMesh.new()
	nuvola.radius = 0.4
	nuvola.height = 0.8
	nuvola.radial_segments = 10
	nuvola.rings = 5
	var materiale := StandardMaterial3D.new()
	materiale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materiale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materiale.vertex_color_use_as_albedo = true
	nuvola.material = materiale
	fumo.mesh = nuvola
	var colori := Gradient.new()
	colori.set_color(0, Color(0.25, 0.22, 0.24, 0.75))
	colori.set_color(1, Color(0.45, 0.42, 0.46, 0.0))
	fumo.color_ramp = colori
	fumo.position = Vector3(0, altezza() * 0.8, 0.6)
	add_child(fumo)
	var cartello := Label3D.new()
	cartello.text = "DANNEGGIATO"
	cartello.font_size = 52
	cartello.pixel_size = 0.009
	cartello.outline_size = 18
	cartello.modulate = Color("#ffd0c4")
	cartello.outline_modulate = Color("#8a1f17")
	cartello.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cartello.no_depth_test = true
	cartello.render_priority = 3
	cartello.position = Vector3(0, 1.4, 2.6)
	add_child(cartello)


func imposta_selezione(attivo: bool) -> void:
	if _evidenziatore == null:
		var materiale := StandardMaterial3D.new()
		materiale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		materiale.albedo_color = COLORE_SELEZIONE
		materiale.emission_enabled = true
		materiale.emission = COLORE_SELEZIONE
		materiale.emission_energy_multiplier = 1.5
		var forma := BoxMesh.new()
		forma.size = Vector3(LARGHEZZA - 0.6, 0.04, 0.22)
		_evidenziatore = MeshInstance3D.new()
		_evidenziatore.mesh = forma
		_evidenziatore.material_override = materiale
		_evidenziatore.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_evidenziatore.position = Vector3(0, 0.1, 3.35)
		add_child(_evidenziatore)
	_evidenziatore.visible = attivo


## Barra di avanzamento e conto alla rovescia sopra il cantiere.
func _crea_avanzamento() -> void:
	_barra = Node3D.new()
	_barra.position = Vector3(0, altezza() + (0.0 if dati["stato"] == StatoGioco.CANTIERE else 0.6), 1.4)
	if dati["stato"] == StatoGioco.MURA:
		_barra.position = Vector3(-0.6, altezza() + 0.8, 9.2)   # sopra il cancello
	add_child(_barra)
	var sfondo := MeshInstance3D.new()
	var forma_sfondo := BoxMesh.new()
	forma_sfondo.size = Vector3(2.6, 0.32, 0.06)
	sfondo.mesh = forma_sfondo
	sfondo.material_override = _materiale_piatto(Color("#2b2230"))
	sfondo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_barra.add_child(sfondo)
	_riempimento = MeshInstance3D.new()
	var forma := BoxMesh.new()
	forma.size = Vector3(2.44, 0.2, 0.08)
	_riempimento.mesh = forma
	_riempimento.material_override = _materiale_piatto(Color("#e3b448"))
	_riempimento.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_barra.add_child(_riempimento)
	_conto = Label3D.new()
	_conto.font_size = 56
	_conto.pixel_size = 0.008
	_conto.outline_size = 18
	_conto.modulate = Color("#f4e4c1")
	_conto.outline_modulate = Color("#2b2230")
	_conto.position = Vector3(0, 0.55, 0)
	_barra.add_child(_conto)
	aggiorna_avanzamento()


func _materiale_piatto(colore: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colore
	return m


func aggiorna_avanzamento() -> void:
	if _barra == null:
		return
	var quota := StatoGioco.avanzamento(indice)
	_riempimento.scale.x = maxf(quota, 0.001)
	_riempimento.position.x = -1.22 * (1.0 - quota)
	var nome: String = StatoGioco.nome_lotto(indice) if dati["stato"] == StatoGioco.MURA else Bilanciamento.EDIFICI[dati["edificio"]]["nome"]
	if dati.has("potenzia"):
		nome += " → Liv. %d" % int(dati["potenzia"]["livello"])
	_conto.text = "%s  ·  %s" % [nome, Bilanciamento.formatta_conto(StatoGioco.secondi_rimanenti(indice))]


func _process(delta: float) -> void:
	_tempo += delta
	if _barra != null:
		aggiorna_avanzamento()
	if _produzione != null:
		_aggiorna_produzione()
	if _scritta_officina != null:
		_aggiorna_scritta_officina()


func altezza() -> float:
	return _cima if _cima > 0.0 else 5.0


## Edifici senza modello proprio: usano quello delle case con il nome sopra.
func _aggiungi_nome_provvisorio() -> void:
	var nome := Label3D.new()
	nome.text = Bilanciamento.EDIFICI[dati["edificio"]]["nome"].to_upper()
	nome.font_size = 56
	nome.pixel_size = 0.009
	nome.modulate = Color("#f4e4c1")
	nome.outline_modulate = Color("#5b3a29")
	nome.outline_size = 20
	nome.position = Vector3(0, 3.6, 2.2)
	_radice.add_child(nome)


# ------------------------------------------------------------------ produzione


## Sopra gli edifici che producono: una barra che si riempie e, quando c'è
## qualcosa da raccogliere, l'icona della risorsa che saltella.
func _crea_indicatore_produzione() -> void:
	var risorsa: String = Bilanciamento.EDIFICI[dati["edificio"]]["produce"]
	_produzione = Node3D.new()
	_produzione.position = Vector3(0, altezza() + 0.35, 1.2)
	add_child(_produzione)

	var sfondo := MeshInstance3D.new()
	var forma_sfondo := BoxMesh.new()
	forma_sfondo.size = Vector3(1.9, 0.22, 0.05)
	sfondo.mesh = forma_sfondo
	sfondo.material_override = _materiale_piatto(Color("#2b2230"))
	sfondo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_produzione.add_child(sfondo)
	_barra_produzione = MeshInstance3D.new()
	var forma := BoxMesh.new()
	forma.size = Vector3(1.78, 0.12, 0.07)
	_barra_produzione.mesh = forma
	_barra_produzione.material_override = _materiale_piatto(Color("#8fc96b"))
	_barra_produzione.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_produzione.add_child(_barra_produzione)

	_icona_pronta = Sprite3D.new()
	_icona_pronta.texture = load(Bilanciamento.RISORSE[risorsa]["icona"])
	_icona_pronta.pixel_size = 0.016
	_icona_pronta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icona_pronta.no_depth_test = true
	_icona_pronta.render_priority = 2
	_icona_pronta.position = Vector3(0, 0.95, 0)
	_produzione.add_child(_icona_pronta)
	_numero_pronto = Label3D.new()
	_numero_pronto.font_size = 44
	_numero_pronto.pixel_size = 0.008
	_numero_pronto.outline_size = 16
	_numero_pronto.modulate = Color("#f4e4c1")
	_numero_pronto.outline_modulate = Color("#2b2230")
	_numero_pronto.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_numero_pronto.no_depth_test = true
	_numero_pronto.render_priority = 3
	_numero_pronto.position = Vector3(0.55, 0.62, 0)
	_produzione.add_child(_numero_pronto)
	_aggiorna_produzione()


func _aggiorna_produzione() -> void:
	var stato := StatoGioco.stato_produzione(indice)
	var quota: float = stato["avanzamento"]
	_barra_produzione.scale.x = maxf(quota, 0.001)
	_barra_produzione.position.x = -0.89 * (1.0 - quota)
	var pronto: bool = stato["cicli"] > 0
	_icona_pronta.visible = pronto
	_numero_pronto.visible = pronto
	if pronto:
		_numero_pronto.text = "%d" % stato["pronto"]
		var salto := absf(sin(_tempo * 3.2)) * 0.25
		_icona_pronta.position.y = 0.95 + salto
		_numero_pronto.position.y = 0.62 + salto
		_numero_pronto.modulate = Color("#e3b448") if stato["pieno"] else Color("#f4e4c1")


func ha_produzione_pronta() -> bool:
	return StatoGioco.produce(indice) and StatoGioco.stato_produzione(indice)["cicli"] > 0


## Scritta "+12" che sale e svanisce dopo una raccolta.
func mostra_guadagno(risorsa: String, quantita: int) -> void:
	var scritta := Label3D.new()
	scritta.text = "+%d %s" % [quantita, Bilanciamento.RISORSE[risorsa]["nome"].to_lower()]
	scritta.font_size = 56
	scritta.pixel_size = 0.0075
	scritta.outline_size = 20
	scritta.modulate = Color("#ffe08a")
	scritta.outline_modulate = Color("#2b2230")
	scritta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	scritta.no_depth_test = true
	scritta.render_priority = 4
	scritta.position = Vector3(0, altezza() * 0.75, 2.4)
	add_child(scritta)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(scritta, "position:y", scritta.position.y + 1.1, 1.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(scritta, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tween.chain().tween_callback(scritta.queue_free)
	rimbalza()


## Durante il potenziamento: pali e tavole davanti alla facciata e coni.
func _aggiungi_impalcatura() -> void:
	var acciaio := StandardMaterial3D.new()
	acciaio.albedo_color = Color("#9aa3ab")
	acciaio.metallic = 0.5
	acciaio.roughness = 0.4
	var legno := StandardMaterial3D.new()
	legno.albedo_color = Color("#a8744a")
	var arancio := StandardMaterial3D.new()
	arancio.albedo_color = Color("#ef7d2d")
	var altezza_impalcatura := altezza() * 0.85
	for x in [-2.2, -0.7, 0.7, 2.2]:
		var palo := MeshInstance3D.new()
		var forma := CylinderMesh.new()
		forma.top_radius = 0.05
		forma.bottom_radius = 0.05
		forma.height = altezza_impalcatura
		palo.mesh = forma
		palo.material_override = acciaio
		palo.position = Vector3(x, altezza_impalcatura / 2.0, 2.3)
		add_child(palo)
	for y in [altezza_impalcatura * 0.4, altezza_impalcatura * 0.8]:
		var tavola := MeshInstance3D.new()
		var forma_tavola := BoxMesh.new()
		forma_tavola.size = Vector3(4.6, 0.08, 0.5)
		tavola.mesh = forma_tavola
		tavola.material_override = legno
		tavola.position = Vector3(0, y, 2.3)
		add_child(tavola)
	for x in [-2.6, 2.6]:
		var cono := MeshInstance3D.new()
		var forma_cono := CylinderMesh.new()
		forma_cono.top_radius = 0.03
		forma_cono.bottom_radius = 0.2
		forma_cono.height = 0.55
		cono.mesh = forma_cono
		cono.material_override = arancio
		cono.position = Vector3(x, 0.3, 3.0)
		add_child(cono)


## Comparsa dopo un cambio (cantiere aperto o edificio finito).
func compari() -> void:
	_radice.scale = Vector3(1.0, 0.05, 1.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_radice, "scale", Vector3.ONE, 0.45)


## Piccolo rimbalzo quando il lotto viene toccato.
func rimbalza() -> void:
	var tween := create_tween()
	tween.tween_property(_radice, "scale", Vector3(1.05, 0.94, 1.05), 0.08)
	tween.tween_property(_radice, "scale", Vector3(0.97, 1.04, 0.97), 0.1)
	tween.tween_property(_radice, "scale", Vector3.ONE, 0.12)


# ------------------------------------------------------------------ officina


## Sopra l'Officina al lavoro: cosa c'è sul banco e quanto manca.
func _crea_scritta_officina() -> void:
	_scritta_officina = Label3D.new()
	_scritta_officina.font_size = 44
	_scritta_officina.pixel_size = 0.008
	_scritta_officina.outline_size = 16
	_scritta_officina.modulate = Color("#f4e4c1")
	_scritta_officina.outline_modulate = Color("#2b2230")
	_scritta_officina.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_scritta_officina.no_depth_test = true
	_scritta_officina.render_priority = 2
	_scritta_officina.position = Vector3(0, altezza() + 0.5, 1.2)
	add_child(_scritta_officina)
	_aggiorna_scritta_officina()


func _aggiorna_scritta_officina() -> void:
	var stato := StatoGioco.stato_fabbrica(indice)
	var nome := ""
	if not stato.is_empty():
		nome = Bilanciamento.nome_oggetto(stato["oggetto"])
	else:
		stato = StatoGioco.stato_appello(indice)
		nome = "IN ONDA"
	if stato.is_empty():
		_scritta_officina.visible = false
		return
	if float(stato["secondi"]) < 0.0:
		_scritta_officina.text = "%s  ·  fermo" % nome
	else:
		_scritta_officina.text = "%s  ·  %s" % [nome, Bilanciamento.formatta_conto(stato["secondi"])]
