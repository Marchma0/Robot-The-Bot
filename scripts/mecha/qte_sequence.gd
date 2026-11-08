class_name QteSequence
extends Node
## QTE à deux, à tour de rôle, sur les pads à 4 flèches des consoles des jambes.
## Une séquence = une suite d'étapes (jambe gauche / droite + flèche). Seule l'étape en cours compte :
## la bonne flèche du bon joueur la valide ; toute autre flèche fait reculer la séquence un peu.
## Générique : sert au relèvement du robot (M7.2), resservira pour les autres QTE (panneaux muraux M7.4, saut M7.5…).
##
## Réseau : l'hôte tient la séquence et reçoit les appuis (signal `pressed` des PushButton, déjà validés).
## Il synchronise la séquence entière (`sequence`), l'étape en cours (`current_leg`, `current_arrow`),
## l'avancement et le nombre d'erreurs : chaque peer dessine lui-même l'écran du QTE (QteScreen).

signal completed
signal mistake(leg: int)

enum Arrow { UP, DOWN, LEFT, RIGHT }

## Pads de chaque console, dans l'ordre : haut, bas, gauche, droite.
@export var pads_left: Array[PushButton] = []
@export var pads_right: Array[PushButton] = []
## Nombre d'étapes perdues à chaque erreur.
@export var penalty_steps: int = 1
## La jauge se vide avec le temps (étapes par seconde) : si on traîne, on perd l'étape d'avant.
@export var drain_steps_per_second: float = 0.45
## Délai avant que la jauge commence à se vider, au lancement du QTE (s).
@export var start_grace: float = 1.0

## Séquence en cours. Autorité : hôte (synchronisé).
var active: bool = false
var step_index: int = 0
var step_count: int = 0
var current_leg: int = -1
var current_arrow: int = -1
## Remplissage de la jauge, en étapes (step_index au plus, baisse en continu). Autorité : hôte.
var progress_steps: float = 0.0
## Toute la séquence, une case par étape : jambe * 4 + flèche. Autorité : hôte (synchronisé, pour l'écran).
var sequence: PackedInt32Array = PackedInt32Array()
## Nombre d'erreurs depuis le début de la partie (l'écran clignote en rouge quand il change). Autorité : hôte.
var mistake_count: int = 0

var _steps: Array[Vector2i] = []
var _grace: float = 0.0


func _ready() -> void:
	for arrow: int in pads_left.size():
		pads_left[arrow].pressed.connect(_on_pad.bind(0, arrow))
	for arrow: int in pads_right.size():
		pads_right[arrow].pressed.connect(_on_pad.bind(1, arrow))


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not active:
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


## Hôte : tire une séquence au hasard. `turns` tours qui alternent les joueurs, 1 ou 2 flèches par tour.
func start_random(turns: int) -> void:
	var steps: Array[Vector2i] = []
	var first: int = randi() % 2
	for turn: int in turns:
		var leg: int = (first + turn) % 2
		for i: int in 1 + randi() % 2:
			steps.append(Vector2i(leg, randi() % 4))
	start(steps)


## Hôte : lance une séquence donnée (x = jambe 0/1, y = flèche).
func start(steps: Array[Vector2i]) -> void:
	if not multiplayer.is_server() or steps.is_empty():
		return
	_steps = steps
	var packed: PackedInt32Array = PackedInt32Array()
	for step: Vector2i in steps:
		packed.append(step.x * 4 + step.y)
	sequence = packed
	step_index = 0
	progress_steps = 0.0
	step_count = steps.size()
	_grace = start_grace
	active = true
	_update_current()


func cancel() -> void:
	active = false
	current_leg = -1
	current_arrow = -1


func _on_pad(_peer_id: int, leg: int, arrow: int) -> void:
	if not multiplayer.is_server() or not active:
		return
	var expected: Vector2i = _steps[step_index]
	if leg == expected.x and arrow == expected.y:
		step_index += 1
		progress_steps = float(step_index)
		if step_index >= step_count:
			cancel()
			completed.emit()
			return
	else:
		step_index = maxi(0, step_index - penalty_steps)
		progress_steps = minf(progress_steps, float(step_index))
		mistake_count += 1
		mistake.emit(leg)
	_update_current()


func _update_current() -> void:
	current_leg = _steps[step_index].x
	current_arrow = _steps[step_index].y
