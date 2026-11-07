class_name MissionTerminal
extends StaticBody3D
## Terminal de mission devant le robot, au camp (M12).
## Tirer le grand levier arme la mission : un compte à rebours démarre, l'écran dit « montez à bord »
## et le gyrophare clignote. Dès que tous les nains sont dans le robot, la mission part
## (MissionDirector.start_mission). Si le compte à rebours se termine avant, la mission est annulée.
##
## Réseau : le levier est un Lever (déjà synchronisé, l'hôte valide qui le tient). L'hôte est autoritaire
## sur `countdown` (répliqué). L'écran et le gyrophare sont calculés localement par chaque peer
## (le nombre de nains à bord se déduit de leurs places, déjà synchronisées).

## Temps laissé pour monter à bord après avoir tiré le levier (s).
const ARM_TIME: float = 20.0
## Le levier compte comme tiré au-delà de cette inclinaison (dans un sens ou dans l'autre).
const PULL_THRESHOLD: float = 0.85
const SCREEN_SIZE: Vector2i = Vector2i(512, 344)
const FONT: FontVariation = preload("res://assets/fonts/fredoka.tres")
const SCREEN_SHADER: Shader = preload("res://scenes/mecha/controls/camera_feed_screen.gdshader")
const COLOR_IDLE: Color = Color(0.55, 1.0, 0.75)
const COLOR_ARMED: Color = Color(1.0, 0.72, 0.3)

@export var mission_id: StringName = &"test_ground"
@export var mission_title: String = "Terrain d'essai"

## Temps restant pour monter à bord (0 = mission pas armée). Autorité : hôte.
var countdown: float = 0.0

var _was_pulled: bool = false
var _title: Label
var _status: Label
var _crew: Label
var _blink: float = 0.0

@onready var _lever: Lever = %Lever
@onready var _screen: MeshInstance3D = %Screen
@onready var _viewport: SubViewport = %ScreenViewport
@onready var _beacon: OmniLight3D = %Beacon


func _ready() -> void:
	_build_screen()
	NetworkManager.session_ended.connect(func(_reason: String) -> void: countdown = 0.0)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var director: MissionDirector = _director()
	if director == null or not director.in_lobby():
		countdown = 0.0
		return
	var pulled: bool = absf(_lever.value.y) > PULL_THRESHOLD
	if pulled and not _was_pulled and countdown <= 0.0:
		countdown = ARM_TIME
	_was_pulled = pulled
	if countdown > 0.0:
		countdown = maxf(countdown - delta, 0.0)
		if director.everyone_aboard() and director.start_mission(mission_id):
			countdown = 0.0


func _process(delta: float) -> void:
	var director: MissionDirector = _director()
	if director == null:
		return
	var count: Vector2i = director.count_aboard()
	_crew.text = "à bord : %d / %d" % [count.x, count.y]
	_blink += delta
	if countdown > 0.0:
		_status.text = "Montez à bord !  %d" % ceili(countdown)
		_status.modulate = COLOR_ARMED
		_beacon.light_color = COLOR_ARMED
		_beacon.light_energy = 2.5 if fmod(_blink, 0.6) < 0.3 else 0.2
	else:
		_status.text = "Tirez le levier"
		_status.modulate = COLOR_IDLE
		_beacon.light_color = COLOR_IDLE
		_beacon.light_energy = 0.8


func _director() -> MissionDirector:
	return get_tree().get_first_node_in_group(&"mission_director") as MissionDirector


## L'écran : une petite interface dans un SubViewport, affichée en vieux moniteur (même shader que les postes).
func _build_screen() -> void:
	_viewport.size = SCREEN_SIZE
	var root: ColorRect = ColorRect.new()
	root.color = Color(0.05, 0.09, 0.07)
	root.size = Vector2(SCREEN_SIZE)
	_viewport.add_child(root)
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(28, 26)
	column.size = Vector2(SCREEN_SIZE) - Vector2(56, 52)
	column.add_theme_constant_override(&"separation", 18)
	root.add_child(column)
	var caption: Label = _label("MISSION", 26, Color(0.55, 0.8, 0.65))
	column.add_child(caption)
	_title = _label(mission_title, 52, Color(0.85, 1.0, 0.9))
	column.add_child(_title)
	_status = _label("", 40, COLOR_IDLE)
	column.add_child(_status)
	_crew = _label("", 32, Color(0.7, 0.9, 0.8))
	column.add_child(_crew)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SCREEN_SHADER
	material.set_shader_parameter(&"feed", _viewport.get_texture())
	material.set_shader_parameter(&"tint", Color(0.85, 1.0, 0.9))
	material.set_shader_parameter(&"noise", 0.12)
	_screen.material_override = material


func _label(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	return label
