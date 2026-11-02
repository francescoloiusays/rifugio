extends Node
## Effetti sonori e musica. Tutti i suoni sono generati da
## strumenti/genera_suoni.py (sintetizzati, niente file esterni).
## Le preferenze (musica ed effetti sì/no) si salvano a parte dalla partita.

const CARTELLA := "res://assets/suoni/"
const PERCORSO_IMPOSTAZIONI := "user://impostazioni.cfg"
const VOCI := 10
## Volume di ogni suono, in decibel: alcuni sono naturalmente più forti.
const VOLUMI := {
	"clic": -14.0, "raccolta": -6.0, "costruito": -5.0, "livello": -3.0, "notifica": -12.0,
	"sparo": -10.0, "sparo_pesante": -8.0, "colpo": -12.0, "zombie_1": -14.0, "zombie_2": -14.0,
	"zombie_3": -14.0, "esplosione": -4.0, "allarme": -13.0, "vittoria": -4.0, "sconfitta": -4.0,
	"radio": -8.0, "martello": -8.0, "porta": -6.0,
}
const VOLUME_MUSICA := -15.0

var musica_attiva := true
var effetti_attivi := true
var _voci: Array[AudioStreamPlayer] = []
var _prossima := 0
var _flussi := {}
var _musica: AudioStreamPlayer
var _brano := ""
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_leggi_impostazioni()
	for i in VOCI:
		var voce := AudioStreamPlayer.new()
		add_child(voce)
		_voci.append(voce)
	_musica = AudioStreamPlayer.new()
	add_child(_musica)
	for nome in VOLUMI:
		var flusso := load(CARTELLA + nome + ".wav") as AudioStream
		if flusso != null:
			_flussi[nome] = flusso
	StatoGioco.raccolto.connect(func(_i: int, _r: String, _q: int) -> void: suona("raccolta"))
	StatoGioco.livello_cambiato.connect(_su_livello)
	StatoGioco.sopravvissuto_arrivato.connect(func() -> void:
		if not StatoGioco.sopravvissuto.is_empty():
			suona("porta"))
	StatoGioco.attacco_cambiato.connect(func() -> void:
		if StatoGioco.attacco_pronto:
			suona("allarme"))


var _livello_sentito := -1


func _su_livello() -> void:
	# il segnale arriva anche all'avvio: suona solo quando la città sale davvero
	if _livello_sentito >= 0 and StatoGioco.livello_citta > _livello_sentito:
		suona("livello")
	_livello_sentito = StatoGioco.livello_citta


## Suona un effetto. variazione: piccolo cambio di tono, così i suoni
## ripetuti (spari, colpi) non sono tutti uguali.
func suona(nome: String, variazione := 0.06, volume_extra := 0.0) -> void:
	if not effetti_attivi or not _flussi.has(nome):
		return
	var voce := _voci[_prossima]
	_prossima = (_prossima + 1) % VOCI
	voce.stream = _flussi[nome]
	voce.volume_db = float(VOLUMI.get(nome, -8.0)) + volume_extra
	voce.pitch_scale = 1.0 + randf_range(-variazione, variazione)
	voce.play()


## Cambia musica con una dissolvenza. "" la ferma.
func musica(nome: String) -> void:
	if nome == _brano and _musica.playing:
		return
	_brano = nome
	if _tween != null:
		_tween.kill()
	if nome == "" or not musica_attiva:
		_musica.stop()
		return
	var flusso := load(CARTELLA + "musica_" + nome + ".wav") as AudioStreamWAV
	if flusso == null:
		return
	flusso = flusso.duplicate() as AudioStreamWAV
	flusso.loop_mode = AudioStreamWAV.LOOP_FORWARD
	flusso.loop_begin = 0
	flusso.loop_end = int(flusso.get_length() * flusso.mix_rate)
	_musica.stream = flusso
	_musica.volume_db = -40.0
	_musica.play()
	_tween = create_tween()
	_tween.tween_property(_musica, "volume_db", VOLUME_MUSICA, 1.5)


func imposta_musica(attiva: bool) -> void:
	musica_attiva = attiva
	var brano := _brano
	_brano = ""
	if attiva:
		musica(brano)
	else:
		_musica.stop()
		_brano = brano
	_scrivi_impostazioni()


func imposta_effetti(attivi: bool) -> void:
	effetti_attivi = attivi
	_scrivi_impostazioni()


func _leggi_impostazioni() -> void:
	var file := ConfigFile.new()
	if file.load(PERCORSO_IMPOSTAZIONI) == OK:
		musica_attiva = bool(file.get_value("audio", "musica", true))
		effetti_attivi = bool(file.get_value("audio", "effetti", true))


func _scrivi_impostazioni() -> void:
	var file := ConfigFile.new()
	file.load(PERCORSO_IMPOSTAZIONI)
	file.set_value("audio", "musica", musica_attiva)
	file.set_value("audio", "effetti", effetti_attivi)
	file.save(PERCORSO_IMPOSTAZIONI)
