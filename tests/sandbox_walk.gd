extends Node3D
## Bac à sable M7.1 : pilote automatiquement les deux joysticks de jambe (on est l'hôte, sans réseau)
## selon un scénario, affiche ce que fait le robot et enregistre des images dans build/views/walk_<n>.png.

## Scénario : [nom, jambe (0 = gauche, 1 = droite), direction (x = droite, y = avant), début (s)].
## Chaque poussée dure 0,15 s puis le joystick revient au centre.
var _script: Array = []
var _phases: Array = []
var _time: float = 0.0
var _phase_index: int = 0
var _shots: Array[float] = [3.0, 3.2, 7.5, 12.0, 15.5, 19.5, 26.0]
var _shot_index: int = 0
var _stumbles: int = 0

@export var quit_when_done: bool = true

@onready var _mecha: Node3D = $Mecha
@onready var _walker: MechaWalker = $Mecha/Walker
@onready var _sticks: Array[Lever] = [$Mecha/Controls/LegL_Stick as Lever, $Mecha/Controls/LegR_Stick as Lever]
@onready var _camera: Camera3D = $Camera3D


var _start: Vector3 = Vector3.ZERO


func _ready() -> void:
	_start = _mecha.global_position
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	_walker.stumbled.connect(func() -> void: _stumbles += 1)
	var t: float = 1.0
	_phases.append(["départ", 0.0])
	_phases.append(["8 pas alternés rapides vers l'avant", t])
	for i: int in 8:
		_script.append([i % 2, Vector2(0.0, 1.0), t])
		t += 0.33
	t += 1.0
	_phases.append(["4 pas alternés lents vers l'avant", t])
	for i: int in 4:
		_script.append([i % 2, Vector2(0.0, 1.0), t])
		t += 1.0
	_phases.append(["6 pas en diagonale avant-droite", t])
	for i: int in 6:
		_script.append([i % 2, Vector2(0.7, 0.7), t])
		t += 0.45
	t += 0.8
	_phases.append(["4 pas de côté vers la gauche (pivot)", t])
	for i: int in 4:
		_script.append([i % 2, Vector2(-1.0, 0.0), t])
		t += 0.5
	t += 0.8
	_phases.append(["4 pas vers l'arrière", t])
	for i: int in 4:
		_script.append([i % 2, Vector2(0.0, -1.0), t])
		t += 0.5
	t += 0.8
	_phases.append(["un seul joueur (gauche) pousse 4 fois", t])
	for i: int in 4:
		_script.append([0, Vector2(0.0, 1.0), t])
		t += 0.7
	t += 0.8
	_phases.append(["désaccord : gauche avant puis droite arrière", t])
	_script.append([0, Vector2(0.0, 1.0), t])
	_script.append([1, Vector2(0.0, -1.0), t + 0.5])
	t += 2.0
	_phases.append(["fin", t])


func _physics_process(delta: float) -> void:
	_time += delta
	var wanted: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	for push: Array in _script:
		if _time >= push[2] and _time < push[2] + 0.15:
			wanted[push[0]] = push[1]
	for leg: int in 2:
		_sticks[leg].value = wanted[leg]
	while _phase_index < _phases.size() and _time >= _phases[_phase_index][1]:
		_report(_phases[_phase_index][0])
		_phase_index += 1
		if _phase_index == _phases.size():
			var moved: float = Vector2(_mecha.global_position.x - _start.x, _mecha.global_position.z - _start.z).length()
			TestCheck.expect(moved > 3.0, "le robot a avancé (%.1f m)" % moved)
			TestCheck.expect(_stumbles >= 1, "le désaccord fait trébucher")
		if _phase_index >= _phases.size() and (quit_when_done or TestCheck.is_auto()):
			TestCheck.finish(get_tree())
	var center: Vector3 = _mecha.global_position + Vector3.UP * 1.6
	var side: Vector3 = _mecha.global_basis.x
	_camera.global_position = center + side * 8.5 + _mecha.global_basis.z * 3.0 + Vector3.UP * 0.6
	_camera.look_at(center, Vector3.UP)
	if _shot_index < _shots.size() and _time >= _shots[_shot_index]:
		_shot_index += 1
		_capture(_shot_index)


func _report(name: String) -> void:
	var pos: Vector3 = _mecha.global_position
	print("[%5.2f s] %s -> corps (%.2f, %.2f, %.2f), cap %.0f°, trébuchements %d" % [
		_time, name, pos.x, pos.y, pos.z, rad_to_deg(_mecha.global_rotation.y), _stumbles])


func _capture(index: int) -> void:
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/walk_%d.png" % index)