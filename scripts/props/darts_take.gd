class_name DartsTake
extends Interactable
## La cible des fléchettes du robot (DartsGame). Si des fléchettes traînent ailleurs (mur, sol, dans un nain),
## un clic les remet toutes sur la cible (pratique quand on les a perdues) ; sinon, un clic prend les
## fléchettes de la cible, qui vont ensemble dans une case de l'inventaire. E fait pareil.

@export var game: DartsGame


func interact(press: bool, grab: bool, _hands_free: bool) -> Use:
	if not (press or grab) or game == null:
		return Use.NONE
	if game.has_darts_away():
		game.request_reset.rpc_id(1)
		return Use.DONE
	if not game.has_free_darts():
		return Use.NONE
	game.request_take.rpc_id(1)
	return Use.DONE


func get_hints() -> Array[InputHint]:
	if game == null:
		return []
	if game.has_darts_away():
		return [InputHint.make(&"grab", &"darts_reset")]
	if not game.has_free_darts():
		return []
	return [InputHint.make(&"grab", &"dart")]
