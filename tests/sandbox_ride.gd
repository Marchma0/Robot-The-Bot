extends Node3D
## Bac à sable du robot praticable (3.14) : un nain debout dehors sur une partie du robot la suit quand elle
## bouge. Sur le bras grappin baissé, on lève et on tourne le bras : il reste dessus. Sur le toit, le robot
## marche : il reste sur le toit. Images dans build/views/ride_<nom>.png.

const DWARF_SCENE: PackedScene = preload("res://scenes/player/dwarf.tscn")

var _dwarf: Dwarf
var _camera: Camera3D

@onready var _mecha: Node3D = $Mecha
@onready var _arm: GrabberArm = $Mecha/GrabberArm
@onready var _sticks: Array[Lever] = [$Mecha/Controls/LegL_Stick as Lever, $Mecha/Controls/LegR_Stick as Lever]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.current = true
	_arm.arm_pitch = -0.35
	_arm.arm_yaw = 0.5   # vers l'extérieur (bras gauche : positif)
	_dwarf = DWARF_SCENE.instantiate() as Dwarf
	_dwarf.setup(1, 0)
	_mecha.get_node("Players").add_child(_dwarf)
	await _wait(0.6)

	# Sur le bras : posé sur le fût, à 1 m de l'épaule.
	var barrel: Node3D = _arm.get_node("ElbowPivot/BarrelBody")
	_dwarf.place_at(_arm.get_node("ElbowPivot").global_transform * Vector3(0.0, 0.95, -1.0))
	await _wait(0.8)
	TestCheck.expect(_dwarf.is_on_floor(), "nain posé sur le bras du grappin")
	var on_arm: Vector3 = barrel.global_transform.affine_inverse() * _dwarf.global_position
	await _shot("1_sur_le_bras", _dwarf.global_position)
	var start_height: float = _dwarf.global_position.y
	# Le pilote lève et tourne le bras en 1,5 s.
	var drift: float = 0.0
	var off_ticks: int = 0
	for i: int in 90:
		var t: float = float(i + 1) / 90.0
		_arm.arm_pitch = lerpf(-0.35, 0.35, t)
		_arm.arm_yaw = lerpf(0.5, 0.9, t)
		await get_tree().physics_frame
		var now: Vector3 = barrel.global_transform.affine_inverse() * _dwarf.global_position
		drift = maxf(drift, now.distance_to(on_arm))
		if not _dwarf.is_on_floor():
			off_ticks += 1
	await _wait(0.3)
	var rise: float = _dwarf.global_position.y - start_height
	TestCheck.expect(rise > 0.5, "le bras se lève : le nain monte avec lui (%.2f m)" % rise)
	TestCheck.expect(drift < 0.15, "le nain reste à sa place sur le bras (écart %.2f m)" % drift)
	TestCheck.expect(off_ticks < 10, "le nain ne décolle pas du bras (%d étapes en l'air)" % off_ticks)
	await _shot("2_bras_leve", _dwarf.global_position)

	# Coup sec du bras : le nain est projeté.
	_dwarf.place_at(_arm.get_node("ElbowPivot").global_transform * Vector3(0.0, 0.95, -2.2))
	await _wait(0.8)
	var before_flick: Vector3 = _dwarf.global_position
	for i: int in 4:
		_arm.arm_yaw -= 0.2
		await get_tree().physics_frame
	await _wait(0.4)
	var thrown: float = _dwarf.global_position.distance_to(before_flick)
	TestCheck.expect(thrown > 1.5, "coup sec du bras : le nain est projeté (%.1f m)" % thrown)
	await _shot("2b_projete", _dwarf.global_position)

	# Sur le toit : le robot fait quelques pas, le nain reste sur le toit.
	_dwarf.place_at(_mecha.global_transform * Vector3(0.5, 8.75, 0.5))
	await _wait(0.8)
	TestCheck.expect(_dwarf.is_on_floor(), "nain posé sur le toit")
	var on_roof: Vector3 = _mecha.global_transform.affine_inverse() * _dwarf.global_position
	for i: int in 6:
		_sticks[i % 2].value = Vector2(0.0, 1.0)
		await _wait(0.15)
		_sticks[i % 2].value = Vector2.ZERO
		await _wait(0.35)
	await _wait(0.5)
	var moved: float = _mecha.global_position.length()
	var roof_drift: float = (_mecha.global_transform.affine_inverse() * _dwarf.global_position).distance_to(on_roof)
	TestCheck.expect(moved > 2.0, "le robot a marché (%.1f m)" % moved)
	TestCheck.expect(roof_drift < 0.3, "le nain est resté à sa place sur le toit (écart %.2f m)" % roof_drift)
	await _shot("3_sur_le_toit", _dwarf.global_position)
	TestCheck.finish(get_tree())


func _shot(shot_name: String, target: Vector3) -> void:
	_camera.global_position = target + _mecha.global_basis.x * -6.0 + Vector3.UP * 2.5 + _mecha.global_basis.z * 4.0
	_camera.look_at(target, Vector3.UP)
	await TestCheck.frame_drawn(get_tree())
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/ride_%s.png" % shot_name)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
