class_name QteSequence
extends Node
## QTE à deux sur les consoles des jambes. Une séquence = une suite d'étapes :
## - une flèche (jambe gauche / droite + flèche), à tour de rôle : la bonne flèche du bon joueur la valide,
##   toute autre flèche fait reculer la séquence un peu ;
## - une étape joystick (`BOTH`) : les deux pilotes poussent leur joystick dans la même direction (à
##   `stick_tolerance_degrees` près). La direction choisie est gardée (`stick_direction`) : sert au saut ;
## - une étape « ensemble » (`TOGETHER`) : chaque pilote a sa flèche, les deux appuis doivent arriver à
##   `together_window` s près. Mauvaise flèche, ou l'autre trop lent : c'est une erreur.
## Sert au relèvement du robot (M7.2), au saut et à l'accroupi (MechaManeuvers).
## Un QTE lancé avec `fail_after` échoue (signal `failed`) si personne ne progresse pendant ce temps.
##
## Réseau : l'hôte tient la séquence, reçoit les appuis (signal `pressed` des PushButton, déjà validés) et lit
## les joysticks (valeurs déjà envoyées par les pilotes, voir Lever). Il synchronise la séquence entière
## (`sequence`), l'étape en cours (`current_leg`, `current_arrow`), l'avancement et le nombre d'erreurs :
## chaque peer dessine lui-même l'écran du QTE (QteScreen).

signal completed
signal mistake(leg: int)
signal failed

enum Arrow { UP, DOWN, LEFT, RIGHT }

## « Jambe » d'une étape joystick à faire par les deux pilotes (Vector2i(BOTH, 0) dans `start`).
const BOTH: int = 2
## « Jambe » d'une étape « ensemble » : Vector2i(TOGETHER, flèche gauche + 4 * flèche droite) dans `start`.
const TOGETHER: int = 3
## Seuil de poussée d'un joystick pour l'étape joystick (comme un pas, voir MechaWalker).
const STICK_TRIGGER: float = 0.6

## Pads de chaque console, dans l'ordre : haut, bas, gauche, droite.
@export var pads_left: Array[PushButton] = []
@export var pads_right: Array[PushButton] = []
## Joysticks des deux consoles (étape joystick).
@export var stick_left: Lever
@export var stick_right: Lever
## Écart max entre les deux joysticks pour l'étape joystick (degrés).
@export var stick_tolerance_degrees: float = 30.0
## Nombre d'étapes perdues à chaque erreur.
@export var penalty_steps: int = 1
## La jauge se vide avec le temps (étapes par seconde) : si on traîne, on perd l'étape d'avant.
@export var drain_steps_per_second: float = 0.45
## Délai avant que la jauge commence à se vider, au lancement du QTE (s).
@export var start_grace: float = 1.0
## Étape « ensemble » : écart max entre les appuis des deux pilotes (s).
@export var together_window: float = 0.4

## Séquence en cours. Autorité : hôte (synchronisé).
var active: bool = false
var step_index: int = 0
var step_count: int = 0
var current_leg: int = -1
var current_arrow: int = -1
## Remplissage de la jauge, en étapes (step_index au plus, baisse en continu). Autorité : hôte.
var progress_steps: float = 0.0
## Toute la séquence, une case par étape : jambe * 16 + flèche (+ 4 * flèche droite pour TOGETHER), voir
## `step_leg_of` / `step_arrow_of`. Autorité : hôte (synchronisé, pour l'écran).
var sequence: PackedInt32Array = PackedInt32Array()
## Étape « ensemble » : qui a déjà appuyé sur sa flèche (bit 0 = gauche, bit 1 = droite).
## Autorité : hôte (synchronisé, pour l'écran : « attends l'autre » / « vite ! »).
var together_pressed: int = 0
## Nombre d'erreurs depuis le début de la partie (l'écran clignote en rouge quand il change). Autorité : hôte.
var mistake_count: int = 0
## Hôte : direction choisie à l'étape joystick (radians : 0 = vers l'avant, positif = vers la droite).
var stick_direction: float = 0.0

var _steps: Array[Vector2i] = []
var _grace: float = 0.0
## Hôte : temps sans progrès, et délai avant l'échec (0 = jamais).
var _stall: float = 0.0
var _fail_after: float = 0.0
## Hôte : temps depuis le premier appui d'une étape « ensemble ».
var _together_time: float = 0.0


func _ready() -> void:
	for arrow: int in pads_left.size():
		pads_left[arrow].pressed.connect(_on_pad.bind(0, arrow))
	for arrow: int in pads_right.size():
		pads_right[arrow].pressed.connect(_on_pad.bind(1, arrow))


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not active:
		return
	if current_leg == BOTH:
		_check_sticks()
		if not active:
			return
	if current_leg == TOGETHER and together_pressed != 0:
		_together_time += delta
		if _together_time > together_window:
			_mistake(-1)   # l'autre n'a pas suivi à temps
	_stall += delta
	if _fail_after > 0.0 and _stall > _fail_after:
		_fail()
		return
	if _grace > 0.0:
		_grace -= delta
		return
	# Vidange : la jauge descend en continu ; passée sous l'étape d'avant, cette étape est perdue.
	progress_steps = maxf(0.0, progress_steps - drain_steps_per_second * delta)
	if step_index > 0 and progress_steps <= float(step_index - 1):
		step_index -= 1
		_update_current()


## Avancement de 0 à 1 (pour la jauge).
func get_progress() -> float:
	return progress_steps / float(step_count) if step_count > 0 else 0.0


