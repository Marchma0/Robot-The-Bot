extends Node3D
## Bac à sable M8 + M9 (+ M9.5) : foreuse et grappin pilotés depuis leurs postes assis.
## Scénario automatique en boucle :
## 1) Poste de la foreuse occupé : la foreuse s'allume, s'étend, fore un bloc minable qui éclate ;
## 2) Le grappin s'oriente vers une caisse au sol, s'étend, la saisit et la range dans le sac à dos ;
## 3) Le grappin est lancé au bout de son câble sur une caisse à 10 m, la ramène et la range ;
## Au démarrage, vérifie que les deux bras ne rentrent jamais dans la coque, quels que soient les angles.
## Saut / Espace = basculer entre la caméra extérieure et la caméra (brouillée) du grappin.

const CRATE_SCENE: PackedScene = preload("res://scenes/props/cargo_crate.tscn")
## Volume de la coque (repère du mécha) dans lequel aucun bras ne doit entrer.
const HULL_MIN: Vector3 = Vector3(-2.37, 2.3, -2.05)
const HULL_MAX: Vector3 = Vector3(2.37, 8.5, 2.05)
## Demi-largeur des bras (pince ouverte comprise).
const ARM_HALF_WIDTH: float = 0.35

@export var quit_when_done: bool = false

var _time: float = 0.0
var _cycle_time: float = 0.0
var _use_wrist_cam: bool = false
var _shots_done: Dictionary = {}
var _near_crate: CargoCrate = null
var _far_crate: CargoCrate = null
var _grab_triggered: bool = false
var _launched: bool = false

@onready var _mecha: Node3D = $Mecha
@onready var _drill_arm: DrillArm = $Mecha/DrillArm
@onready var _grabber_arm: GrabberArm = $Mecha/GrabberArm
@onready var _backpack: Backpack = $Mecha/Backpack
@onready var _drill_seat: Seat = $Mecha/Controls/Drill_Seat
@onready var _grabber_seat: Seat = $Mecha/Controls/Grabber_Seat
@onready var _rock: MineableRock = $TestGround/MineableRocks/Rock1
@onready var _cam_ext: Camera3D = $CamExt
@onready var _cam_drill: Camera3D = $CamDrill


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	_drill_arm.rock_mined.connect(_on_rock_mined)
	_grabber_arm.item_grabbed.connect(_on_item_grabbed)
	_backpack.item_stored.connect(_on_item_stored)
	_check_arm_limits()
	_place_cameras()
	_reset_cycle()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		_use_wrist_cam = not _use_wrist_cam
		var pov: Camera3D = _grabber_seat.get_pov_camera()
		_grabber_seat.set_overlay_visible(_use_wrist_cam)
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

	# Phase 1 (0.3 .. 3.4 s) : poste de la foreuse occupé, mèche en marche, bras qui s'étend vers Rock1.
	if _cycle_time >= 0.30 and _cycle_time < 3.40:
		_drill_seat.occupant_peer_id = 1
		_drill_seat.control_move = Vector2(0.0, 1.0)
		_drill_seat.control_grab = true
		_drill_arm.arm_pitch = -0.12
		if _cycle_time >= 1.45 and _drill_arm.drilling:
			_shoot("1_foreuse_minage", _cam_drill)
		if _cycle_time >= 1.6:
			_shoot_feed("1b_foreuse_vue_cam", _drill_seat)
	elif _drill_seat.occupant_peer_id != 0:
		_drill_seat.control_move = Vector2(0.0, -1.0)
		_drill_seat.control_grab = false
		if _drill_arm.extension <= 0.0:
			_drill_seat.occupant_peer_id = 0

	# Phase 2 (3.4 .. 5.2 s) : le grappin vise la caisse proche, s'étend et referme la pince
	if _cycle_time >= 3.40 and _cycle_time < 5.00 and not _grab_triggered:
		var u: float = clampf((_cycle_time - 3.40) / 1.10, 0.0, 1.0)
		_grabber_arm.arm_yaw = 0.0
		_grabber_arm.arm_pitch = lerpf(-0.12, -0.64, u)
		_grabber_arm.extension = lerpf(0.0, 2.55, u)
		_grabber_arm.claw_closed = false
		if _cycle_time >= 4.25:
			_shoot_feed("2_grappin_vue_cam", _grabber_seat)
		if _cycle_time >= 4.60:
			_grab_triggered = true
			if _near_crate != null and is_instance_valid(_near_crate):
				_grabber_arm.grab_node(_near_crate, _near_crate.item_kind)

	if _cycle_time >= 5.05:
		_shoot("3_grappin_capture", _cam_ext)

	# Phase 3 (5.8 s ..) : le grappin vise la caisse lointaine et lance sa pince
	if _cycle_time >= 5.80 and not _launched:
		_grabber_arm.extension = 0.0
		_aim_grabber_at(_far_crate.global_position + Vector3(0.0, 0.3, 0.0))
		if _cycle_time >= 6.30:
			_launched = _grabber_arm.launch()
			print("[%.2f s] Grappin lancé : %s" % [_time, _launched])
	if _launched and _grabber_arm.shot_state == GrabberArm.Shot.OUT and _grabber_arm.shot_distance > 5.0:
		_shoot("4_grappin_lance", _cam_ext)
	if _launched and _grabber_arm.shot_state == GrabberArm.Shot.BACK and _grabber_arm.shot_distance < 6.0:
		_shoot("5_grappin_ramene", _cam_ext)

	if _cycle_time >= 9.50:
		if quit_when_done:
			get_tree().quit()
			return
		_reset_cycle()


