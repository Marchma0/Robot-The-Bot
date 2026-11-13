extends Node3D
## Bac à sable du parcours tuto de dev (on est l'hôte, sans réseau). Le script pilote les deux joysticks des
## jambes comme deux joueurs et fait tout le parcours : il vérifie que chaque obstacle arrête le robot (trou,
## poutre, rochers, portes, barrière), que la bonne commande le fait passer, que les caisses mobiles bougent
## jusqu'à ce qu'on les prenne, que la foreuse baissée touche le sol et, levée, arrive au-dessus de la tour,
## et que les étapes avancent jusqu'au bout.
## Saut et accroupi sont lancés directement (leur QTE est testé dans sandbox_maneuvers), la foreuse et le
## grappin aussi (testés dans sandbox_arms). Images dans build/views/tuto_<nom>.png.

@onready var _mecha: Node3D = $Mecha
@onready var _walker: MechaWalker = $Mecha/Walker
@onready var _sticks: Array[Lever] = [$Mecha/Controls/LegL_Stick as Lever, $Mecha/Controls/LegR_Stick as Lever]
@onready var _level: DevTutorial = $DevTutorial
@onready var _camera: Camera3D = $Camera3D

var _stick_wanted: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _blocked: int = 0
var _leg: int = 0
var _last_angle: float = 0.0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	_level.mecha = _mecha
	_walker.blocked.connect(func() -> void: _blocked += 1)
	await _wait(1.0)
	await _shot("0_vue_d_ensemble", Vector3(4.0, 120.0, -38.0), Vector3(4.0, 0.0, -38.0))

	await _walk_to(Vector2(0.0, -20.0))
	_expect_step(DevTutorial.Step.TURN, "étape 1 : la dalle de la ligne droite est validée")
	await _walk_to(Vector2(0.0, -36.0))
	await _walk_to(Vector2(14.0, -36.0))
	_expect_step(DevTutorial.Step.JUMP, "étape 2 : la dalle après le virage est validée")

	# Trou : on ne peut pas y marcher (le robot s'approche du bord à petits pas), on saute par-dessus.
	await _walk_to(Vector2(27.0, -36.0), true)
	var feet_x: float = maxf(_walker.get_foot_transform(0).origin.x, _walker.get_foot_transform(1).origin.x)
	TestCheck.expect(_blocked > 0 and feet_x < 22.0 and feet_x > 21.0,
		"trou : le robot s'arrête au bord, à petits pas (pied le plus avancé à x = %.2f, bord à 22)" % feet_x)
	await _shot("1_bord_du_trou", Vector3(31.0, 9.0, -31.0), Vector3(23.0, -2.0, -37.0))
	await _wait(1.0)
	_walker.jump(0.0)
	await _wait(_walker.jump_prep_time + _walker.jump_air_time + _walker.jump_land_time + 0.5)
	TestCheck.expect(_pos().x > 25.5 and absf(_mecha.global_position.y - 0.55) < 0.2,
		"trou : le saut le fait passer (x = %.1f, hauteur %.2f)" % [_pos().x, _mecha.global_position.y])
	await _walk_to(Vector2(32.0, -36.0))
	_expect_step(DevTutorial.Step.CROUCH, "étape 3 : la dalle après le trou est validée")

	# Poutre basse : debout, il bute ; accroupi, il passe ; dessous, il ne peut pas se relever.
	_blocked = 0
	await _walk_to(Vector2(42.0, -36.0), true)
	TestCheck.expect(_blocked > 0 and _pos().x < 36.0, "poutre : debout, le robot s'arrête devant (x = %.1f)" % _pos().x)
	await _shot_follow("2_devant_la_poutre")
	_walker.set_crouched(true)
	await _wait(1.6)
	await _walk_to(Vector2(38.5, -36.0))
	await _wait(1.6)
	_walker.set_crouched(false)
	TestCheck.expect(_walker.crouched, "poutre : dessous, il ne peut pas se relever")
	await _walk_to(Vector2(47.0, -36.0))
	_expect_step(DevTutorial.Step.U_TURN, "étape 4 : la dalle après la poutre est validée")
	await _wait(1.6)
	_walker.set_crouched(false)
	await _wait(1.0)
	TestCheck.expect(not _walker.crouched, "après la poutre, il se relève")

	# Demi-tour dans la salle du fond.
	await _walk_to(Vector2(63.0, -36.0))
	await _walk_to(Vector2(63.0, -52.0))
	await _walk_to(Vector2(48.0, -52.0))
	_expect_step(DevTutorial.Step.DRILL, "étape 5 : la dalle après le demi-tour est validée")

	# Rochers : ils bouchent le passage jusqu'à ce qu'on les casse.
	_blocked = 0
	await _walk_to(Vector2(30.0, -52.0), true)
	TestCheck.expect(_blocked > 0 and _pos().x > 38.0, "rochers : le robot s'arrête devant (x = %.1f)" % _pos().x)
	for rock: MineableRock in _level.get_node("MineableRocks").get_children():
		rock.apply_drill_damage(1000.0)
	await _wait(1.5)
	await _walk_to(Vector2(28.5, -52.0))
	_expect_step(DevTutorial.Step.GRAB, "étape 6 : rochers cassés, la dalle d'après est validée")

	# Porte 1 : fermée tant que le sac n'a pas reçu 2 caisses.
	_blocked = 0
	await _walk_to(Vector2(12.0, -52.0), true)
	TestCheck.expect(_blocked > 0 and _pos().x > 22.0 and not _level.is_gate_open(DevTutorial.Gate.CRATES),
		"porte 1 : fermée, le robot s'arrête devant (x = %.1f)" % _pos().x)
	var backpack: Backpack = get_tree().get_first_node_in_group(&"backpacks") as Backpack
	var crates: Array[Node] = _level.get_node("CargoCrates").get_children()
	TestCheck.expect(crates.size() >= 4, "les rochers ont laissé leurs caisses (%d caisses)" % crates.size())
	backpack.store_node(crates[0] as Node3D)
	await _wait(0.3)
	TestCheck.expect(not _level.is_gate_open(DevTutorial.Gate.CRATES), "une seule caisse : la porte 1 reste fermée")
	backpack.store_node(crates[1] as Node3D)
	await _wait(DevTutorial.GATE_TIME + 0.5)
	TestCheck.expect(_level.is_gate_open(DevTutorial.Gate.CRATES), "deux caisses dans le sac : la porte 1 s'ouvre")
	await _walk_to(Vector2(12.0, -52.0))
	_expect_step(DevTutorial.Step.MOVING, "étape 7 : la dalle après la porte 1 est validée")

	# Caisses mobiles : elles bougent, la barrière garde le robot sur le chemin, une caisse prise ne bouge plus.
	await _walk_to(Vector2(-10.0, -52.0))
	var movers: Node3D = _level.get_node("%MovingCrates")
	var before: Dictionary[StringName, Vector3] = {}
	for crate: Node3D in movers.get_children():
		before[crate.name] = crate.position
	await _wait(1.0)
	var moved: int = 0
	for crate: Node3D in movers.get_children():
		if crate.position.distance_to(before[crate.name]) > 0.5:
			moved += 1
	TestCheck.expect(moved == 4 and _level.crates_left == 4, "caisses mobiles : les 4 bougent (%d)" % moved)
	await _shot("3_caisses_mobiles", Vector3(-11.0, 30.0, -40.0), Vector3(-11.0, 0.0, -68.0))
	_blocked = 0
	await _walk_to(Vector2(-10.0, -66.0), true)
	var feet_z: float = minf(_walker.get_foot_transform(0).origin.z, _walker.get_foot_transform(1).origin.z)
	TestCheck.expect(_blocked > 0 and feet_z > -59.5, "barrière : les pieds du robot restent sur le chemin (z = %.1f)" % feet_z)
	var grabber: GrabberArm = _mecha.get_node("GrabberArm") as GrabberArm
	grabber.grab_node(movers.get_node("Mover1") as Node3D)
	await _wait(2.0)
	TestCheck.expect(_level.crates_left == 3 and backpack.get_item_count() == 3,
		"caisse mobile prise par la pince : rangée dans le sac (reste %d)" % _level.crates_left)
	TestCheck.expect(not _level.is_gate_open(DevTutorial.Gate.MOVING), "il reste des caisses : la porte 2 reste fermée")
	for crate: Node3D in movers.get_children():
		backpack.store_node(crate)
	await _wait(DevTutorial.GATE_TIME + 0.5)
	TestCheck.expect(_level.is_gate_open(DevTutorial.Gate.MOVING), "toutes les caisses mobiles rangées : la porte 2 s'ouvre")
	_expect_step(DevTutorial.Step.BUTTON, "étape 8 : caisses mobiles toutes attrapées")

	# Collé à la barrière, il ne peut pas pivoter (un pied avancerait dedans) : il recule d'abord.
	await _step_back(4)
	# Porte 3 fermée tant que le bouton au sol n'est pas appuyé (appui déjà validé par l'hôte).
	await _walk_to(Vector2(-10.0, -52.0))
	_blocked = 0
	await _walk_to(Vector2(-56.0, -52.0), true)
	TestCheck.expect(_blocked > 0 and _pos().x > -48.0, "porte 3 : fermée, le robot s'arrête devant (x = %.1f)" % _pos().x)
	(_level.get_node("%OutsideButton") as PushButton).pressed.emit(1)
	await _wait(DevTutorial.GATE_TIME + 0.5)
	TestCheck.expect(_level.is_gate_open(DevTutorial.Gate.BUTTON), "bouton au sol : la porte 3 s'ouvre")
	_expect_step(DevTutorial.Step.FINISH, "étapes 9 et 10 : bouton au sol, puis tout le monde à bord (pas de nain ici)")
	await _walk_to(Vector2(-58.0, -52.0))
	_expect_step(DevTutorial.Step.DONE, "étape 11 : arrivée, tuto terminé")
	TestCheck.expect(_walker.phase == MechaWalker.Phase.WALKING, "le robot n'est jamais tombé")
	await _shot_follow("6_arrivee")
	TestCheck.finish(get_tree())


