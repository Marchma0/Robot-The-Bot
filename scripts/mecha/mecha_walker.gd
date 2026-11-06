class_name MechaWalker
extends Node
## Marche en rythme du mécha (M7.1, voir docs/design_jambes.md).
## Un coup de joystick = un pas de la jambe de ce joystick. Les pas alternés font avancer le robot.
##
## Réseau : tout est calculé sur l'hôte. Les clients n'envoient que leurs joysticks (Lever, déjà en place).
## L'hôte déplace le corps du mécha (synchronisé et lissé par le NetSmoother du mécha) et les deux
## cibles de pied (`FootL`, `FootR`, chacune avec son NetSmoother, même horloge que le corps).
## Les marques au sol (`landing_*`, `swinging_*`) sont synchronisées par le MultiplayerSynchronizer du nœud.
## Chaque peer calcule ensuite lui-même la pliure des jambes (LegIK).

signal stepped(leg: int)
signal stumbled

enum Leg { LEFT, RIGHT }

## Hanches dans le repère du mécha (Godot), hauteur des hanches au-dessus du sol debout,
## et longueur max hanche -> cheville (jambes jamais tout à fait tendues).
const HIP_LOCAL: Array[Vector3] = [Vector3(-1.4, 2.2, 0.0), Vector3(1.4, 2.2, 0.0)]
const HIP_HEIGHT: float = 2.75
const ANKLE_HEIGHT: float = 0.35
const MAX_REACH: float = 2.45
## Seuils du joystick : au-delà de TRIGGER on fait un pas, il faut revenir sous RELEASE pour le suivant.
const TRIGGER: float = 0.6
const RELEASE: float = 0.3

@export var body: Node3D
@export var stick_left: Lever
@export var stick_right: Lever
## Durée d'un pas (s) et hauteur du pied en l'air (m).
@export var step_time: float = 0.42
@export var lift_height: float = 0.45
## Longueur de pas : courte si on enchaîne lentement, longue à rythme soutenu.
@export var stride_slow: float = 1.0
@export var stride_fast: float = 1.4
@export var stride_back: float = 0.7
## Rotation par pas : diagonale (avance en tournant) et côté pur (pivot sur place), en degrés.
@export var turn_step_degrees: float = 20.0
@export var pivot_step_degrees: float = 25.0
## Écart max de direction entre deux pas successifs avant de trébucher (degrés).
@export var mismatch_degrees: float = 60.0
## Un pas demandé pendant que l'autre pied est en l'air attend au plus ce temps (s).
@export var buffer_time: float = 0.35

## Où le pied va se poser, et s'il est en l'air (pour la marque lumineuse). Autorité : hôte.
var landing_left: Vector3 = Vector3.ZERO
var landing_right: Vector3 = Vector3.ZERO
var swinging_left: bool = false
var swinging_right: bool = false

var _feet: Array[Dictionary] = []
var _armed: Array[bool] = [true, true]
var _pending: Array[float] = [-1.0, -1.0]      # angle demandé en attente (NAN = rien)
var _pending_time: Array[float] = [0.0, 0.0]
var _last_step_time: float = -10.0
var _last_step_angle: float = 0.0
var _last_step_leg: int = -1
var _stumble: float = 0.0
var _time: float = 0.0
var _yaw: float = 0.0
var _hip_center: Vector3
var _ready_done: bool = false

@onready var _foot_nodes: Array[Node3D] = [$FootL as Node3D, $FootR as Node3D]


func _ready() -> void:
	for node: Node3D in _foot_nodes:
		node.top_level = true
		(node.get_node("NetSmoother") as NetSmoother).world_space = true   # les pieds restent dans le monde
	_pending = [NAN, NAN]
	# Les pieds se posent au sol une fois le mécha placé (après le premier tour de physique).
	_init_feet.call_deferred()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not _ready_done:
		return
	_time += delta
	_stumble = maxf(0.0, _stumble - delta)
	_read_stick(Leg.LEFT, stick_left)
	_read_stick(Leg.RIGHT, stick_right)
	for leg: int in 2:
		_try_pending(leg)
		_advance_swing(leg, delta)
	_place_body(delta)
	_publish()


## Pied (contact au sol) et orientation, en global, tels qu'affichés (lissés chez les clients).
func get_foot_transform(leg: int) -> Transform3D:
	return _foot_nodes[leg].get_global_transform_interpolated()


