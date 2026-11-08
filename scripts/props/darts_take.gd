class_name DartsTake
extends Interactable
## La cible des fléchettes du robot : on la vise pour prendre toutes les fléchettes libres (DartsGame),
## qui vont ensemble dans une case de l'inventaire.

@export var game: DartsGame


## Prendre les fléchettes (même avec un objet en main) : l'hôte les range dans une case.
func interact(press: bool, grab: bool, _hands_free: bool) -> Use:
	if not (press or grab) or game == null or not game.has_free_darts():
		return Use.NONE
	game.request_take.rpc_id(1)
	return Use.DONE


func get_hints() -> Array[InputHint]:
	if game == null or not game.has_free_darts():
		return []
	return [InputHint.make(&"interact", &"dart")]
