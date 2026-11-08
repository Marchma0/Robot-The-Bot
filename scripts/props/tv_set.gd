class_name TvSet
extends Node3D
## Télé du salon : le bouton du haut du panneau l'allume et l'éteint. En s'éteignant, l'image s'écrase
## en une ligne puis en un point, comme un vieux tube ; elle se rallume en sens inverse.
##
## Réseau : l'état allumé est celui du bouton (`PushButton.is_on`, tenu par l'hôte et synchronisé) ;
## l'animation est jouée par chaque peer.

## Durée de l'extinction / de l'allumage (s).
const SWITCH_TIME: float = 0.35
const GLOW_ENERGY: float = 0.35

@export var power: PushButton

## 1 = image entière, 0 = éteinte.
var _level: float = 1.0

@onready var _screen: MeshInstance3D = %Screen
@onready var _glow: OmniLight3D = %Glow


func _ready() -> void:
	_level = 1.0 if power.is_on else 0.0
	_apply()


func _process(delta: float) -> void:
	var target: float = 1.0 if power.is_on else 0.0
	if is_equal_approx(_level, target):
		return
	_level = move_toward(_level, target, delta / SWITCH_TIME)
	_apply()


func is_on() -> bool:
	return power.is_on


func _apply() -> void:
	# D'abord la hauteur qui s'écrase en ligne, puis la largeur qui se resserre en point.
	var height: float = clampf((_level - 0.4) / 0.6, 0.0, 1.0)
	var width: float = clampf(_level / 0.4, 0.0, 1.0)
	_screen.visible = _level > 0.0
	_screen.scale = Vector3(maxf(width, 0.01), maxf(height, 0.01), 1.0)
	_glow.light_energy = GLOW_ENERGY * _level
