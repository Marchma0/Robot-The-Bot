class_name Interactor
extends RayCast3D
## Rayon de visée du nain local (enfant de sa caméra).
## Trouve la commande visée, la surligne et lui passe les appuis (`Interactable.interact`) : c'est la
## commande qui envoie sa demande à l'hôte. Une nouvelle commande n'a donc rien à changer ici.
## Garde aussi ce que le joueur tient ou occupe (`_claim` : levier, siège ou corde,
## un seul à la fois, voir Possession), attend que l'hôte le confirme, et gère les touches tant qu'on le tient.
## Avec un objet de l'inventaire en main (voir Inventory) : clic = le lancer, G = le poser, E = ramasser ou
## appuyer ; prendre un levier, la corde ou s'asseoir range l'objet (`Interactable.stows_hand_item`), sauf un
## objet lourd (caisse) : clic ou G la pose, et il faut la poser avant de prendre une commande.
## Actif uniquement pour le joueur local.

## Les indices à afficher (touche → icône) ont changé (liste vide = rien à afficher).
signal hints_changed(hints: Array[InputHint])
## Le joueur vient d'appuyer sur un bouton (sert à l'animation "press").
signal button_pressed
## Le joueur vient de lancer un objet (sert à l'animation "throw").
signal thrown
## Le joystick à ressort tenu vient d'être poussé assez loin pour faire un pas (« clac »), direction (x droite, y avant).
signal stick_kicked(direction: Vector2)

## Délai max d'attente de la réponse de l'hôte après une demande (attraper, s'installer…).
const GRAB_TIMEOUT: float = 1.0
## Zone morte du stick de la manette pour un joystick à ressort.
const STICK_DEADZONE: float = 0.2
## Joystick à ressort à la souris : il reste poussé ce temps (s) après le dernier mouvement,
## puis revient au centre à cette vitesse (par seconde), comme un vrai manche qu'on relâche.
const STICK_HOLD_TIME: float = 0.14
const STICK_RETURN_SPEED: float = 7.0

## Variation de la valeur du levier par pixel de souris.
@export var mouse_lever_sensitivity: float = 0.006
## Pareil pour un joystick à ressort (jambes) : course courte, un petit coup de souris suffit pour un pas.
@export var mouse_stick_sensitivity: float = 0.012
## Variation de la valeur du levier par seconde au stick (stick à fond).
@export var stick_lever_speed: float = 2.5

var _target: Interactable = null
var _excluded_seat: Seat = null
## Ce que le joueur a demandé ou tient (voir Possession), et depuis combien de temps il attend l'hôte.
var _claim: Node = null
var _claim_confirmed: bool = false
var _claim_wait: float = 0.0
## Levier tenu : valeur voulue par le joueur.
var _wanted: Vector2 = Vector2.ZERO
## Le joueur a poussé le levier tenu pendant cette image (sinon un joystick à ressort revient au centre).
var _pushed: bool = false
## Joystick à ressort : temps depuis la dernière poussée, et prêt pour un nouveau « clac » (revenu près du centre).
var _since_push: float = 0.0
var _stick_armed: bool = true
var _hints_key: String = ""


func _ready() -> void:
	set_active(false)


func _physics_process(delta: float) -> void:
	_update_claim(delta)
	if _claim is Seat or _claim is Rope:
		# Assis ou sur la corde (ou en attente de l'hôte) : on ne vise rien, seule action possible, en sortir…
		# sauf, assis sur un simple siège (canapé), les commandes faites pour ça (dames) : clic pour les utiliser.
		_update_seated_target()
		_update_seat_or_rope()
	else:
		_exclude_seat(null)
		_update_target()
		_handle_actions()
		if is_holding():
			_update_lever(delta)
	_update_prompt()


func set_active(active: bool) -> void:
	enabled = active
	set_physics_process(active)
	if not active:
		_set_target(null)


## Commence à tenir ou occuper `node` (sa demande vient de partir vers l'hôte) : on attend sa réponse.
## Appelé après `Interactable.interact` (aussi par les scènes de test).
func begin_claim(node: Node) -> void:
	_claim = node
	_claim_confirmed = false
	_claim_wait = 0.0
	if node is Lever:
		_wanted = (node as Lever).value


## Vrai quand le joueur tient un levier (confirmé par l'hôte).
func is_holding() -> bool:
	return _claim is Lever and _holds_claim()


## Le siège où le joueur est installé (confirmé par l'hôte), sinon null.
func get_seat() -> Seat:
	return _claim as Seat if _claim is Seat and _holds_claim() else null


