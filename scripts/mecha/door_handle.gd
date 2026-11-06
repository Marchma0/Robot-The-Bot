class_name DoorHandle
extends Interactable
## Zone visée de la porte des toilettes : E (ou clic) l'ouvre ou la ferme.

@export var door: ToiletDoor


func get_hints() -> Array[InputHint]:
	return [InputHint.make(&"interact", &"door_close" if door.is_open else &"door_open")]


@rpc("any_peer", "call_local", "reliable")
func request_toggle() -> void:
	if multiplayer.is_server() and is_peer_in_reach(multiplayer.get_remote_sender_id(), reach):
		door.toggle()