func _init_feet() -> void:
	_yaw = body.global_rotation.y
	var basis: Basis = Basis(Vector3.UP, _yaw)
	_hip_center = body.global_position + basis * Vector3(0.0, HIP_LOCAL[0].y, 0.0)
	_feet.clear()
	for leg: int in 2:
		var hip: Vector3 = body.global_position + basis * HIP_LOCAL[leg]
		var ground: Vector3 = _ground_at(hip)
		_feet.append({"pos": ground, "yaw": _yaw, "swing": false, "t": 0.0,
			"from": ground, "to": ground, "from_yaw": _yaw, "to_yaw": _yaw})
	_ready_done = true
	if multiplayer.is_server():
		_place_body(1.0)
		_publish()


func _read_stick(leg: int, stick: Lever) -> void:
	if stick == null:
		return
	var value: Vector2 = stick.value
	if value.length() < RELEASE:
		_armed[leg] = true
	elif value.length() > TRIGGER and _armed[leg]:
		_armed[leg] = false
		# 0 = vers l'avant (le hublot), positif = vers la droite.
		_pending[leg] = atan2(value.x, value.y)
		_pending_time[leg] = _time


func _try_pending(leg: int) -> void:
	if is_nan(_pending[leg]):
		return
	if _time - _pending_time[leg] > buffer_time or _stumble > 0.0:
		_pending[leg] = NAN
		return
	var other: int = 1 - leg
	if _feet[leg]["swing"] or _feet[other]["swing"]:
		return   # deux pieds en l'air : interdit, on attend
	var angle: float = _pending[leg]
	_pending[leg] = NAN
	# Désaccord avec le pas précédent de l'autre jambe : il trébuche.
	if _last_step_leg == other and _time - _last_step_time < 1.5 \
			and absf(angle_difference(angle, _last_step_angle)) > deg_to_rad(mismatch_degrees):
		_stumble = 0.9
		_last_step_leg = -1
		stumbled.emit()
		return
	_start_step(leg, angle)


func _start_step(leg: int, angle: float) -> void:
	var other: int = 1 - leg
	var a: float = absf(angle)
	var side: float = signf(angle)
	var advance: float = 0.0
	var turn: float = 0.0
	# Plus on enchaîne vite après l'autre jambe, plus le pas est long.
	var since: float = _time - _last_step_time if _last_step_leg == other else 10.0
	var stride: float = lerpf(stride_fast, stride_slow, clampf((since - 0.45) / 0.8, 0.0, 1.0))
	if a <= deg_to_rad(30.0):
		advance = stride
	elif a <= deg_to_rad(70.0):
		advance = stride * 0.8
		turn = turn_step_degrees
	elif a <= deg_to_rad(110.0):
		turn = pivot_step_degrees
	elif a <= deg_to_rad(150.0):
		advance = -stride_back * 0.8
		turn = turn_step_degrees
	else:
		advance = -stride_back
	# Vers la droite (angle positif) = rotation horaire vue de dessus = lacet négatif.
	# La rotation part du pied resté au sol : en alternant, chaque pas tourne le robot de `turn` ;
	# un seul joueur ne peut pas dépasser `turn` d'écart avec l'autre pied (il piétine).
	var other_yaw: float = _feet[other]["yaw"]
	var new_yaw: float = other_yaw - side * deg_to_rad(turn)
	var basis: Basis = Basis(Vector3.UP, new_yaw)
	var lateral: float = (HIP_LOCAL[leg].x - HIP_LOCAL[other].x)
	var target: Vector3 = _feet[other]["pos"] + basis * Vector3(lateral, 0.0, -advance)
	target = _ground_at(target)
	var foot: Dictionary = _feet[leg]
	foot["swing"] = true
	foot["t"] = 0.0
	foot["from"] = foot["pos"]
	foot["to"] = target
	foot["from_yaw"] = foot["yaw"]
	foot["to_yaw"] = new_yaw
	_last_step_time = _time
	_last_step_angle = angle
	_last_step_leg = leg
	stepped.emit(leg)


func _advance_swing(leg: int, delta: float) -> void:
	var foot: Dictionary = _feet[leg]
	if not foot["swing"]:
		return
	var t: float = minf(1.0, foot["t"] + delta / step_time)
	foot["t"] = t
	var eased: float = t * t * (3.0 - 2.0 * t)
	var pos: Vector3 = (foot["from"] as Vector3).lerp(foot["to"], eased)
	pos.y += sin(PI * t) * lift_height
	foot["pos"] = pos
	foot["yaw"] = lerp_angle(foot["from_yaw"], foot["to_yaw"], eased)
	if t >= 1.0:
		foot["swing"] = false
		foot["pos"] = foot["to"]


