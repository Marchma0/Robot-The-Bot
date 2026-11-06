class_name LegDashboard
extends Node3D
## Tableau de bord d'une console de jambe : cadran de la jauge d'erreur, jauge de QTE,
## voyant « à toi » et flèche du pad à presser.
## Purement visuel : chaque peer l'affiche à partir de l'état synchronisé (MechaWalker, QteSequence).
## Le nœud est posé sur le plateau incliné de la console (X vers la droite, Y vers le haut du plateau,
## Z vers le pilote).

## 0 = console de la jambe gauche, 1 = droite.
@export var leg: int = 0
@export var walker: MechaWalker
@export var qte: QteSequence
## Pads de cette console, dans l'ordre : haut, bas, gauche, droite.
@export var pads: Array[PushButton] = []
## Débattement de l'aiguille (degrés de chaque côté du centre).
@export var needle_sweep_degrees: float = 120.0

var _shown_error: float = 0.0
var _shown_progress: float = 0.0
var _lamp_material: StandardMaterial3D
var _fill_material: StandardMaterial3D

@onready var _needle: Node3D = %Needle
@onready var _fill: MeshInstance3D = %QteFill
@onready var _lamp: MeshInstance3D = %TurnLamp
@onready var _fill_left: float = _fill.position.x - (_fill.mesh as BoxMesh).size.x / 2.0
@onready var _fill_width: float = (_fill.mesh as BoxMesh).size.x


func _ready() -> void:
	_lamp_material = (_lamp.mesh as Mesh).surface_get_material(0).duplicate() as StandardMaterial3D
	_lamp.material_override = _lamp_material
	_fill_material = (_fill.mesh as Mesh).surface_get_material(0).duplicate() as StandardMaterial3D
	_fill.material_override = _fill_material


func _process(delta: float) -> void:
	if walker == null or qte == null:
		return
	var k: float = 1.0 - exp(-8.0 * delta)
	_shown_error = lerpf(_shown_error, walker.error_gauge, k)
	# Aiguille : à gauche = 0, à droite = jauge pleine. Elle tremble quand ça devient critique.
	var shake: float = sin(Time.get_ticks_msec() * 0.05) * 3.0 * maxf(0.0, _shown_error - 0.7) / 0.3
	_needle.rotation.y = deg_to_rad(needle_sweep_degrees - 2.0 * needle_sweep_degrees * _shown_error + shake)
	# Jauge de QTE : se remplit de gauche à droite.
	_shown_progress = lerpf(_shown_progress, qte.get_progress() if qte.active else 0.0, k)
	_fill.visible = _shown_progress > 0.005
	_fill.scale.x = maxf(0.001, _shown_progress)
	_fill.position.x = _fill_left + _fill_width * _shown_progress / 2.0
	# À moi de jouer : voyant qui clignote et flèche allumée.
	var my_turn: bool = qte.active and qte.current_leg == leg
	var blink: bool = fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.3
	_lamp_material.emission_enabled = my_turn and blink
	_fill_material.emission_energy_multiplier = 1.5 if qte.active else 0.3
	for arrow: int in pads.size():
		pads[arrow].lit = my_turn and qte.current_arrow == arrow
