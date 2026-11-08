class_name MechaArm
extends Node3D
## Base des deux bras du robot (foreuse à droite `DrillArm`, grappin à gauche `GrabberArm`) :
## visée depuis le poste assis `seat` (lacet + tangage bornés pour ne jamais rentrer dans la coque,
## extension télescopique), caméra du poste accrochée au bras, remise à zéro en fin de partie.
## Chaque bras ajoute son outil (mèche, pince) et dit de quel côté il est (`_side_sign`) et jusqu'où
## il s'étend (`_max_extension`).
##
## Réseau : l'hôte est seul autoritaire sur `arm_yaw`, `arm_pitch` et `extension` (répliqués par le
## MultiplayerSynchronizer de chaque bras) ; chaque peer anime le bras à partir de ces valeurs.

const REST_PITCH: float = -0.12

## Poste assis qui pilote ce bras.
@export var seat: Seat
@export var extend_speed: float = 2.4
@export var yaw_key_speed: float = 1.1
@export var look_sensitivity: float = 0.65

## Lacet du bras (rad). Autorité : hôte.
var arm_yaw: float = 0.0
## Tangage du bras (rad, négatif = vers le bas). Autorité : hôte.
var arm_pitch: float = REST_PITCH
## Extension télescopique en mètres (0 .. `_max_extension()`). Autorité : hôte.
var extension: float = 0.0

@onready var _elbow_pivot: Node3D = %ElbowPivot
@onready var _camera_anchor: Marker3D = %CameraAnchor


func _ready() -> void:
	if seat != null:
		seat.camera_anchor = _camera_anchor
	NetworkManager.session_ended.connect(func(_reason: String) -> void: reset_arm())


## Point d'ancrage de la caméra embarquée du poste.
func get_camera_anchor() -> Marker3D:
	return _camera_anchor


## Peer assis au poste de ce bras (0 = personne).
func get_occupant() -> int:
	return seat.occupant_peer_id if seat != null else 0


## Remet le bras au repos (fin de partie). Chaque bras y ajoute son outil.
func reset_arm() -> void:
	arm_yaw = 0.0
	arm_pitch = REST_PITCH
	extension = 0.0


## +1.0 = bras droit (la coque est vers les lacets positifs), -1.0 = bras gauche. À surcharger.
func _side_sign() -> float:
	return 1.0


## Extension maximale du bras (m). À surcharger.
func _max_extension() -> float:
	return 3.0


## Hôte : applique les commandes du poste (souris / stick et Q/D = orientation, Z/S = extension).
## Oriente le bras et renvoie l'extension demandée, que chaque bras applique à sa façon.
func _steer(delta: float) -> float:
	var look: Vector2 = seat.control_look
	seat.control_look = Vector2.ZERO
	var move: Vector2 = seat.control_move
	arm_yaw = MechaArmUtils.clamp_yaw(arm_yaw - look.x * look_sensitivity - move.x * yaw_key_speed * delta, _side_sign())
	arm_pitch = MechaArmUtils.clamp_pitch(arm_pitch + look.y * look_sensitivity)
	return clampf(extension + move.y * extend_speed * delta, 0.0, _max_extension())


## Chaque image : oriente le coude selon l'état répliqué.
func _show_aim() -> void:
	_elbow_pivot.rotation = Vector3(arm_pitch, arm_yaw, 0.0)
