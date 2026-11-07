class_name GrabberArm
extends Node3D
## Bras gauche du mécha : grappin articulé avec caméra embarquée (M9 — Grappin, lancer en M9.5).
## Piloté par le nain assis au poste `seat` (`Grabber_Seat`) :
## - souris / stick droit (`control_look`) et Q/D (`control_move.x`) : orientent le bras (lacet + tangage),
##   sans jamais pouvoir rentrer dans la coque (`MechaArmUtils`) ;
## - Z/S (`control_move.y`) : étendent ou replient le fût télescopique (0 → 3,8 m) ;
## - clic gauche / RT (`control_grab`) : referme la pince pour saisir un objet (`CargoCrate`, `Poop`…) ;
## - saut (`control_fire_count`) : lance la pince au bout de son câble, droit dans l'axe du bras (15 m).
##   Elle attrape le premier objet rangeable qu'elle croise, rebondit sur le décor, puis s'enroule.
## Dès qu'un objet est saisi, la pince le ramène à l'épaule gauche puis
## le transfère automatiquement dans le sac à dos (`Backpack.store_node`, M10).
##
## Réseau : l'hôte est seul autoritaire sur `arm_yaw`, `arm_pitch`, `extension`, `claw_closed`,
## `shot_state` et `shot_distance` (répliqués par MultiplayerSynchronizer). Chaque peer anime le bras,
## les mâchoires et le câble localement.

signal item_grabbed(item: Node3D, item_kind: String)

## Pince lancée : au repos, partie, en train de revenir.
enum Shot { IDLE, OUT, BACK }

## Bras gauche : l'intérieur (la coque) est un lacet négatif.
const SIDE_SIGN: float = -1.0
const MAX_EXTENSION: float = 3.80
const SLIDER_REST_Z: float = -1.80
## Fût télescopique : fût fixe (drill_barrel.glb), deux manchons emboîtés puis la glissière.
## Chaque étage avance d'une part de l'extension : à 3,8 m tout reste emboîté (12 cm de recouvrement mini).
const SLEEVE_OUTER_REST_Z: float = -0.9
const SLEEVE_INNER_REST_Z: float = -0.95
const SLEEVE_OUTER_SHARE: float = 0.3
const SLEEVE_INNER_SHARE: float = 0.62
const REST_PITCH: float = -0.12
const CLAW_OPEN_ANGLE: float = 0.44
const CLAW_CLOSED_ANGLE: float = -0.10
const CLAW_SPEED: float = 6.5
const DELIVER_DURATION: float = 0.55
const DELIVER_YAW: float = 0.16
const DELIVER_PITCH: float = 0.28
const DELIVER_EXT: float = 0.20
## Distance max de la pince à l'objet pour le saisir (au bras ou en vol).
const GRAB_RADIUS: float = 1.45
## Lancer : portée, vitesse de sortie et d'enroulement (m, m/s).
const SHOT_RANGE: float = 15.0
const SHOT_SPEED: float = 22.0
const REEL_SPEED: float = 13.0
## Câble : nombre de tronçons, rayon, point d'attache sur le poignet (repère de la glissière).
const CABLE_SEGMENTS: int = 12
const CABLE_RADIUS: float = 0.025
const CABLE_ROOT_Z: float = -0.32
const CABLE_SAG: float = 0.035

@export var seat: Seat
@export var backpack: Backpack
@export var extend_speed: float = 2.8
@export var yaw_key_speed: float = 1.1
@export var look_sensitivity: float = 0.65

## Lacet du bras (rad). Autorité : hôte.
var arm_yaw: float = 0.0
## Tangage du bras (rad, négatif = vers le bas). Autorité : hôte.
var arm_pitch: float = REST_PITCH
## Extension télescopique en mètres (0.0 .. 3.8). Autorité : hôte.
var extension: float = 0.0
## Vrai quand les mâchoires de la pince sont fermées. Autorité : hôte.
var claw_closed: bool = false
## État du lancer (`Shot`). Autorité : hôte.
var shot_state: int = Shot.IDLE
## Distance de la pince lancée à son poignet (m). Autorité : hôte.
var shot_distance: float = 0.0

