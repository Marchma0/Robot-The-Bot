class_name MechaManeuvers
extends Node
## Saut et accroupi du robot (M7.5), lancés depuis l'écran « Prêt » des consoles des jambes :
## - ↑ par les deux pilotes à moins de `pair_window` s d'écart : QTE du saut. 1re étape : les deux poussent
##   leur joystick dans la même direction (à 30° près) ; puis des flèches à tour de rôle. Réussi : le robot
##   saute dans cette direction (MechaWalker.jump).
## - ↓ par les deux : QTE de l'accroupi (des flèches). Réussi : le robot reste accroupi. Accroupi, ↓ par les
##   deux le relève, sans QTE.
## - Un QTE où personne ne progresse pendant `fail_after` s s'annule et la jauge d'erreur monte (`fail_error`).
##
## Réseau : tout se décide chez l'hôte (appuis déjà validés par les PushButton, joysticks déjà envoyés).
## Synchronisés : la flèche attendue chez l'autre pilote (`waiting_arrow`, `waiting_leg`), pour que
## l'écran dise « attends l'autre ». Le QTE (QteSequence) et le robot (MechaWalker) ont leur propre synchro.

enum Kind { NONE, JUMP, CROUCH }

@export var walker: MechaWalker
@export var qte: QteSequence
## Écart max entre les appuis des deux pilotes (s).
@export var pair_window: float = 1.0
## Tours de flèches après l'étape joystick (saut), et pour l'accroupi.
@export var jump_turns: int = 2
@export var crouch_turns: int = 2
## Un QTE qui ne progresse plus pendant ce temps (s) échoue ; la jauge d'erreur monte de `fail_error`.
@export var fail_after: float = 3.0
@export var fail_error: float = 0.35

## Flèche (QteSequence.Arrow) sur laquelle un pilote a appuyé, en attendant l'autre (-1 = rien), et sa jambe.
## Autorité : hôte (synchronisé).
var waiting_arrow: int = -1
var waiting_leg: int = -1

var _wait_time: float = 0.0
var _running: Kind = Kind.NONE
## Hôte : juste après la fin d'un QTE, les appuis sont ignorés un instant (le dernier appui du QTE ne doit
## pas compter comme une demande de saut ou d'accroupi).
var _cooldown: float = 0.0


func _ready() -> void:
	if qte == null:
		return
	for leg: int in 2:
		var pads: Array[PushButton] = qte.pads_left if leg == 0 else qte.pads_right
		pads[QteSequence.Arrow.UP].pressed.connect(_on_pad.bind(leg, QteSequence.Arrow.UP))
		pads[QteSequence.Arrow.DOWN].pressed.connect(_on_pad.bind(leg, QteSequence.Arrow.DOWN))
	qte.completed.connect(_on_qte_completed)
	qte.failed.connect(_on_qte_failed)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if waiting_arrow < 0:
		return
	_wait_time += delta
	if _wait_time > pair_window or not _can_start():
		_clear_wait()


func _on_pad(_peer_id: int, leg: int, arrow: int) -> void:
	if not multiplayer.is_server() or not _can_start() or _cooldown > 0.0:
		return
	if waiting_arrow == arrow and waiting_leg != leg:
		_clear_wait()
		_launch(arrow)
		return
	waiting_arrow = arrow
	waiting_leg = leg
	_wait_time = 0.0


## Hôte : les deux pilotes ont appuyé sur la même flèche.
func _launch(arrow: int) -> void:
	if arrow == QteSequence.Arrow.DOWN and walker.crouched:
		walker.set_crouched(false)   # accroupi : ↓ ensemble le relève, sans QTE
		return
	if arrow == QteSequence.Arrow.UP:
		if walker.crouched:
			return   # pas de saut accroupi : il faut d'abord se relever
		var steps: Array[Vector2i] = [Vector2i(QteSequence.BOTH, 0)]
		steps.append_array(QteSequence.random_steps(jump_turns))
		_running = Kind.JUMP
		qte.start(steps, fail_after)
	else:
		_running = Kind.CROUCH
		qte.start(QteSequence.random_steps(crouch_turns), fail_after)


func _on_qte_completed() -> void:
	var kind: Kind = _running
	_running = Kind.NONE
	_cooldown = 0.5
	match kind:
		Kind.JUMP:
			walker.jump(qte.stick_direction)
		Kind.CROUCH:
			walker.set_crouched(true)


func _on_qte_failed() -> void:
	_cooldown = 0.5
	if _running == Kind.NONE:
		return
	_running = Kind.NONE
	walker.add_error(fail_error)


## Un saut ou un accroupi peut partir : le robot marche, aucun pied en l'air, pas de QTE en cours.
func _can_start() -> bool:
	return walker != null and qte != null and not qte.active and walker.can_maneuver()


func _clear_wait() -> void:
	waiting_arrow = -1
	waiting_leg = -1
	_wait_time = 0.0
