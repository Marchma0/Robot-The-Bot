class_name MechaCustomizer
extends Node3D
## Personnalisation du robot au garage (roadmap 3.8 / 4.5 / 4.7) :
## - 3 skins complets (`skin_index`) : peinture extérieure (coque, jambes, bras, sac à dos) + ornements 3D
##   sur le toit et la poitrine (cheminées et couronne steampunk « Baron Cuivre », gyrophares et pare-buffle
##   « Secours Blindé ») ;
## - 4 configurations de bras (`arm_mode`) : Standard (Grappin G / Foreuse D), Inversé (Foreuse G / Grappin D),
##   Minage Titan (propulseurs de forage lourds + blindage), Électro-Aimant (bobines Tesla magnétiques).
##
## Réseau : l'hôte est seul autoritaire sur `skin_index` et `arm_mode` (répliqués par MultiplayerSynchronizer
## avec `spawn = true`). Chaque peer applique la peinture, les ornements et l'emplacement des bras localement.

const GROUP: StringName = &"mecha_customizers"
const SKIN_COUNT: int = 3
const ARM_MODE_COUNT: int = 4

const SKIN_TITLES: Array[String] = [
	"Mécano Original",
	"Baron Cuivre",
	"Secours Blindé",
]

const ARM_TITLES: Array[String] = [
	"Standard (Grappin G / Foreuse D)",
	"Inversé (Foreuse G / Grappin D)",
	"Minage Titan (Foreuse Lourde)",
	"Électro-Aimant (Grappin Magnéto)",
]

const RIGHT_SHOULDER: Vector3 = Vector3(2.95, 3.4, -0.3)
const LEFT_SHOULDER: Vector3 = Vector3(-2.95, 3.4, -0.3)
const EXTERIOR_MATERIALS: Array[String] = ["Paint", "Copper", "Cream"]

@export var mecha: Node3D
@export var drill_arm: DrillArm
@export var grabber_arm: GrabberArm
@export var skip_branches: Array[Node] = []

## Indice du skin du robot (0 .. SKIN_COUNT - 1). Autorité : hôte.
var skin_index: int = 0:
	set(value):
		skin_index = clampi(value, 0, SKIN_COUNT - 1)
		if is_node_ready():
			_apply_skin()

## Configuration des bras (0 .. ARM_MODE_COUNT - 1). Autorité : hôte.
var arm_mode: int = 0:
	set(value):
		arm_mode = clampi(value, 0, ARM_MODE_COUNT - 1)
		if is_node_ready():
			_apply_arms()

var _ornaments_baron: Node3D
var _ornaments_rescue: Node3D
var _rescue_light_l: OmniLight3D
var _rescue_light_r: OmniLight3D
var _titan_drill_mod: Node3D
var _titan_grab_mod: Node3D
var _magneto_drill_mod: Node3D
var _magneto_grab_mod: Node3D
var _beacon_phase: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_build_skin_ornaments()
	_build_arm_mods()
	_apply_skin()
	_apply_arms()


func _process(delta: float) -> void:
	if skin_index == 2 and _ornaments_rescue != null and _ornaments_rescue.visible:
		_beacon_phase += delta * 6.0
		if _rescue_light_l != null:
			_rescue_light_l.light_energy = 1.8 if sin(_beacon_phase) > 0.0 else 0.15
		if _rescue_light_r != null:
			_rescue_light_r.light_energy = 1.8 if sin(_beacon_phase) <= 0.0 else 0.15


## Nom traduit du skin actuel.
func skin_title() -> String:
	return tr(SKIN_TITLES[clampi(skin_index, 0, SKIN_TITLES.size() - 1)])


## Nom traduit de la configuration de bras actuelle.
func arm_title() -> String:
	return tr(ARM_TITLES[clampi(arm_mode, 0, ARM_TITLES.size() - 1)])


## Hôte : change le skin du robot (+1 ou -1).
func cycle_skin(step: int) -> void:
	if not multiplayer.is_server():
		return
	skin_index = posmod(skin_index + step, SKIN_COUNT)


