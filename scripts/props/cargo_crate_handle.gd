class_name CargoCrateHandle
extends Interactable
## Zone visée pour ranger une caisse de ravitaillement dans le sac à dos (enfant de CargoCrate).

@export var crate: CargoCrate


func get_hints() -> Array[InputHint]:
	return [InputHint.make(&"interact", &"hand_grab")]


func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	var meshes: Array[GeometryInstance3D] = []
	if crate == null:
		return meshes
	for node: Node in crate.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as GeometryInstance3D)
	return meshes
