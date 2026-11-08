class_name MissionTerminal
extends StaticBody3D
## Terminal de mission devant le robot, au camp (M12.1).
## Les deux flèches choisissent la mission (écran : titre, « ◄ 1 / 3 ► »), le gros bouton vert la lance :
## un compte à rebours démarre, l'écran dit « montez à bord » et le gyrophare clignote. Dès que tous les nains
## sont dans le robot, la mission part (MissionDirector.start_mission). Si le compte à rebours se termine
## avant, elle est annulée ; un second appui sur le bouton vert l'annule aussi.
##
## Réseau : les boutons sont des PushButton (l'hôte valide l'appui et émet `pressed`). L'hôte est autoritaire
## sur `selected` et `countdown` (répliqués). L'écran et le gyrophare sont calculés localement par chaque peer
## (le nombre de nains à bord se déduit de leurs places, déjà synchronisées).

## Temps laissé pour monter à bord après avoir lancé (s).
const ARM_TIME: float = 20.0
const SCREEN_SIZE: Vector2i = Vector2i(512, 336)
const FONT: FontVariation = preload("res://assets/fonts/fredoka.tres")
const SCREEN_SHADER: Shader = preload("res://scenes/mecha/controls/camera_feed_screen.gdshader")
const COLOR_IDLE: Color = Color(0.55, 1.0, 0.75)
const COLOR_ARMED: Color = Color(1.0, 0.72, 0.3)
const COLOR_LOCKED: Color = Color(0.55, 0.62, 0.58)

## Mission choisie (indice dans MissionDirector.MISSIONS). Autorité : hôte.
var selected: int = 0
## Temps restant pour monter à bord (0 = mission pas lancée). Autorité : hôte.
var countdown: float = 0.0

var _title: Label
var _pager: Label
var _status: Label
var _crew: Label
var _blink: float = 0.0

@onready var _prev: PushButton = %Prev
@onready var _next: PushButton = %Next
@onready var _launch: PushButton = %Launch
@onready var _screen: MeshInstance3D = %Screen
@onready var _viewport: SubViewport = %ScreenViewport
@onready var _beacon: OmniLight3D = %Beacon


func _ready() -> void:
	_build_screen()
	_prev.pressed.connect(func(_peer_id: int) -> void: _browse(-1))
	_next.pressed.connect(func(_peer_id: int) -> void: _browse(1))
	_launch.pressed.connect(func(_peer_id: int) -> void: _on_launch())
	NetworkManager.session_ended.connect(func(_reason: String) -> void: countdown = 0.0)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or countdown <= 0.0:
		return
	var director: MissionDirector = _director()
	if director == null or not director.in_lobby():
		countdown = 0.0
		return
	countdown = maxf(countdown - delta, 0.0)
	if director.everyone_aboard() and director.start_mission(_mission()["id"]):
		countdown = 0.0


func _process(delta: float) -> void:
	var director: MissionDirector = _director()
	if director == null:
		return
	var mission: Dictionary = _mission()
	var locked: bool = mission["id"] == &""
	_title.text = tr(mission["title"])
	_title.modulate = COLOR_LOCKED if locked else Color.WHITE
	_pager.text = "◄  %d / %d  ►" % [selected + 1, MissionDirector.MISSIONS.size()]
	var count: Vector2i = director.count_aboard()
	_crew.text = tr("à bord : %d / %d") % [count.x, count.y]
	_blink += delta
	if countdown > 0.0:
		_status.text = tr("Montez à bord !  %d") % ceili(countdown)
		_status.modulate = COLOR_ARMED
		_beacon.light_color = COLOR_ARMED
		_beacon.light_energy = 2.5 if fmod(_blink, 0.6) < 0.3 else 0.2
	else:
		_status.text = tr("Verrouillée") if locked else tr("Bouton vert : partir")
		_status.modulate = COLOR_LOCKED if locked else COLOR_IDLE
		_beacon.light_color = COLOR_IDLE
		_beacon.light_energy = 0.8
	_launch.lit = countdown > 0.0 and fmod(_blink, 0.6) < 0.3


func _mission() -> Dictionary:
	return MissionDirector.MISSIONS[clampi(selected, 0, MissionDirector.MISSIONS.size() - 1)]


## Hôte : flèches. On ne change pas de mission pendant le compte à rebours.
func _browse(step: int) -> void:
	if not multiplayer.is_server() or countdown > 0.0:
		return
	selected = posmod(selected + step, MissionDirector.MISSIONS.size())


## Hôte : bouton vert. Lance le compte à rebours, ou l'annule s'il tourne déjà.
func _on_launch() -> void:
	if not multiplayer.is_server():
		return
	var director: MissionDirector = _director()
	if director == null or not director.in_lobby():
		return
	if countdown > 0.0:
		countdown = 0.0
	elif _mission()["id"] != &"":
		countdown = ARM_TIME


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
	column.position = Vector2(26, 20)
	column.size = Vector2(SCREEN_SIZE) - Vector2(52, 40)
	column.add_theme_constant_override(&"separation", 10)
	root.add_child(column)
	column.add_child(_label("MISSION", 24, Color(0.55, 0.8, 0.65)))
	_title = _label("", 46, Color(0.85, 1.0, 0.9))
	column.add_child(_title)
	_pager = _label("", 30, Color(0.75, 0.95, 0.85))
	column.add_child(_pager)
	_status = _label("", 36, COLOR_IDLE)
	column.add_child(_status)
	_crew = _label("", 28, Color(0.7, 0.9, 0.8))
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
