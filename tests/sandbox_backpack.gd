extends Node3D
## Bac à sable M10 : sac à dos et inventaire synchronisé du mécha (sans réseau, on est l'hôte).
## Dépose automatiquement des caisses dans le sac à dos en boucle pour observer l'ouverture du
## couvercle, la trajectoire en arc par-dessus l'épaule, l'empilement dans le puits et la jauge.
## Clic / Espace / E = déposer une caisse immédiatement ; Saut / Tab = changer d'angle de caméra.

const CRATE_SCENE: PackedScene = preload("res://scenes/props/cargo_crate.tscn")
const SPAWN_OFFSETS: Array[Vector3] = [
	Vector3(-2.9, 1.8, -2.4),
	Vector3(-1.8, 0.0, 4.4),
	Vector3(1.6, 0.0, 4.5),
	Vector3(0.0, 0.0, 5.2),
]

@export var quit_when_done: bool = false

var _time: float = 0.0
var _crates: Array[CargoCrate] = []
var _next_store_index: int = 0
var _next_store_time: float = 0.8
var _shots_done: Dictionary = {}
var _use_top_cam: bool = false

@onready var _mecha: Node3D = $Mecha
@onready var _backpack: Backpack = $Mecha/Backpack
@onready var _cam_back: Camera3D = $CamBack
@onready var _cam_top_well: Camera3D = $CamTopWell


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	_backpack.item_stored.connect(_on_item_stored)
	_spawn_batch()
	_place_cameras()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		_use_top_cam = not _use_top_cam
		(_cam_top_well if _use_top_cam else _cam_back).current = true
	elif event.is_action_pressed("interact") or event.is_action_pressed("grab"):
		_deposit_one()


func _physics_process(delta: float) -> void:
	_time += delta
	_place_cameras()

	if _time >= 0.25:
		_shoot("0_ferme", _cam_back)

	if _time >= _next_store_time:
		_deposit_one()
		_next_store_time = _time + 1.65

	if _next_store_index == 1 and _time >= 1.15:
		_shoot("1_ouverture_arc", _cam_back)

	if _next_store_index >= 3 and _time >= 4.2:
		_shoot("2_puits_interieur", _cam_top_well)

	if _backpack.get_item_count() >= 4 and _time >= 6.8:
		_shoot("3_jauge_remplie", _cam_back)
		if quit_when_done:
			get_tree().quit()


func _deposit_one() -> void:
	if _backpack.is_full():
		_backpack.clear_inventory()
		_spawn_batch()
		return
	if _next_store_index >= _crates.size():
		_spawn_batch()
	var crate: CargoCrate = _crates[_next_store_index]
	_next_store_index += 1
	if is_instance_valid(crate):
		crate.request_collect()


func _spawn_batch() -> void:
	for c: CargoCrate in _crates:
		if is_instance_valid(c):
			c.queue_free()
	_crates.clear()
	_next_store_index = 0
	for offset: Vector3 in SPAWN_OFFSETS:
		var crate: CargoCrate = CRATE_SCENE.instantiate() as CargoCrate
		add_child(crate)
		crate.global_position = _mecha.global_transform * offset
		_crates.append(crate)


func _on_item_stored(item_kind: String, total_count: int) -> void:
	print("[%.2f s] objet rangé (%s) -> inventaire %d/%d" % [
		_time, item_kind, total_count, _backpack.max_capacity
	])


func _place_cameras() -> void:
	var xf: Transform3D = _mecha.global_transform
	var back_target: Vector3 = xf * Vector3(0.0, 4.1, 2.9)
	_cam_back.global_position = xf * Vector3(-2.6, 5.2, 8.2)
	_cam_back.look_at(back_target, Vector3.UP)

	var well_target: Vector3 = xf * Vector3(0.0, 4.35, 2.95)
	_cam_top_well.global_position = xf * Vector3(1.9, 7.6, 6.2)
	_cam_top_well.look_at(well_target, Vector3.UP)


func _shoot(shot_name: String, camera: Camera3D) -> void:
	if _shots_done.has(shot_name):
		return
	_shots_done[shot_name] = true
	var prev_cam: Camera3D = _cam_top_well if _use_top_cam else _cam_back
	camera.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/views/backpack_%s.png" % shot_name)
	prev_cam.current = true
