class_name SoundCounter
extends RefCounted
## Compte les sons ponctuels joués (SoundFx) pendant une scène de test, par nom de fichier.
## Usage : `var sounds := SoundCounter.new(get_tree())` puis `sounds.count("robot_step")`.

var _counts: Dictionary = {}


func _init(tree: SceneTree) -> void:
	tree.node_added.connect(_on_node_added)


## Nombre de sons joués dont le fichier commence par `prefix` (ex. "robot_step").
func count(prefix: String) -> int:
	var total: int = 0
	for file: String in _counts:
		if file.begins_with(prefix):
			total += _counts[file]
	return total


func _on_node_added(node: Node) -> void:
	var player: AudioStreamPlayer3D = node as AudioStreamPlayer3D
	if player == null:
		return
	# Le son est réglé juste après l'ajout : on le lit à l'image suivante.
	_read.call_deferred(player)


func _read(player: AudioStreamPlayer3D) -> void:
	if not is_instance_valid(player) or player.stream == null:
		return
	var file: String = player.stream.resource_path.get_file()
	_counts[file] = _counts.get(file, 0) + 1