var _claw_open_ratio: float = 1.0
var _deliver_timer: float = -1.0
var _deliver_start_yaw: float = 0.0
var _deliver_start_pitch: float = 0.0
var _deliver_start_ext: float = 0.0
var _held_item: Node3D = null
var _held_kind: String = "crate"
var _last_fire_count: int = 0
var _last_occupant: int = 0
## Distance de la pince affichée (lissée chez les clients entre deux paquets).
var _shown_shot: float = 0.0
var _cable_parts: Array[MeshInstance3D] = []

@onready var _elbow_pivot: Node3D = %ElbowPivot
@onready var _sleeve_outer: MeshInstance3D = %SleeveOuter
@onready var _sleeve_inner: MeshInstance3D = %SleeveInner
@onready var _slider_pivot: Node3D = %SliderPivot
@onready var _claw_head: Node3D = %ClawHead
@onready var _hub: MeshInstance3D = %Hub
@onready var _cable_root: Node3D = %Cable
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
			MechaArmUtils.strip_static_arm(ext_details, SIDE_SIGN)
	if seat != null:
		seat.camera_anchor = _camera_anchor
	_build_cable()
	NetworkManager.session_ended.connect(_on_session_ended)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var occupant: int = seat.occupant_peer_id if seat != null else 0
	if occupant != _last_occupant:
		_last_occupant = occupant
		_last_fire_count = 0
	if _deliver_timer >= 0.0:
		_update_delivery(delta)
		return
	if shot_state != Shot.IDLE:
		_update_shot(delta)
		return

	if occupant != 0:
		var look: Vector2 = seat.control_look
		seat.control_look = Vector2.ZERO
		var move: Vector2 = seat.control_move
		arm_yaw = MechaArmUtils.clamp_yaw(arm_yaw - look.x * look_sensitivity - move.x * yaw_key_speed * delta, SIDE_SIGN)
		arm_pitch = MechaArmUtils.clamp_pitch(arm_pitch + look.y * look_sensitivity)
		extension = clampf(extension + move.y * extend_speed * delta, 0.0, MAX_EXTENSION)
		claw_closed = seat.control_grab
		if seat.control_fire_count != _last_fire_count:
			_last_fire_count = seat.control_fire_count
			launch()
			return
		if claw_closed:
			var found: Array = _find_grabbable(_hold_point.global_position, GRAB_RADIUS)
			if not found.is_empty():
				grab_node(found[0], found[1])
	else:
		claw_closed = false


func _process(delta: float) -> void:
	_elbow_pivot.rotation = Vector3(arm_pitch, arm_yaw, 0.0)
	_slider_pivot.position = Vector3(0.0, 0.0, SLIDER_REST_Z - extension)
	_sleeve_outer.position = Vector3(0.0, 0.0, SLEEVE_OUTER_REST_Z - extension * SLEEVE_OUTER_SHARE)
	_sleeve_inner.position = Vector3(0.0, 0.0, SLEEVE_INNER_REST_Z - extension * SLEEVE_INNER_SHARE)

	var target_open: float = 0.0 if claw_closed else 1.0
	_claw_open_ratio = move_toward(_claw_open_ratio, target_open, CLAW_SPEED * delta)
	var jaw_angle: float = lerpf(CLAW_CLOSED_ANGLE, CLAW_OPEN_ANGLE, _claw_open_ratio)
	_claw_left.rotation.y = jaw_angle
	_claw_right.rotation.y = -jaw_angle

	if multiplayer.is_server():
		_shown_shot = shot_distance
	else:
		_shown_shot = lerpf(_shown_shot, shot_distance, 1.0 - exp(-30.0 * delta))
	_claw_head.position = Vector3(0.0, 0.0, -_shown_shot)
	_update_cable()


