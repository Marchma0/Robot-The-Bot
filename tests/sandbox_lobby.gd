extends Node
## Bac à sable M12 : lance le jeu (scène principale) en hôte hors réseau, puis joue tout le parcours :
## apparition au camp, vues du camp, monter à bord, tirer le levier du terminal (compte à rebours),
## départ en mission (terrain de test), puis bouton « retour au camp ». Captures : build/views/lobby_*.png.

@export var quit_when_done: bool = true

var _main: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	await _wait(1.0)
	NetworkManager.host_game()
	await _wait(2.0)
	var director: MissionDirector = _main.get_node("World/MissionDirector")
	var mecha: Node3D = _main.get_node("World/Mecha")
	var dwarf: Node3D = mecha.get_node("Players").get_child(0) as Node3D
	print("Niveau : %s, nain en %s, à bord %s" % [director.current_level, dwarf.global_position, director.count_aboard()])
	await _shot("1_apparition")
	# Vue d'ensemble du camp, de haut
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	cam.global_position = Vector3(16.0, 14.0, -22.0)
	cam.look_at(Vector3(0.0, 2.0, 4.0), Vector3.UP)
	cam.current = true
	await _shot("2_vue_ensemble")
	cam.global_position = Vector3(-6.0, 9.0, 22.0)
	cam.look_at(Vector3(0.0, 3.0, -6.0), Vector3.UP)
	await _shot("3_vue_arriere")
	cam.current = false
	# Tirer le levier depuis le terminal : la mission s'arme
	var lever: Lever = director.get_level().get_node("MissionTerminal/Lever")
	var terminal: MissionTerminal = director.get_level().get_node("MissionTerminal")
	dwarf.global_position = terminal.global_position + Vector3(0.0, 0.1, -1.0)
	await _wait(0.3)
	lever.value = Vector2(0.0, 1.0)
	await _wait(0.3)
	lever.value = Vector2.ZERO
	print("Levier tiré : compte à rebours %.1f s" % terminal.countdown)
	cam.current = true
	cam.global_position = terminal.global_position + Vector3(0.3, 1.7, -1.6)
	cam.look_at(terminal.global_position + Vector3(0.0, 1.2, 0.0), Vector3.UP)
	await _shot("4_terminal_arme")
	cam.current = false
	# Le nain monte à bord : la mission part toute seule
	dwarf.position = (mecha.get_node("SpawnPoints").get_child(0) as Node3D).position
	await _wait(2.5)
	print("Après montée à bord : niveau %s, robot en %s" % [director.current_level, mecha.global_position])
	await _shot("5_mission")
	# Bouton « retour au camp »
	var button: PushButton = mecha.get_node("Controls/ReturnToCamp")
	print("Bouton de retour visible : %s" % button.visible)
	button.pressed.emit(1)
	await _wait(2.5)
	print("Après retour : niveau %s, robot en %s, bouton visible %s" % [director.current_level, mecha.global_position, button.visible])
	await _shot("6_retour_camp")
	if quit_when_done:
		get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await _wait(0.4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/views/lobby_%s.png" % shot_name)
