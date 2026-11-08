class_name CargoCrate
extends RigidBody3D
## Caisse de ravitaillement / minerai (M10 — Inventaire).
## Peut être attrapée par le grappin (M9), lancée dans l'ouverture du sac à dos,
## ou envoyée dans le sac à dos en interagissant avec elle à proximité du robot.
##
## Réseau : l'hôte valide la collecte et déclenche `Backpack.store_node`, qui supprime
## la caisse et lance l'animation de rangement synchronisée chez tous les peers.

## Distance max (m) entre un nain et la caisse pour la ranger directement.
const COLLECT_REACH: float = 5.5
## Distance max (m) entre la caisse et le sac à dos du robot.
const BACKPACK_REACH: float = 14.0

## Identifiant du type d'objet stocké dans le sac.
@export var item_kind: String = "crate"

@onready var _model: Node3D = %Model


func _ready() -> void:
	add_to_group(&"storable_items")
	# STATIC et non KINEMATIC : en KINEMATIC, Jolt réécrit parfois une ancienne place quand le parent bouge.
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true


## Demande d'un joueur pour ranger cette caisse dans le sac à dos du robot.
@rpc("any_peer", "call_local", "reliable")
func request_collect() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var dwarves: Array[Node] = get_tree().get_nodes_in_group(&"dwarves")
	if not dwarves.is_empty():
		var dwarf: Node3D = _find_dwarf(sender)
		if dwarf == null or dwarf.global_position.distance_to(global_position) > COLLECT_REACH:
			return
	var backpack: Backpack = _find_nearest_backpack()
	if backpack == null:
		return
	if backpack.global_position.distance_to(global_position) > BACKPACK_REACH:
		return
	backpack.store_node(self, item_kind)


func get_model() -> Node3D:
	return _model


func _find_dwarf(peer_id: int) -> Node3D:
	for node: Node in get_tree().get_nodes_in_group(&"dwarves"):
		if node.name == str(peer_id):
			return node as Node3D
	return null


func _find_nearest_backpack() -> Backpack:
	var best: Backpack = null
	var best_dist: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"backpacks"):
		var bp: Backpack = node as Backpack
		if bp == null or bp.is_full():
			continue
		var d: float = bp.global_position.distance_to(global_position)
		if d < best_dist:
			best_dist = d
			best = bp
	return best
