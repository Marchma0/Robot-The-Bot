class_name NetAudit
extends RefCounted
## Photo de « ce que ce joueur voit » du monde partagé, pour comparer l'hôte et un client.
## Utilisé par le test réseau automatique (`tests/tools/net_test.tscn`) et par la touche de
## debug F9 en partie (`NetworkManager`) : un écart entre l'hôte et un client = un bug de synchro.
##
## Contenu de la photo (clé = chemin depuis `root`) :
## - chaque propriété « à chaque changement » des MultiplayerSynchronizer tenus par l'hôte ;
## - chaque objet réseau (RigidBody3D, ou nœud qui porte un MultiplayerSynchronizer) : sa présence
##   et sa place (à 10 cm près).
## Les nains sont ignorés (chaque joueur a l'autorité sur le sien). Les objets du groupe `MOVING_GROUP` ne comptent
## que par leur présence.

const POSITION_TOLERANCE: float = 0.15
const FLOAT_TOLERANCE: float = 0.05
## Objets que l'hôte déplace sans arrêt (caisses mobiles du tuto…) : leur place n'est jamais la même au même
## instant chez deux joueurs. On ne compare que leur présence. Le groupe est donné chez chaque joueur.
const MOVING_GROUP: StringName = &"net_moving"


## `continuous` : ajoute aussi les propriétés envoyées en continu (bras, jauges…). Elles bougent tout le
## temps et ne se comparent pas entre deux joueurs, mais servent à voir si une action a eu un effet.
## Les flux des NetSmoother (place + horloge) n'y sont jamais : leur horloge avance toute seule, ils feraient croire
## qu'une demande refusée a changé quelque chose.
static func snapshot(root: Node, continuous: bool = false) -> Dictionary:
	var out: Dictionary = {}
	_walk(root, root, out, continuous)
	return out


## Lignes lisibles décrivant les écarts entre la photo de l'hôte et celle du client.
static func diff(host: Dictionary, client: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for key: String in host:
		if not client.has(key):
			lines.append("%s : absent chez le client (hôte : %s)" % [key, host[key]])
		elif not _same(host[key], client[key]):
			lines.append("%s : hôte %s, client %s" % [key, host[key], client[key]])
	for key: String in client:
		if not host.has(key):
			lines.append("%s : en trop chez le client (%s)" % [key, client[key]])
	lines.sort()
	return lines


static func _walk(root: Node, node: Node, out: Dictionary, continuous: bool) -> void:
	if node.is_in_group(&"dwarves"):
		return
	if node is MultiplayerSynchronizer:
		_add_sync(root, node as MultiplayerSynchronizer, out, continuous)
	elif node is Node3D and _is_net_object(node):
		var moving: bool = node.is_in_group(MOVING_GROUP)
		var place: Variant = "présent" if moving else (node as Node3D).global_position.snappedf(0.1)
		out["objet " + str(root.get_path_to(node))] = place
	for child: Node in node.get_children():
		_walk(root, child, out, continuous)


static func _is_net_object(node: Node) -> bool:
	if node is RigidBody3D:
		return true
	for child: Node in node.get_children():
		if child is MultiplayerSynchronizer:
			return true
	return false


static func _add_sync(root: Node, sync: MultiplayerSynchronizer, out: Dictionary, continuous: bool) -> void:
	if sync.get_multiplayer_authority() != 1 or sync.replication_config == null:
		return
	var target: Node = sync.get_node_or_null(sync.root_path)
	if target == null or target.is_in_group(MOVING_GROUP):
		return
	var config: SceneReplicationConfig = sync.replication_config
	for prop: NodePath in config.get_properties():
		var mode: SceneReplicationConfig.ReplicationMode = config.property_get_replication_mode(prop)
		if mode == SceneReplicationConfig.REPLICATION_MODE_ALWAYS and not continuous:
			continue
		var found: Array = target.get_node_and_resource(prop)
		var owner_node: Node = found[0] as Node
		if owner_node == null or (continuous and owner_node is NetSmoother):
			continue
		var value: Variant = owner_node.get_indexed(found[2] as NodePath)
		# Copie : tableaux et dictionnaires sont partagés, la photo « avant » changerait avec l'objet.
		if typeof(value) == TYPE_ARRAY or typeof(value) == TYPE_DICTIONARY or typeof(value) >= TYPE_PACKED_BYTE_ARRAY:
			value = value.duplicate()
		out[str(root.get_path_to(owner_node)) + ":" + str(found[2])] = value


static func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is float:
		return absf(a - b) <= FLOAT_TOLERANCE
	if a is Vector3:
		return (a as Vector3).distance_to(b) <= POSITION_TOLERANCE
	if a is Transform3D:
		# Place d'un objet : à quelques cm près (un objet tenu suit la main, qui bouge avec l'animation).
		var ta: Transform3D = a
		var tb: Transform3D = b
		return ta.origin.distance_to(tb.origin) <= POSITION_TOLERANCE \
			and (ta.basis.x - tb.basis.x).length() + (ta.basis.y - tb.basis.y).length() \
			+ (ta.basis.z - tb.basis.z).length() <= 3.0 * FLOAT_TOLERANCE
	return a == b
