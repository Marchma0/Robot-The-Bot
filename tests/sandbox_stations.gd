extends Node3D
## Bac à sable M9.5 : un vrai nain (hors réseau, on est l'hôte) s'assoit au poste du grappin,
## la caméra fait son traveling jusqu'à l'écran puis passe sur l'image brouillée ; il lance la pince
## sur une caisse lointaine (saut), puis se lève (traveling retour). Puis même chose au poste de la foreuse.
## Captures dans build/views/stations_*.png.

const DWARF_SCENE: PackedScene = preload("res://scenes/player/dwarf.tscn")
const CRATE_SCENE: PackedScene = preload("res://scenes/props/cargo_crate.tscn")

@export var quit_when_done: bool = true

var _dwarf: Dwarf = null

@onready var _mecha: Node3D = $Mecha
@onready var _grabber_seat: Seat = $Mecha/Controls/Grabber_Seat
@onready var _drill_seat: Seat = $Mecha/Controls/Drill_Seat
@onready var _grabber_arm: GrabberArm = $Mecha/GrabberArm


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	var crate: CargoCrate = CRATE_SCENE.instantiate() as CargoCrate
	add_child(crate)
	crate.global_position = _mecha.global_transform * Vector3(-2.95, 0.0, -10.0)
	_dwarf = DWARF_SCENE.instantiate() as Dwarf
	_dwarf.setup(1, 0)
	_mecha.add_child(_dwarf)
	_dwarf.position = Vector3(-0.6, 5.75, 0.3)
	await get_tree().create_timer(1.0).timeout
	await _station_run(_grabber_seat, "grappin", true)
	_dwarf.position = Vector3(0.6, 5.75, 0.3)
	await get_tree().create_timer(0.6).timeout
	await _station_run(_drill_seat, "foreuse", false)
	if quit_when_done:
		get_tree().quit()


func _station_run(seat: Seat, label: String, fire: bool) -> void:
	var interactor: Interactor = _dwarf.get_node("%Interactor") as Interactor
	seat.request_sit.rpc_id(1)
	interactor.set("_seat", seat)
	interactor.set("_seat_pending", true)
	await _capture_at(0.05, "%s_0_assis" % label)
	await _capture_at(0.35, "%s_1_traveling" % label)
	await _capture_at(0.35, "%s_2_ecran" % label)
	await _capture_at(0.2, "%s_3_neige" % label)
	if fire:
		# Vise la caisse lointaine (droit devant, un peu vers le bas) puis lance.
		_grabber_arm.arm_pitch = -0.32
		await get_tree().create_timer(0.3).timeout
		await _tap("jump")
		await _capture_at(0.3, "%s_4_lance" % label)
		await _capture_at(1.4, "%s_5_ramene" % label)
		print("Grappin : état %d, sac %d objet(s)" % [_grabber_arm.shot_state, ($Mecha/Backpack as Backpack).stored_items.size()])
	else:
		await _capture_at(0.6, "%s_4_vue" % label)
	await _tap("interact")
	await _capture_at(0.25, "%s_6_leve" % label)
	await _capture_at(0.6, "%s_7_debout" % label)


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)


func _capture_at(delay: float, shot_name: String) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/views/stations_%s.png" % shot_name)
