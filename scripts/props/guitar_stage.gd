class_name GuitarStage
extends StaticBody3D
## Scène « Rock Garage » : mini-jeu de guitare électrique en QTE (roadmap 4.4).
## Un nain appuie sur le bouton vert pour lancer un solo de 10 accords endiablés :
## - Les notes s'accélèrent au fur et à mesure du morceau !
## - Jouable en solo ou en DUO coop : un allié peut écraser les pédales sur scène pour sauver le solo (bonus Duo !).
## - Les fausses notes font chauffer et fumer les amplis à lampes.
## - À 3 erreurs : L'AMPLI EXPLOSE dans un grand fracas et catapulte les rockers hors de la scène !
## - Si le solo arrive au bout : feu d'artifice d'étincelles et titre de « LÉGENDE DU ROCK ».
##
## Réseau : l'hôte est autoritaire sur la progression, le score, les fautes et le statut.
## Les accords, la fumée, les sons rock et l'explosion passent par RPC `authority, call_local` et `Dwarf.knock_peer`.

const SONG_STEPS: int = 10
const NOTE_TIME_START: float = 2.4
const NOTE_TIME_END: float = 1.15
const MAX_MISTAKES: int = 3
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
var mistakes: int = 0
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
		# Temps écoulé pour cette note : faute !
		combo = 0
		mistakes += 1
		_play_mistake_fx.rpc(mistakes)
		if mistakes >= MAX_MISTAKES:
			_explode_amp()
		else:
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
		var t: float = float(Time.get_ticks_msec()) * 0.008
		_guitar_prop.position = Vector3(0.0, 0.82 + sin(t * 2.0) * 0.06, 0.05)
		_guitar_prop.rotation = Vector3(0.15, sin(t) * 0.45, -0.35 + sin(t * 3.0) * 0.12)
	else:
		_guitar_prop.position = Vector3(0.55, 0.58, 0.35)
		_guitar_prop.rotation = Vector3(-0.2, 0.4, -0.18)

	_update_screen()


func _stage_pulse(_delta: float) -> void:
	_stage_light.light_energy = 3.6
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
	mistakes = 0
	step_index = 0
	current_arrow = (peer_id + step_index) % 4
	note_timer = _current_note_duration()
	_play_chord_fx.rpc(RIFF_FREQS[0], true)


func _on_pad_pressed(peer_id: int, arrow_idx: int) -> void:
	if not multiplayer.is_server() or not playing:
		return
	if arrow_idx == current_arrow:
		combo += 1
		var is_duo: bool = peer_id != rocker_peer and peer_id != 0
		var bonus: int = 150 if is_duo else 0
		score += 100 + combo * 30 + bonus
		var freq: float = RIFF_FREQS[posmod(step_index, RIFF_FREQS.size())]
		_play_chord_fx.rpc(freq, true)
		if is_duo:
			var helper: String = Dwarf.name_of_peer(peer_id)
			_play_duo_fx.rpc(helper)
		_advance_note()
	else:
		combo = 0
		mistakes += 1
		_play_mistake_fx.rpc(mistakes)
		if mistakes >= MAX_MISTAKES:
			_explode_amp()


func _advance_note() -> void:
	step_index += 1
	if step_index >= SONG_STEPS:
		_win_song()
		return
	current_arrow = posmod(current_arrow + 1 + (step_index % 2), 4)
	note_timer = _current_note_duration()


func _current_note_duration() -> float:
	var progress: float = float(step_index) / float(SONG_STEPS - 1)
	return lerpf(NOTE_TIME_START, NOTE_TIME_END, progress)


func _win_song() -> void:
	if score > best_score:
		best_score = score
		best_name = rocker_name
	_play_win_fx.rpc()
	playing = false
	note_timer = 0.0


func _explode_amp() -> void:
	playing = false
	note_timer = 0.0
	_play_explosion_fx.rpc()

	# Expulse tous les nains qui traînent sur l'estrade !
	var stage_center: Vector3 = global_position
	for node: Node in get_tree().get_nodes_in_group(&"dwarves"):
		var dwarf: Dwarf = node as Dwarf
		if dwarf == null:
			continue
		var dist: float = dwarf.global_position.distance_to(stage_center)
		if dist <= 3.4:
			var away: Vector3 = (dwarf.global_position - stage_center)
			away.y = 0.0
			var push_dir: Vector3 = away.normalized() if away.length() > 0.1 else -global_basis.z
			Dwarf.knock_peer(dwarf.peer_id, push_dir * 3.5 + Vector3.UP * 3.0)