## La corde à laquelle le joueur grimpe (confirmé par l'hôte), sinon null.
func get_rope() -> Rope:
	return _claim as Rope if _claim is Rope and _holds_claim() else null


## Lâche la corde (relâcher le bouton, sauter, ou arrivé en haut).
func release_rope() -> void:
	if _claim is Rope:
		_release_claim()


## Vrai quand le joueur a un objet de l'inventaire en main (caca, fléchettes…).
func has_item_in_hand() -> bool:
	return not _hand_item().is_empty()


## Vrai quand le joueur tient un levier, la corde, ou est assis (ou attend la réponse de l'hôte).
func has_claim() -> bool:
	return _claim != null


## L'objet de l'inventaire en main ({} = main vide), voir Inventory.slots_of.
func _hand_item() -> Dictionary:
	return Inventory.item_in_hand(get_tree(), multiplayer.get_unique_id())


## Inclinaison affichée du levier tenu, en radians (x = côté, y = avant/arrière), ZERO si on ne tient rien.
func get_held_tilt() -> Vector2:
	if not is_holding():
		return Vector2.ZERO
	return _wanted * deg_to_rad((_claim as Lever).max_angle_degrees)


## Vrai quand le levier tenu est un joystick à ressort (jambes) : la vue ne le suit pas.
func is_holding_spring_stick() -> bool:
	return is_holding() and (_claim as Lever).self_centering


## Mouvement de souris en pixels (x droite, y haut) pendant qu'on tient un levier.
func drive_mouse(motion: Vector2) -> void:
	var spring: bool = is_holding_spring_stick()
	_drive(motion * (mouse_stick_sensitivity if spring else mouse_lever_sensitivity))
	_pushed = _pushed or motion.length() > 0.0


## Stick (-1..1, y haut) pendant qu'on tient un levier.
func drive_stick(stick: Vector2, delta: float) -> void:
	if is_holding_spring_stick():
		# Joystick à ressort : à la manette, il suit directement le stick (relâché = au centre).
		if InputGlyph.use_gamepad:
			_wanted = (_claim as Lever).constrain(stick if stick.length() > STICK_DEADZONE else Vector2.ZERO)
			_pushed = true
		return
	_drive(stick * stick_lever_speed * delta)


func _drive(change: Vector2) -> void:
	if is_holding():
		_wanted = (_claim as Lever).constrain(_wanted + change)


## Vrai si l'hôte nous a donné l'objet demandé (vérifié en direct sur son porteur, répliqué).
func _holds_claim() -> bool:
	return _claim != null and is_instance_valid(_claim) and Possession.holder_of(_claim) == multiplayer.get_unique_id()


## Attente de la réponse de l'hôte, puis suivi : refusé (délai dépassé ou pris par un autre) ou retiré
## par l'hôte (trop loin, fin de manche…) = on l'oublie.
func _update_claim(delta: float) -> void:
	if _claim == null:
		return
	if not is_instance_valid(_claim):
		_claim = null
		return
	var holder: int = Possession.holder_of(_claim)
	if holder == multiplayer.get_unique_id():
		_claim_confirmed = true
		return
	if _claim_confirmed:
		_claim = null   # l'hôte nous l'a retiré
		return
	_claim_wait += delta
	if _claim_wait > GRAB_TIMEOUT or holder != 0:
		_claim = null   # refusé (trop loin, déjà pris, ou on tient déjà autre chose)


## Lâche ce qu'on tient. Envoyé même si l'hôte n'a pas encore répondu : les RPC fiables arrivent dans l'ordre,
## donc un « attraper » accepté juste avant sera bien suivi du « lâcher ».
func _release_claim() -> void:
	if _claim is Lever:
		(_claim as Lever).request_release.rpc_id(1)
	elif _claim is Rope:
		(_claim as Rope).request_release.rpc_id(1)
	elif _claim is Seat:
		(_claim as Seat).request_leave.rpc_id(1)
	_claim = null


## Assis : E pour se lever. Sur la corde : relâcher le bouton = lâcher.
func _update_seat_or_rope() -> void:
	if _claim is Seat:
		if _holds_claim() and Input.is_action_just_pressed("interact"):
			_release_claim()
	elif not Input.is_action_pressed("grab"):
		_release_claim()


