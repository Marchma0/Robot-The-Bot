class_name CargoCrateHandle
extends Interactable
## Zone visée pour prendre une caisse à deux mains (enfant de CargoCrate) : elle va dans l'inventaire,
## en objet lourd. Seul le robot la range dans son sac (grappin).

@export var crate: CargoCrate


func get_hints() -> Array[InputHint]:
	if crate.holder_peer_id != 0:
		return []
	return [InputHint.make(&"interact", &"crate")]


## Prendre la caisse (même avec un objet en main : il est rangé, la caisse passe en main).
func interact(press: bool, grab: bool, _hands_free: bool) -> Use:
	if not (press or grab) or crate.holder_peer_id != 0:
		return Use.NONE
	crate.request_pick.rpc_id(1)
	return Use.DONE


func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	var meshes: Array[GeometryInstance3D] = []
	if crate == null:
		return meshes
	for node: Node in crate.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as GeometryInstance3D)
	return meshes