func _physics_process(_delta: float) -> void:
	for leg: int in 2:
		_sticks[leg].value = _stick_wanted[leg]


func _pos() -> Vector2:
	return Vector2(_mecha.global_position.x, _mecha.global_position.z)


func _expect_step(step: DevTutorial.Step, label: String) -> void:
	TestCheck.expect(_level.step == step, "%s (étape %d)" % [label, _level.step + 1])


## Marche vers `target` comme deux joueurs qui alternent : tout droit, en diagonale si l'écart de direction
## est moyen, en pivot sur place s'il est grand. On change de façon de marcher après une pause (sinon les deux
## pas ne vont pas dans la même direction et la jauge d'erreur monte). `stop_on_block` : s'arrête au premier
## pas refusé (obstacle).
func _walk_to(target: Vector2, stop_on_block: bool = false) -> void:
	var blocked_before: int = _blocked
	for i: int in 160:
		var to: Vector2 = target - _pos()
		if to.length() < 1.2:
			return
		if stop_on_block and _blocked > blocked_before:
			await _wait(1.0)
			return
		var forward: Vector3 = -_mecha.global_basis.z
		var heading: float = atan2(forward.x, -forward.z)
		var wanted: float = atan2(to.x, -to.y)
		var error: float = angle_difference(heading, wanted)   # positif = vers la droite
		var angle: float = 0.0
		if absf(error) > deg_to_rad(35.0):
			angle = signf(error) * PI / 2.0
		elif absf(error) > deg_to_rad(8.0):
			angle = signf(error) * deg_to_rad(50.0)
		if not is_equal_approx(angle, _last_angle):
			await _wait(1.6)
			_last_angle = angle
		_stick_wanted[_leg] = Vector2(sin(angle), cos(angle))
		await _wait(0.15)
		_stick_wanted[_leg] = Vector2.ZERO
		await _wait(0.3)
		_leg = 1 - _leg
	TestCheck.expect(false, "le robot n'arrive pas en %s (il est en %s)" % [target, _pos()])


## Les deux pilotes reculent de `steps` pas (joysticks vers l'arrière, chacun son tour).
func _step_back(steps: int) -> void:
	await _wait(1.6)
	_last_angle = PI
	for i: int in steps:
		_stick_wanted[_leg] = Vector2(0.0, -1.0)
		await _wait(0.15)
		_stick_wanted[_leg] = Vector2.ZERO
		await _wait(0.45)
		_leg = 1 - _leg


func _shot(name: String, from: Vector3, look_at_point: Vector3) -> void:
	_camera.global_position = from
	_camera.look_at(look_at_point, Vector3.FORWARD if absf(from.x - look_at_point.x) + absf(from.z - look_at_point.z) < 0.1 else Vector3.UP)
	_camera.reset_physics_interpolation()
	for i: int in 3:
		await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/tuto_%s.png" % name)


## Image de trois quarts arrière, au-dessus du robot.
func _shot_follow(name: String) -> void:
	var back: Vector3 = _mecha.global_basis.z
	var at: Vector3 = _mecha.global_position
	await _shot(name, at + back * 16.0 + Vector3(6.0, 14.0, 0.0), at + Vector3(0.0, 3.0, 0.0) - back * 6.0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
