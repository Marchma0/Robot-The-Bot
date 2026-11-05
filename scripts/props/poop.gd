class_name Poop
extends RigidBody3D
## Caca : se ramasse (E), se tient dans la main, se lance (clic) ou se pose (E).
## Un nain touché par un caca lancé recule et a l'écran taché quelques secondes.
##
## Réseau : l'hôte est autoritaire. Il simule le vol (corps rigide), décide qui le tient
## (`holder_peer_id`, répliqué) et détecte les nains touchés. Les clients ne simulent rien :
## ils reçoivent la position, et placent eux-mêmes le caca dans la main de celui qui le tient.
## Au repos (ou tenu), le corps est figé et suit le mécha (enfant de Mecha/Props).

## Vitesse de lancer (m/s) et petit élan vers le haut.
const THROW_SPEED: float = 9.0
const THROW_LIFT: float = 1.2
## Portée max pour le ramasser (m).
const PICK_REACH: float = 2.2
## Durée de vie au sol avant de disparaître (s).
const LIFETIME: float = 120.0

## Peer qui le tient (0 = personne). Autorité : hôte.
var holder_peer_id: int = 0
## Écrasé (après avoir touché quelqu'un) : il s'aplatit.
var splatted: bool = false
## Caca légendaire (doré, brillant, ne disparaît jamais). Fixé à la création.
var golden: bool = false:
	set(value):
		golden = value
		if is_node_ready():
			_apply_look()

var _thrower: int = 0
var _flying: bool = false
var _slow_time: float = 0.0
var _age: float = 0.0
var _gold_material: StandardMaterial3D
var _gold_light: OmniLight3D

@onready var _model: Node3D = %Model


func _ready() -> void:
	add_to_group(&"poops")
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(_on_body_entered)
	_apply_look()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_age += delta
	if _flying:
		# Il s'arrête : on le refige pour qu'il suive de nouveau le mécha.
		_slow_time = _slow_time + delta if linear_velocity.length() < 0.3 else 0.0
		if _slow_time > 0.3:
			_land()
	elif holder_peer_id == 0 and _age > LIFETIME and not golden:
		queue_free()


func _process(_delta: float) -> void:
	# Tenu : chaque peer le place lui-même dans la main du porteur (fluide, pas de réseau).
	if holder_peer_id != 0:
		var dwarf: Dwarf = _find_dwarf(holder_peer_id)
		if dwarf != null:
			global_transform = dwarf.get_hold_transform()
	_model.scale = Vector3(1.4, 0.45, 1.4) if splatted else Vector3.ONE
	if _gold_material != null:
		# Scintillement du caca doré.
		var shine: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		_gold_material.emission_energy_multiplier = 0.4 + 0.8 * shine
		_gold_light.light_energy = 0.25 + 0.25 * shine


func is_held_locally() -> bool:
	return holder_peer_id != 0 and holder_peer_id == multiplayer.get_unique_id()


@rpc("any_peer", "call_local", "reliable")
func request_pick() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var dwarf: Dwarf = _find_dwarf(sender)
	if holder_peer_id != 0 or _flying or dwarf == null:
		return
	if dwarf.global_position.distance_to(global_position) > PICK_REACH:
		return
	for node: Node in get_tree().get_nodes_in_group(&"poops"):
		if (node as Poop).holder_peer_id == sender:
			return   # un seul caca à la fois
	holder_peer_id = sender
	splatted = false
	freeze = true
	_age = 0.0


## Lancer dans la direction du regard, ou poser (direction nulle).
@rpc("any_peer", "call_local", "reliable")
func request_throw(direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != holder_peer_id:
		return
	var dwarf: Dwarf = _find_dwarf(sender)
	if dwarf != null:
		global_transform = dwarf.get_hold_transform()
	holder_peer_id = 0
	_thrower = sender
	_flying = true
	_slow_time = 0.0
	freeze = false
	if direction.length() > 0.1:
		linear_velocity = direction.normalized() * THROW_SPEED + Vector3.UP * THROW_LIFT
		angular_velocity = Vector3(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
	else:
		linear_velocity = Vector3.ZERO


func _on_body_entered(body: Node) -> void:
	if not multiplayer.is_server() or not _flying:
		return
	var dwarf: Dwarf = body as Dwarf
	if dwarf != null and dwarf.peer_id != _thrower:
		dwarf.receive_splat.rpc()
		splatted = true
		linear_velocity *= 0.15


## Matériau doré + petite lumière pour le caca légendaire.
func _apply_look() -> void:
	if not golden or _gold_material != null:
		return
	_gold_material = StandardMaterial3D.new()
	_gold_material.albedo_color = Color(1.0, 0.78, 0.2)
	_gold_material.metallic = 1.0
	_gold_material.roughness = 0.2
	_gold_material.emission_enabled = true
	_gold_material.emission = Color(1.0, 0.7, 0.2)
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = _gold_material
	_gold_light = OmniLight3D.new()
	_gold_light.light_color = Color(1.0, 0.8, 0.35)
	_gold_light.omni_range = 1.2
	add_child(_gold_light)


func _land() -> void:
	_flying = false
	_age = 0.0
	freeze = true


func _find_dwarf(peer_id: int) -> Dwarf:
	for node: Node in get_tree().get_nodes_in_group(&"dwarves"):
		if node.name == str(peer_id):
			return node as Dwarf
	return null
