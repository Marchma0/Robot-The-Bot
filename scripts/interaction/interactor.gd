class_name Interactor
extends RayCast3D
## Rayon de visée du nain local (enfant de sa caméra).
## Trouve la commande visée, la surligne, envoie les demandes à l'hôte
## (appuyer, attraper, lâcher, s'installer, se lever) et pilote le levier tenu.
## Actif uniquement pour le joueur local.

## Le message à afficher a changé ("" = rien à afficher).
signal prompt_changed(text: String)
## Le joueur vient d'appuyer sur un bouton (sert à l'animation "press").
signal button_pressed

## Délai max d'attente de la réponse de l'hôte après une demande (attraper, s'installer).
const GRAB_TIMEOUT: float = 1.0

## Variation de la valeur du levier par pixel de souris.
@export var mouse_lever_sensitivity: float = 0.006
## Variation de la valeur du levier par seconde au stick (stick à fond).
@export var stick_lever_speed: float = 2.5

var _target: Interactable = null
var _held: Lever = null
var _grab_pending: bool = false
var _grab_wait: float = 0.0
var _wanted: Vector2 = Vector2.ZERO
var _seat: Seat = null
var _seat_pending: bool = false
var _seat_wait: float = 0.0
var _prompt: String = ""


func _ready() -> void:
	set_active(false)


func _physics_process(delta: float) -> void:
	if _seat != null:
		# Assis (ou en attente de l'hôte) : seule action possible, se lever.
		_set_target(null)
		_update_seat(delta)
	else:
		_update_target()
		_handle_actions()
		_update_held(delta)
	_update_prompt()


func set_active(active: bool) -> void:
	enabled = active
	set_physics_process(active)
	if not active:
		_set_target(null)


## Vrai quand le joueur tient un levier (confirmé par l'hôte).
func is_holding() -> bool:
	return _held != null and not _grab_pending and _held.is_held_locally()


## Le siège où le joueur est installé (confirmé par l'hôte), sinon null.
func get_seat() -> Seat:
	if _seat != null and not _seat_pending and _seat.is_seated_locally():
		return _seat
	return null


## Mouvement de souris en pixels (x droite, y haut) pendant qu'on tient un levier.
func drive_mouse(motion: Vector2) -> void:
	_drive(motion * mouse_lever_sensitivity)


## Stick (-1..1, y haut) pendant qu'on tient un levier.
func drive_stick(stick: Vector2, delta: float) -> void:
	_drive(stick * stick_lever_speed * delta)


func _drive(change: Vector2) -> void:
	if is_holding():
		_wanted = _held.constrain(_wanted + change)


func _update_target() -> void:
	var collider: Object = get_collider() if is_colliding() else null
	_set_target(collider as Interactable)


func _set_target(target: Interactable) -> void:
	if target == _target:
		return
	if _target != null and is_instance_valid(_target):
		_target.set_highlighted(false)
	_target = target
	if _target != null:
		_target.set_highlighted(true)


func _handle_actions() -> void:
	var press: bool = Input.is_action_just_pressed("interact")
	var grab: bool = Input.is_action_just_pressed("grab")
	if _target is PushButton and (press or grab):
		(_target as PushButton).request_press.rpc_id(1)
		button_pressed.emit()
	elif _target is Seat and (press or grab) and _held == null:
		_seat = _target as Seat
		_seat_pending = true
		_seat_wait = 0.0
		_seat.request_sit.rpc_id(1)
	elif _target is Lever and grab and _held == null:
		_held = _target as Lever
		_grab_pending = true
		_grab_wait = 0.0
		_wanted = _held.value
		_held.request_grab.rpc_id(1)
	if _held != null and Input.is_action_just_released("grab"):
		_release()


func _update_held(delta: float) -> void:
	if _held == null:
		return
	if _grab_pending:
		_grab_wait += delta
		if _held.is_held_locally():
			_grab_pending = false
		elif _grab_wait > GRAB_TIMEOUT or (_held.holder_peer_id != 0):
			# Refusé (trop loin, déjà tenu, ou on tient déjà autre chose).
			_held = null
			_grab_pending = false
		return
	if not _held.is_held_locally():
		# L'hôte nous l'a retiré (trop loin, etc.).
		_held = null
		return
	_held.set_local_value(_wanted)
	_held.submit_value.rpc_id(1, _wanted)


func _update_seat(delta: float) -> void:
	if _seat_pending:
		_seat_wait += delta
		if _seat.is_seated_locally():
			_seat_pending = false
		elif _seat_wait > GRAB_TIMEOUT or _seat.occupant_peer_id != 0:
			_seat = null   # refusé (occupé, trop loin…)
			_seat_pending = false
		return
	if not _seat.is_seated_locally():
		_seat = null   # l'hôte nous a libéré
		return
	if Input.is_action_just_pressed("interact"):
		_seat.request_leave.rpc_id(1)
		_seat = null


func _release() -> void:
	# Envoyé même si l'hôte n'a pas encore répondu : les RPC fiables arrivent dans l'ordre,
	# donc un "attraper" accepté juste avant sera bien suivi du "lâcher".
	_held.request_release.rpc_id(1)
	_held = null
	_grab_pending = false


func _update_prompt() -> void:
	var text: String = ""
	if _seat != null and not _seat_pending:
		text = _seat.get_prompt()
	elif _held != null and not _grab_pending:
		text = _held.get_prompt()
	elif _target != null:
		text = _target.get_prompt()
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)
