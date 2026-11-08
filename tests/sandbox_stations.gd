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
	await _joystick_run()
	if quit_when_done or TestCheck.is_auto():
		TestCheck.finish(get_tree())


## Joystick de la jambe gauche à la souris : on le prend (clic maintenu), 4 coups de souris vers l'avant
## (chacun doit faire un pas), Tab replie puis rouvre le panneau des touches, on le lâche.
func _joystick_run() -> void:
	var stick: Lever = $Mecha/Controls/LegL_Stick as Lever
	var walker: MechaWalker = $Mecha/Walker as MechaWalker
	var interactor: Interactor = _dwarf.get_node("%Interactor") as Interactor
	var steps: Array[int] = [0]
	walker.stepped.connect(func(_leg: int) -> void: steps[0] += 1)
	var kicks: Array[int] = [0]
	interactor.stick_kicked.connect(func(_dir: Vector2) -> void: kicks[0] += 1)
	# Le nain se place devant la console de la jambe gauche, regard sur le joystick.
	_dwarf.position = Vector3(-1.22, 2.65, -0.75)
	_dwarf.rotation = Vector3.ZERO
	await get_tree().create_timer(0.5).timeout
	Input.action_press(&"grab")
	stick.request_grab.rpc_id(1)
	interactor.begin_claim(stick)
	await _capture_at(0.4, "joystick_0_tenu")
	for i: int in 4:
		# Un coup de souris vers l'avant étalé sur quelques images, puis plus rien (il revient seul).
		for k: int in 4:
			interactor.drive_mouse(Vector2(0.0, 18.0))
			await get_tree().physics_frame
		if i == 0:
			await _capture_at(0.02, "joystick_1_clac")
		await get_tree().create_timer(0.9).timeout
	print("Joystick : %d coups de souris, %d « clac », %d pas" % [4, kicks[0], steps[0]])
	TestCheck.expect(kicks[0] == 4 and steps[0] == 4, "joystick à la souris : 4 coups = 4 « clac » = 4 pas")
	_tap_event(&"toggle_help")
	await _capture_at(0.15, "joystick_2_panneau_replie")
	_tap_event(&"toggle_help")
	Input.action_release(&"grab")
	await _capture_at(0.4, "joystick_3_lache")


func _tap_event(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


func _station_run(seat: Seat, label: String, fire: bool) -> void:
	var interactor: Interactor = _dwarf.get_node("%Interactor") as Interactor
	seat.request_sit.rpc_id(1)
	interactor.begin_claim(seat)
	await _capture_at(0.05, "%s_0_assis" % label)
	TestCheck.expect(interactor.get_seat() == seat, "%s : assis au poste" % label)
	await _capture_at(0.35, "%s_1_traveling" % label)
	await _capture_at(0.35, "%s_2_ecran" % label)
	await _capture_at(0.2, "%s_3_neige" % label)
	if fire:
		# Vise la caisse lointaine (droit devant, un peu vers le bas) puis lance.
		_grabber_arm.arm_pitch = -0.32
		await get_tree().create_timer(0.3).timeout
		await _tap("jump")
		await _capture_at(0.3, "%s_4_lance" % label)
		await _capture_at(1.0, "%s_5_ramene" % label)
		await get_tree().create_timer(1.2).timeout   # aller + retour + rangement ≈ 1,7 s
		print("Grappin : état %d, sac %d objet(s)" % [_grabber_arm.shot_state, ($Mecha/Backpack as Backpack).stored_items.size()])
		TestCheck.expect(($Mecha/Backpack as Backpack).stored_items.size() == 1, "grappin lancé : la caisse lointaine finit dans le sac")
	else:
		await _capture_at(0.6, "%s_4_vue" % label)
	_tap_key(KEY_TAB)
	await _capture_at(0.2, "%s_4b_tab" % label)
	_tap_key(KEY_TAB)
	await _tap("interact")
	await _capture_at(0.25, "%s_6_leve" % label)
	await _capture_at(0.6, "%s_7_debout" % label)
	TestCheck.expect(seat.occupant_peer_id == 0 and interactor.get_seat() == null, "%s : E pour se lever" % label)
	# La chaise a une collision : debout, le nain doit être au sol à côté, pas coincé dedans ni perché dessus.
	var stand_height: float = _dwarf.position.y - seat.position.y
	print("%s : debout à %.2f m au-dessus du sol du poste" % [label, stand_height])
	TestCheck.expect(absf(stand_height) < 0.15, "%s : debout au sol, pas sur la chaise" % label)


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)


func _capture_at(delay: float, shot_name: String) -> void:
	await get_tree().create_timer(delay).timeout
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/stations_%s.png" % shot_name)
## Appui réel sur une touche du clavier (comme un joueur), relâchée juste après.
func _tap_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