## Hôte : change la configuration des bras (+1 ou -1).
func cycle_arm_mode(step: int) -> void:
	if not multiplayer.is_server():
		return
	arm_mode = posmod(arm_mode + step, ARM_MODE_COUNT)


func _apply_skin() -> void:
	if mecha == null:
		return
	var overrides: Dictionary[String, StandardMaterial3D] = _make_skin_materials(skin_index)
	for node: Node in mecha.find_children("*", "MeshInstance3D", true, false):
		if _is_skipped(node):
			continue
		var mesh_inst: MeshInstance3D = node as MeshInstance3D
		if mesh_inst == null or mesh_inst.mesh == null:
			continue
		for s: int in mesh_inst.mesh.get_surface_count():
			var mat: Material = mesh_inst.mesh.surface_get_material(s)
			if mat == null or not EXTERIOR_MATERIALS.has(mat.resource_name):
				continue
			mesh_inst.set_surface_override_material(s, overrides.get(mat.resource_name, null))
	if _ornaments_baron != null:
		_ornaments_baron.visible = (skin_index == 1)
	if _ornaments_rescue != null:
		_ornaments_rescue.visible = (skin_index == 2)


func _apply_arms() -> void:
	if drill_arm == null or grabber_arm == null:
		return
	var swapped: bool = (arm_mode == 1)
	if swapped:
		drill_arm.position = LEFT_SHOULDER
		drill_arm.side_sign_override = -1.0
		_mirror_shoulder(drill_arm, -1.0)
		grabber_arm.position = RIGHT_SHOULDER
		grabber_arm.side_sign_override = 1.0
		_mirror_shoulder(grabber_arm, -1.0)
	else:
		drill_arm.position = RIGHT_SHOULDER
		drill_arm.side_sign_override = 1.0
		_mirror_shoulder(drill_arm, 1.0)
		grabber_arm.position = LEFT_SHOULDER
		grabber_arm.side_sign_override = -1.0
		_mirror_shoulder(grabber_arm, 1.0)
	drill_arm.arm_yaw = MechaArmUtils.clamp_yaw(drill_arm.arm_yaw, drill_arm._side_sign())
	grabber_arm.arm_yaw = MechaArmUtils.clamp_yaw(grabber_arm.arm_yaw, grabber_arm._side_sign())
	drill_arm.mining_dps = 72.0 if arm_mode == 2 else 48.0
	if _titan_drill_mod != null:
		_titan_drill_mod.visible = (arm_mode == 2)
	if _titan_grab_mod != null:
		_titan_grab_mod.visible = (arm_mode == 2)
	if _magneto_drill_mod != null:
		_magneto_drill_mod.visible = (arm_mode == 3)
	if _magneto_grab_mod != null:
		_magneto_grab_mod.visible = (arm_mode == 3)


func _mirror_shoulder(arm: Node3D, sx: float) -> void:
	var arm_model: Node3D = arm.get_node_or_null("ArmModel") as Node3D
	if arm_model != null:
		arm_model.scale.x = sx
	var shoulder_body: Node3D = arm.get_node_or_null("ShoulderBody") as Node3D
	if shoulder_body != null:
		shoulder_body.scale.x = sx


func _is_skipped(node: Node) -> bool:
	for branch: Node in skip_branches:
		if branch != null and (branch == node or branch.is_ancestor_of(node)):
			return true
	return false


func _make_skin_materials(idx: int) -> Dictionary[String, StandardMaterial3D]:
	var result: Dictionary[String, StandardMaterial3D] = {}
	if idx == 0:
		return result
	var paint: StandardMaterial3D = StandardMaterial3D.new()
	var copper: StandardMaterial3D = StandardMaterial3D.new()
	var cream: StandardMaterial3D = StandardMaterial3D.new()
	if idx == 1:
		# Baron Cuivre : bordeaux royal, or poli et ivoire chaud.
		paint.albedo_color = Color(0.54, 0.14, 0.13)
		paint.roughness = 0.42
		paint.metallic = 0.35
		copper.albedo_color = Color(0.95, 0.76, 0.22)
		copper.roughness = 0.28
		copper.metallic = 0.85
		cream.albedo_color = Color(0.95, 0.88, 0.72)
		cream.roughness = 0.65
	else:
		# Secours Blindé : jaune chantier / orange secours, titane sombre et blanc.
		paint.albedo_color = Color(0.94, 0.56, 0.08)
		paint.roughness = 0.45
		paint.metallic = 0.20
		copper.albedo_color = Color(0.20, 0.23, 0.27)
		copper.roughness = 0.42
		copper.metallic = 0.78
		cream.albedo_color = Color(0.92, 0.94, 0.96)
		cream.roughness = 0.55
	result["Paint"] = paint
	result["Copper"] = copper
	result["Cream"] = cream
	return result


