class_name TvSet
extends Node3D
## Télé du salon : le bouton du haut du panneau l'allume et l'éteint. Allumée, elle montre le jeu « Robo-Jet »
## (RoboJetGame, dessiné par RoboJetScreen dans un SubViewport). En s'éteignant, l'image s'écrase en une ligne
## puis en un point, comme un vieux tube ; elle se rallume en sens inverse. Éteinte, l'image du jeu n'est plus
## calculée (aucun coût).
##
## Réseau : l'état allumé est celui du bouton (`PushButton.is_on`, tenu par l'hôte et synchronisé) ;
## l'animation est jouée par chaque peer. Le jeu a sa propre synchro (RoboJetGame).

## Durée de l'extinction / de l'allumage (s).
const SWITCH_TIME: float = 0.35
const GLOW_ENERGY: float = 0.35

@export var power: PushButton

## 1 = image entière, 0 = éteinte.
var _level: float = 1.0

@onready var _screen: MeshInstance3D = %Screen
@onready var _glow: OmniLight3D = %Glow
@onready var _viewport: SubViewport = %ScreenViewport
@onready var _game_screen: RoboJetScreen = %RoboJetScreen
@onready var _game: RoboJetGame = %RoboJet


func _ready() -> void:
	_game_screen.game = _game
	var material: ShaderMaterial = (_screen.mesh as QuadMesh).material as ShaderMaterial
	material.set_shader_parameter(&"screen_texture", _viewport.get_texture())
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
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _level > 0.0 else SubViewport.UPDATE_DISABLED
	_game_screen.set_process(_level > 0.0)
