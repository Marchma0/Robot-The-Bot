class_name LegDashboard
extends Node3D
## Tableau de bord d'une console de jambe (habillage façon manette : leg_controls.glb) : cadran de la jauge
## d'erreur, voyant « à toi » (marche) et écran du QTE (QteScreen, façon « Just Dance »).
## Purement visuel : chaque peer l'affiche à partir de l'état synchronisé (MechaWalker, QteSequence).
## Le nœud est posé sur le plateau incliné de la console (X vers la droite, Y vers le haut du plateau,
## Z vers le pilote).

## Couleur du voyant « à toi » : vert = fais ton pas (marche). Pendant un QTE, c'est l'écran qui guide.
const LAMP_STEP: Color = Color(0.3, 1.0, 0.35)


## 0 = console de la jambe gauche, 1 = droite.
@export var leg: int = 0
@export var walker: MechaWalker
@export var qte: QteSequence
## Débattement de l'aiguille (degrés de chaque côté du centre).
@export var needle_sweep_degrees: float = 120.0
## Cadran : centre (repère du tableau de bord), rayons de l'arc de couleur, hauteur au-dessus du plateau.
@export var dial_center: Vector3 = Vector3(-0.04, 0.0215, -0.1)
@export var arc_inner: float = 0.05
@export var arc_outer: float = 0.074
## À partir de là (0 à 1) l'aiguille est dans le rouge : la butée de chute clignote.
@export var danger_from: float = 0.8

var _shown_error: float = 0.0
var _lamp_material: StandardMaterial3D
var _end_stop_material: StandardMaterial3D

@onready var _needle: Node3D = %Needle
@onready var _lamp: MeshInstance3D = %TurnLamp
@onready var _screen: MeshInstance3D = %Screen
@onready var _viewport: SubViewport = %ScreenViewport


func _ready() -> void:
	_lamp_material = (_lamp.mesh as Mesh).surface_get_material(0).duplicate() as StandardMaterial3D
	_lamp.material_override = _lamp_material
	_build_screen()
	_build_dial()


func _process(delta: float) -> void:
	if walker == null or qte == null:
		return
	var k: float = 1.0 - exp(-8.0 * delta)
	_shown_error = lerpf(_shown_error, walker.error_gauge, k)
	# Aiguille : à gauche = 0, à droite = jauge pleine. Elle tremble quand ça devient critique.
	var shake: float = sin(Time.get_ticks_msec() * 0.05) * 3.0 * maxf(0.0, _shown_error - 0.7) / 0.3
	_needle.rotation.y = deg_to_rad(needle_sweep_degrees - 2.0 * needle_sweep_degrees * _shown_error + shake)
	# Butée de chute : elle clignote quand l'aiguille entre dans le rouge.
	var danger: bool = _shown_error >= danger_from and fmod(Time.get_ticks_msec() / 1000.0, 0.4) < 0.2
	_end_stop_material.emission_energy_multiplier = 4.0 if danger else 0.6
	# Voyant « à toi » : vert fixe tant que c'est à moi de faire mon pas (il s'éteint dès que j'ai poussé
	# mon joystick, l'autre s'allume).
	var my_step: bool = not qte.active and walker.phase == MechaWalker.Phase.WALKING \
		and (walker.next_leg == -1 or walker.next_leg == leg)
	_lamp_material.emission = LAMP_STEP
	_lamp_material.albedo_color = LAMP_STEP.darkened(0.55)
	_lamp_material.emission_enabled = my_step


## Écran du QTE : l'image du SubViewport (dessinée par QteScreen) affichée sur la dalle, sans ombrage.
func _build_screen() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _viewport.get_texture()
	_screen.material_override = material
	if qte != null:
		(%QteScreen as QteScreen).setup(qte, leg)


## Arc de couleur autour de l'aiguille (vert = début, jaune, rouge = chute) + butées de début et de fin.
func _build_dial() -> void:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: int = 32
	for i: int in segments:
		var v0: float = float(i) / segments
		var v1: float = float(i + 1) / segments
		var c0: Color = _zone_color(v0)
		var c1: Color = _zone_color(v1)
		var a: Vector3 = _dial_dir(v0)
		var b: Vector3 = _dial_dir(v1)
		_quad(tool, a * arc_inner, a * arc_outer, b * arc_outer, b * arc_inner, c0, c0, c1, c1)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_is_srgb = true
	tool.set_material(material)
	var arc: MeshInstance3D = MeshInstance3D.new()
	arc.mesh = tool.commit()
	arc.position = dial_center
	add_child(arc)
	# Butée de début (sombre, fine) et butée de chute (rouge, épaisse, clignote dans le rouge).
	add_child(_stop(0.0, Color(0.15, 0.15, 0.16), 0.006, null))
	_end_stop_material = StandardMaterial3D.new()
	_end_stop_material.albedo_color = Color(0.85, 0.08, 0.05)
	_end_stop_material.emission_enabled = true
	_end_stop_material.emission = Color(1.0, 0.1, 0.05)
	_end_stop_material.emission_energy_multiplier = 0.6
	add_child(_stop(1.0, Color.WHITE, 0.012, _end_stop_material))


## Direction de l'aiguille pour une valeur de 0 (début, à gauche) à 1 (chute, à droite).
func _dial_dir(value: float) -> Vector3:
	var angle: float = deg_to_rad(needle_sweep_degrees - 2.0 * needle_sweep_degrees * value)
	return Vector3(-sin(angle), 0.0, -cos(angle))


func _zone_color(value: float) -> Color:
	var green: Color = Color(0.25, 0.7, 0.3)
	var yellow: Color = Color(0.95, 0.78, 0.2)
	var red: Color = Color(0.85, 0.12, 0.08)
	if value < 0.5:
		return green.lerp(yellow, value / 0.5)
	return yellow.lerp(red, clampf((value - 0.5) / (danger_from - 0.5), 0.0, 1.0))


func _quad(tool: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
		c0: Color, c1: Color, c2: Color, c3: Color) -> void:
	for pair: Array in [[p0, c0], [p1, c1], [p2, c2], [p0, c0], [p2, c2], [p3, c3]]:
		tool.set_normal(Vector3.UP)
		tool.set_color(pair[1])
		tool.add_vertex(pair[0])


## Petite butée en relief au bout de l'arc.
func _stop(value: float, color: Color, width: float, material: StandardMaterial3D) -> MeshInstance3D:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(width, 0.012, arc_outer - arc_inner + 0.012)
	if material == null:
		material = StandardMaterial3D.new()
		material.albedo_color = color
	box.material = material
	var stop: MeshInstance3D = MeshInstance3D.new()
	stop.mesh = box
	var dir: Vector3 = _dial_dir(value)
	stop.position = dial_center + dir * (arc_inner + arc_outer) / 2.0 + Vector3.UP * 0.004
	stop.basis = Basis(Vector3.UP, atan2(-dir.x, -dir.z))
	return stop
