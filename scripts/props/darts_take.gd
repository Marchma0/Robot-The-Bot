class_name DartsTake
extends Interactable
## Seau de fléchettes posé près de la ligne de tir : on le vise et on prend les 3 fléchettes (DartsGame).

@export var game: DartsGame


func get_hints() -> Array[InputHint]:
	if game == null:
		return []
	if game.thrower_peer_id == 0:
		return [InputHint.make(&"grab", &"hand_grab")]
	if game.is_thrower_locally():
		return []
	return [InputHint.state(&"locked")]
