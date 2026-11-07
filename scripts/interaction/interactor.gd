class_name Interactor
extends RayCast3D
## Rayon de visée du nain local (enfant de sa caméra).
## Trouve la commande visée, la surligne, envoie les demandes à l'hôte
## (appuyer, attraper, lâcher, s'installer, se lever, grimper, ramasser / lancer un caca)
## et pilote le levier tenu.
## Actif uniquement pour le joueur local.

## Les indices à afficher (touche → icône) ont changé (liste vide = rien à afficher).
signal hints_changed(hints: Array[InputHint])
## Le joueur vient d'appuyer sur un bouton (sert à l'animation "press").
signal button_pressed
## Le joueur vient de lancer un objet (sert à l'animation "throw").
signal thrown

## Délai max d'attente de la réponse de l'hôte après une demande (attraper, s'installer).
const GRAB_TIMEOUT: float = 1.0
## Zone morte du stick de la manette pour un joystick à ressort.
const STICK_DEADZONE: float = 0.2

## Variation de la valeur du levier par pixel de souris.
@export var mouse_lever_sensitivity: float = 0.006
## Variation de la valeur du levier par seconde au stick (stick à fond).
@export var stick_lever_speed: float = 2.5

var _target: Interactable = null
var _held: Lever = null
var _grab_pending: bool = false
var _grab_wait: float = 0.0
var _wanted: Vector2 = Vector2.ZERO
## Le joueur a poussé le levier tenu pendant cette image (sinon un joystick à ressort revient au centre).
var _pushed: bool = false
var _seat: Seat = null
var _seat_pending: bool = false
var _seat_wait: float = 0.0
var _rope: Rope = null
var _rope_pending: bool = false
var _rope_wait: float = 0.0
var _poop: Poop = null
var _poop_wait: float = 0.0
var _hints_key: String = ""


func _ready() -> void:
	set_active(false)


func _physics_process(delta: float) -> void:
	if _seat != null:
		# Assis (ou en attente de l'hôte) : seule action possible, se lever.
		_set_target(null)
		_update_seat(delta)
	elif _rope != null:
		# Sur la corde (ou en attente de l'hôte) : seule action possible, lâcher.
		_set_target(null)
		_update_rope(delta)
	else:
		_update_target()
		_handle_actions()
		_update_held(delta)
		_update_poop(delta)
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


## La corde à laquelle le joueur grimpe (confirmé par l'hôte), sinon null.
func get_rope() -> Rope:
	if _rope != null and not _rope_pending and _rope.is_held_locally():
		return _rope
	return null


## Lâche la corde (relâcher le bouton, sauter, ou arrivé en haut).
func release_rope() -> void:
	if _rope != null:
		_rope.request_release.rpc_id(1)
		_rope = null
		_rope_pending = false


## Vrai quand le joueur tient un caca (confirmé par l'hôte).
func is_holding_poop() -> bool:
	return _poop != null and is_instance_valid(_poop) and _poop.is_held_locally()


## Inclinaison affichée du levier tenu, en radians (x = côté, y = avant/arrière), ZERO si on ne tient rien.
func get_held_tilt() -> Vector2:
	if not is_holding():
		return Vector2.ZERO
	return _wanted * deg_to_rad(_held.max_angle_degrees)


## Mouvement de souris en pixels (x droite, y haut) pendant qu'on tient un levier.
func drive_mouse(motion: Vector2) -> void:
	_drive(motion * mouse_lever_sensitivity)
	_pushed = _pushed or motion.length() > 0.0


## Stick (-1..1, y haut) pendant qu'on tient un levier.
func drive_stick(stick: Vector2, delta: float) -> void:
	if is_holding() and _held.self_centering:
		# Joystick à ressort : il suit directement le stick de la manette.
		if stick.length() > STICK_DEADZONE:
			_wanted = _held.constrain(stick)
			_pushed = true
		return
	_drive(stick * stick_lever_speed * delta)


func _drive(change: Vector2) -> void:
	if is_holding():
		_wanted = _held.constrain(_wanted + change)


func _update_target() -> void:
	var collider: Object = get_collider() if is_colliding() else null
	_set_target(collider as Interactable)