## Point d'ancrage de la caméra embarquée sur la pince.
func get_camera_anchor() -> Marker3D:
	return _camera_anchor


## Lance la pince au bout de son câble (hôte). Sans effet si elle est déjà partie ou si le sac est plein.
func launch() -> bool:
	if not multiplayer.is_server() or shot_state != Shot.IDLE or _deliver_timer >= 0.0:
		return false
	if backpack != null and backpack.is_full():
		return false
	shot_state = Shot.OUT
	shot_distance = 0.0
	claw_closed = false
	return true


## Déclenche manuellement la capture d'un objet (utile aussi pour les tests / bacs à sable).
func grab_node(item: Node3D, item_kind: String = "crate") -> bool:
	if not multiplayer.is_server():
		return false
	if item == null or not is_instance_valid(item) or _deliver_timer >= 0.0 or shot_state != Shot.IDLE:
		return false
	if backpack != null and backpack.is_full():
		return false
	_hold_item(item, item_kind)
	_begin_delivery()
	return true


## Objet rangeable le plus proche de `center` dans `radius` : [objet, type] ou [] s'il n'y en a pas.
func _find_grabbable(center: Vector3, radius: float) -> Array:
	var best_item: Node3D = null
	var best_kind: String = "crate"
	var best_dist: float = radius
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
		var kind: String = _kind_of(body)
		if kind.is_empty():
			continue
		var item_center: Vector3 = body.global_position + Vector3(0.0, 0.30, 0.0)
		var d: float = item_center.distance_to(center)
		if d < best_dist:
			best_dist = d
			best_item = body
			best_kind = kind
	if best_item == null:
		return []
	return [best_item, best_kind]


## Type d'objet pour le sac à dos, ou "" si la pince ne peut pas le prendre.
func _kind_of(body: Node3D) -> String:
	if body is CargoCrate:
		return (body as CargoCrate).item_kind
	if body is Poop:
		var poop: Poop = body as Poop
		if poop.holder_peer_id != 0:
			return ""
		return "poop_gold" if poop.golden else "poop"
	if body.is_in_group(&"storable_items"):
		return "crate"
	return ""


func _hold_item(item: Node3D, item_kind: String) -> void:
	_held_item = item
	_held_kind = item_kind
	claw_closed = true
	if item is RigidBody3D:
		(item as RigidBody3D).freeze = true
	item_grabbed.emit(item, item_kind)


func _begin_delivery() -> void:
	_deliver_timer = 0.0
	_deliver_start_yaw = arm_yaw
	_deliver_start_pitch = arm_pitch
	_deliver_start_ext = extension
	claw_closed = true


## Pince lancée (hôte) : elle file droit dans l'axe du bras, attrape ou rebondit, puis s'enroule.
func _update_shot(delta: float) -> void:
	if shot_state == Shot.OUT:
		var from: Vector3 = _hold_point.global_position
		shot_distance = minf(shot_distance + SHOT_SPEED * delta, SHOT_RANGE)
		_claw_head.position = Vector3(0.0, 0.0, -shot_distance)
		var to: Vector3 = _hold_point.global_position
		var found: Array = _find_grabbable(to, GRAB_RADIUS)
		if found.is_empty():
			found = _cast_shot(from, to)
		if not found.is_empty():
			if found[0] != null:
				_hold_item(found[0], found[1])
			claw_closed = true
			shot_state = Shot.BACK
		elif shot_distance >= SHOT_RANGE:
			claw_closed = true
			shot_state = Shot.BACK
	else:
		shot_distance = maxf(shot_distance - REEL_SPEED * delta, 0.0)
		_claw_head.position = Vector3(0.0, 0.0, -shot_distance)
		if shot_distance <= 0.0:
			shot_state = Shot.IDLE
			if _held_item != null and is_instance_valid(_held_item):
				_begin_delivery()
			else:
				_held_item = null
				claw_closed = false
	_carry_held_item()


