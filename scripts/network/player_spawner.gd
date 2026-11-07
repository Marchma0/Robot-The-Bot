extends MultiplayerSpawner
## Crée un nain par joueur. Seul l'hôte décide des spawns/despawns ;
## le MultiplayerSpawner les réplique chez les clients (y compris ceux qui arrivent en cours).

@export var dwarf_scene: PackedScene
## Parent contenant les Marker3D de spawn dans le robot, un par slot de joueur (pendant une mission).
@export var spawn_points: Node3D
## Au camp, les nains apparaissent dehors, aux Marker3D du nœud `PlayerSpawns` du niveau.
@export var director: MissionDirector

## peer_id -> slot (0..MAX_PLAYERS-1). Tenu uniquement sur l'hôte.
var _slots: Dictionary[int, int] = {}


func _ready() -> void:
	spawn_function = _spawn_dwarf
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.session_ended.connect(_on_session_ended)


func _on_player_joined(peer_id: int) -> void:
	if not multiplayer.is_server() or _slots.has(peer_id):
		return
	var slot: int = _first_free_slot()
	if slot < 0:
		push_warning("Plus de slot libre pour le peer %d" % peer_id)
		return
	_slots[peer_id] = slot
	# La place est calculée ici (hôte) et envoyée : tout le monde fait apparaître le nain au même endroit.
	spawn({"peer_id": peer_id, "slot": slot, "xform": _spawn_transform(slot)})


func _on_player_left(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_slots.erase(peer_id)
	var dwarf: Node = get_node(spawn_path).get_node_or_null(str(peer_id))
	if dwarf:
		dwarf.queue_free()


func _on_session_ended(_reason: String) -> void:
	# Hors ligne, plus rien n'est répliqué : on nettoie localement.
	_slots.clear()
	for child: Node in get_node(spawn_path).get_children():
		child.queue_free()


## Exécuté sur tous les peers avec les mêmes données.
func _spawn_dwarf(data: Variant) -> Node:
	var info: Dictionary = data
	var slot: int = info["slot"]
	var dwarf: Dwarf = dwarf_scene.instantiate()
	dwarf.setup(info["peer_id"], slot)
	dwarf.transform = info.get("xform", (spawn_points.get_child(slot) as Node3D).transform)
	return dwarf


## Place d'apparition (repère du parent des nains, dans le robot) : au camp, un point du niveau ;
## sinon, un point dans le robot.
func _spawn_transform(slot: int) -> Transform3D:
	var parent: Node3D = get_node(spawn_path) as Node3D
	if director != null and director.in_lobby() and director.get_level() != null:
		var spawns: Node = director.get_level().get_node_or_null("PlayerSpawns")
		if spawns != null and slot < spawns.get_child_count():
			var marker: Node3D = spawns.get_child(slot) as Node3D
			return parent.global_transform.affine_inverse() * marker.global_transform
	return (spawn_points.get_child(slot) as Node3D).transform


func _first_free_slot() -> int:
	var used: Array = _slots.values()
	for i: int in spawn_points.get_child_count():
		if not used.has(i):
			return i
	return -1
