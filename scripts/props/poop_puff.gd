class_name PoopPuff
extends Node3D
## Petit nuage de fumée marron (ou doré) quand un caca lancé touche quelque chose.
## Purement visuel : chaque peer le joue chez lui (déclenché par Poop.play_burst), puis il se supprime.

const LIFETIME: float = 0.55
const BROWN: Color = Color(0.3, 0.18, 0.08)
const GOLD: Color = Color(1.0, 0.82, 0.3)

## Version dorée (caca légendaire).
var golden: bool = false

@onready var _smoke: CPUParticles3D = %Smoke
@onready var _bits: CPUParticles3D = %Bits


func _ready() -> void:
	var color: Color = GOLD if golden else BROWN
	_smoke.color_ramp = _fade(color, 0.9)
	_bits.color_ramp = _fade(color.darkened(0.2), 1.0)
	_smoke.restart()
	_bits.restart()
	get_tree().create_timer(LIFETIME + 0.2).timeout.connect(queue_free)


## Dégradé de la couleur, opaque puis transparent.
func _fade(color: Color, start_alpha: float) -> Gradient:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(color, start_alpha))
	gradient.set_color(1, Color(color, 0.0))
	return gradient
