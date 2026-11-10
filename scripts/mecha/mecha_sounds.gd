class_name MechaSounds
extends Node
## Sons du robot : pas, réception d'un saut, chute à genoux, et bips du QTE sur les consoles des jambes.
##
## Réseau : rien à envoyer. Chaque peer regarde l'état déjà synchronisé (pieds en l'air, phase du Walker,
## avancement et erreurs du QTE) et joue le son quand il change.

@export var walker: MechaWalker
@export var qte: QteSequence
## Consoles des jambes : les bips du QTE en sortent.
@export var consoles: Array[Node3D] = []
## Corps du robot (la chute s'entend de là).
@export var body: Node3D

var _ready_done: bool = false
var _was_swinging: Array[bool] = [false, false]
var _last_phase: int = MechaWalker.Phase.WALKING
var _landing_sound_done: bool = false
var _last_step_index: int = 0
var _last_mistakes: int = 0
var _was_active: bool = false


func _physics_process(_delta: float) -> void:
	if not _ready_done:
		_remember()
		_ready_done = true
		return
	_feet()
	_phase()
	_qte()
	_remember()


func _feet() -> void:
	var swinging: Array[bool] = [walker.swinging_left, walker.swinging_right]
	for leg: int in 2:
		if not (_was_swinging[leg] and not swinging[leg]):
			continue
		var foot: Node3D = walker.get_node("FootL" if leg == 0 else "FootR") as Node3D
		if _last_phase == MechaWalker.Phase.JUMPING or walker.phase == MechaWalker.Phase.JUMPING:
			if not _landing_sound_done:
				_landing_sound_done = true   # les deux pieds se posent ensemble : un seul gros choc
				SoundFx.play_at(foot, SoundFx.ROBOT_LAND, 4.0, 0.8)
		else:
			SoundFx.play_at(foot, SoundFx.pick(SoundFx.ROBOT_STEPS), 0.0, 0.75)


func _phase() -> void:
	if walker.phase == _last_phase:
		return
	if walker.phase == MechaWalker.Phase.JUMPING:
		_landing_sound_done = false
	elif walker.phase == MechaWalker.Phase.FALLEN and _last_phase == MechaWalker.Phase.FALLING:
		SoundFx.play_at(body, SoundFx.ROBOT_FALL, 6.0, 0.7)


func _qte() -> void:
	if qte.active and _was_active:
		if qte.mistake_count > _last_mistakes:
			_on_consoles(SoundFx.QTE_ERROR, -4.0)
		elif qte.step_index > _last_step_index:
			_on_consoles(SoundFx.QTE_TICK, -2.0)
	elif _was_active and not qte.active:
		if qte.step_count > 0 and qte.step_index >= qte.step_count:
			_on_consoles(SoundFx.QTE_SUCCESS, -2.0)
		elif qte.mistake_count > _last_mistakes:
			_on_consoles(SoundFx.QTE_ERROR, -4.0)   # QTE qui traîne : annulé


func _on_consoles(stream: AudioStream, volume_db: float) -> void:
	for console: Node3D in consoles:
		SoundFx.play_at(console, stream, volume_db, 1.0, 0.0)


func _remember() -> void:
	_was_swinging = [walker.swinging_left, walker.swinging_right]
	_last_phase = walker.phase
	_last_step_index = qte.step_index
	_last_mistakes = qte.mistake_count
	_was_active = qte.active
