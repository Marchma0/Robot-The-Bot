class_name PushButton
extends Interactable
## Bouton : action instantanée (E / clic), utilisable en marchant.
## L'hôte valide l'appui, émet `pressed`, puis joue l'animation chez tout le monde.

## Émis sur l'hôte uniquement, après validation.
signal pressed(peer_id: int)

const PRESS_DEPTH: float = 0.025
const PRESS_DURATION: float = 0.15

@export var cap_color: Color = Color(0.8, 0.15, 0.1)

var press_count: int = 0

var _press_timer: float = 0.0
var _cap_rest_y: float = 0.0

@onready var _cap: MeshInstance3D = %Cap
@onready var _debug_label: Label3D = %DebugLabel


func _ready() -> void:
	super()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = cap_color
	material.roughness = 0.5
	_cap.material_override = material
	_cap_rest_y = _cap.position.y
	_debug_label.visible = show_debug
	_update_debug()


func _process(delta: float) -> void:
	# Animation purement visuelle (pas de gameplay ici).
	_press_timer = maxf(_press_timer - delta, 0.0)
	_cap.position.y = _cap_rest_y - (PRESS_DEPTH if _press_timer > 0.0 else 0.0)


func get_prompt() -> String:
	return "[E / clic] appuyer — %s" % display_name


@rpc("any_peer", "call_local", "reliable")
func request_press() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not is_peer_in_reach(sender, reach):
		return
	press_count += 1
	pressed.emit(sender)
	_play_press.rpc(press_count)


@rpc("authority", "call_local", "reliable")
func _play_press(count: int) -> void:
	press_count = count
	_press_timer = PRESS_DURATION
	_update_debug()


func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	return [_cap]


func _update_debug() -> void:
	_debug_label.text = "%s\nappuis : %d" % [display_name, press_count]
