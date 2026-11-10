extends Node
## Bac à sable M12 / M12.1 : lance le jeu (scène principale) en hôte hors réseau, puis joue tout le parcours :
## apparition au camp, vues du camp, bras de fer (contre un adversaire simulé),
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
	await _shot_from("2_vue_ensemble", Vector3(13.5, 7.5, -13.0), Vector3(0.0, 2.5, 1.0))

	# Atelier du robot : changement de skin et de configuration des bras
	var workshop: MechaWorkshop = level.get_node("MechaWorkshop")
	var customizer: MechaCustomizer = mecha.get_node("Customizer")
	workshop.get_node("SkinNext").pressed.emit(1)
	workshop.get_node("ArmNext").pressed.emit(1)
	await _wait(0.2)
	TestCheck.expect(customizer.skin_index == 1 and customizer.arm_mode == 1, "atelier du robot : skin Baron Cuivre et bras inversés")
	await _shot_from("3a_atelier_robot", Vector3(6.5, 3.8, -9.8), Vector3(1.5, 4.2, -1.5))
	workshop.get_node("SkinPrev").pressed.emit(1)
	workshop.get_node("ArmPrev").pressed.emit(1)
	await _wait(0.1)

	# Vestiaire des nains : changement de tenue et de couleur
	var wardrobe: DwarfWardrobe = level.get_node("DwarfWardrobe")
	_place_dwarf(dwarf, wardrobe.to_global(Vector3(0.0, 0.0, -1.1)), wardrobe.global_position)
	wardrobe.get_node("NextSkin").pressed.emit(1)
	wardrobe.get_node("CycleColor").pressed.emit(1)
	await _wait(0.2)
	TestCheck.expect(dwarf.skin_index == 1 and wardrobe.last_skin == 1, "vestiaire : nain en tenue Garagiste Soudeur")
	await _shot_from("3b_vestiaire_nains", wardrobe.to_global(Vector3(0.8, 1.4, -1.9)), wardrobe.to_global(Vector3(0.0, 1.0, 0.0)))

	# Scène Guitare QTE : lancement du solo et accord réussi
	var guitar: GuitarStage = level.get_node("Minigames/GuitarStage")
	guitar.get_node("StartButton").pressed.emit(1)
	await _wait(0.15)
	TestCheck.expect(guitar.playing, "guitare QTE : solo lancé")
	var expected_pad: PushButton = [guitar.get_node("PadUp"), guitar.get_node("PadDown"), guitar.get_node("PadLeft"), guitar.get_node("PadRight")][guitar.current_arrow]
	expected_pad.pressed.emit(1)
	await _wait(0.15)
	TestCheck.expect(guitar.score > 0 and guitar.combo == 1, "guitare QTE : accord réussi augmente le score et le combo")
	await _shot_from("3c_guitare_qte", guitar.to_global(Vector3(1.2, 1.8, -2.4)), guitar.to_global(Vector3(0.0, 0.9, 0.2)))
	guitar.get_node("StartButton").pressed.emit(1)

	# Punch-O-Mètre, Ferraille-Hoops et Forge Naine
	var punch: PunchMachine = level.get_node("Minigames/PunchMachine")
	punch.get_node("HitButton").pressed.emit(1)
	await _wait(0.2)
	punch.get_node("HitButton").pressed.emit(1)
	await _wait(0.1)
	TestCheck.expect(punch.last_score > 0, "punch-o-mètre : coup enregistré")

	var hoops: GarageHoops = level.get_node("Minigames/GarageHoops")
	hoops.get_node("ShootButton").pressed.emit(1)
	await _wait(0.1)
	TestCheck.expect(hoops.total_score >= 2, "ferraille-hoops : panier marqué")

	var anvil: AnvilGame = level.get_node("Minigames/AnvilGame")
	for _s: int in AnvilGame.STRIKES_PER_INGOT:
		anvil.get_node("StrikeButton").pressed.emit(1)
	await _wait(0.1)
	TestCheck.expect(anvil.forged_ingots == 1, "forge naine : lingot forgé en 3 coups")

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