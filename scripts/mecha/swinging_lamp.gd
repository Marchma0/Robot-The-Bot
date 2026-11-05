class_name SwingingLamp
extends Node3D
## Lampe suspendue au plafond qui se balance quand le mécha bouge (pas, virages, cahots).
## Purement visuelle : chaque peer la calcule à partir du mouvement du mécha (déjà synchronisé).
## Pendule amorti qui suit la « gravité ressentie » (gravité moins l'accélération du plafond).

## Longueur du fil (m).
@export var length: float = 0.6
## Amortissement (plus grand = s'arrête plus vite).
@export var damping: float = 3.0
## Angle max (rad), pour éviter qu'elle tape le plafond.
@export var max_angle: float = 0.45

var _angle: Vector2 = Vector2.ZERO      # x = autour de X (avant / arrière), y = autour de Z (côtés)
var _speed: Vector2 = Vector2.ZERO
var _last_position: Vector3
var _last_velocity: Vector3 = Vector3.ZERO
## Accélération lissée (les à-coups d'un pas ne doivent pas faire sauter la lampe).
var _smoothed_acceleration: Vector3 = Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _pendulum: Node3D = %Pendulum


func _ready() -> void:
	_last_position = global_position


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var velocity: Vector3 = (global_position - _last_position) / delta
	var acceleration: Vector3 = (velocity - _last_velocity) / delta
	_last_position = global_position
	_last_velocity = velocity
	_smoothed_acceleration = _smoothed_acceleration.lerp(acceleration.limit_length(6.0), 1.0 - exp(-6.0 * delta))
	# Gravité ressentie dans le repère du plafond (le mécha peut pencher).
	var felt: Vector3 = global_basis.inverse() * (Vector3.DOWN * _gravity - _smoothed_acceleration)
	var target: Vector2 = Vector2(atan2(-felt.z, -felt.y), atan2(felt.x, -felt.y)).limit_length(max_angle * 0.5)
	var stiffness: float = _gravity / length
	var accel: Vector2 = (target - _angle) * stiffness - _speed * damping
	_speed += accel * delta
	_angle = (_angle + _speed * delta).clamp(Vector2(-max_angle, -max_angle), Vector2(max_angle, max_angle))
	_pendulum.rotation = Vector3(_angle.x, 0.0, _angle.y)
