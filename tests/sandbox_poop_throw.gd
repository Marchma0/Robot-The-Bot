extends Node3D
## Bac à sable : lancers de caca dans le ventre du mécha (sans réseau, on est l'hôte).
## Affiche la trajectoire (hauteur max, distance) et enregistre une image du nuage à l'impact
## dans build/views/poop_puff_<n>.png. Le 2e lancer est un caca doré.

const POOP_SCENE: PackedScene = preload("res://scenes/props/poop.tscn")
## Départ : main d'un nain au fond à droite du ventre, à hauteur d'épaule.
const START: Vector3 = Vector3(1.4, 3.55, 1.3)
const AIMS: Array[Vector3] = [Vector3(-0.5, 0.0, -1.0), Vector3(-1.0, 0.15, -0.6), Vector3(0.0, 0.3, -1.0)]

@export var quit_when_done: bool = true

var _poop: Poop = null
var _index: int = 0
var _peak: float = 0.0
var _last_pos: Vector3

@onready var _props: Node3D = $Mecha/Props
@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	_camera.look_at(Vector3(-0.6, 3.1, -0.6), Vector3.UP)
	await get_tree().create_timer(0.5).timeout
	_throw_next()


func _physics_process(_delta: float) -> void:
	if _poop == null:
		return
	if is_instance_valid(_poop) and not _poop.is_queued_for_deletion():
		_last_pos = _poop.global_position
		_peak = maxf(_peak, _last_pos.y)
		return
	var flat: float = Vector2(_last_pos.x - START.x, _last_pos.z - START.z).length()
	print("lancer %d : monte de %.2f m, touche à %.2f m (impact %s)" % [_index, _peak - START.y, flat, _last_pos])
	_poop = null
	_capture()


func _throw_next() -> void:
	if _index >= AIMS.size():
		if quit_when_done or TestCheck.is_auto():
			TestCheck.finish(get_tree())
		return
	_poop = POOP_SCENE.instantiate() as Poop
	_poop.golden = _index == 1
	_props.add_child(_poop)
	_poop.global_position = START
	_peak = START.y
	_poop.request_throw(AIMS[_index])
	_index += 1


func _capture() -> void:
	for i: int in 9:
		await get_tree().process_frame
	TestCheck.save_view(get_viewport(), "res://build/views/poop_puff_%d.png" % _index)
	await get_tree().create_timer(0.8).timeout
	_throw_next()