func _build_skin_ornaments() -> void:
	if mecha == null:
		return
	var gold_mat: StandardMaterial3D = StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.95, 0.76, 0.22)
	gold_mat.metallic = 0.85
	gold_mat.roughness = 0.28
	var crimson_mat: StandardMaterial3D = StandardMaterial3D.new()
	crimson_mat.albedo_color = Color(0.58, 0.14, 0.13)
	crimson_mat.metallic = 0.35
	crimson_mat.roughness = 0.45

	# --- Skin 1 : Baron Cuivre (cheminées jumelles + couronne frontale sur le toit) ---
	_ornaments_baron = Node3D.new()
	_ornaments_baron.name = "OrnamentsBaron"
	_ornaments_baron.visible = false
	add_child(_ornaments_baron)
	for sx: float in [-1.0, 1.0]:
		var stack: MeshInstance3D = _box_mesh(Vector3(0.38, 1.35, 0.38), gold_mat)
		stack.position = Vector3(sx * 1.75, 9.15, 1.45)
		_ornaments_baron.add_child(stack)
		var ring: MeshInstance3D = _box_mesh(Vector3(0.50, 0.18, 0.50), crimson_mat)
		ring.position = Vector3(sx * 1.75, 9.75, 1.45)
		_ornaments_baron.add_child(ring)
	var crest_base: MeshInstance3D = _box_mesh(Vector3(1.80, 0.32, 0.28), gold_mat)
	crest_base.position = Vector3(0.0, 8.70, -1.95)
	_ornaments_baron.add_child(crest_base)
	for i: int in range(-2, 3):
		var spike: MeshInstance3D = _box_mesh(Vector3(0.22, 0.48 - absf(float(i)) * 0.07, 0.22), gold_mat)
		spike.position = Vector3(float(i) * 0.36, 9.05, -1.95)
		_ornaments_baron.add_child(spike)

	# --- Skin 2 : Secours Blindé (rampe de gyrophares sur le toit + pare-buffle avant) ---
	var orange_glow: StandardMaterial3D = StandardMaterial3D.new()
	orange_glow.albedo_color = Color(1.0, 0.48, 0.08)
	orange_glow.emission_enabled = true
	orange_glow.emission = Color(1.0, 0.48, 0.08)
	orange_glow.emission_energy_multiplier = 2.6
	var dark_iron: StandardMaterial3D = StandardMaterial3D.new()
	dark_iron.albedo_color = Color(0.18, 0.20, 0.23)
	dark_iron.metallic = 0.78
	dark_iron.roughness = 0.42

	_ornaments_rescue = Node3D.new()
	_ornaments_rescue.name = "OrnamentsRescue"
	_ornaments_rescue.visible = false
	add_child(_ornaments_rescue)
	var lightbar: MeshInstance3D = _box_mesh(Vector3(3.20, 0.22, 0.42), dark_iron)
	lightbar.position = Vector3(0.0, 8.68, -1.65)
	_ornaments_rescue.add_child(lightbar)
	for sx: float in [-1.0, 1.0]:
		var dome: MeshInstance3D = _box_mesh(Vector3(0.56, 0.34, 0.38), orange_glow)
		dome.position = Vector3(sx * 1.25, 8.94, -1.65)
		_ornaments_rescue.add_child(dome)
	_rescue_light_l = OmniLight3D.new()
	_rescue_light_l.position = Vector3(-1.25, 9.15, -1.65)
	_rescue_light_l.light_color = Color(1.0, 0.52, 0.12)
	_rescue_light_l.omni_range = 4.5
	_ornaments_rescue.add_child(_rescue_light_l)
	_rescue_light_r = OmniLight3D.new()
	_rescue_light_r.position = Vector3(1.25, 9.15, -1.65)
	_rescue_light_r.light_color = Color(1.0, 0.52, 0.12)
	_rescue_light_r.omni_range = 4.5
	_ornaments_rescue.add_child(_rescue_light_r)
	# Pare-buffle blindé sur le bas de la coque avant
	var bumper: MeshInstance3D = _box_mesh(Vector3(4.20, 0.42, 0.26), dark_iron)
	bumper.position = Vector3(0.0, 2.85, -2.22)
	_ornaments_rescue.add_child(bumper)


