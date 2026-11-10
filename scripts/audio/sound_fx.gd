class_name SoundFx
extends RefCounted
## Sons ponctuels joués en 3D à une place, sans nœud à préparer (sons Kenney, CC0 : assets/audio/sfx/).
##
## Réseau : rien. Règle du projet : on synchronise l'état, jamais le son ; chaque peer joue lui-même le son
## quand il voit l'état changer (pas du robot, appui sur un bouton…).

const ROBOT_STEPS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/robot_step_1.ogg"),
	preload("res://assets/audio/sfx/robot_step_2.ogg"),
	preload("res://assets/audio/sfx/robot_step_3.ogg"),
]
const ROBOT_LAND: AudioStream = preload("res://assets/audio/sfx/robot_land.ogg")
const ROBOT_FALL: AudioStream = preload("res://assets/audio/sfx/robot_fall.ogg")
const QTE_TICK: AudioStream = preload("res://assets/audio/sfx/qte_tick.ogg")
const QTE_ERROR: AudioStream = preload("res://assets/audio/sfx/qte_error.ogg")
const QTE_SUCCESS: AudioStream = preload("res://assets/audio/sfx/qte_success.ogg")
const STICK_CLACK: AudioStream = preload("res://assets/audio/sfx/stick_clack.ogg")
const BUTTON_CLICK: AudioStream = preload("res://assets/audio/sfx/button_click.ogg")


## Joue `stream` une fois, accroché à `parent` (il suit ses déplacements), puis le lecteur disparaît.
## `pitch_jitter` : petite variation de hauteur au hasard, pour qu'un même son répété ne lasse pas.
static func play_at(parent: Node3D, stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0,
		pitch_jitter: float = 0.06) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	player.finished.connect(player.queue_free)
	parent.add_child(player)
	player.play()


## Un des sons de `streams`, au hasard.
static func pick(streams: Array[AudioStream]) -> AudioStream:
	return streams[randi() % streams.size()]
