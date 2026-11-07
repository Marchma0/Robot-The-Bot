extends Node3D
## Bac à sable M8 + M9 : foreuse télescopique (bras droit) et grappin articulé avec caméra (bras gauche).
## Scénario automatique en boucle :
## 1) La foreuse s'allume, s'étend jusqu'à 3 m, fore un bloc minable (étincelles + tremblement) qui éclate
##    et libère une caisse de minerai ;
## 2) Le grappin s'oriente vers une caisse au sol, s'étend, referme ses mâchoires dessus, replie le bras
##    et transfère automatiquement la caisse dans le sac à dos (M10).
## Saut / Espace = basculer entre la caméra extérieure et la caméra embarquée sur le poignet du grappin.

const CRATE_SCENE: PackedScene = preload("res://scenes/props/cargo_crate.tscn")

@export var quit_when_done: bool = false

var _time: float = 0.0
var _cycle_time: float = 0.0
var _use_wrist_cam: bool = false
var _shots_done: Dictionary = {}
var _target_crate: CargoCrate = null
var _grab_triggered: bool = false

@onready var _mecha: Node3D = $Mecha
@onready var _drill_arm: DrillArm = $Mecha/DrillArm
@onready var _grabber_arm: GrabberArm = $Mecha/GrabberArm
@onready var _backpack: Backpack = $Mecha/Backpack
@onready var _drill_lever: Lever = $Mecha/Controls/Drill_Depth
@onready var _drill_button: PushButton = $Mecha/Controls/Drill_Mine
@onready var _grabber_seat: Seat = $Mecha/Controls/Grabber_Seat
@onready var _rock: MineableRock = $TestGround/MineableRocks/Rock1
@onready var _cam_ext: Camera3D = $CamExt
@onready var _cam_drill: Camera3D = $CamDrill


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	_drill_arm.rock_mined.connect(_on_rock_mined)
	_grabber_arm.item_grabbed.connect(_on_item_grabbed)
	_backpack.item_stored.connect(_on_item_stored)
	_place_cameras()
	_reset_cycle()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		_use_wrist_cam = not _use_wrist_cam
		var pov: Camera3D = _grabber_seat.get_pov_camera()
		if _use_wrist_cam and pov != null:
			pov.current = true
		else:
			_cam_ext.current = true


func _physics_process(delta: float) -> void:
	_time += delta
	_cycle_time += delta
	_place_cameras()

	if _cycle_time >= 0.20:
		_shoot("0_repos", _cam_ext)

	# Phase 1 (0.3 .. 3.4 s) : la foreuse s'allume et s'étend à 3 m pour miner Rock1
	if _cycle_time >= 0.30 and _cycle_time < 3.40:
		_drill_button.is_on = true
		_drill_lever.value = Vector2(0.0, 1.0)
		if _cycle_time >= 1.45 and _drill_arm.drilling:
			_shoot("1_foreuse_minage", _cam_drill)
	else:
		_drill_button.is_on = false
		_drill_lever.value = Vector2.ZERO

	# Phase 2 (3.4 .. 5.2 s) : le grappin vise la caisse au sol, s'étend et referme la pince
	if _cycle_time >= 3.40 and _cycle_time < 5.00 and not _grab_triggered:
		var u: float = clampf((_cycle_time - 3.40) / 1.10, 0.0, 1.0)
		_grabber_arm.arm_yaw = lerpf(0.0, 0.0, u)
		_grabber_arm.arm_pitch = lerpf(-0.12, -0.64, u)
		_grabber_arm.extension = lerpf(0.0, 2.55, u)
		_grabber_arm.claw_closed = false
		if _cycle_time >= 4.25:
			var pov: Camera3D = _grabber_seat.get_pov_camera()
			if pov != null:
				_shoot("2_grappin_vue_cam", pov)
		if _cycle_time >= 4.60:
			_grab_triggered = true
			_grabber_arm.claw_closed = true
			if _target_crate != null and is_instance_valid(_target_crate):
				_grabber_arm.grab_node(_target_crate, _target_crate.item_kind)

	if _cycle_time >= 5.05:
		_shoot("3_grappin_capture", _cam_ext)

	if _cycle_time >= 7.20:
		if quit_when_done:
			get_tree().quit()
			return
		_reset_cycle()


func _reset_cycle() -> void:
	_cycle_time = 0.0
	_grab_triggered = false
	if _rock != null:
		_rock.max_hp = 65.0
		_rock.reset_rock()
	if _target_crate == null or not is_instance_valid(_target_crate):
		_target_crate = CRATE_SCENE.instantiate() as CargoCrate
		_target_crate.item_kind = "ore"
		add_child(_target_crate)
	_target_crate.global_position = _mecha.global_transform * Vector3(-2.95, 0.0, -4.55)
	_target_crate.rotation = Vector3.ZERO


func _place_cameras() -> void:
	var xf: Transform3D = _mecha.global_transform
	_cam_ext.global_position = xf * Vector3(-5.8, 5.4, -7.8)
	_cam_ext.look_at(xf * Vector3(0.0, 2.8, -1.8), Vector3.UP)

	_cam_drill.global_position = xf * Vector3(6.8, 4.8, -6.5)
	_cam_drill.look_at(xf * Vector3(2.95, 3.3, -3.8), Vector3.UP)


func _on_rock_mined(rock: MineableRock) -> void:
	print("[%.2f s] M8 Foreuse : rocher miné et détruit (%s)" % [_time, rock.name])


func _on_item_grabbed(_item: Node3D, item_kind: String) -> void:
	print("[%.2f s] M9 Grappin : objet saisi par la pince (%s)" % [_time, item_kind])


func _on_item_stored(item_kind: String, total_count: int) -> void:
	print("[%.2f s] M10 Sac à dos : objet rangé (%s) -> %d/%d" % [
		_time, item_kind, total_count, _backpack.max_capacity
	])


func _shoot(shot_name: String, camera: Camera3D) -> void:
	if _shots_done.has(shot_name):
		return
	_shots_done[shot_name] = true
	var prev_cam: Camera3D = get_viewport().get_camera_3d()
	camera.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/views/arms_%s.png" % shot_name)
	if prev_cam != null:
		prev_cam.current = true
