class_name DrillArm
extends MechaArm
## Bras droit du mécha : foreuse télescopique orientable (M8 — Foreuse, poste assis en M9.5).
## Pilotée par le nain assis au poste `seat` (`Drill_Seat`), comme le grappin (visée commune : MechaArm) :
## - souris / stick droit (`control_look`) et Q/D (`control_move.x`) : orientent le bras (lacet + tangage),
##   sans jamais pouvoir rentrer dans la coque (`MechaArmUtils`) ;
## - Z/S (`control_move.y`) : étendent ou replient le fût télescopique (0 → 3 m) ;
## - clic gauche / RT maintenu (`control_grab`) : fait tourner la mèche et fore les blocs `MineableRock`.
##
## Réseau : l'hôte est seul autoritaire sur `arm_yaw`, `arm_pitch`, `extension` (MechaArm), `spinning` et `drilling`
## (répliqués par MultiplayerSynchronizer). Chaque peer anime localement la rotation
## de la mèche, le coulissement du fût, les vibrations et les étincelles de forage.

signal rock_mined(rock: MineableRock)

## Bras droit : l'intérieur (la coque) est un lacet positif.
const SIDE_SIGN: float = 1.0
const MAX_EXTENSION: float = 3.0
const SLIDER_REST_Z: float = -1.72
const MID_SLEEVE_REST_Z: float = -0.88
## Pointe de la mèche depuis le coude, fût rentré (glissière 1,72 + mandrin 0,78 + mèche 1,35).
const BIT_TIP_REST: float = 3.85
## La mèche s'enfonce de cette profondeur dans un rocher avant de buter.
const BITE_DEPTH: float = 0.35
const BIT_SPIN_MAX: float = 20.0
const BIT_ACCEL: float = 28.0
const SPARK_COUNT: int = 6
## Emprise (repère du mécha) des restes de l'ancienne console dans Int_Head, effacés au démarrage.
const OLD_CONSOLE_DECOR: AABB = AABB(Vector3(0.75, 6.1, -1.56), Vector3(0.6, 0.2, 0.33))

@export var mining_dps: float = 48.0

## Vrai quand le moteur de la mèche tourne (bouton maintenu au poste). Autorité : hôte.
var spinning: bool = false
## Vrai quand la mèche en rotation attaque un bloc minable. Autorité : hôte.
var drilling: bool = false

var _spin_rate: float = 0.0
var _vib_phase: float = 0.0
var _sparks: Array[MeshInstance3D] = []

@onready var _mid_sleeve: MeshInstance3D = %MidSleeve
@onready var _slider_pivot: Node3D = %SliderPivot
@onready var _bit_pivot: Node3D = %BitPivot
@onready var _sparks_root: Node3D = %Sparks
@onready var _work_light: OmniLight3D = %WorkLight


func _ready() -> void:
	super()
	var parent_node: Node = get_parent()
	if parent_node != null:
		# Petit tableau de l'ancienne console de la foreuse, resté dans Int_Head : il traverserait l'établi.
		var head_decor: MeshInstance3D = parent_node.get_node_or_null("Int_Head") as MeshInstance3D
		if head_decor != null:
			MechaArmUtils.strip_box(head_decor, OLD_CONSOLE_DECOR)
	_build_sparks()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var target_ext: float = extension
	if get_occupant() != 0:
		target_ext = _steer(delta)
		spinning = seat.control_grab
	else:
		spinning = false

	# La mèche bute dans le rocher qui est dans l'axe du bras (elle s'y enfonce un peu).
	var contact: MineableRock = null
	var origin: Vector3 = _elbow_pivot.global_position
	var axis: Vector3 = -_elbow_pivot.global_basis.z.normalized()
	var best_entry: float = BIT_TIP_REST + MAX_EXTENSION + BITE_DEPTH
	for node: Node in get_tree().get_nodes_in_group(&"mineable_rocks"):
		var rock: MineableRock = node as MineableRock
		if rock == null or rock.broken:
			continue
		var entry: float = rock.ray_entry(origin, axis)
		if entry >= 0.0 and entry < best_entry:
			best_entry = entry
			contact = rock
	if contact != null:
		var max_reach: float = maxf(best_entry + BITE_DEPTH - BIT_TIP_REST, 0.0)
		target_ext = minf(target_ext, max_reach)
		if BIT_TIP_REST + target_ext < best_entry - 0.05:
			contact = null   # dans l'axe, mais pas encore touché

	extension = move_toward(extension, target_ext, extend_speed * delta)

	if spinning and contact != null:
		drilling = true
		if contact.apply_drill_damage(mining_dps * delta):
			rock_mined.emit(contact)
	else:
		drilling = false


func _process(delta: float) -> void:
	_show_aim()
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


func reset_arm() -> void:
	super()
	spinning = false
	drilling = false
	_spin_rate = 0.0


func _side_sign() -> float:
	return SIDE_SIGN


func _max_extension() -> float:
	return MAX_EXTENSION


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