## Rayon entre deux positions de la pince en vol. Renvoie [objet, type] si elle touche un objet rangeable,
## [null, ""] si elle heurte le décor, [] si rien.
func _cast_shot(from: Vector3, to: Vector3) -> Array:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = _mecha_bodies()
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return []
	var body: Node3D = hit.get("collider") as Node3D
	if body != null:
		var kind: String = _kind_of(body)
		if not kind.is_empty():
			return [body, kind]
	return [null, ""]


## Corps de collision du mécha lui-même (coque, jambes, nains à bord) : la pince passe à travers.
func _mecha_bodies() -> Array[RID]:
	var rids: Array[RID] = []
	var mecha: Node = get_parent()
	if mecha == null:
		return rids
	var stack: Array[Node] = [mecha]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CollisionObject3D and not node.is_in_group(&"storable_items"):
			rids.append((node as CollisionObject3D).get_rid())
		stack.append_array(node.get_children())
	return rids


func _carry_held_item() -> void:
	if _held_item != null and is_instance_valid(_held_item):
		_held_item.global_position = _hold_point.global_position
		_held_item.global_rotation = _hold_point.global_rotation


func _update_delivery(delta: float) -> void:
	_deliver_timer += delta
	var t: float = clampf(_deliver_timer / DELIVER_DURATION, 0.0, 1.0)
	var s: float = t * t * (3.0 - 2.0 * t)
	arm_yaw = lerpf(_deliver_start_yaw, DELIVER_YAW, s)
	arm_pitch = lerpf(_deliver_start_pitch, DELIVER_PITCH, s)
	extension = lerpf(_deliver_start_ext, DELIVER_EXT, s)
	claw_closed = true
	_carry_held_item()

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


func _build_cable() -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = CABLE_RADIUS
	mesh.bottom_radius = CABLE_RADIUS
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 1
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.11, 0.1)
	mat.roughness = 0.7
	mat.metallic = 0.4
	mesh.material = mat
	for i: int in range(CABLE_SEGMENTS):
		var part: MeshInstance3D = MeshInstance3D.new()
		part.mesh = mesh
		part.visible = false
		part.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_cable_root.add_child(part)
		_cable_parts.append(part)


## Câble entre le poignet et la pince lancée : légèrement affaissé, plus tendu quand elle part.
func _update_cable() -> void:
	var out: bool = _shown_shot > 0.05
	_hub.visible = out
	for part: MeshInstance3D in _cable_parts:
		part.visible = out
	if not out:
		return
	# Positions telles qu'elles sont affichées (lissées), sinon le câble décroche quand le mécha marche.
	var a: Vector3 = _slider_pivot.get_global_transform_interpolated() * Vector3(0.0, 0.0, CABLE_ROOT_Z)
	var b: Vector3 = _claw_head.get_global_transform_interpolated() * Vector3(0.0, 0.0, CABLE_ROOT_Z)
	var sag: float = CABLE_SAG * _shown_shot * (0.5 if shot_state == Shot.OUT else 1.0)
	var prev: Vector3 = a
	for i: int in range(CABLE_SEGMENTS):
		var t: float = float(i + 1) / float(CABLE_SEGMENTS)
		var p: Vector3 = a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		var part: MeshInstance3D = _cable_parts[i]
		var dir: Vector3 = p - prev
		var length: float = dir.length()
		if length > 0.0001:
			var y_axis: Vector3 = dir / length
			var x_axis: Vector3 = y_axis.cross(Vector3.FORWARD if absf(y_axis.y) > 0.9 else Vector3.UP).normalized()
			var z_axis: Vector3 = x_axis.cross(y_axis)
			part.global_transform = Transform3D(Basis(x_axis, y_axis * length, z_axis), (prev + p) * 0.5)
		prev = p


func _on_session_ended(_reason: String) -> void:
	arm_yaw = 0.0
	arm_pitch = REST_PITCH
	extension = 0.0
	claw_closed = false
	shot_state = Shot.IDLE
	shot_distance = 0.0
	_deliver_timer = -1.0
	_held_item = null