## Le corps se place entre les pieds, à la bonne hauteur, et regarde dans leur direction moyenne.
func _place_body(delta: float) -> void:
	var left: Dictionary = _feet[Leg.LEFT]
	var right: Dictionary = _feet[Leg.RIGHT]
	var mid: Vector3 = ((left["pos"] as Vector3) + (right["pos"] as Vector3)) / 2.0
	var roll: float = 0.0
	var dip: float = 0.0
	for leg: int in 2:
		var foot: Dictionary = _feet[leg]
		if foot["swing"]:
			var s: float = sin(PI * float(foot["t"]))
			var planted: Vector3 = _feet[1 - leg]["pos"]
			mid = mid.lerp(Vector3(planted.x, mid.y, planted.z), 0.25 * s)   # poids sur le pied d'appui
			roll += (-1.0 if leg == Leg.RIGHT else 1.0) * deg_to_rad(3.0) * s
			dip += 0.06 * s
	var target_yaw: float = lerp_angle(left["yaw"], right["yaw"], 0.5)
	var k: float = 1.0 - exp(-10.0 * delta)
	_yaw = lerp_angle(_yaw, target_yaw, k)
	# Hauteur : hanches à HIP_HEIGHT au-dessus du sol moyen, sans dépasser la portée des jambes.
	var ground_y: float = (minf(left["pos"].y, left["to"].y) + minf(right["pos"].y, right["to"].y)) / 2.0
	var hip_y: float = ground_y + HIP_HEIGHT - dip
	var basis: Basis = Basis(Vector3.UP, _yaw)
	for leg: int in 2:
		if _feet[leg]["swing"]:
			continue
		var hip: Vector3 = mid + basis * Vector3(HIP_LOCAL[leg].x, 0.0, 0.0)
		var ankle: Vector3 = (_feet[leg]["pos"] as Vector3) + Vector3.UP * ANKLE_HEIGHT
		var flat: float = Vector2(hip.x - ankle.x, hip.z - ankle.z).length()
		hip_y = minf(hip_y, ankle.y + sqrt(maxf(0.0, MAX_REACH * MAX_REACH - flat * flat)))
	var wanted: Vector3 = Vector3(mid.x, hip_y, mid.z)
	_hip_center = _hip_center.lerp(wanted, k) if delta < 1.0 else wanted
	# Trébuche : le robot vacille.
	var pitch: float = 0.0
	if _stumble > 0.0:
		var shake: float = _stumble / 0.9
		roll += sin(_time * 18.0) * deg_to_rad(5.0) * shake
		pitch += sin(_time * 13.0) * deg_to_rad(3.0) * shake
	var full: Basis = Basis.from_euler(Vector3(pitch, _yaw, roll))
	body.global_transform = Transform3D(full, _hip_center - full * Vector3(0.0, HIP_LOCAL[0].y, 0.0))


func _publish() -> void:
	for leg: int in 2:
		var foot: Dictionary = _feet[leg]
		_foot_nodes[leg].global_transform = Transform3D(Basis(Vector3.UP, foot["yaw"]), foot["pos"])
	swinging_left = _feet[Leg.LEFT]["swing"]
	swinging_right = _feet[Leg.RIGHT]["swing"]
	landing_left = _feet[Leg.LEFT]["to"]
	landing_right = _feet[Leg.RIGHT]["to"]


## Point du sol sous `point` (rayon vertical qui ignore le mécha lui-même).
func _ground_at(point: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * 1.5, point + Vector3.DOWN * 4.0, 1)
	query.exclude = _own_bodies()
	var hit: Dictionary = space.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else Vector3(point.x, point.y - ANKLE_HEIGHT, point.z)


func _own_bodies() -> Array[RID]:
	var rids: Array[RID] = []
	for node: Node in body.find_children("*", "CollisionObject3D", true, false):
		rids.append((node as CollisionObject3D).get_rid())
	for node: Node in get_tree().get_nodes_in_group(&"dwarves"):
		if node is CollisionObject3D:
			rids.append((node as CollisionObject3D).get_rid())
	return rids
