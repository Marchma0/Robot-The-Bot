class_name TractorBeam
extends Node3D
## Rayon tracteur vertical qui relie le ventre et la tête du mécha.
## Un nain dont les pieds sont dans la colonne est porté vers le haut ou vers le bas,
## selon le sens choisi aux interrupteurs (BeamSwitch).
##
## Réseau : l'hôte est autoritaire sur `going_up` (répliqué par le MultiplayerSynchronizer).
## Chaque joueur calcule lui-même le déplacement de son nain en lisant ce sens.
## L'origine du nœud est au centre de l'émetteur du bas ; son axe Y est l'axe du rayon.

## Rayon de la colonne (m) : un nain dont le centre est dans ce rayon est porté.
@export var radius: float = 0.4
## Hauteur de la colonne (m), du sol du ventre au plafond de la tête.
@export var height: float = 5.7
## En montant, le rayon tient les pieds du nain à cette hauteur (juste au-dessus du sol de la tête).
@export var top_hover: float = 3.25
## Vitesse max de montée / descente (m/s).
@export var lift_speed: float = 2.0
@export var up_color: Color = Color(0.35, 0.75, 1.0)
@export var down_color: Color = Color(1.0, 0.55, 0.2)

## Sens du rayon. Autorité : hôte.
var going_up: bool = true

var _color: Color
var _material: ShaderMaterial

@onready var _column: MeshInstance3D = %Column
@onready var _light: OmniLight3D = %Light


func _ready() -> void:
	add_to_group(&"tractor_beams")
	var mesh: CylinderMesh = _column.mesh as CylinderMesh
	mesh.height = height
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	_column.position.y = height / 2.0
	_material = _column.get_active_material(0) as ShaderMaterial
	_color = up_color if going_up else down_color
	NetworkManager.session_ended.connect(_on_session_ended)


func _process(delta: float) -> void:
	# Purement visuel : couleur et sens de défilement des anneaux suivent le sens du rayon.
	var wanted: Color = up_color if going_up else down_color
	_color = _color.lerp(wanted, 1.0 - exp(-6.0 * delta))
	_material.set_shader_parameter(&"beam_color", _color)
	_material.set_shader_parameter(&"direction", 1.0 if going_up else -1.0)
	_light.light_color = _color


## Appelé par l'hôte (interrupteur validé).
func toggle_direction() -> void:
	if multiplayer.is_server():
		going_up = not going_up


## Vrai si le centre du nain est dans la colonne.
func contains(feet: Vector3) -> bool:
	var local: Vector3 = to_local(feet)
	return local.y >= -0.2 and local.y <= height and Vector2(local.x, local.z).length() <= radius


## Vitesse verticale (m/s, le long de l'axe du rayon) à donner à un nain dont les pieds sont en `feet`.
func get_lift_speed(feet: Vector3) -> float:
	var local_y: float = to_local(feet).y
	return clampf((_target_height() - local_y) * 3.0, -lift_speed, lift_speed)


## Vitesse horizontale (globale) qui ramène le nain vers l'axe pendant le trajet, pour passer le trou.
## Nulle une fois arrivé, pour pouvoir sortir de la colonne en marchant.
func get_centering(feet: Vector3) -> Vector3:
	var local: Vector3 = to_local(feet)
	if absf(_target_height() - local.y) < 0.3:
		return Vector3.ZERO
	var toward_axis: Vector3 = global_basis * Vector3(-local.x, 0.0, -local.z)
	return (toward_axis * 3.0).limit_length(1.0)


## Vrai si le nain est en train d'être transporté (pas encore arrivé).
func is_travelling(feet: Vector3) -> bool:
	return absf(_target_height() - to_local(feet).y) >= 0.1


func _target_height() -> float:
	return top_hover if going_up else 0.0


func _on_session_ended(_reason: String) -> void:
	going_up = true
