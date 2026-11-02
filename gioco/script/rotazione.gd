extends CanvasLayer
## Telefono: in verticale il gioco non ci sta, quindi copre tutto e chiede di
## girarlo; in orizzontale ingrandisce l'interfaccia, che altrimenti sarebbe
## minuscola. Vale in città e in battaglia.

## Risoluzione di riferimento sul telefono: più piccola = tutto più grande.
const RISOLUZIONE_TELEFONO := Vector2i(1024, 576)
const RISOLUZIONE_NORMALE := Vector2i(1280, 720)

var _copertura: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_adatta_scala()
	get_window().size_changed.connect(_adatta_scala)
	_copertura = ColorRect.new()
	_copertura.color = Color("#2b2230")
	_copertura.set_anchors_preset(Control.PRESET_FULL_RECT)
	_copertura.mouse_filter = Control.MOUSE_FILTER_STOP
	_copertura.visible = false
	add_child(_copertura)
	var testo := Label.new()
	testo.text = "⟲\nGira il telefono in orizzontale"
	testo.add_theme_font_size_override("font_size", 40)
	testo.add_theme_color_override("font_color", Color("#f4e4c1"))
	testo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	testo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	testo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_copertura.add_child(testo)


## Sul telefono, e in una finestra piccola (meno di 1280×720 punti),
## l'interfaccia usa la risoluzione di riferimento ridotta: le scritte restano
## leggibili invece di rimpicciolirsi insieme alla finestra.
func _adatta_scala() -> void:
	var telefono := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") \
			or (OS.has_feature("web") and DisplayServer.is_touchscreen_available())
	var finestra := Vector2(get_window().size) / maxf(1.0, DisplayServer.screen_get_scale())
	var piccola := finestra.x < RISOLUZIONE_NORMALE.x or finestra.y < RISOLUZIONE_NORMALE.y
	var voluta := RISOLUZIONE_TELEFONO if telefono or piccola else RISOLUZIONE_NORMALE
	if get_window().content_scale_size != voluta:
		get_window().content_scale_size = voluta


func _process(_delta: float) -> void:
	var dimensioni := get_viewport().get_visible_rect().size
	_copertura.visible = dimensioni.y > dimensioni.x * 1.05
