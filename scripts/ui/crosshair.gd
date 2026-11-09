class_name Crosshair
extends Control
## Point de visée, au centre de l'écran. Il devient un petit anneau quand on vise quelque chose d'utilisable :
## c'est le signal principal qu'on peut interagir (l'objet visé s'illumine aussi, voir Interactable).
## Purement local (interface du joueur), rien sur le réseau.

const DOT_RADIUS: float = 2.0
const RING_RADIUS: float = 9.0
const RING_WIDTH: float = 2.0
const COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)
const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.35)
## Vitesse du passage point ↔ anneau (par seconde).
const MORPH_SPEED: float = 9.0

## Vrai quand le joueur vise une commande ; `dim` : commande prise par un autre (anneau pâle).
var targeting: bool = false
var dim: bool = false

var _amount: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var wanted: float = 1.0 if targeting else 0.0
	if is_equal_approx(_amount, wanted):
		return
	_amount = move_toward(_amount, wanted, delta * MORPH_SPEED)
	queue_redraw()


func set_targeting(on: bool, locked: bool = false) -> void:
	if on == targeting and locked == dim:
		return
	targeting = on
	dim = locked
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var eased: float = _amount * _amount * (3.0 - 2.0 * _amount)
	var color: Color = Color(COLOR, COLOR.a * (0.45 if dim else 1.0))
	# Le point rétrécit pendant que l'anneau s'ouvre autour.
	var dot: float = lerpf(DOT_RADIUS, 1.4, eased)
	draw_circle(center, dot + 1.0, SHADOW)
	draw_circle(center, dot, color)
	if eased > 0.01:
		var radius: float = lerpf(DOT_RADIUS, RING_RADIUS, eased)
		var ring: Color = Color(color, color.a * eased)
		draw_arc(center, radius, 0.0, TAU, 40, Color(SHADOW, SHADOW.a * eased), RING_WIDTH + 2.0, true)
		draw_arc(center, radius, 0.0, TAU, 40, ring, RING_WIDTH, true)
