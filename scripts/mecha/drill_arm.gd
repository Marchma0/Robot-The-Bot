class_name DrillArm
extends Node3D
## Bras droit du mécha : foreuse télescopique (M8 — Foreuse).
## Piloté depuis la console de la tête par :
## - `depth_lever` (`Drill_Depth`, 0 → 1) : étend le bras en animation de 0 à 3 m vers l'avant (-Z) ;
## - `mine_button` (`Drill_Mine`, interrupteur) : fait tourner la mèche et fore les blocs `MineableRock`.
##
## Réseau : l'hôte est seul autoritaire sur `extension`, `spinning` et `drilling`
## (répliqués par MultiplayerSynchronizer). Chaque peer anime localement la rotation
## de la mèche, le coulissement du fût, les vibrations et les étincelles de forage.

signal rock_mined(rock: MineableRock)

const MAX_EXTENSION: float = 3.0
const SLIDER_REST_Z: float = -1.72
const MID_SLEEVE_REST_Z: float = -0.88
const BIT_SPIN_MAX: float = 20.0
const BIT_ACCEL: float = 28.0
const SPARK_COUNT: int = 6

@export var depth_lever: Lever
@export var mine_button: PushButton
@export var extend_speed: float = 2.4
@export var mining_dps: float = 48.0

## Extension actuelle du fût télescopique en mètres (0.0 .. 3.0). Autorité : hôte.
var extension: float = 0.0
## Vrai quand le moteur de la mèche est allumé (`Drill_Mine`). Autorité : hôte.
var spinning: bool = false
## Vrai quand la mèche en rotation attaque un bloc minable. Autorité : hôte.
var drilling: bool = false

var _spin_rate: float = 0.0
var _vib_phase: float = 0.0
var _sparks: Array[MeshInstance3D] = []

@onready var _mid_sleeve: MeshInstance3D = %MidSleeve
@onready var _slider_pivot: Node3D = %SliderPivot
@onready var _bit_pivot: Node3D = %BitPivot
@onready var _drill_zone: Area3D = %DrillZone
@onready var _sparks_root: Node3D = %Sparks
@onready var _work_light: OmniLight3D = %WorkLight


func _ready() -> void:
	var parent_node: Node = get_parent()
	if parent_node != null:
		var ext_details: MeshInstance3D = parent_node.get_node_or_null("Ext_Details") as MeshInstance3D
		if ext_details != null:
			MechaArmUtils.strip_static_arm(ext_details, 1.0)
	_build_sparks()
	NetworkManager.session_ended.connect(_on_session_ended)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var target_depth: float = 0.0
	if depth_lever != null:
		target_depth = clampf(depth_lever.value.y, 0.0, 1.0) * MAX_EXTENSION
	if mine_button != null:
		spinning = mine_button.is_on

	var active_rock: MineableRock = _find_contact_rock()
	# Si le bras pousse contre un rocher non détruit, l'extension bute légèrement dans le rocher.
	if active_rock != null and target_depth > extension:
		var max_reach: float = _max_extension_against(active_rock)
		target_depth = minf(target_depth, max_reach)

	extension = move_toward(extension, target_depth, extend_speed * delta)

	if spinning and active_rock != null:
		drilling = true
		if active_rock.apply_drill_damage(mining_dps * delta):
			rock_mined.emit(active_rock)
	else:
		drilling = false


func _process(delta: float) -> void:
	var target_spin: float = BIT_SPIN_MAX if spinning else 0.0
	_spin_rate = move_toward(_spin_rate, target_spin, BIT_ACCEL * delta)
	_bit_pivot.rotation.z += _spin_rate * delta

	var vib_offset: Vector3 = Vector3.ZERO
	if drilling:
		_vib_phase += delta * 60.0
		vib_offset = Vector3(
			sin(_vib_phase * 1.9) * 0.018,
			cos(_vib_phase * 2.3) * 0.018,
			sin(_vib_phase * 3.1) * 0.025
		)
	_slider_pivot.position = Vector3(0.0, 0.0, SLIDER_REST_Z - extension) + vib_offset
	if _mid_sleeve != null:
		_mid_sleeve.position = Vector3(0.0, 0.0, MID_SLEEVE_REST_Z - extension * 0.5) + vib_offset * 0.5

	if _work_light != null:
		_work_light.light_energy = 1.6 if spinning else 0.35
		_work_light.light_color = Color(1.0, 0.65, 0.2) if drilling else Color(1.0, 0.82, 0.5)

	_update_sparks(delta)


## Recherche un bloc `MineableRock` en contact avec la pointe de la mèche.
func _find_contact_rock() -> MineableRock:
	var tip_pos: Vector3 = _drill_zone.global_position if _drill_zone != null else _bit_pivot.global_position
	var best_rock: MineableRock = null
	var best_dist: float = 1.65
	for node: Node in get_tree().get_nodes_in_group(&"mineable_rocks"):
		var rock: MineableRock = node as MineableRock
		if rock == null or rock.broken:
			continue
		var dy: float = tip_pos.y - rock.global_position.y
		if dy < -0.3 or dy > 4.6:
			continue
		var d_xz: float = Vector2(tip_pos.x - rock.global_position.x, tip_pos.z - rock.global_position.z).length()
		if d_xz < best_dist:
			best_dist = d_xz
			best_rock = rock
	return best_rock


func _max_extension_against(rock: MineableRock) -> float:
	var local_rock: Vector3 = to_local(rock.global_position)
	# Distance avant (-Z) jusqu'au cœur du rocher, en laissant la mèche (longueur ~2,1 m) mordre dedans.
	var forward_dist: float = -local_rock.z
	return clampf(forward_dist - 2.65, 0.0, MAX_EXTENSION)


func _build_sparks() -> void:
	for i: int in range(SPARK_COUNT):
		var m: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.06, 0.06, 0.14)
		m.mesh = box
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		var col: Color = Color(1.0, 0.78, 0.22) if i % 2 == 0 else Color(1.0, 0.48, 0.12)
		mat.albedo_color = col
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.material_override = mat
		m.visible = false
		_sparks_root.add_child(m)
		_sparks.append(m)


func _update_sparks(_delta: float) -> void:
	for i: int in range(_sparks.size()):
		var spark: MeshInstance3D = _sparks[i]
		spark.visible = drilling
		if not drilling:
			continue
		var phase: float = fmod(_vib_phase * 0.18 + float(i) / float(SPARK_COUNT), 1.0)
		var angle: float = float(i) * (TAU / float(SPARK_COUNT)) + _vib_phase * 0.12
		var radius: float = 0.15 + phase * 0.55
		spark.position = Vector3(
			cos(angle) * radius,
			sin(angle) * radius + 0.12 * sin(phase * PI),
			-0.95 + phase * 0.45
		)
		spark.rotation = Vector3(angle, phase * 4.0, angle * 0.7)
		spark.scale = Vector3.ONE * (1.1 - phase * 0.85)


func _on_session_ended(_reason: String) -> void:
	extension = 0.0
	spinning = false
	drilling = false
	_spin_rate = 0.0
