class_name PushButton
extends Interactable
## Bouton : action instantanée (E / clic), utilisable en marchant.
## En mode `toggle`, chaque appui allume / éteint (le bouton reste enfoncé et brille quand il est allumé).
## L'hôte valide l'appui, émet `pressed`, met à jour l'état (répliqué par le
## MultiplayerSynchronizer) puis déclenche l'animation chez tout le monde.

## Émis sur l'hôte uniquement, après validation.
signal pressed(peer_id: int)

const PRESS_DEPTH: float = 0.025
const PRESS_DURATION: float = 0.15

@export var cap_color: Color = Color(0.8, 0.15, 0.1)
## Interrupteur : un appui allume, l'appui suivant éteint.
@export var toggle: bool = false

## Nombre d'appuis validés. Autorité : hôte.
var press_count: int = 0
## État allumé (mode toggle). Autorité : hôte.
var is_on: bool = false

var _press_timer: float = 0.0
var _cap_rest_y: float = 0.0
var _cap_material: StandardMaterial3D

@onready var _cap: MeshInstance3D = %Cap
@onready var _debug_label: Label3D = %DebugLabel


func _ready() -> void:
	super()
	_cap_material = StandardMaterial3D.new()
	_cap_material.albedo_color = cap_color
	_cap_material.roughness = 0.5
	_cap_material.emission = cap_color
	_cap.material_override = _cap_material
	_cap_rest_y = _cap.position.y
	_debug_label.visible = show_debug
	NetworkManager.session_ended.connect(_on_session_ended)


func _process(delta: float) -> void:
	# Animation purement visuelle (pas de gameplay ici).
	_press_timer = maxf(_press_timer - delta, 0.0)
	var down: bool = _press_timer > 0.0 or (toggle and is_on)
	_cap.position.y = _cap_rest_y - (PRESS_DEPTH if down else 0.0)
	_cap_material.emission_enabled = toggle and is_on
	if show_debug:
		var state: String = ("allumé" if is_on else "éteint") if toggle else "appuis : %d" % press_count
		_debug_label.text = "%s\n%s" % [display_name, state]


func get_hints() -> Array[InputHint]:
	if toggle:
		return [InputHint.make(&"grab", &"power_off" if is_on else &"power_on")]
	return [InputHint.make(&"grab", &"press")]


@rpc("any_peer", "call_local", "reliable")
func request_press() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not is_peer_in_reach(sender, reach):
		return
	press_count += 1
	if toggle:
		is_on = not is_on
	pressed.emit(sender)
	_play_press.rpc()


@rpc("authority", "call_local", "reliable")
func _play_press() -> void:
	_press_timer = PRESS_DURATION


func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	return [_cap]


func _on_session_ended(_reason: String) -> void:
	press_count = 0
	is_on = false