## Jambe d'une case de `sequence` (0, 1, BOTH ou TOGETHER).
static func step_leg_of(packed: int) -> int:
	return packed >> 4


## Flèche d'une case de `sequence` ; pour une étape TOGETHER, `side` choisit la flèche du pilote (0 ou 1).
static func step_arrow_of(packed: int, side: int = 0) -> int:
	return (packed >> (2 * side)) & 3


## `turns` tours qui alternent les joueurs, 1 ou 2 flèches par tour, tirés au hasard, et `together` étapes
## « ensemble » glissées entre deux tours (jamais en premier : on se met d'abord dans le rythme).
static func random_steps(turns: int, together: int = 0) -> Array[Vector2i]:
	var steps: Array[Vector2i] = []
	var first: int = randi() % 2
	var slots: Array[int] = []
	for turn: int in range(1, turns):
		slots.append(turn)
	slots.shuffle()
	var together_before: Array[int] = slots.slice(0, together)
	for turn: int in turns:
		if together_before.has(turn):
			steps.append(Vector2i(TOGETHER, randi() % 4 + 4 * (randi() % 4)))
		var leg: int = (first + turn) % 2
		for i: int in 1 + randi() % 2:
			steps.append(Vector2i(leg, randi() % 4))
	return steps


## Hôte : tire une séquence au hasard (voir `random_steps`).
func start_random(turns: int) -> void:
	start(random_steps(turns))


## Hôte : lance une séquence donnée (x = jambe 0/1 ou BOTH pour l'étape joystick, y = flèche).
## `fail_after` > 0 : le QTE échoue si personne ne progresse pendant ce temps (s).
func start(steps: Array[Vector2i], fail_after: float = 0.0) -> void:
	if not multiplayer.is_server() or steps.is_empty():
		return
	_steps = steps
	var packed: PackedInt32Array = PackedInt32Array()
	for step: Vector2i in steps:
		packed.append(step.x * 16 + (0 if step.x == BOTH else step.y))
	sequence = packed
	step_index = 0
	progress_steps = 0.0
	step_count = steps.size()
	_grace = start_grace
	_stall = 0.0
	_fail_after = fail_after
	active = true
	_update_current()


func cancel() -> void:
	active = false
	current_leg = -1
	current_arrow = -1
	together_pressed = 0


## Boutons à presser pour l'étape en cours (deux pour une étape « ensemble », aucun pour l'étape joystick).
## Sert aux scènes de test, qui jouent les pilotes.
func expected_pads() -> Array[PushButton]:
	var pads: Array[PushButton] = []
	if not active or current_leg == BOTH:
		return pads
	if current_leg == TOGETHER:
		pads.append(pads_left[step_arrow_of(sequence[step_index], 0)])
		pads.append(pads_right[step_arrow_of(sequence[step_index], 1)])
	else:
		pads.append((pads_left if current_leg == 0 else pads_right)[current_arrow])
	return pads


func _on_pad(_peer_id: int, leg: int, arrow: int) -> void:
	if not multiplayer.is_server() or not active or current_leg == BOTH:
		return   # pendant l'étape joystick, les flèches ne comptent pas
	var expected: Vector2i = _steps[step_index]
	if expected.x == TOGETHER:
		_on_together_pad(leg, arrow, expected.y)
		return
	if leg == expected.x and arrow == expected.y:
		_advance()
		return
	_mistake(leg)


## Étape « ensemble » : chacun sa flèche ; validée quand les deux ont appuyé à `together_window` s près.
func _on_together_pad(leg: int, arrow: int, arrows: int) -> void:
	var bit: int = 1 << leg
	if arrow != (arrows >> (2 * leg)) & 3 or together_pressed & bit:
		_mistake(leg)   # mauvaise flèche, ou appuyé deux fois
		return
	if together_pressed == 0:
		_together_time = 0.0
	together_pressed |= bit
	if together_pressed == 3:
		_advance()


## Erreur (`leg` = pilote fautif, -1 = les deux) : la séquence recule.
func _mistake(leg: int) -> void:
	step_index = maxi(0, step_index - penalty_steps)
	progress_steps = minf(progress_steps, float(step_index))
	mistake_count += 1
	mistake.emit(leg)
	_update_current()


## Étape joystick : les deux joysticks poussés, dans la même direction (à la tolérance près).
func _check_sticks() -> void:
	if stick_left == null or stick_right == null:
		return
	var a: Vector2 = stick_left.value
	var b: Vector2 = stick_right.value
	if a.length() < STICK_TRIGGER or b.length() < STICK_TRIGGER:
		return
	if rad_to_deg(absf(a.angle_to(b))) > stick_tolerance_degrees:
		return
	var mean: Vector2 = a.normalized() + b.normalized()
	stick_direction = atan2(mean.x, mean.y)   # 0 = vers l'avant (le hublot), positif = vers la droite
	_advance()


func _advance() -> void:
	step_index += 1
	progress_steps = float(step_index)
	_stall = 0.0
	if step_index >= step_count:
		cancel()
		completed.emit()
		return
	_update_current()


## Personne n'a progressé à temps : le QTE s'annule (l'écran clignote en rouge).
func _fail() -> void:
	mistake_count += 1
	cancel()
	failed.emit()


func _update_current() -> void:
	current_leg = _steps[step_index].x
	current_arrow = _steps[step_index].y if current_leg < BOTH else -1
	together_pressed = 0
