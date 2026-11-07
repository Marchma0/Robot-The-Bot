class_name GrabberArm
extends Node3D
## Bras gauche du mécha : grappin articulé avec caméra embarquée (M9 — Grappin).
## Piloté par le nain assis au poste `seat` (`Grabber_Seat`) :
## - souris / stick droit (`control_look`) et Q/D (`control_move.x`) : orientent le bras (lacet + tangage) ;
## - Z/S (`control_move.y`) : étendent ou replient le fût télescopique (0 → 3,8 m) ;
## - clic gauche / RT (`control_grab`) : referme la pince pour saisir un objet (`CargoCrate`, `Poop`…).
## Dès qu'un objet est saisi, la pince le soulève en repliant le bras vers l'épaule gauche puis
## le transfère automatiquement dans le sac à dos (`Backpack.store_node`, M10).
##
## Réseau : l'hôte est seul autoritaire sur `arm_yaw`, `arm_pitch`, `extension` et `claw_closed`
## (répliqués par MultiplayerSynchronizer). Chaque peer anime le bras et les mâchoires localement.

signal item_grabbed(item: Node3D, item_kind: String)

const MAX_EXTENSION: float = 3.80
const SLIDER_REST_Z: float = -1.80
const MID_SLEEVE_REST_Z: float = -0.95
const MAX_YAW: float = deg_to_rad(52.0)
const MIN_PITCH: float = deg_to_rad(-44.0)
const MAX_PITCH: float = deg_to_rad(26.0)
const CLAW_OPEN_ANGLE: float = 0.44
const CLAW_CLOSED_ANGLE: float = -0.10
const CLAW_SPEED: float = 6.5
const DELIVER_DURATION: float = 0.55
const DELIVER_YAW: float = 0.16
const DELIVER_PITCH: float = 0.28
const DELIVER_EXT: float = 0.20

@export var seat: Seat
@export var backpack: Backpack
@export var extend_speed: float = 2.8
@export var yaw_key_speed: float = 1.1
@export var look_sensitivity: float = 0.65

## Lacet du bras (rad). Autorité : hôte.
var arm_yaw: float = 0.0
## Tangage du bras (rad, négatif = vers le bas). Autorité : hôte.
var arm_pitch: float = -0.12
## Extension télescopique en mètres (0.0 .. 3.8). Autorité : hôte.
var extension: float = 0.0
## Vrai quand les mâchoires de la pince sont fermées. Autorité : hôte.
var claw_closed: bool = false

var _claw_open_ratio: float = 1.0
var _deliver_timer: float = -1.0
var _deliver_start_yaw: float = 0.0
var _deliver_start_pitch: float = 0.0
var _deliver_start_ext: float = 0.0
var _held_item: Node3D = null
var _held_kind: String = "crate"

@onready var _elbow_pivot: Node3D = %ElbowPivot
@onready var _mid_sleeve: MeshInstance3D = %MidSleeve
@onready var _slider_pivot: Node3D = %SliderPivot
@onready var _claw_left: Node3D = %ClawLeft
@onready var _claw_right: Node3D = %ClawRight
@onready var _camera_anchor: Marker3D = %CameraAnchor
@onready var _grab_zone: Area3D = %GrabZone
@onready var _hold_point: Marker3D = %HoldPoint


func _ready() -> void:
	var parent_node: Node = get_parent()
	if parent_node != null:
		var ext_details: MeshInstance3D = parent_node.get_node_or_null("Ext_Details") as MeshInstance3D
		if ext_details != null:
			MechaArmUtils.strip_static_arm(ext_details, -1.0)
	if seat != null:
		seat.camera_anchor = _camera_anchor
	NetworkManager.session_ended.connect(_on_session_ended)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _deliver_timer >= 0.0:
		_update_delivery(delta)
		return

	if seat != null and seat.occupant_peer_id != 0:
		var look: Vector2 = seat.control_look
		seat.control_look = Vector2.ZERO
		var move: Vector2 = seat.control_move
		arm_yaw = clampf(arm_yaw - look.x * look_sensitivity - move.x * yaw_key_speed * delta, -MAX_YAW, MAX_YAW)
		arm_pitch = clampf(arm_pitch + look.y * look_sensitivity, MIN_PITCH, MAX_PITCH)
		extension = clampf(extension + move.y * extend_speed * delta, 0.0, MAX_EXTENSION)
		claw_closed = seat.control_grab
		if claw_closed:
			_try_grab_overlapping()
	else:
		claw_closed = false


