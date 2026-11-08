class_name DartHandle
extends Interactable
## Une fléchette du jeu du robot (DartsGame). Plantée quelque part (cible, mur…) : la viser permet de
## prendre toutes les fléchettes libres. Plantée dans un nain : un autre nain la vise pour la lui retirer.
## Placée et montrée par DartsGame à partir de son état synchronisé.

var game: DartsGame
## Numéro de la fléchette dans le jeu (0 à 2).
var index: int = 0

@onready var _shape: CollisionShape3D = $CollisionShape3D


## Visable seulement quand elle est plantée (pas en main, pas en vol).
func set_pickable(pickable: bool) -> void:
	_shape.disabled = not pickable


func interact(press: bool, grab: bool, hands_free: bool) -> Use:
	if not (press or grab) or game == null:
		return Use.NONE
	if game.dart_where[index] == DartsGame.Where.IN_DWARF:
		if game.dart_peer[index] == multiplayer.get_unique_id():
			return Use.NONE
		game.request_pull.rpc_id(1, index)
		return Use.DONE
	if not hands_free:
		return Use.NONE
	game.request_take.rpc_id(1)
	return Use.CLAIM


func get_claim() -> Node:
	return game


func get_hints() -> Array[InputHint]:
	if game == null:
		return []
	if game.dart_where[index] == DartsGame.Where.IN_DWARF:
		if game.dart_peer[index] == multiplayer.get_unique_id():
			return []
		return [InputHint.make(&"grab", &"hand_grab")]
	if game.thrower_peer_id == 0:
		return [InputHint.make(&"grab", &"hand_grab")]
	return [] if game.is_thrower_locally() else [InputHint.state(&"locked")]


func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	var meshes: Array[GeometryInstance3D] = []
	for node: Node in find_children("*", "GeometryInstance3D", true, false):
		meshes.append(node as GeometryInstance3D)
	return meshes
