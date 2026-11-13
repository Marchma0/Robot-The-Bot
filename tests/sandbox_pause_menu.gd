extends Node
## Bac à sable du menu Échap : lance le jeu (scène principale) en hôte hors réseau, ouvre le menu avec Échap,
## vérifie que les touches du jeu sont coupées puis rendues, que les ombres se coupent et reviennent, et que
## les réglages sont gardés. Les réglages de test vont dans un fichier à part (ceux du joueur ne bougent pas).

const TEST_SETTINGS: String = "user://settings_test.cfg"
## Port à part : les scènes de test tournent plusieurs à la fois (le camp de test héberge sur le port par défaut).
const PORT: int = 7790

var _main: Node


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	var menu: PauseMenu = _main.get_node("PauseMenu") as PauseMenu
	menu.use_settings(GraphicsSettings.load_from(TEST_SETTINGS))
	await _wait(0.5)
	_press_pause()
	await _wait(0.2)
	TestCheck.expect(not menu.visible, "écran d'accueil : Échap n'ouvre pas le menu de partie")

	NetworkManager.host_game(PORT)
	await _wait(2.0)
	var jump_events: int = InputMap.action_get_events(&"jump").size()
	_press_pause()
	await _wait(0.2)
	TestCheck.expect(menu.visible and PauseMenu.is_open(), "en partie : Échap ouvre le menu")
	TestCheck.expect(InputMap.action_get_events(&"jump").is_empty() and InputMap.action_get_events(&"move_forward").is_empty(),
		"menu ouvert : les touches du jeu sont coupées")
	TestCheck.expect(not InputMap.action_get_events(&"pause").is_empty() and not InputMap.action_get_events(&"ui_accept").is_empty(),
		"menu ouvert : Échap et les touches de l'interface marchent toujours")
	TestCheck.expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "menu ouvert : la souris est libérée")
	await _shot("pause_menu_principal")

	# Ombres coupées puis remises : chaque lumière reprend son réglage d'origine.
	var settings: GraphicsSettings = menu.get_settings()
	var lights: Array[Light3D] = []
	for node: Node in _main.find_children("*", "Light3D", true, false):
		if (node as Light3D).shadow_enabled:
			lights.append(node as Light3D)
	TestCheck.expect(not lights.is_empty(), "des lumières font de l'ombre au départ (%d)" % lights.size())
	settings.shadows = GraphicsSettings.Shadows.OFF
	settings.apply(get_tree())
	TestCheck.expect(lights.all(func(light: Light3D) -> bool: return not light.shadow_enabled), "ombres désactivées : plus aucune ombre")
	settings.shadows = GraphicsSettings.Shadows.MEDIUM
	settings.render_scale = 0.75
	settings.fps_limit = 60
	settings.apply(get_tree())
	settings.save()
	TestCheck.expect(lights.all(func(light: Light3D) -> bool: return light.shadow_enabled), "ombres remises : chaque lumière retrouve la sienne")
	TestCheck.expect(is_equal_approx(get_tree().root.scaling_3d_scale, 0.75) and Engine.max_fps == 60,
		"résolution du rendu et images par seconde appliquées")
	var reloaded: GraphicsSettings = GraphicsSettings.load_from(TEST_SETTINGS)
	TestCheck.expect(reloaded.shadows == GraphicsSettings.Shadows.MEDIUM and is_equal_approx(reloaded.render_scale, 0.75)
		and reloaded.fps_limit == 60, "réglages gardés dans le fichier et relus")

	menu.open_options()
	await _shot("pause_menu_options")
	menu.close()
	_press_pause()
	await _wait(0.2)
	_press_pause()
	await _wait(0.2)
	TestCheck.expect(not menu.visible and not PauseMenu.is_open(), "Échap referme le menu")
	TestCheck.expect(InputMap.action_get_events(&"jump").size() == jump_events, "menu fermé : les touches du jeu reviennent")

	_press_pause()
	await _wait(0.2)
	NetworkManager.leave_game()
	await _wait(0.5)
	TestCheck.expect(not menu.visible and InputMap.action_get_events(&"jump").size() == jump_events,
		"partie quittée menu ouvert : menu fermé, touches rendues")
	Engine.max_fps = 0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	TestCheck.finish(get_tree())


func _press_pause() -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"pause"
	event.pressed = true
	Input.parse_input_event(event)
	var release: InputEventAction = InputEventAction.new()
	release.action = &"pause"
	Input.parse_input_event(release)


## Capture dans build/views/<nom>.png (ignorée sans fenêtre).
func _shot(file: String) -> void:
	await _wait(0.3)
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/%s.png" % file)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
