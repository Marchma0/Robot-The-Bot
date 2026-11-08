class_name CheckersCell
extends Interactable
## Une case sombre du damier de la table basse : on la vise pour choisir un pion, puis la case où il va
## (CheckersGame). Créée par CheckersGame, une par case jouable.

var game: CheckersGame
var cell: int = -1

var _marker: MeshInstance3D


func setup(p_game: CheckersGame, p_cell: int, size: float, marker_material: Material) -> void:
	game = p_game
	cell = p_cell
	display_name = "Dames"
	reach = CheckersGame.REACH
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(size, 0.03, size)
	shape.shape = box
	shape.position.y = 0.013
	add_child(shape)
	# Surface invisible de la case, qui se surligne quand on la vise.
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.material = marker_material
	_marker = MeshInstance3D.new()
	_marker.mesh = plane
	_marker.position.y = 0.0012
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)


func interact(press: bool, grab: bool, _hands_free: bool) -> Use:
	if not (press or grab):
		return Use.NONE
	game.request_cell.rpc_id(1, cell)
	return Use.DONE


func get_hints() -> Array[InputHint]:
	return game.hints_for(cell)


func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	var meshes: Array[GeometryInstance3D] = [_marker]
	meshes.append_array(game.piece_meshes_at(cell))
	return meshes