## Le siège où l'on est assis ne bloque pas la visée (le rayon partirait dans sa zone).
func _exclude_seat(seat: Seat) -> void:
	if seat == _excluded_seat:
		return
	if _excluded_seat != null and is_instance_valid(_excluded_seat):
		remove_exception(_excluded_seat)
	_excluded_seat = seat
	if seat != null:
		add_exception(seat)


## Assis sur un simple siège : on peut viser et utiliser (clic) les commandes `usable_seated` à portée de main.
func _update_seated_target() -> void:
	var seat: Seat = _claim as Seat
	_exclude_seat(seat if seat != null and not seat.has_screen else null)
	if seat == null or seat.has_screen or not _holds_claim():
		_set_target(null)
		return
	var target: Interactable = (get_collider() if is_colliding() else null) as Interactable
	_set_target(target if target != null and target.usable_seated else null)
	if _target != null and Input.is_action_just_pressed("grab"):
		if _target.interact(false, true, false) == Interactable.Use.DONE:
			button_pressed.emit()


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
	var item: Dictionary = _hand_item() if _claim == null else {}
	var stows: bool = _target != null and _target.stows_hand_item()
	if not item.is_empty() and not (stows and not item["heavy"]):
		# Objet en main : clic = le lancer dans la direction du regard (objet lourd : le poser), G = le poser ;
		# E = ramasser ou appuyer sur la commande visée. Levier, siège, corde : on passe à la suite (l'objet
		# se range tout seul), sauf avec un objet lourd.
		if grab:
			item["node"].call(&"throw_from_hand", global_position, -global_basis.z)
			if not item["heavy"]:
				thrown.emit()
		elif Input.is_action_just_pressed("drop"):
			item["node"].call(&"drop_from_hand")
		elif press and _target != null and not stows:
			if _target.interact(true, false, false) == Interactable.Use.DONE:
				button_pressed.emit()
		return
	if _target != null and (press or grab):
		match _target.interact(press, grab, _claim == null):
			Interactable.Use.DONE:
				button_pressed.emit()
			Interactable.Use.CLAIM:
				begin_claim(_target.get_claim())
	if _claim is Lever and Input.is_action_just_released("grab"):
		_release_claim()


## Levier tenu : on envoie la valeur voulue à l'hôte à chaque étape (et on l'affiche tout de suite).
func _update_lever(delta: float) -> void:
	var lever: Lever = _claim as Lever
	if lever.self_centering:
		_update_spring_stick(lever, delta)
	_pushed = false
	lever.set_local_value(_wanted)
	lever.submit_value.rpc_id(1, _wanted)


## Joystick à ressort : il tient la poussée un instant puis revient au centre ; poussé au-delà du seuil
## d'un pas, il part en butée (« clac ») et il faut le laisser revenir près du centre pour le pas suivant
## (mêmes seuils que la marche, voir MechaWalker).
func _update_spring_stick(lever: Lever, delta: float) -> void:
	_since_push = 0.0 if _pushed else _since_push + delta
	if _since_push > STICK_HOLD_TIME:
		_wanted = _wanted.move_toward(Vector2.ZERO, STICK_RETURN_SPEED * delta)
	var amount: float = _wanted.length()
	if amount < MechaWalker.RELEASE:
		_stick_armed = true
	elif amount > MechaWalker.TRIGGER and _stick_armed:
		_stick_armed = false
		var direction: Vector2 = _wanted / amount
		if not InputGlyph.use_gamepad:
			_wanted = direction   # en butée
		lever.kick()
		stick_kicked.emit(direction)


func _update_prompt() -> void:
	var hints: Array[InputHint] = []
	var item: Dictionary = _hand_item() if _claim == null else {}
	var stows: bool = _target != null and _target.stows_hand_item()
	if stows and not item.is_empty() and not item["heavy"]:
		hints = _target.get_hints()   # levier, siège, corde : l'objet en main se rangera
	elif not item.is_empty():
		# Lancer (clic) va de soi ; poser (G) est rappelé en petit sur la case de l'inventaire (InventoryBar).
		if _target != null and not stows:
			hints.append_array(_target.get_hints())   # ramasser, appuyer…
	elif _claim is Interactable and _claim_confirmed:
		hints = (_claim as Interactable).get_hints()
		if _claim is Seat and _target != null:
			var seat_hints: Array[InputHint] = hints   # assis au canapé, en visant le damier
			hints = _target.get_hints()
			hints.append_array(seat_hints)
	elif _claim == null and _target != null:
		hints = _target.get_hints()
	var key: String = InputHint.key_of(hints)
	if key != _hints_key:
		_hints_key = key
		hints_changed.emit(hints)
