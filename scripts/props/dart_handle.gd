class_name DartHandle
extends Interactable
## Une fléchette du jeu du robot (DartsGame). Hors de la cible (posée au sol, plantée dans un mur) : la viser
## permet de prendre celle-là seulement ; dans la cible, toutes celles de la cible. Plantée dans un nain :
## un autre nain la vise pour la lui retirer.
## Dans les deux cas, elles vont dans une case de l'inventaire de celui qui les prend.
## Placée et montrée par DartsGame à partir de son état synchronisé.

var game: DartsGame
## Numéro de la fléchette dans le jeu (0 à 2).
var index: int = 0

@onready var _shape: CollisionShape3D = $CollisionShape3D


## Visable seulement quand elle est plantée (pas en main, pas en vol).
func set_pickable(pickable: bool) -> void:
	_shape.disabled = not pickable


func interact(press: bool, grab: bool, _hands_free: bool) -> Use:
	if not (press or grab) or game == null:
		return Use.NONE
	if game.dart_where[index] == DartsGame.Where.IN_DWARF:
		if game.dart_peer[index] == multiplayer.get_unique_id():
			return Use.NONE
		game.request_pull.rpc_id(1, index)
		return Use.DONE
	game.request_take_one.rpc_id(1, index)
	return Use.DONE


## Fléchette qui traîne hors de la cible (sol, mur) ou plantée dans un allié : avec un objet en main, le clic
## la ramasse au lieu de lancer. Dans la cible, le clic lance (c'est le jeu).
func takes_click_with_item() -> bool:
	if game == null:
		return false
	match game.dart_where[index]:
		DartsGame.Where.PLANTED:
			return not game.is_on_board(index)
		DartsGame.Where.IN_DWARF:
			return game.dart_peer[index] != multiplayer.get_unique_id()
	return false


func get_hints() -> Array[InputHint]:
	if game == null:
		return []
	if game.dart_where[index] == DartsGame.Where.IN_DWARF and game.dart_peer[index] == multiplayer.get_unique_id():
		return []
	return [InputHint.make(&"interact", &"dart")]


func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	var meshes: Array[GeometryInstance3D] = []
	for node: Node in find_children("*", "GeometryInstance3D", true, false):
		meshes.append(node as GeometryInstance3D)
	return meshes
