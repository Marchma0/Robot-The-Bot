class_name GuitarStage
extends StaticBody3D
## Scène « Rock Garage » : mini-jeu de guitare électrique en QTE (roadmap 4.4).
## Un nain appuie sur le bouton de départ (ou sur la guitare) pour lancer un solo de 10 accords :
## l'écran de scène affiche la note attendue (▲ ▼ ◄ ►) et la pédale correspondante s'allume.
## Le guitariste peut appuyer sur les 4 pédales fléchées devant le retour de scène (ou utiliser ses
## touches de direction s'il est le soliste en cours) avant la fin du temps de chaque mesure.
## Chaque accord réussi joue un power-chord de guitare saturée sur les amplis à lampes, fait jaillir
## des étincelles et monte le combo ainsi que le record du garage.
##
## Réseau : l'hôte est seul autoritaire sur `playing`, `rocker_peer`, `rocker_name`, `step_index`,
## `current_arrow`, `score`, `combo`, `best_score` et `best_name` (répliqués par MultiplayerSynchronizer).
## Les accords joués déclenchent un RPC `authority, call_local` pour le son de guitare et les étincelles.

const SONG_STEPS: int = 10
const NOTE_TIME: float = 2.6
const SCREEN_SIZE: Vector2i = Vector2i(480, 320)
const SAMPLE_RATE: float = 22050.0
const FONT: FontVariation = preload("res://assets/fonts/fredoka.tres")
const SCREEN_SHADER: Shader = preload("res://scenes/mecha/controls/camera_feed_screen.gdshader")
const ARROW_GLYPHS: Array[String] = ["▲", "▼", "◄", "►"]
const ARROW_COLORS: Array[Color] = [
	Color(0.30, 0.95, 0.45),
	Color(0.35, 0.75, 1.0),
	Color(1.0, 0.78, 0.22),
	Color(1.0, 0.38, 0.32),
]
## Fréquences fondamentales (Hz) d'un riff rock pentatonique (Mi, Sol, La, Si, Ré, Mi aigu).
const RIFF_FREQS: Array[float] = [164.81, 196.00, 220.00, 246.94, 293.66, 329.63, 293.66, 246.94, 220.00, 329.63]

## Vrai quand un solo de guitare est en cours. Autorité : hôte.
var playing: bool = false
## Peer id du guitariste en scène (0 = personne). Autorité : hôte.
var rocker_peer: int = 0
var rocker_name: String = ""
## Indice de la note actuelle dans le solo (0 .. SONG_STEPS - 1). Autorité : hôte.
var step_index: int = 0
## Flèche attendue (0 haut, 1 bas, 2 gauche, 3 droite). Autorité : hôte.
var current_arrow: int = 0
## Temps restant pour jouer la note actuelle (s). Autorité : hôte.
var note_timer: float = 0.0
var score: int = 0
var combo: int = 0
var best_score: int = 0
var best_name: String = ""

var _title_lbl: Label
var _arrow_lbl: Label
var _info_lbl: Label
var _record_lbl: Label
var _spark_timer: float = 0.0
var _chord_freq: float = 0.0
var _chord_time: float = 0.0
var _chord_phase: float = 0.0
var _playback: AudioStreamGeneratorPlayback = null
var _pads: Array[PushButton] = []

@onready var _start_btn: PushButton = %StartButton
@onready var _pad_up: PushButton = %PadUp
@onready var _pad_down: PushButton = %PadDown
@onready var _pad_left: PushButton = %PadLeft
@onready var _pad_right: PushButton = %PadRight
@onready var _guitar_prop: Node3D = %GuitarProp
@onready var _screen: MeshInstance3D = %Screen
@onready var _viewport: SubViewport = %ScreenViewport
@onready var _stage_light: OmniLight3D = %StageLight
@onready var _sparks: Node3D = %Sparks
@onready var _audio: AudioStreamPlayer3D = %AmpAudio


func _ready() -> void:
	_pads = [_pad_up, _pad_down, _pad_left, _pad_right]
	_build_screen()
	_setup_audio()
	_start_btn.pressed.connect(_on_start_pressed)
	for i: int in _pads.size():
		_pads[i].pressed.connect(_on_pad_pressed.bind(i))
	NetworkManager.session_ended.connect(func(_reason: String) -> void: _stop_song(false))


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not playing:
		return
	note_timer -= delta
	if note_timer <= 0.0:
		# Note manquée : combo remis à zéro, on passe à la mesure suivante.
		combo = 0
		_play_chord_fx.rpc(92.5, false)
		_advance_note()


func _process(delta: float) -> void:
	_fill_audio(delta)
	_spark_timer = maxf(_spark_timer - delta, 0.0)
	_sparks.visible = _spark_timer > 0.0
	if _spark_timer > 0.0:
		_sparks.rotation.y += delta * 14.0
		_stage_pulse(delta)
	else:
		_stage_light.light_energy = 1.6 if playing else 0.9
		_stage_light.light_color = Color(1.0, 0.55, 0.22) if playing else Color(1.0, 0.85, 0.65)

	for i: int in _pads.size():
		_pads[i].lit = playing and current_arrow == i
	_start_btn.lit = not playing

	# La guitare flotte et vibre au centre de la scène pendant un solo, sinon elle repose sur son stand.
	if playing:
		var t: float = float(Time.get_ticks_msec()) * 0.006
		_guitar_prop.position = Vector3(0.0, 0.82 + sin(t * 2.0) * 0.05, 0.05)
		_guitar_prop.rotation = Vector3(0.15, sin(t) * 0.35, -0.35 + sin(t * 3.0) * 0.08)
	else:
		_guitar_prop.position = Vector3(0.55, 0.58, 0.35)
		_guitar_prop.rotation = Vector3(-0.2, 0.4, -0.18)

	_update_screen()