func _set_target(target: Interactable) -> void:
	# La cible visée a pu disparaître (caca qui touche quelque chose) : on l'oublie,
	# sinon "target == _target" la croit encore là et elle reste en mémoire.
	if not is_instance_valid(_target):
		_target = null
	if target == _target:
		return
	if _target != null:
		_target.set_highlighted(false)
	_target = target
	if _target != null:
		_target.set_highlighted(true)


func _handle_actions() -> void:
	var press: bool = Input.is_action_just_pressed("interact")
	var grab: bool = Input.is_action_just_pressed("grab")
	if is_holding_poop():
		# Caca en main : clic = lancer dans la direction du regard, E = le poser.
		if grab:
			_poop.request_throw.rpc_id(1, -global_basis.z)
			_poop = null
			thrown.emit()
			return
		if press and not (_target is PushButton or _target is BeamSwitch or _target is DoorHandle):
			_poop.request_throw.rpc_id(1, Vector3.ZERO)
			_poop = null
			return
	var free_hands: bool = _held == null and _poop == null
	if _target is PoopHandle and (press or grab) and free_hands:
		_poop = (_target as PoopHandle).poop
		_poop_wait = 0.0
		_poop.request_pick.rpc_id(1)
		button_pressed.emit()
	elif _target is PushButton and (press or grab):
		(_target as PushButton).request_press.rpc_id(1)
		button_pressed.emit()
	elif _target is BeamSwitch and (press or grab):
		(_target as BeamSwitch).request_press.rpc_id(1)
		button_pressed.emit()
	elif _target is DoorHandle and (press or grab):
		(_target as DoorHandle).request_toggle.rpc_id(1)
		button_pressed.emit()
	elif _target is Rope and grab and free_hands:
		_rope = _target as Rope
		_rope_pending = true
		_rope_wait = 0.0
		_rope.request_grab.rpc_id(1)
	elif _target is Seat and (press or grab) and free_hands:
		_seat = _target as Seat
		_seat_pending = true
		_seat_wait = 0.0
		_seat.request_sit.rpc_id(1)
	elif _target is Lever and grab and free_hands:
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
	if _held.self_centering and not _pushed:
		# Joystick à ressort : on ne le pousse plus, il revient au centre.
		_wanted = _wanted.move_toward(Vector2.ZERO, _held.return_speed * delta)
	_pushed = false
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


func _update_rope(delta: float) -> void:
	if _rope_pending:
		_rope_wait += delta
		if _rope.is_held_locally():
			_rope_pending = false
		elif not Input.is_action_pressed("grab"):
			release_rope()
		elif _rope_wait > GRAB_TIMEOUT or _rope.holder_peer_id != 0:
			_rope = null   # refusé (trop loin, quelqu'un grimpe déjà)
			_rope_pending = false
		return
	if not _rope.is_held_locally():
		_rope = null   # l'hôte nous l'a retirée
		return
	if not Input.is_action_pressed("grab"):
		release_rope()


func _release() -> void:
	# Envoyé même si l'hôte n'a pas encore répondu : les RPC fiables arrivent dans l'ordre,
	# donc un "attraper" accepté juste avant sera bien suivi du "lâcher".
	_held.request_release.rpc_id(1)
	_held = null
	_grab_pending = false


## Attente de la réponse de l'hôte après « ramasser » (refusé = on oublie le caca).
func _update_poop(delta: float) -> void:
	if _poop == null:
		return
	if not is_instance_valid(_poop):
		_poop = null
		return
	if _poop.is_held_locally():
		return
	_poop_wait += delta
	if _poop_wait > GRAB_TIMEOUT or _poop.holder_peer_id != 0:
		_poop = null


func _update_prompt() -> void:
	var hints: Array[InputHint] = []
	if is_holding_poop():
		hints = [InputHint.make(&"grab", &"throw"), InputHint.make(&"interact", &"drop")]
	elif _seat != null and not _seat_pending:
		hints = _seat.get_hints()
	elif _rope != null and not _rope_pending:
		hints = _rope.get_hints()
	elif _held != null and not _grab_pending:
		hints = _held.get_hints()
	elif _target != null:
		hints = _target.get_hints()
	var key: String = InputHint.key_of(hints)
	if key != _hints_key:
		_hints_key = key
		hints_changed.emit(hints)