## Vise un point global avec le grappin (lacet + tangage bornés comme en jeu).
func _aim_grabber_at(target: Vector3) -> void:
	var local: Vector3 = _grabber_arm.to_local(target)
	var yaw: float = atan2(-local.x, -local.z)
	var pitch: float = atan2(local.y, Vector2(local.x, local.z).length())
	_grabber_arm.arm_yaw = MechaArmUtils.clamp_yaw(yaw, GrabberArm.SIDE_SIGN)
	_grabber_arm.arm_pitch = MechaArmUtils.clamp_pitch(pitch)


## Teste toutes les orientations extrêmes des deux bras, fût sorti au maximum : aucun point ne doit
## entrer dans la coque.
func _check_arm_limits() -> void:
	var failures: int = 0
	for arm: Node3D in [_drill_arm, _grabber_arm]:
		var side: float = DrillArm.SIDE_SIGN if arm == _drill_arm else GrabberArm.SIDE_SIGN
		var reach: float = 1.8 + (DrillArm.MAX_EXTENSION + 2.1 if arm == _drill_arm else GrabberArm.MAX_EXTENSION + 1.4)
		for yaw_in: float in [1.0, 0.5, 0.0, -0.5, -1.0]:
			for pitch_t: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
				# Lacet demandé bien au-delà des limites : clamp_yaw doit le ramener.
				var yaw: float = MechaArmUtils.clamp_yaw(yaw_in * 3.0 * side, side)
				var pitch: float = MechaArmUtils.clamp_pitch(lerpf(-2.0, 2.0, pitch_t))
				var basis: Basis = Basis.from_euler(Vector3(pitch, yaw, 0.0))
				var axis: Vector3 = basis * Vector3.FORWARD
				var side_dir: Vector3 = basis * Vector3.RIGHT
				for k: int in range(1, 41):
					var d: float = reach * float(k) / 40.0
					for w: float in [-ARM_HALF_WIDTH, 0.0, ARM_HALF_WIDTH]:
						var p: Vector3 = arm.position + axis * d + side_dir * w
						if p.x > HULL_MIN.x and p.x < HULL_MAX.x and p.y > HULL_MIN.y and p.y < HULL_MAX.y \
								and p.z > HULL_MIN.z and p.z < HULL_MAX.z:
							failures += 1
	if failures == 0:
		print("Limites des bras : OK, aucun bras ne rentre dans la coque")
	else:
		push_error("Limites des bras : %d points dans la coque" % failures)


func _reset_cycle() -> void:
	_cycle_time = 0.0
	_grab_triggered = false
	_launched = false
	if _rock != null:
		_rock.max_hp = 65.0
		_rock.reset_rock()
	_near_crate = _ensure_crate(_near_crate, Vector3(-2.95, 0.0, -4.55))
	_far_crate = _ensure_crate(_far_crate, Vector3(-9.5, 0.0, -8.0))


func _ensure_crate(previous: Variant, local_pos: Vector3) -> CargoCrate:
	var crate: CargoCrate = previous as CargoCrate if is_instance_valid(previous) else null
	if crate == null or not crate.is_inside_tree():
		crate = CRATE_SCENE.instantiate() as CargoCrate
		crate.item_kind = "ore"
		add_child(crate)
	crate.global_position = _mecha.global_transform * local_pos
	crate.rotation = Vector3.ZERO
	return crate


func _place_cameras() -> void:
	var xf: Transform3D = _mecha.global_transform
	_cam_ext.global_position = xf * Vector3(-9.5, 6.4, -9.0)
	_cam_ext.look_at(xf * Vector3(-2.0, 2.4, -5.5), Vector3.UP)

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


## Capture de la vue plein écran d'un poste (image brouillée + viseur).
func _shoot_feed(shot_name: String, seat: Seat) -> void:
	if _shots_done.has(shot_name) or seat.get_pov_camera() == null:
		return
	seat.set_overlay_visible(true)
	await _shoot(shot_name, seat.get_pov_camera())
	seat.set_overlay_visible(_use_wrist_cam and seat == _grabber_seat)


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