func _stage_pulse(_delta: float) -> void:
	_stage_light.light_energy = 3.2
	_stage_light.light_color = ARROW_COLORS[clampi(current_arrow, 0, ARROW_COLORS.size() - 1)]


func _on_start_pressed(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if playing:
		_stop_song(true)
		return
	playing = true
	rocker_peer = peer_id
	rocker_name = Dwarf.name_of_peer(peer_id)
	score = 0
	combo = 0
	step_index = 0
	current_arrow = (peer_id + step_index) % 4
	note_timer = NOTE_TIME
	_play_chord_fx.rpc(RIFF_FREQS[0], true)


func _on_pad_pressed(_peer_id: int, arrow_idx: int) -> void:
	if not multiplayer.is_server() or not playing:
		return
	if arrow_idx == current_arrow:
		combo += 1
		score += 100 + combo * 25
		var freq: float = RIFF_FREQS[posmod(step_index, RIFF_FREQS.size())]
		_play_chord_fx.rpc(freq, true)
		_advance_note()
	else:
		combo = 0
		_play_chord_fx.rpc(98.0, false)


func _advance_note() -> void:
	step_index += 1
	if step_index >= SONG_STEPS:
		_stop_song(true)
		return
	current_arrow = posmod(current_arrow + 1 + (step_index % 2), 4)
	note_timer = NOTE_TIME


func _stop_song(record_score: bool) -> void:
	if record_score and score > best_score:
		best_score = score
		best_name = rocker_name
	playing = false
	note_timer = 0.0


@rpc("authority", "call_local", "reliable")
func _play_chord_fx(freq: float, hit: bool) -> void:
	_chord_freq = freq
	_chord_time = 0.38 if hit else 0.22
	if hit:
		_spark_timer = 0.35


func _setup_audio() -> void:
	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.12
	_audio.stream = gen
	_audio.play()
	_playback = _audio.get_stream_playback() as AudioStreamGeneratorPlayback


func _fill_audio(delta: float) -> void:
	if _playback == null:
		return
	if _chord_time > 0.0:
		_chord_time = maxf(_chord_time - delta, 0.0)
	var frames: int = _playback.get_frames_available()
	for _i: int in range(frames):
		if _chord_time <= 0.0 or _chord_freq <= 0.0:
			_playback.push_frame(Vector2.ZERO)
			continue
		_chord_phase += _chord_freq / SAMPLE_RATE
		# Accord de quinte (fondamentale + quinte 1.5x + octave 2x) avec légère saturation rock.
		var raw: float = sin(_chord_phase * TAU) * 0.55 + sin(_chord_phase * 1.5 * TAU) * 0.35 + sin(_chord_phase * 2.0 * TAU) * 0.20
		var env: float = clampf(_chord_time / 0.38, 0.0, 1.0)
		var sample: float = tanh(raw * 2.6) * 0.22 * env
		_playback.push_frame(Vector2(sample, sample))


func _build_screen() -> void:
	_viewport.size = SCREEN_SIZE
	var root: ColorRect = ColorRect.new()
	root.color = Color(0.08, 0.04, 0.10)
	root.size = Vector2(SCREEN_SIZE)
	_viewport.add_child(root)
	var col: VBoxContainer = VBoxContainer.new()
	col.position = Vector2(20, 14)
	col.size = Vector2(SCREEN_SIZE) - Vector2(40, 28)
	col.add_theme_constant_override(&"separation", 6)
	root.add_child(col)
	_title_lbl = _make_label(tr("GUITARE QTE"), 26, Color(1.0, 0.55, 0.22))
	col.add_child(_title_lbl)
	_arrow_lbl = _make_label("🎸", 76, Color(1.0, 0.88, 0.32))
	_arrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_arrow_lbl)
	_info_lbl = _make_label("", 26, Color(0.92, 0.95, 1.0))
	col.add_child(_info_lbl)
	_record_lbl = _make_label("", 22, Color(0.75, 0.88, 0.78))
	col.add_child(_record_lbl)

	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SCREEN_SHADER
	mat.set_shader_parameter(&"feed", _viewport.get_texture())
	mat.set_shader_parameter(&"tint", Color(1.0, 0.92, 0.85))
	mat.set_shader_parameter(&"noise", 0.10)
	_screen.material_override = mat


func _update_screen() -> void:
	if playing:
		var idx: int = clampi(current_arrow, 0, ARROW_GLYPHS.size() - 1)
		_title_lbl.text = "%s — %d / %d" % [rocker_name if rocker_name != "" else tr("SOLO"), step_index + 1, SONG_STEPS]
		_arrow_lbl.text = ARROW_GLYPHS[idx]
		_arrow_lbl.modulate = ARROW_COLORS[idx]
		_info_lbl.text = "%s : %d   (x%d)" % [tr("Score"), score, maxi(combo, 1)]
	else:
		_title_lbl.text = tr("SCÈNE GUITARE QTE")
		_arrow_lbl.text = "◄ ▲ ▼ ►"
		_arrow_lbl.modulate = Color(1.0, 0.82, 0.28)
		_info_lbl.text = "%s : %d" % [tr("Dernier score"), score] if score > 0 else tr("Bouton vert : lancer le solo")
	if best_score > 0:
		_record_lbl.text = "%s : %d (%s)" % [tr("Record"), best_score, best_name]
	else:
		_record_lbl.text = tr("Pédales fléchées : jouer la note")


func _make_label(text: String, size: int, color: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_override(&"font", FONT)
	lbl.add_theme_font_size_override(&"font_size", size)
	lbl.add_theme_color_override(&"font_color", color)
	return lbl
