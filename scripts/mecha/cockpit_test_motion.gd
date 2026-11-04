extends Node
## Mouvement scripté TEMPORAIRE du cockpit, en attendant le vrai mécha (M4).
## Fait tourner le cockpit en rond avec un balancement façon "pas de mécha".
## Tourne uniquement sur l'hôte ; le MultiplayerSynchronizer du cockpit réplique le résultat.

@export var target: Node3D
@export var forward_speed: float = 1.5
## Vitesse de rotation (rad/s). Rayon du cercle = forward_speed / turn_rate.
@export var turn_rate: float = 0.1
## Nombre de pas par seconde.
@export var step_frequency: float = 1.2
@export var bob_height: float = 0.12
@export var roll_degrees: float = 3.0
@export var pitch_degrees: float = 1.5

var _time: float = 0.0
var _yaw: float = 0.0
var _base_height: float = 0.0


func _ready() -> void:
	_yaw = target.rotation.y
	_base_height = target.position.y


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_time += delta
	_yaw += turn_rate * delta
	# Une demi-période de sinus = un pas.
	var phase: float = PI * step_frequency * _time
	var forward: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, _yaw)
	var new_position: Vector3 = target.position + forward * forward_speed * delta
	new_position.y = _base_height + absf(sin(phase)) * bob_height
	target.position = new_position
	target.rotation = Vector3(
		deg_to_rad(pitch_degrees) * sin(2.0 * phase),
		_yaw,
		deg_to_rad(roll_degrees) * sin(phase),
	)
