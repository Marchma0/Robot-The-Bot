class_name DartsTake
extends Interactable
## Seau de fléchettes posé près de la ligne de tir : on le vise et on prend les 3 fléchettes (DartsGame).

@export var game: DartsGame


## Prendre les 3 fléchettes (mains libres) : on va les tenir.
func interact(press: bool, grab: bool, hands_free: bool) -> Use:
	if not (press or grab) or not hands_free or game == null:
		return Use.NONE
	game.request_take.rpc_id(1)
	return Use.CLAIM


func get_claim() -> Node:
	return game


func get_hints() -> Array[InputHint]:
	if game == null:
		return []
	if game.thrower_peer_id == 0:
		return [InputHint.make(&"grab", &"hand_grab")]
	if game.is_thrower_locally():
		return []
	return [InputHint.state(&"locked")]