func _build_arm_mods() -> void:
	if drill_arm == null or grabber_arm == null:
		return
	var titan_mat: StandardMaterial3D = StandardMaterial3D.new()
	titan_mat.albedo_color = Color(0.82, 0.22, 0.14)
	titan_mat.metallic = 0.55
	titan_mat.roughness = 0.38
	var gold_mat: StandardMaterial3D = StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.95, 0.76, 0.22)
	gold_mat.metallic = 0.85
	gold_mat.roughness = 0.28
	var cyan_glow: StandardMaterial3D = StandardMaterial3D.new()
	cyan_glow.albedo_color = Color(0.20, 0.90, 1.0)
	cyan_glow.emission_enabled = true
	cyan_glow.emission = Color(0.20, 0.90, 1.0)
	cyan_glow.emission_energy_multiplier = 2.8

	var drill_slider: Node3D = drill_arm.get_node_or_null("ElbowPivot/SliderPivot") as Node3D
	var grab_slider: Node3D = grabber_arm.get_node_or_null("ElbowPivot/SliderPivot") as Node3D
	if drill_slider != null:
		_titan_drill_mod = Node3D.new()
		_titan_drill_mod.name = "TitanDrillMod"
		_titan_drill_mod.visible = false
		drill_slider.add_child(_titan_drill_mod)
		for sx: float in [-1.0, 1.0]:
			var booster: MeshInstance3D = _box_mesh(Vector3(0.22, 0.28, 1.15), titan_mat)
			booster.position = Vector3(sx * 0.48, 0.08, -0.35)
			_titan_drill_mod.add_child(booster)
			var tip: MeshInstance3D = _box_mesh(Vector3(0.16, 0.16, 0.45), gold_mat)
			tip.position = Vector3(sx * 0.48, 0.08, -1.05)
			_titan_drill_mod.add_child(tip)

		_magneto_drill_mod = Node3D.new()
		_magneto_drill_mod.name = "MagnetoDrillMod"
		_magneto_drill_mod.visible = false
		drill_slider.add_child(_magneto_drill_mod)
		for i: int in range(3):
			var coil: MeshInstance3D = _box_mesh(Vector3(0.88, 0.88, 0.10), cyan_glow)
			coil.position = Vector3(0.0, 0.0, -0.15 - float(i) * 0.35)
			_magneto_drill_mod.add_child(coil)

	if grab_slider != null:
		_titan_grab_mod = Node3D.new()
		_titan_grab_mod.name = "TitanGrabMod"
		_titan_grab_mod.visible = false
		grab_slider.add_child(_titan_grab_mod)
		for sx: float in [-1.0, 1.0]:
			var shield: MeshInstance3D = _box_mesh(Vector3(0.18, 0.52, 1.10), titan_mat)
			shield.position = Vector3(sx * 0.44, 0.05, -0.10)
			_titan_grab_mod.add_child(shield)

		_magneto_grab_mod = Node3D.new()
		_magneto_grab_mod.name = "MagnetoGrabMod"
		_magneto_grab_mod.visible = false
		grab_slider.add_child(_magneto_grab_mod)
		for i: int in range(3):
			var coil: MeshInstance3D = _box_mesh(Vector3(0.82, 0.82, 0.10), cyan_glow)
			coil.position = Vector3(0.0, 0.0, -0.10 - float(i) * 0.35)
			_magneto_grab_mod.add_child(coil)


func _box_mesh(size: Vector3, mat: Material) -> MeshInstance3D:
	var inst: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	box.material = mat
	inst.mesh = box
	return inst
