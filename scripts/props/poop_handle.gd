class_name PoopHandle
extends Interactable
## Zone visée pour ramasser un caca (enfant du caca) : il va dans une case de l'inventaire.

@export var poop: Poop


func get_hints() -> Array[InputHint]:
	if poop.holder_peer_id != 0:
		return []
	return [InputHint.make(&"interact", &"poop_gold" if poop.golden else &"poop")]


## Ramasser le caca (même avec un objet en main) : l'hôte le range dans une case libre.
func interact(press: bool, grab: bool, _hands_free: bool) -> Use:
	if not (press or grab) or poop.holder_peer_id != 0:
		return Use.NONE
	poop.request_pick.rpc_id(1)
	return Use.DONE


func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	var meshes: Array[GeometryInstance3D] = []
	for node: Node in poop.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as GeometryInstance3D)
	return meshes
