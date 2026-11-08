extends Node3D
## Bac à sable M7.2 : jauge d'erreur, chute, QTE de relèvement (on est l'hôte, sans réseau).
## Scénario automatique : 2 pas normaux, puis 3 gros désaccords (la jauge se remplit), chute,
## QTE joué par le script (avec une erreur volontaire), relèvement. Images dans build/views/fall_<nom>.png.

@export var quit_when_done: bool = true

var _time: float = 0.0
var _pushes: Array = []   # [jambe, direction, début]
var _qte_next: float = 0.0
var _qte_presses: int = 0
var _mistake_done: bool = false
var _last_phase: int = -1
var _shots_done: Dictionary = {}
var _end_time: float = -1.0

@onready var _mecha: Node3D = $Mecha
@onready var _walker: MechaWalker = $Mecha/Walker
@onready var _qte: QteSequence = $Mecha/RecoveryQte
@onready var _sticks: Array[Lever] = [$Mecha/Controls/LegL_Stick as Lever, $Mecha/Controls/LegR_Stick as Lever]
@onready var _cam_inside: Camera3D = $CamInside
@onready var _cam_outside: Camera3D = $CamOutside


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	_walker.stepped.connect(func(leg: int) -> void: print("   pas jambe %d, jauge %.2f" % [leg, _walker.error_gauge]))
	_walker.stumbled.connect(func() -> void: print("   trébuche, jauge %.2f" % _walker.error_gauge))
	_qte.mistake.connect(func(leg: int) -> void: print("   QTE : erreur (jambe %d), avancement %d/%d" % [leg, _qte.step_index, _qte.step_count]))
	_pushes = [[0, Vector2(0, 1), 1.0], [1, Vector2(0, 1), 1.45]]
	var t: float = 2.6
	for i: int in 3:
		_pushes.append([0, Vector2(0, 1), t])
		_pushes.append([1, Vector2(0, -1), t + 0.5])
		t += 1.6


func _physics_process(delta: float) -> void:
	_time += delta
	var wanted: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	for push: Array in _pushes:
		if _time >= push[2] and _time < push[2] + 0.15:
			wanted[push[0]] = push[1]
	for leg: int in 2:
		_sticks[leg].value = wanted[leg]
	if _walker.phase != _last_phase:
		_last_phase = _walker.phase
		print("[%5.2f s] phase %s, jauge d'erreur %.2f" % [_time, MechaWalker.Phase.keys()[_walker.phase], _walker.error_gauge])
	_play_qte()
	_place_cameras()
	_maybe_shoot()
	if _end_time < 0.0 and _walker.phase == MechaWalker.Phase.WALKING and _qte_presses > 0:
		_end_time = _time + 1.0
	if _end_time > 0.0 and _time > _end_time:
		print("[%5.2f s] fin : jauge %.2f, appuis QTE %d" % [_time, _walker.error_gauge, _qte_presses])
		TestCheck.expect(_qte_presses > 0, "le robot est tombé et le QTE a été joué")
		TestCheck.expect(_walker.phase == MechaWalker.Phase.WALKING and _walker.error_gauge == 0.0, "QTE réussi : il est relevé, jauge à zéro")
		if quit_when_done or TestCheck.is_auto():
			TestCheck.finish(get_tree())


## Joue le QTE comme deux joueurs : la bonne flèche toutes les 0,4 s, une fausse au 3e appui.
func _play_qte() -> void:
	if not _qte.active or _time < _qte_next:
		return
	# Après le 4e appui, les joueurs hésitent 3 s : la jauge se vide et ils perdent une étape.
	_qte_next = _time + (3.0 if _qte_presses == 4 else 0.4)
	if _qte_presses == 4:
		print("   QTE : hésitation de 3 s (avancement %d/%d)" % [_qte.step_index, _qte.step_count])
	_qte_presses += 1
	var pads: Array[PushButton] = _qte.pads_left if _qte.current_leg == 0 else _qte.pads_right
	if _qte_presses == 3 and not _mistake_done:
		_mistake_done = true
		var wrong: int = (_qte.current_arrow + 1) % 4
		pads[wrong].pressed.emit(1)
		return
	print("   QTE : jambe %d flèche %s (%d/%d)" % [_qte.current_leg, QteSequence.Arrow.keys()[_qte.current_arrow],
		_qte.step_index + 1, _qte.step_count])
	pads[_qte.current_arrow].pressed.emit(1)


func _place_cameras() -> void:
	var xf: Transform3D = _mecha.global_transform
	_cam_inside.global_position = xf * Vector3(-0.85, 3.85, -0.95)
	_cam_inside.look_at(xf * Vector3(-1.0, 3.2, -1.48), xf.basis.y)
	var center: Vector3 = _mecha.global_position + Vector3.UP * 2.0
	_cam_outside.global_position = center - xf.basis.x * 9.0 - xf.basis.z * 5.0 + Vector3.UP * 2.5
	_cam_outside.look_at(center, Vector3.UP)


func _maybe_shoot() -> void:
	if _time > 1.1 and _time < 1.4 and _walker.next_leg == 1:
		_shoot("5_voyant_eteint", _cam_inside)
	if _time > 1.6 and _time < 2.4 and _walker.next_leg == 0:
		_shoot("6_voyant_vert", _cam_inside)
	if _walker.error_gauge > 0.5 and _walker.phase == MechaWalker.Phase.WALKING:
		_shoot("1_jauge", _cam_inside)
	if _time > 0.6 and _walker.error_gauge == 0.0 and _walker.phase == MechaWalker.Phase.WALKING:
		_shoot("0_jauge_vide", _cam_inside)
	if _qte.active and _qte.step_index >= 1 and _qte.current_leg == 0 and fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.25:
		_shoot("2_qte_console", _cam_inside)
	if _qte.active and _mistake_done:
		_shoot("7_qte_erreur", _cam_inside)
	if _qte.active and _qte.step_index >= 2:
		_shoot("3_a_terre", _cam_outside)
	if _walker.phase == MechaWalker.Phase.WALKING and _qte_presses > 0 and _time > _end_time - 0.2 and _end_time > 0.0:
		_shoot("4_releve", _cam_outside)


func _shoot(name: String, camera: Camera3D) -> void:
	if _shots_done.has(name):
		return
	_shots_done[name] = true
	camera.current = true
	await TestCheck.frame_drawn(get_tree())
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/fall_%s.png" % name)