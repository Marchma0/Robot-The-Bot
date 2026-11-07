extends Node3D
## Bac à sable M10 : sac à dos et inventaire synchronisé du mécha (sans réseau, on est l'hôte).
## Scénario automatique : dépose successivement 4 objets dans le sac à dos (dont un depuis la
## pince du grappin à l'avant gauche), vérifie l'ouverture du couvercle, la trajectoire en arc,
## le remplissage du puits intérieur et de la jauge arrière, puis enregistre 4 captures dans
## build/views/backpack_<nom>.png.

const CRATE_SCENE: PackedScene = preload("res://scenes/props/cargo_crate.tscn")
const SPAWN_OFFSETS: Array[Vector3] = [
	Vector3(-2.9, 1.8, -2.4),
	Vector3(-1.8, 0.0, 4.4),
	Vector3(1.6, 0.0, 4.5),
	Vector3(0.0, 0.0, 5.2),
]

@export var quit_when_done: bool = true

var _time: float = 0.0
var _crates: Array[CargoCrate] = []
var _next_store_index: int = 0
var _next_store_time: float = 0.55
var _shots_done: Dictionary = {}
var _finish_time: float = -1.0

@onready var _mecha: Node3D = $Mecha
@onready var _backpack: Backpack = $Mecha/Backpack
@onready var _cam_back: Camera3D = $CamBack
@onready var _cam_top_well: Camera3D = $CamTopWell


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	_backpack.item_stored.connect(_on_item_stored)
	for offset: Vector3 in SPAWN_OFFSETS:
		var crate: CargoCrate = CRATE_SCENE.instantiate() as CargoCrate
		add_child(crate)
		crate.global_position = _mecha.global_transform * offset
		_crates.append(crate)
	_place_cameras()


func _physics_process(delta: float) -> void:
	_time += delta
	_place_cameras()

	if _time >= 0.25:
		_shoot("0_ferme", _cam_back)

	if _next_store_index < _crates.size() and _time >= _next_store_time:
		var crate: CargoCrate = _crates[_next_store_index]
		_next_store_index += 1
		_next_store_time = _time + 1.05
		crate.request_collect()
		if _next_store_index == _crates.size():
			_finish_time = _time + 1.85

	# Pendant le 1er dépôt : capture de l'arc par-dessus l'épaule avec le couvercle ouvert
	if _next_store_index == 1 and _time >= 0.92:
		_shoot("1_ouverture_arc", _cam_back)

	# Pendant le 3e dépôt : vue plongeante dans le puits ouvert avec le tas d'objets à l'intérieur
	if _next_store_index >= 3 and _time >= 3.05:
		_shoot("2_puits_interieur", _cam_top_well)

	# Une fois les 4 objets rangés et le couvercle refermé : vue arrière de la jauge remplie
	if _finish_time > 0.0 and _time >= _finish_time - 0.25:
		_shoot("3_jauge_remplie", _cam_back)

	if _finish_time > 0.0 and _time >= _finish_time:
		print("[%.2f s] fin sandbox_backpack : %d/%d objets stockés" % [
			_time, _backpack.get_item_count(), _backpack.max_capacity
		])
		if quit_when_done:
			get_tree().quit()


func _on_item_stored(item_kind: String, total_count: int) -> void:
	print("[%.2f s] objet rangé (%s) -> inventaire %d/%d" % [
		_time, item_kind, total_count, _backpack.max_capacity
	])


func _place_cameras() -> void:
	var xf: Transform3D = _mecha.global_transform
	var back_target: Vector3 = xf * Vector3(0.0, 4.1, 2.9)
	_cam_back.global_position = xf * Vector3(-2.6, 4.8, 8.2)
	_cam_back.look_at(back_target, Vector3.UP)

	var well_target: Vector3 = xf * Vector3(0.0, 4.35, 2.95)
	_cam_top_well.global_position = xf * Vector3(1.9, 7.6, 6.2)
	_cam_top_well.look_at(well_target, Vector3.UP)


func _shoot(shot_name: String, camera: Camera3D) -> void:
	if _shots_done.has(shot_name):
		return
	_shots_done[shot_name] = true
	camera.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/views/backpack_%s.png" % shot_name)
