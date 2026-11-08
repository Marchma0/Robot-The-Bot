extends Node
## Bac à sable M12 / M12.1 : lance le jeu (scène principale) en hôte hors réseau, puis joue tout le parcours :
## apparition au camp, vues du camp, fléchettes (3 lancers), bras de fer (contre un adversaire simulé),
## terminal (flèches + bouton vert, compte à rebours), départ en mission (terrain de test) quand le nain
## monte à bord, puis bouton « retour au camp ». Captures : build/views/lobby_*.png.

@export var quit_when_done: bool = true

var _main: Node
var _cam: Camera3D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	await _wait(1.0)
	NetworkManager.host_game()
	await _wait(2.0)
	var director: MissionDirector = _main.get_node("World/MissionDirector")
	var mecha: Node3D = _main.get_node("World/Mecha")
	var dwarf: Dwarf = mecha.get_node("Players").get_child(0) as Dwarf
	var level: Node3D = director.get_level()
	print("Niveau : %s, nain en %s, à bord %s" % [director.current_level, dwarf.global_position, director.count_aboard()])
	TestCheck.expect(director.in_lobby(), "on démarre au camp")
	TestCheck.expect(director.count_aboard() == Vector2i(0, 1), "le nain apparaît dehors")
	await _shot("1_apparition")
	_cam = Camera3D.new()
	add_child(_cam)
	await _shot_from("2_vue_ensemble", Vector3(16.0, 14.0, -22.0), Vector3(0.0, 2.0, 4.0))

	# Fléchettes : derrière la ligne, 3 lancers visés sur la cible
	var darts: DartsGame = level.get_node("Minigames/Darts")
	_place_dwarf(dwarf, darts.to_global(Vector3(0.2, 0.0, -3.5)), darts.to_global(Vector3(0.0, 0.0, 0.0)))
	await _wait(0.3)
	darts.request_take.rpc_id(1)
	await _wait(0.2)
	for k: int in 3:
		var eye: Vector3 = dwarf.global_position + Vector3(0.0, 0.95, 0.0)
		var target: Vector3 = darts.to_global(DartsGame.BOARD_CENTER + Vector3(0.06 * (k - 1), 0.05 * k, 0.0))
		var flight_time: float = eye.distance_to(target) / DartsGame.THROW_SPEED
		var aim: Vector3 = target + Vector3(0.0, 0.5 * DartsGame.DART_GRAVITY * flight_time * flight_time, 0.0)
		darts.request_throw.rpc_id(1, eye, (aim - eye).normalized())
		await _wait(0.7)
	print("Fléchettes : %s, record %d (%s)" % [darts.round_scores, darts.record, darts.record_name])
	TestCheck.expect(darts.round_scores.size() == 3, "fléchettes : 3 lancers comptés")
	TestCheck.expect(darts.record > 0 and darts.record_name == dwarf.get_display_name(), "fléchettes : record au nom du joueur")
	await _shot_from("3_flechettes", darts.to_global(Vector3(-0.4, 1.4, -2.4)), darts.to_global(Vector3(0.45, 1.25, 0.0)))

	# Bras de fer : le nain s'assoit à gauche, un adversaire simulé à droite (peer 99)
	var arm: ArmwrestleGame = level.get_node("Minigames/ArmWrestling")
	arm.seat_left.occupant_peer_id = 1
	arm.seat_right.occupant_peer_id = 99
	await _wait(3.4)
	print("Bras de fer : état %d (2 = combat), occupants %d / %d" % [arm.state, arm.seat_left.occupant_peer_id, arm.seat_right.occupant_peer_id])
	for k: int in 12:
		arm.seat_left.game_pushed.emit(1)
		await _wait(0.05)
	await _shot_from("4_bras_de_fer", arm.to_global(Vector3(0.2, 1.5, 2.2)), arm.to_global(Vector3(0.0, 0.9, 0.0)))
	for k: int in 30:
		arm.seat_left.game_pushed.emit(1)
		await _wait(0.05)
	await _wait(0.2)
	print("Bras de fer : état %d (3 = gagné), rapport %.2f, gagnant « %s »" % [arm.state, arm.balance, arm.winner_name])
	TestCheck.expect(arm.state == ArmwrestleGame.State.WIN and arm.winner_name == dwarf.get_display_name(), "bras de fer : le joueur qui martèle gagne")
	arm.seat_left.occupant_peer_id = 0
	arm.seat_right.occupant_peer_id = 0

	# Terminal : flèche suivante (mission verrouillée), retour, bouton vert
	var terminal: MissionTerminal = level.get_node("MissionTerminal")
	_place_dwarf(dwarf, terminal.to_global(Vector3(0.0, 0.0, -1.0)), terminal.global_position)
	await _wait(0.3)
	terminal.get_node("Next").pressed.emit(1)
	await _wait(0.2)
	print("Flèche suivante : mission %d" % terminal.selected)
	TestCheck.expect(terminal.selected == 1, "terminal : flèche suivante")
	await _shot_from("5_terminal_verrouille", terminal.to_global(Vector3(0.15, 1.15, -1.0)), terminal.to_global(Vector3(0.0, 0.75, 0.0)))
	terminal.get_node("Prev").pressed.emit(1)
	terminal.get_node("Launch").pressed.emit(1)
	await _wait(0.3)
	print("Bouton vert : mission %d, compte à rebours %.1f s" % [terminal.selected, terminal.countdown])
	TestCheck.expect(terminal.selected == 0 and terminal.countdown > 0.0, "terminal : bouton vert lance le compte à rebours")
	await _shot_from("6_terminal_lance", terminal.to_global(Vector3(0.15, 1.15, -1.0)), terminal.to_global(Vector3(0.0, 0.75, 0.0)))

	# Le nain monte à bord : la mission part toute seule
	dwarf.position = (mecha.get_node("SpawnPoints").get_child(0) as Node3D).position
	await _wait(2.5)
	print("Après montée à bord : niveau %s, robot en %s" % [director.current_level, mecha.global_position])
	TestCheck.expect(director.current_level == &"test_ground", "tout le monde à bord : la mission part")
	await _shot("7_mission")
	var button: PushButton = mecha.get_node("Controls/ReturnToCamp")
	button.pressed.emit(1)
	await _wait(2.5)
	print("Après retour : niveau %s, robot en %s, bouton visible %s" % [director.current_level, mecha.global_position, button.visible])
	TestCheck.expect(director.in_lobby() and not button.visible, "bouton retour : on revient au camp, bouton caché")
	if quit_when_done or TestCheck.is_auto():
		TestCheck.finish(get_tree())


## Place le nain (dehors, dans le monde) en `at`, tourné vers `look`.
func _place_dwarf(dwarf: Dwarf, at: Vector3, look: Vector3) -> void:
	var flat: Vector3 = Vector3(look.x - at.x, 0.0, look.z - at.z)
	dwarf.set(&"_world_position", at)
	dwarf.set(&"_world_yaw", atan2(-flat.x, -flat.z))
	dwarf.global_position = at


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot_from(shot_name: String, from: Vector3, look: Vector3) -> void:
	_cam.global_position = from
	_cam.look_at(look, Vector3.UP)
	_cam.current = true
	await _shot(shot_name)
	_cam.current = false


func _shot(shot_name: String) -> void:
	await _wait(0.4)
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/lobby_%s.png" % shot_name)