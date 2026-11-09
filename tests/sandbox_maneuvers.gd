extends Node3D
## Bac à sable du saut et de l'accroupi (M7.5), on est l'hôte, sans réseau. Le script joue les deux pilotes :
## ↓ ensemble → QTE de l'accroupi → accroupi ; ↑ refusé tant qu'il est accroupi ; ↓ ensemble → debout ;
## ↑ ensemble → QTE du saut (joysticks d'abord en désaccord, puis ensemble vers l'avant) → saut d'environ 4 m ;
## enfin un QTE abandonné : annulé, la jauge d'erreur monte. Images dans build/views/maneuvers_<nom>.png.

@onready var _mecha: Node3D = $Mecha
@onready var _walker: MechaWalker = $Mecha/Walker
@onready var _qte: QteSequence = $Mecha/RecoveryQte
@onready var _maneuvers: MechaManeuvers = $Mecha/Maneuvers
@onready var _sticks: Array[Lever] = [$Mecha/Controls/LegL_Stick as Lever, $Mecha/Controls/LegR_Stick as Lever]
@onready var _cam_inside: Camera3D = $CamInside
@onready var _cam_outside: Camera3D = $CamOutside

var _stick_wanted: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	await _wait(1.5)
	var standing_y: float = _mecha.global_position.y
	await _shot("0_pret", _cam_inside)

	# Accroupi : ↓ par un pilote (l'autre doit suivre), puis par l'autre.
	_pad(0, QteSequence.Arrow.DOWN)
	await _wait(0.2)
	TestCheck.expect(_maneuvers.waiting_arrow == QteSequence.Arrow.DOWN and not _qte.active,
		"↓ par un seul pilote : on attend l'autre")
	await _shot("1_attends_l_autre", _cam_inside)
	_pad(1, QteSequence.Arrow.DOWN)
	await _wait(0.1)
	TestCheck.expect(_qte.active and not _qte.sequence.has(QteSequence.BOTH * 4), "↓ ensemble : QTE de l'accroupi lancé")
	await _play_arrows()
	await _wait(_walker.crouch_time + 0.3)
	TestCheck.expect(_walker.crouched, "QTE réussi : le robot est accroupi")
	var drop: float = standing_y - _mecha.global_position.y
	TestCheck.expect(drop > 0.7, "accroupi : le corps est descendu (%.2f m)" % drop)
	await _shot("2_accroupi", _cam_outside)
	await _shot("2b_ecran_accroupi", _cam_inside)

	# Pas de saut accroupi.
	await _both(QteSequence.Arrow.UP)
	TestCheck.expect(not _qte.active, "accroupi : ↑ ensemble ne lance pas de saut")

	# ↓ ensemble : il se relève, sans QTE.
	await _wait(0.6)
	await _both(QteSequence.Arrow.DOWN)
	TestCheck.expect(not _qte.active and not _walker.crouched, "accroupi : ↓ ensemble le relève, sans QTE")
	await _wait(_walker.crouch_time + 0.3)
	TestCheck.expect(absf(_mecha.global_position.y - standing_y) < 0.15, "il est de nouveau debout")

	# Saut : ↑ ensemble, puis les joysticks.
	await _wait(0.6)
	var start: Vector3 = _mecha.global_position
	var forward: Vector3 = -_mecha.global_basis.z
	await _both(QteSequence.Arrow.UP)
	TestCheck.expect(_qte.active and _qte.current_leg == QteSequence.BOTH, "↑ ensemble : QTE du saut, étape joystick d'abord")
	await _shot("3_ensemble", _cam_inside)
	_stick_wanted = [Vector2(0.0, 1.0), Vector2(1.0, 0.0)]   # l'un devant, l'autre à droite : pas d'accord
	await _wait(0.4)
	TestCheck.expect(_qte.current_leg == QteSequence.BOTH, "joysticks dans deux directions : l'étape attend")
	_stick_wanted = [Vector2(0.0, 1.0), Vector2(0.3, 0.95)]   # tous les deux vers l'avant (à 17° près)
	await _wait(0.2)
	_stick_wanted = [Vector2.ZERO, Vector2.ZERO]
	TestCheck.expect(_qte.step_index >= 1 and absf(rad_to_deg(_qte.stick_direction)) < 20.0,
		"joysticks ensemble vers l'avant : étape validée (direction %.0f°)" % rad_to_deg(_qte.stick_direction))
	await _play_arrows()
	TestCheck.expect(_walker.phase == MechaWalker.Phase.JUMPING, "QTE réussi : le robot saute")
	await _wait(_walker.jump_prep_time + _walker.jump_air_time * 0.5)
	TestCheck.expect(_mecha.global_position.y > start.y + 0.8, "en l'air (%.2f m plus haut)" % (_mecha.global_position.y - start.y))
	await _shot("4_en_l_air", _cam_outside)
	await _wait(_walker.jump_air_time * 0.5 + _walker.jump_land_time + 0.5)
	var moved: Vector3 = _mecha.global_position - start
	TestCheck.expect(_walker.phase == MechaWalker.Phase.WALKING, "réception : il remarche")
	TestCheck.expect(moved.dot(forward) > 3.2 and moved.dot(forward) < 4.8,
		"il a sauté d'environ 4 m vers l'avant (%.2f m)" % moved.dot(forward))
	await _shot("5_arrive", _cam_outside)

	# QTE abandonné : annulé, la jauge d'erreur monte.
	var gauge: float = _walker.error_gauge
	await _both(QteSequence.Arrow.DOWN)
	TestCheck.expect(_qte.active, "↓ ensemble : QTE lancé")
	await _wait(_maneuvers.fail_after + 0.5)
	TestCheck.expect(not _qte.active and not _walker.crouched, "personne ne joue : le QTE s'annule")
	TestCheck.expect(_walker.error_gauge > gauge + 0.25, "QTE raté : la jauge d'erreur monte (%.2f)" % _walker.error_gauge)
	TestCheck.finish(get_tree())


