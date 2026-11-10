class_name CargoCrate
extends RigidBody3D
## Caisse de ravitaillement / minerai (M10). Seul le robot la range dans son sac à dos : attrapée par le
## grappin (M9) ou lancée dans l'ouverture du sac. Un nain peut la porter à deux mains pour la déplacer :
## c'est un objet lourd de l'inventaire (voir Inventory) : elle prend une case, reste en main (on ne
## change plus de case), et on ne ramasse rien d'autre ni ne prend de levier tant qu'on la porte.
## Clic ou G : on la pose devant soi.
##
## Réseau : l'hôte décide qui la porte (`holder_peer_id`, `holder_slot`, répliqués) et où elle est posée
## (`position`, `rotation`). Portée, chaque peer la place lui-même devant celui qui la porte.
## Le rangement passe par `Backpack.store_node`, qui supprime la caisse et lance l'animation chez tous.

## Distance max (m) entre un nain et la caisse pour la prendre.
const PICK_REACH: float = 2.6
## Calque de collision de la caisse quand elle est posée (monde + objets).
const COLLISION_LAYERS: int = 9

## Identifiant du type d'objet stocké dans le sac.
@export var item_kind: String = "crate"

## Peer qui la porte (0 = personne). Autorité : hôte.
var holder_peer_id: int = 0:
	set(value):
		holder_peer_id = value
		if is_node_ready():
			_apply_carried()
## Case de l'inventaire du porteur. Autorité : hôte.
var holder_slot: int = 0

@onready var _model: Node3D = %Model
@onready var _handle_shape: CollisionShape3D = $Handle/CollisionShape3D
## Place du modèle dans la caisse (il y revient quand on la pose).
@onready var _model_rest: Transform3D = _model.transform


func _ready() -> void:
	add_to_group(&"storable_items")
	add_to_group(Inventory.GROUP)
	# STATIC et non KINEMATIC : en KINEMATIC, Jolt réécrit parfois une ancienne place quand le parent bouge.
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	_apply_carried()


func _physics_process(_delta: float) -> void:
	if holder_peer_id == 0:
		return
	var dwarf: Dwarf = Dwarf.of_peer(holder_peer_id)
	if dwarf == null:
		if multiplayer.is_server():
			_put_down(global_transform)   # son porteur est parti : posée là où elle était
		return
	# La caisse (sans collision ni image) suit son porteur ; son modèle, lui, est accroché au nain.
	global_transform = dwarf.get_carry_transform()
	if _model.get_parent() != dwarf:
		_attach_model(dwarf)   # porteur apparu après la caisse (joueur qui arrive en cours de partie)


func _exit_tree() -> void:
	if _model.get_parent() != self:
		_model.queue_free()   # caisse supprimée pendant qu'on la porte : son modèle part avec elle


## Inventaire (voir Inventory) : une case, objet lourd.
func inventory_entries(peer_id: int) -> Array[Dictionary]:
	if holder_peer_id != peer_id:
		return []
	return [{"slot": holder_slot, "icon": &"crate", "count": 1, "heavy": true}]


## Joueur local, caisse en main : clic = la poser aussi (trop lourde pour la lancer).
func throw_from_hand(_origin: Vector3, _direction: Vector3) -> void:
	request_put_down.rpc_id(1)


func drop_from_hand() -> void:
	request_put_down.rpc_id(1)


func get_model() -> Node3D:
	return _model


## Prendre la caisse à deux mains (il faut une case libre et ne rien porter de lourd).
@rpc("any_peer", "call_local", "reliable")
func request_pick() -> void:
	if not multiplayer.is_server() or holder_peer_id != 0:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not Dwarf.is_peer_near(sender, global_position, PICK_REACH) or Possession.holds_control(get_tree(), sender):
		return
	var slot: int = Inventory.free_slot(get_tree(), sender)
	if slot < 0:
		return
	holder_slot = slot
	holder_peer_id = sender


## Poser la caisse au sol devant soi.
@rpc("any_peer", "call_local", "reliable")
func request_put_down() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var dwarf: Dwarf = Dwarf.of_peer(sender)
	if sender != holder_peer_id or dwarf == null:
		return
	_put_down(dwarf.get_carry_transform(), dwarf)


## Hôte : posée sous `from` (sur ce qu'il y a dessous), droite, tournée comme `from`.
func _put_down(from: Transform3D, carrier: Dwarf = null) -> void:
	var up: Vector3 = Vector3.UP
	var exclude: Array[RID] = [get_rid()]
	if carrier != null:
		exclude.append(carrier.get_rid())
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from.origin + up * 0.3, from.origin - up * 4.0, 1, exclude)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var ground: Vector3 = hit["position"] if not hit.is_empty() else from.origin
	var forward: Vector3 = Vector3(-from.basis.z.x, 0.0, -from.basis.z.z)
	var yaw: float = atan2(-forward.x, -forward.z) if forward.length() > 0.01 else 0.0
	global_transform = Transform3D(Basis(up, yaw), ground)
	holder_peer_id = 0
	reset_physics_interpolation()


## Portée : ni collision (elle gênerait son porteur), ni visée, et son modèle est accroché au nain, qui
## l'emporte avec lui (même lissage que son corps : elle avance exactement avec lui).
func _apply_carried() -> void:
	var carried: bool = holder_peer_id != 0
	collision_layer = 0 if carried else COLLISION_LAYERS
	_handle_shape.disabled = carried
	var dwarf: Dwarf = Dwarf.of_peer(holder_peer_id) if carried else null
	if dwarf != null:
		_attach_model(dwarf)
	elif not carried:
		_detach_model()


func _attach_model(dwarf: Dwarf) -> void:
	if _model.get_parent() == dwarf:
		return
	_model.get_parent().remove_child(_model)
	dwarf.add_child(_model)
	_model.transform = Transform3D(Basis.IDENTITY, Dwarf.CARRY_OFFSET) * _model_rest
	_model.reset_physics_interpolation()
	if not dwarf.tree_exiting.is_connected(_detach_model):
		dwarf.tree_exiting.connect(_detach_model, CONNECT_ONE_SHOT)


## Le modèle revient dans la caisse (posée, ou porteur parti : sinon il disparaîtrait avec lui).
func _detach_model() -> void:
	if _model == null or _model.get_parent() == self:
		return
	var dwarf: Node = _model.get_parent()
	if dwarf != null:
		if dwarf.tree_exiting.is_connected(_detach_model):
			dwarf.tree_exiting.disconnect(_detach_model)
		dwarf.remove_child(_model)
	add_child(_model)
	_model.transform = _model_rest
	_model.reset_physics_interpolation()
