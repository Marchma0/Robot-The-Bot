class_name PoopHandle
extends Interactable
## Zone visée pour ramasser un caca (enfant du caca).

@export var poop: Poop


func get_prompt() -> String:
	if poop.holder_peer_id != 0:
		return ""
	return "[E / clic] ramasser — %s" % display_name


func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	var meshes: Array[GeometryInstance3D] = []
	for node: Node in poop.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as GeometryInstance3D)
	return meshes