func _physics_process(_delta: float) -> void:
	for leg: int in 2:
		_sticks[leg].value = _stick_wanted[leg]
	_place_cameras()


## Un pilote appuie sur une flèche de sa console (appui déjà validé par l'hôte).
func _pad(leg: int, arrow: int) -> void:
	var pads: Array[PushButton] = _qte.pads_left if leg == 0 else _qte.pads_right
	pads[arrow].pressed.emit(1)


## Les deux pilotes appuient sur la même flèche, à 0,3 s d'écart.
func _both(arrow: int) -> void:
	_pad(0, arrow)
	await _wait(0.3)
	_pad(1, arrow)
	await _wait(0.1)


## Joue les flèches du QTE en cours (la bonne, toutes les 0,3 s).
func _play_arrows() -> void:
	while _qte.active and _qte.current_leg != QteSequence.BOTH:
		_pad(_qte.current_leg, _qte.current_arrow)
		if not _qte.active:
			return   # dernier appui : on n'attend pas (le saut part tout de suite)
		await _wait(0.3)


func _place_cameras() -> void:
	var xf: Transform3D = _mecha.global_transform
	_cam_inside.global_position = xf * Vector3(-0.85, 3.85, -0.95)
	_cam_inside.look_at(xf * Vector3(-1.0, 3.2, -1.48), xf.basis.y)
	var center: Vector3 = _mecha.global_position + Vector3.UP * 2.0
	_cam_outside.global_position = center - xf.basis.x * 9.0 - xf.basis.z * 5.0 + Vector3.UP * 2.5
	_cam_outside.look_at(center, Vector3.UP)


func _shot(shot_name: String, camera: Camera3D) -> void:
	camera.current = true
	await TestCheck.frame_drawn(get_tree())
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/maneuvers_%s.png" % shot_name)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
