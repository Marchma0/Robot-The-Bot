class_name Toilet
extends Seat
## Toilettes : on s'y assoit (E) pour faire caca. Après quelques secondes d'effort,
## un caca apparaît dans la cuvette (on peut ensuite le ramasser et le lancer).
##
## Réseau : l'hôte compte le temps passé assis et fait apparaître le caca dans `props_root`
## (un MultiplayerSpawner le crée chez tout le monde).

const POOP_SCENE: PackedScene = preload("res://scenes/props/poop.tscn")
## Temps d'effort avant qu'un caca tombe (s).
const PUSH_TIME: float = 3.5
## Nombre max de cacas dans le mécha en même temps.
const MAX_POOPS: int = 6

## Nœud (dans le mécha) où les cacas apparaissent, surveillé par un MultiplayerSpawner.
@export var props_root: Node3D

var _push_time: float = 0.0

@onready var _bowl_point: Marker3D = %BowlPoint


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if occupant_peer_id == 0:
		_push_time = 0.0
		return
	_push_time += delta
	if _push_time >= PUSH_TIME:
		_push_time = 0.0
		_drop_poop()


func get_prompt() -> String:
	if is_seated_locally():
		return "Pousse… — [E] se lever"
	if occupant_peer_id != 0:
		return "%s — occupé" % display_name
	return "[E / clic] faire caca — %s" % display_name


func _drop_poop() -> void:
	if props_root == null or get_tree().get_nodes_in_group(&"poops").size() >= MAX_POOPS:
		return
	var poop: Poop = POOP_SCENE.instantiate()
	props_root.add_child(poop, true)
	poop.global_position = _bowl_point.global_position
