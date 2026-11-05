class_name ToiletDoor
extends Node3D
## Porte des toilettes (le nœud est la charnière) : on l'ouvre ou la ferme avec E,
## de dehors comme de dedans. Fermée, elle bloque le passage.
##
## Réseau : l'hôte est autoritaire sur `is_open` (répliqué) ; la demande passe par la
## poignée (DoorHandle), qui vérifie la portée. Chaque peer anime la rotation.

## Angle d'ouverture (rad) et vitesse (rad/s).
@export var open_angle: float = deg_to_rad(100.0)
@export var speed: float = 3.5

## Ouverte ou fermée. Autorité : hôte.
var is_open: bool = false


func _ready() -> void:
	NetworkManager.session_ended.connect(_on_session_ended)


func _process(delta: float) -> void:
	# Animation purement visuelle (la collision suit la porte, qui est son parent).
	rotation.y = move_toward(rotation.y, open_angle if is_open else 0.0, speed * delta)


## Appelé par l'hôte (poignée validée).
func toggle() -> void:
	if multiplayer.is_server():
		is_open = not is_open


func _on_session_ended(_reason: String) -> void:
	is_open = false
