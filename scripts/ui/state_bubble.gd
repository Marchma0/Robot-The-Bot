class_name StateBubble
extends Control
## Bulle d'état en haut à droite de l'écran (joueur local uniquement) : un mini-portrait
## animé de son propre nain, qui joue la même animation que lui (repos, marche, emote…),
## et le nom de l'état en dessous.
## Le portrait est une petite scène 3D à part (SubViewport avec son propre monde) :
## une copie du modèle du nain, pilotée par un DwarfAnimator branché sur le vrai nain.

const COLOR_DISC: Color = Color(0.93, 0.87, 0.74, 0.92)
const COLOR_RING: Color = Color(0.45, 0.28, 0.14, 1.0)
const RING_WIDTH: float = 5.0

@onready var _portrait: SubViewportContainer = %Portrait
@onready var _puppet_model: Node3D = %PuppetModel
@onready var _puppet_animator: DwarfAnimator = %PuppetAnimator
@onready var _label: Label = %StateLabel


## Branche le portrait sur le nain local (appelé par le nain).
func setup(dwarf: Dwarf) -> void:
	_puppet_animator.dwarf = dwarf
	_puppet_animator.set_process(true)
	dwarf.tint_model(_puppet_model)


func _ready() -> void:
	# Pas de nain tant que setup() n'a pas été appelé.
	if _puppet_animator.dwarf == null:
		_puppet_animator.set_process(false)


func _process(_delta: float) -> void:
	_label.text = _puppet_animator.state_label
	queue_redraw()


func _draw() -> void:
	# Disque de fond + anneau autour du portrait (le portrait est découpé en rond par son shader).
	var rect: Rect2 = _portrait.get_rect()
	var center: Vector2 = rect.get_center()
	var radius: float = rect.size.x / 2.0
	draw_circle(center, radius, COLOR_DISC)
	draw_arc(center, radius + RING_WIDTH / 2.0 - 1.0, 0.0, TAU, 48, COLOR_RING, RING_WIDTH, true)
