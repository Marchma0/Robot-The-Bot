class_name NetSmoother
extends Node
## Synchronise la place d'un Node3D (la cible) et la lisse chez les autres joueurs.
##
## - Chez le propriétaire (autorité) : `net_state` est lu par le MultiplayerSynchronizer,
##   qui l'envoie (~30 fois par seconde). Rien d'autre à faire.
## - Chez les autres : chaque état reçu est rangé avec son heure d'envoi. La cible est
##   affichée avec DELAY de retard, en glissant entre les deux états qui encadrent ce moment.
##   Les paquets en retard ou perdus ne se voient donc pas.
##
## La place est envoyée dans le repère du parent (cas normal : un nain dans le cockpit),
## ou dans le monde si `world_space` est vrai (un nain dehors ne suit plus le mécha).
## La cible est déplacée dans _physics_process : le lissage physique de Godot
## (physics_interpolation) fait le reste entre deux étapes.

## Retard d'affichage des autres joueurs (s).
const DELAY: float = 0.1
## Au-delà de cet écart entre deux états, on saute directement (téléportation, réapparition).
const SNAP_DISTANCE: float = 3.0
## Vitesse de recalage de l'horloge (s par s) et écart au-delà duquel on saute directement (s).
const CLOCK_CATCH_UP: float = 0.05
const MAX_CLOCK_DRIFT: float = 0.25
## Nombre max d'états gardés en mémoire.
const MAX_BUFFER: int = 20

@export var target: Node3D
## Nœud optionnel dont l'inclinaison (rotation.x) est aussi synchronisée (la tête du nain).
@export var pitch_node: Node3D

## Vrai si la cible doit être placée dans le monde et non dans le repère de son parent.
## Écrit par le propriétaire de la cible, envoyé avec la position.
var world_space: bool = false

## État envoyé : [heure, monde ?, px, py, pz, qx, qy, qz, qw, inclinaison].
var net_state: PackedFloat64Array:
	get:
		return _read_state()
	set(value):
		_push_state(value)

## États reçus, du plus ancien au plus récent.
var _buffer: Array[PackedFloat64Array] = []
## Écart entre notre horloge et celle de l'expéditeur (s) : estimé (`_target_offset`) et
## utilisé (`_clock_offset`, qui rejoint l'estimation en douceur pour ne pas faire d'à-coup).
var _clock_offset: float = 0.0
var _target_offset: float = 0.0
var _has_offset: bool = false
var _applied_once: bool = false


func _physics_process(_delta: float) -> void:
	if is_multiplayer_authority() or _buffer.is_empty() or target == null:
		return
	# Recalage doux de l'horloge (au plus 5 % de vitesse en plus ou en moins) ; saut direct si très loin.
	if absf(_target_offset - _clock_offset) > MAX_CLOCK_DRIFT:
		_clock_offset = _target_offset
	else:
		_clock_offset = move_toward(_clock_offset, _target_offset, CLOCK_CATCH_UP * _delta)
	var render_time: float = _now() - _clock_offset - DELAY
	# On jette les états trop vieux, en gardant celui juste avant render_time.
	while _buffer.size() >= 2 and _buffer[1][0] <= render_time:
		_buffer.pop_front()
	var from: PackedFloat64Array = _buffer[0]
	if _buffer.size() == 1 or render_time <= from[0]:
		_apply(from, from, 0.0)
		return
	var to: PackedFloat64Array = _buffer[1]
	var t: float = clampf((render_time - from[0]) / maxf(to[0] - from[0], 0.0001), 0.0, 1.0)
	_apply(from, to, t)


## Heure de simulation : nombre d'étapes physiques écoulées (même pas chez tout le monde).
func _now() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


func _read_state() -> PackedFloat64Array:
	if target == null:
		return PackedFloat64Array()
	var xform: Transform3D = target.global_transform if world_space else target.transform
	var q: Quaternion = xform.basis.get_rotation_quaternion()
	var pitch: float = pitch_node.rotation.x if pitch_node != null else 0.0
	return PackedFloat64Array([
		_now(), 1.0 if world_space else 0.0,
		xform.origin.x, xform.origin.y, xform.origin.z,
		q.x, q.y, q.z, q.w, pitch,
	])


func _push_state(state: PackedFloat64Array) -> void:
	# Pendant l'apparition (spawn), l'état arrive avant l'entrée dans l'arbre : on le garde.
	if state.size() < 10 or (is_inside_tree() and is_multiplayer_authority()):
		return
	var sample: float = _now() - state[0]
	if not _has_offset:
		_target_offset = sample
		_clock_offset = sample
		_has_offset = true
	elif sample < _target_offset:
		# Paquet arrivé plus vite que prévu : l'estimation se cale dessus.
		_target_offset = sample
	else:
		# Le réseau ralentit : on laisse lentement plus de marge.
		_target_offset = lerpf(_target_offset, sample, 0.02)
	if not _buffer.is_empty() and state[0] <= _buffer.back()[0]:
		return   # vieux paquet arrivé en retard
	_buffer.append(state)
	if _buffer.size() > MAX_BUFFER:
		_buffer.pop_front()


func _apply(from: PackedFloat64Array, to: PackedFloat64Array, t: float) -> void:
	var snap: bool = not _applied_once or from[1] != to[1] \
		or _origin(from).distance_to(_origin(to)) > SNAP_DISTANCE
	if snap:
		# Changement de repère (sortie / retour dans le mécha) ou téléportation : pas de glissé.
		from = to
		t = 0.0
	var origin: Vector3 = _origin(from).lerp(_origin(to), t)
	var rotation: Quaternion = _quat(from).slerp(_quat(to), t)
	var xform: Transform3D = Transform3D(Basis(rotation), origin)
	if to[1] > 0.5:
		target.global_transform = xform
	else:
		target.transform = xform
	if pitch_node != null:
		pitch_node.rotation.x = lerpf(from[9], to[9], t)
	if snap and _applied_once:
		target.reset_physics_interpolation()
	if not _applied_once:
		_applied_once = true
		target.reset_physics_interpolation()


func _origin(state: PackedFloat64Array) -> Vector3:
	return Vector3(state[2], state[3], state[4])


func _quat(state: PackedFloat64Array) -> Quaternion:
	return Quaternion(state[5], state[6], state[7], state[8]).normalized()
