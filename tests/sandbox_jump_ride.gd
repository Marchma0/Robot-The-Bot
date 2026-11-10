extends Node3D
## Bac à sable : un nain à bord pendant que le robot marche et saute (bug de la vue saccadée au saut).
## Le nain doit rester collé au sol du cockpit : ni dérive par rapport au robot, ni décollage.
## Sans MechaColliderSync, il dérivait de 25 cm et décollait deux fois par saut.

const DWARF_SCENE: PackedScene = preload("res://scenes/player/dwarf.tscn")

var _dwarf: Dwarf
var _rest: Vector3
var _recording: bool = false
var _max_drift: float = 0.0
var _airborne_ticks: int = 0

@onready var _mecha: Node3D = $Mecha
@onready var _walker: MechaWalker = $Mecha/Walker
@onready var _sticks: Array[Lever] = [$Mecha/Controls/LegL_Stick as Lever, $Mecha/Controls/LegR_Stick as Lever]


func _ready() -> void:
	_dwarf = DWARF_SCENE.instantiate() as Dwarf
	_dwarf.setup(1, 0)
	_mecha.get_node("Players").add_child(_dwarf)
	_dwarf.position = Vector3(-0.3, 2.65, 0.6)
	await _wait(1.5)
	_rest = _dwarf.position

	# Quelques pas : le corps tangue, le nain reste en place.
	_recording = true
	for i: int in 6:
		_sticks[i % 2].value = Vector2(0.0, 1.0)
		await _wait(0.15)
		_sticks[i % 2].value = Vector2.ZERO
		await _wait(0.35)
	await _wait(0.5)
	TestCheck.expect(_max_drift < 0.02, "en marchant, le nain reste en place dans le cockpit (%.3f m)" % _max_drift)
	TestCheck.expect(_airborne_ticks == 0, "en marchant, le nain ne décolle pas du sol (%d étapes)" % _airborne_ticks)

	# Saut : le robot monte et redescend vite, le nain ne doit ni dériver ni décoller.
	_max_drift = 0.0
	_airborne_ticks = 0
	_rest = _dwarf.position
	_walker.jump(0.0)
	TestCheck.expect(_walker.phase == MechaWalker.Phase.JUMPING, "le robot saute")
	await _wait(_walker.jump_prep_time + _walker.jump_air_time + _walker.jump_land_time + 0.3)
	TestCheck.expect(_max_drift < 0.02, "pendant le saut, le nain reste en place dans le cockpit (%.3f m)" % _max_drift)
	TestCheck.expect(_airborne_ticks == 0, "pendant le saut, le nain ne décolle pas du sol (%d étapes)" % _airborne_ticks)
	TestCheck.finish(get_tree())


func _physics_process(_delta: float) -> void:
	if not _recording:
		return
	_max_drift = maxf(_max_drift, _dwarf.position.distance_to(_rest))
	if not _dwarf.is_on_floor():
		_airborne_ticks += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
