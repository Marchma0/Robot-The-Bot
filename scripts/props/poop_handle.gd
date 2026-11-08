class_name PoopHandle
extends Interactable
## Zone visée pour ramasser un caca (enfant du caca).

@export var poop: Poop


func get_hints() -> Array[InputHint]:
	if poop.holder_peer_id != 0:
		return []
	return [InputHint.make(&"grab", &"poop_gold" if poop.golden else &"poop")]


## Ramasser le caca (il faut avoir les mains libres) : on va le tenir.
func interact(press: bool, grab: bool, hands_free: bool) -> Use:
	if not (press or grab) or not hands_free:
		return Use.NONE
	poop.request_pick.rpc_id(1)
	return Use.CLAIM


func get_claim() -> Node:
	return poop


func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	var meshes: Array[GeometryInstance3D] = []
	for node: Node in poop.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as GeometryInstance3D)
	return meshes