func _process(delta: float) -> void:
	_elbow_pivot.rotation = Vector3(arm_pitch, arm_yaw, 0.0)
	_slider_pivot.position = Vector3(0.0, 0.0, SLIDER_REST_Z - extension)
	if _mid_sleeve != null:
		_mid_sleeve.position = Vector3(0.0, 0.0, MID_SLEEVE_REST_Z - extension * 0.5)

	var target_open: float = 0.0 if claw_closed else 1.0
	_claw_open_ratio = move_toward(_claw_open_ratio, target_open, CLAW_SPEED * delta)
	var jaw_angle: float = lerpf(CLAW_CLOSED_ANGLE, CLAW_OPEN_ANGLE, _claw_open_ratio)
	_claw_left.rotation.y = jaw_angle
	_claw_right.rotation.y = -jaw_angle


## Point d'ancrage de la caméra embarquée sur le poignet du grappin.
func get_camera_anchor() -> Marker3D:
	return _camera_anchor


## Déclenche manuellement la capture d'un objet (utile aussi pour les tests / bacs à sable).
func grab_node(item: Node3D, item_kind: String = "crate") -> bool:
	if not multiplayer.is_server():
		return false
	if item == null or not is_instance_valid(item) or _deliver_timer >= 0.0:
		return false
	if backpack != null and backpack.is_full():
		return false
	_held_item = item
	_held_kind = item_kind
	_deliver_timer = 0.0
	_deliver_start_yaw = arm_yaw
	_deliver_start_pitch = arm_pitch
	_deliver_start_ext = extension
	claw_closed = true
	if item is RigidBody3D:
		(item as RigidBody3D).freeze = true
	item_grabbed.emit(item, item_kind)
	return true


func _try_grab_overlapping() -> void:
	if _deliver_timer >= 0.0:
		return
	if backpack != null and backpack.is_full():
		return
	var best_item: Node3D = null
	var best_kind: String = "crate"
	var best_dist: float = 1.45
	var center: Vector3 = _hold_point.global_position
	var candidates: Array[Node] = []
	if _grab_zone != null:
		for body: Node3D in _grab_zone.get_overlapping_bodies():
			candidates.append(body)
	for node: Node in get_tree().get_nodes_in_group(&"storable_items"):
		if not candidates.has(node):
			candidates.append(node)
	for node: Node in candidates:
		var body: Node3D = node as Node3D
		if body == null or not is_instance_valid(body) or body == _held_item:
			continue
		var kind: String = ""
		if body is CargoCrate:
			kind = (body as CargoCrate).item_kind
		elif body is Poop:
			var poop: Poop = body as Poop
			if poop.holder_peer_id != 0:
				continue
			kind = "poop_gold" if poop.golden else "poop"
		elif body.is_in_group(&"storable_items"):
			kind = "crate"
		if kind.is_empty():
			continue
		var item_center: Vector3 = body.global_position + Vector3(0.0, 0.30, 0.0)
		var d: float = item_center.distance_to(center)
		if d < best_dist:
			best_dist = d
			best_item = body
			best_kind = kind
	if best_item != null:
		grab_node(best_item, best_kind)


func _update_delivery(delta: float) -> void:
	_deliver_timer += delta
	var t: float = clampf(_deliver_timer / DELIVER_DURATION, 0.0, 1.0)
	var s: float = t * t * (3.0 - 2.0 * t)
	arm_yaw = lerpf(_deliver_start_yaw, DELIVER_YAW, s)
	arm_pitch = lerpf(_deliver_start_pitch, DELIVER_PITCH, s)
	extension = lerpf(_deliver_start_ext, DELIVER_EXT, s)
	claw_closed = true

	if _held_item != null and is_instance_valid(_held_item):
		_held_item.global_position = _hold_point.global_position
		_held_item.global_rotation = _hold_point.global_rotation

	if _deliver_timer >= DELIVER_DURATION:
		var item_to_store: Node3D = _held_item
		var kind_to_store: String = _held_kind
		_held_item = null
		_deliver_timer = -1.0
		claw_closed = false
		if item_to_store != null and is_instance_valid(item_to_store):
			var target_bp: Backpack = backpack if backpack != null else _find_backpack()
			if target_bp != null:
				target_bp.store_node(item_to_store, kind_to_store)


func _find_backpack() -> Backpack:
	for node: Node in get_tree().get_nodes_in_group(&"backpacks"):
		return node as Backpack
	return null


func _on_session_ended(_reason: String) -> void:
	arm_yaw = 0.0
	arm_pitch = -0.12
	extension = 0.0
	claw_closed = false
	_deliver_timer = -1.0
	_held_item = null
