class_name NetSpawner
extends MultiplayerSpawner
## MultiplayerSpawner qui accepte aussi les objets réseau posés à la main dans l'éditeur.
##
## Un objet posé dans une scène existe chez chaque joueur, mais s'il disparaît ou bouge chez l'hôte,
## les clients ne le savent pas (Godot ne réplique que ce qu'un spawner a créé). Au chargement :
## - chez l'hôte, chaque enfant de `spawn_path` dont la scène est dans la liste du spawner est
##   retiré puis remis : le spawner le prend en charge et l'envoie aux clients (place comprise) ;
## - chez un client, ces copies locales sont supprimées : il recevra celles de l'hôte.
## Résultat : apparitions, disparitions et déplacements vus par tout le monde, même en arrivant
## en cours de partie. À utiliser pour tout dossier d'objets (caisses, cacas…) d'un niveau.


func _ready() -> void:
	var root: Node = get_node_or_null(spawn_path)
	if root == null:
		return
	for child: Node in root.get_children():
		if not _is_spawnable(child):
			continue
		if multiplayer.is_server():
			_adopt.call_deferred(root, child)
		else:
			root.remove_child(child)
			child.queue_free()


func _adopt(root: Node, child: Node) -> void:
	if not is_instance_valid(child) or child.get_parent() != root:
		return
	root.remove_child(child)
	root.add_child(child)
	# Le spawner n'active la synchro qu'au signal `ready`, qui ne revient pas tout seul pour
	# un nœud déjà prêt : on le renvoie (sans relancer `_ready` du script).
	child.ready.emit()


func _is_spawnable(node: Node) -> bool:
	for i: int in get_spawnable_scene_count():
		if get_spawnable_scene(i) == node.scene_file_path:
			return true
	return false