func _stop_song(record_score: bool) -> void:
	if record_score and score > best_score:
		best_score = score
		best_name = rocker_name
	playing = false
	note_timer = 0.0


@rpc("authority", "call_local", "reliable")
func _play_chord_fx(freq: float, hit: bool) -> void:
	_chord_freq = freq
	_chord_time = 0.42 if hit else 0.22
	if hit:
		_spark_timer = 0.35


@rpc("authority", "call_local", "reliable")
func _play_duo_fx(helper_name: String) -> void:
	SfxSynth.play(self, &"fanfare", Vector3(0.0, 1.8, 0.0), -2.0, 1.2)
	PopText.spawn(self, Vector3(0.0, 2.2, -0.6), "%s : %s !" % [tr("DUO ROCK"), helper_name], Color(0.3, 1.0, 0.6), 1.3)
	FxBurst.spawn(self, Vector3(0.0, 1.5, -0.6), [Color(0.2, 0.9, 0.5), Color.WHITE], 20, 3.5)


@rpc("authority", "call_local", "reliable")
func _play_mistake_fx(cur_mistakes: int) -> void:
	_chord_freq = 92.5
	_chord_time = 0.28
	SfxSynth.play(self, &"buzzer", Vector3(0.0, 1.2, 0.5), 1.0, 1.3)
	var warn_color: Color = Color(1.0, 0.6, 0.2) if cur_mistakes == 1 else Color(1.0, 0.25, 0.15)
	var txt: String = "%s (%d/%d)" % [tr("FAUSSE NOTE !"), cur_mistakes, MAX_MISTAKES]
	PopText.spawn(self, Vector3(0.0, 2.1, -0.6), txt, warn_color, 1.2)
	# Fumée qui commence à s'échapper des baffles
	FxBurst.spawn(self, Vector3(-1.05, 1.2, 0.55), [Color(0.2, 0.2, 0.2), Color(0.4, 0.4, 0.4)], 10, 1.5, 0.12, 0.5, 1.5)
	FxBurst.spawn(self, Vector3(1.05, 1.2, 0.55), [Color(0.2, 0.2, 0.2), Color(0.4, 0.4, 0.4)], 10, 1.5, 0.12, 0.5, 1.5)


@rpc("authority", "call_local", "reliable")
func _play_explosion_fx() -> void:
	SfxSynth.play(self, &"boom", Vector3(0.0, 1.2, 0.55), 4.0)
	_stage_light.light_energy = 8.0
	_stage_light.light_color = Color(1.0, 0.3, 0.1)
	PopText.spawn(self, Vector3(0.0, 2.5, 0.0), tr("AMPLI EXPLOSÉ !"), Color(1.0, 0.15, 0.1), 1.8)
	FxBurst.spawn(self, Vector3(-1.05, 1.2, 0.55), [Color(1.0, 0.4, 0.1), Color(0.2, 0.2, 0.2), Color.WHITE], 32, 5.0)
	FxBurst.spawn(self, Vector3(1.05, 1.2, 0.55), [Color(1.0, 0.4, 0.1), Color(0.2, 0.2, 0.2), Color.WHITE], 32, 5.0)


@rpc("authority", "call_local", "reliable")
func _play_win_fx() -> void:
	SfxSynth.play(self, &"fanfare", Vector3(0.0, 2.0, 0.0), 3.0)
	PopText.spawn(self, Vector3(0.0, 2.8, -0.4), tr("LÉGENDE DU ROCK !"), Color(1.0, 0.85, 0.2), 1.8)
	FxBurst.spawn(self, Vector3(0.0, 2.2, 0.0), [Color(1.0, 0.85, 0.2), Color(1.0, 0.4, 0.1), Color.WHITE], 40, 5.5)


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
		var raw: float = sin(_chord_phase * TAU) * 0.55 + sin(_chord_phase * 1.5 * TAU) * 0.35 + sin(_chord_phase * 2.0 * TAU) * 0.20
		var env: float = clampf(_chord_time / 0.42, 0.0, 1.0)
		var sample: float = tanh(raw * 2.8) * 0.25 * env
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
		var f_str: String = "🔥" if mistakes == 2 else ("⚠️" if mistakes == 1 else "")
		_info_lbl.text = "%s : %d   (x%d) %s" % [tr("Score"), score, maxi(combo, 1), f_str]
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
