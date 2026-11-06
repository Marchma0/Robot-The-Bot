class_name PoopHandle
extends Interactable
## Zone visée pour ramasser un caca (enfant du caca).

@export var poop: Poop


func get_hints() -> Array[InputHint]:
	if poop.holder_peer_id != 0:
		return []
	return [InputHint.make(&"interact", &"poop_gold" if poop.golden else &"poop")]


func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	var meshes: Array[GeometryInstance3D] = []
	for node: Node in poop.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as GeometryInstance3D)
	return meshes
