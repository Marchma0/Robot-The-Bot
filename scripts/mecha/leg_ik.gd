class_name LegIK
extends Node3D
## Plie les jambes du mécha pour que les pieds touchent leurs cibles (IK analytique à 2 os).
## Calculé chez chaque peer, à chaque image, à partir des pieds publiés par MechaWalker
## (lissés comme le corps) : le résultat est identique partout, rien d'autre à synchroniser.
## Affiche aussi les marques lumineuses là où un pied en l'air va se poser.

const THIGH: float = 1.25
const SHIN: float = 1.25
const ANKLE_HEIGHT: float = 0.35
## Rayon des collisions de la cuisse et du tibia (le fût peint fait 0,37 à 0,41 m de demi-largeur).
const THIGH_RADIUS: float = 0.4
const SHIN_RADIUS: float = 0.37
const SIDES: Array[String] = ["L", "R"]
const MARK_COLORS: Array[Color] = [Color(0.3, 0.7, 1.0), Color(1.0, 0.6, 0.2)]

@export var walker: MechaWalker

var _thigh: Array[int] = []
var _shin: Array[int] = []
var _foot: Array[int] = []
var _marks: Array[MeshInstance3D] = []

@onready var _skeleton: Skeleton3D = find_child("Skeleton3D", true, false) as Skeleton3D


func _ready() -> void:
	for side: String in SIDES:
		_thigh.append(_skeleton.find_bone("leg_%s_thigh" % side))
		_shin.append(_skeleton.find_bone("leg_%s_shin" % side))
		_foot.append(_skeleton.find_bone("leg_%s_foot" % side))
	for leg: int in 2:
		_marks.append(_make_mark(MARK_COLORS[leg]))
		_add_foot_collision(leg)
		_add_segment_collision(leg, "thigh", THIGH_RADIUS, THIGH)
		_add_segment_collision(leg, "shin", SHIN_RADIUS, SHIN)


func _process(_delta: float) -> void:
	if walker == null or not walker.is_node_ready():
		return
	var skel_global: Transform3D = _skeleton.get_global_transform_interpolated()
	var to_skel: Transform3D = skel_global.affine_inverse()
	for leg: int in 2:
		_solve(leg, to_skel, walker.get_foot_transform(leg))
	_update_marks()


func _solve(leg: int, to_skel: Transform3D, foot_world: Transform3D) -> void:
	var hip: Vector3 = _skeleton.get_bone_global_rest(_thigh[leg]).origin
	var ankle: Vector3 = to_skel * (foot_world.origin + Vector3.UP * ANKLE_HEIGHT)
	var up: Vector3 = (to_skel.basis * Vector3.UP).normalized()
	var forward: Vector3 = (to_skel.basis * (foot_world.basis * Vector3.FORWARD))
	forward = (forward - up * forward.dot(up)).normalized()
	var to_ankle: Vector3 = ankle - hip
	var dist: float = clampf(to_ankle.length(), 0.05, THIGH + SHIN - 0.001)
	var dir: Vector3 = to_ankle.normalized()
	ankle = hip + dir * dist
	# Le genou plie vers l'avant du pied, dans le plan hanche-cheville.
	var bend: Vector3 = forward - dir * forward.dot(dir)
	bend = bend.normalized() if bend.length() > 0.001 else Vector3.FORWARD
	var cos_hip: float = clampf((THIGH * THIGH + dist * dist - SHIN * SHIN) / (2.0 * THIGH * dist), -1.0, 1.0)
	var knee: Vector3 = hip + dir * (THIGH * cos_hip) + bend * (THIGH * sqrt(1.0 - cos_hip * cos_hip))
	# Repères des os (comme au repos : Y le long de l'os, X = axe du genou).
	var hinge: Vector3 = dir.cross(bend).normalized()
	var thigh_y: Vector3 = (knee - hip).normalized()
	var shin_y: Vector3 = (ankle - knee).normalized()
	var thigh_pose: Transform3D = Transform3D(Basis(hinge, thigh_y, hinge.cross(thigh_y)), hip)
	var shin_pose: Transform3D = Transform3D(Basis(hinge, shin_y, hinge.cross(shin_y)), knee)
	var foot_pose: Transform3D = Transform3D(Basis(forward.cross(up), forward, up), ankle)
	var parent: Transform3D = _skeleton.get_bone_global_pose(_skeleton.get_bone_parent(_thigh[leg]))
	_set_global(_thigh[leg], parent, thigh_pose)
	_set_global(_shin[leg], thigh_pose, shin_pose)
	_set_global(_foot[leg], shin_pose, foot_pose)


func _set_global(bone: int, parent_global: Transform3D, global_pose: Transform3D) -> void:
	var local: Transform3D = parent_global.affine_inverse() * global_pose
	_skeleton.set_bone_pose_position(bone, local.origin)
	_skeleton.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion())


func _update_marks() -> void:
	var swinging: Array[bool] = [walker.swinging_left, walker.swinging_right]
	var landing: Array[Vector3] = [walker.landing_left, walker.landing_right]
	for leg: int in 2:
		_marks[leg].visible = swinging[leg]
		if swinging[leg]:
			_marks[leg].global_position = landing[leg] + Vector3.UP * 0.03


## Anneau lumineux posé au sol (dans le monde, ne suit pas le mécha).
func _make_mark(color: Color) -> MeshInstance3D:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.55
	torus.rings = 24
	torus.ring_segments = 6
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = material
	var mark: MeshInstance3D = MeshInstance3D.new()
	mark.mesh = torus
	mark.top_level = true
	mark.visible = false
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mark)
	return mark


## Collision du pied (les nains dehors ne le traversent pas). Suit l'os du pied.
func _add_foot_collision(leg: int) -> void:
	var attachment: BoneAttachment3D = _skeleton.find_child("leg_%s_foot" % SIDES[leg], false, false) as BoneAttachment3D
	if attachment == null:
		return
	var foot_body: AnimatableBody3D = AnimatableBody3D.new()
	foot_body.sync_to_physics = false
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.1, 0.4, 1.8)
	shape.shape = box
	# Repère de l'os du pied : Y vers l'avant, Z vers le haut.
	shape.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-90.0)), Vector3(0.0, 0.25, -0.2))
	foot_body.add_child(shape)
	attachment.add_child(foot_body)


## Collision d'une cuisse ou d'un tibia (`part`) : une gélule le long de l'os, qui le suit
## (un nain qui saute contre la jambe ne la traverse plus).
func _add_segment_collision(leg: int, part: String, radius: float, length: float) -> void:
	var bone_name: String = "leg_%s_%s" % [SIDES[leg], part]
	var attachment: BoneAttachment3D = _skeleton.find_child(bone_name, false, false) as BoneAttachment3D
	if attachment == null:
		attachment = BoneAttachment3D.new()
		attachment.name = bone_name
		_skeleton.add_child(attachment)
		attachment.bone_name = bone_name
	var body: AnimatableBody3D = AnimatableBody3D.new()
	body.sync_to_physics = false
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = length + radius   # déborde un peu sur la hanche / le genou : pas de trou à l'articulation
	shape.shape = capsule
	# Repère de l'os : Y le long de l'os (de la hanche vers le genou).
	shape.position = Vector3(0.0, length * 0.5, 0.0)
	body.add_child(shape)
	attachment.add_child(body)
