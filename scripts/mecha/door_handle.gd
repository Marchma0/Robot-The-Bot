class_name DoorHandle
extends Interactable
## Zone visée de la porte des toilettes : E (ou clic) l'ouvre ou la ferme.

@export var door: ToiletDoor


func get_hints() -> Array[InputHint]:
	return [InputHint.make(&"grab", &"door_close" if door.is_open else &"door_open")]


func interact(press: bool, grab: bool, _hands_free: bool) -> Use:
	if not (press or grab):
		return Use.NONE
	request_toggle.rpc_id(1)
	return Use.DONE


@rpc("any_peer", "call_local", "reliable")
func request_toggle() -> void:
	if multiplayer.is_server() and is_peer_in_reach(multiplayer.get_remote_sender_id(), reach):
		door.toggle()
