class_name PauseMenu
extends CanvasLayer
## Menu Échap (action « pause », Start à la manette) : reprendre, options graphiques, inviter des amis (Steam),
## quitter la partie, quitter le jeu. Depuis l'écran d'accueil, il s'ouvre directement sur les options.
##
## La partie ne s'arrête pas (jeu en ligne) : menu ouvert, les touches du jeu sont coupées (retirées de la
## Input Map, remises à la fermeture) et la souris est libérée. Les réglages sont dans `GraphicsSettings`.
## Réseau : rien, purement local.

## Le menu vient de se fermer.
signal closed

const PANEL_WIDTH: float = 480.0
const TITLE_SIZE: int = 34

## Vrai tant que le menu est ouvert (chez ce joueur).
static var _is_open: bool = false

var _settings: GraphicsSettings
## Touches des actions du jeu, retirées pendant que le menu est ouvert.
var _saved_events: Dictionary[StringName, Array] = {}
## Ouvert depuis l'écran d'accueil (pas de partie) : seulement les options.
var _from_title: bool = false
var _main_page: VBoxContainer
var _options_page: VBoxContainer
var _invite_button: Button
var _scale_value: Label


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_settings = GraphicsSettings.current()
	_settings.apply(get_tree())
	get_tree().node_added.connect(_on_node_added)
	NetworkManager.session_ended.connect(func(_reason: String) -> void: close())
	_build()
	visible = false


func _exit_tree() -> void:
	_suspend_game_input(false)
	_is_open = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if visible:
		if _options_page.visible and not _from_title:
			_show_page(_main_page)
		else:
			close()
		get_viewport().set_input_as_handled()
	elif NetworkManager.is_online():
		open()
		get_viewport().set_input_as_handled()


## Vrai si le menu est ouvert chez ce joueur.
static func is_open() -> bool:
	return _is_open


## En partie : ouvre le menu (page principale).
func open() -> void:
	_from_title = false
	visible = true
	_is_open = true
	_invite_button.visible = NetworkManager.is_steam_session()
	_suspend_game_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_page(_main_page)


## Écran d'accueil : ouvre directement les options.
func open_options() -> void:
	_from_title = true
	visible = true
	_is_open = true
	_show_page(_options_page)


func close() -> void:
	if not visible:
		return
	visible = false
	_is_open = false
	_suspend_game_input(false)
	if NetworkManager.is_online() and not _from_title:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_from_title = false
	closed.emit()


## Les réglages appliqués par ce menu (pour les tests).
func get_settings() -> GraphicsSettings:
	return _settings


## Remplace les réglages (tests : un fichier à part, pour ne pas toucher à ceux du joueur).
func use_settings(settings: GraphicsSettings) -> void:
	_settings = settings
	_settings.apply(get_tree())
	_refresh_options()


## Coupe (ou remet) les touches de toutes les actions du jeu, sauf « pause » et celles de l'interface (ui_*).
func _suspend_game_input(suspend: bool) -> void:
	if suspend:
		if not _saved_events.is_empty():
			return
		for action: StringName in InputMap.get_actions():
			if action == &"pause" or String(action).begins_with("ui_"):
				continue
			_saved_events[action] = InputMap.action_get_events(action)
			Input.action_release(action)
			InputMap.action_erase_events(action)
	else:
		for action: StringName in _saved_events:
			for event: InputEvent in _saved_events[action]:
				InputMap.action_add_event(action, event)
		_saved_events.clear()


func _on_node_added(node: Node) -> void:
	if node is Light3D:
		_settings.apply_to_light(node as Light3D)


func _show_page(page: Control) -> void:
	_main_page.visible = page == _main_page
	_options_page.visible = page == _options_page
	var first: Control = page.find_child("Button*", true, false) as Control
	if page == _options_page:
		_refresh_options()
		first = page.find_child("Fullscreen", true, false) as Control
	if first != null:
		first.grab_focus.call_deferred()


## Un réglage a changé : on l'applique tout de suite et on le garde.
func _changed() -> void:
	_settings.apply(get_tree())
	_settings.save()


# --- Construction de l'interface (en code : deux pages simples, faciles à compléter) ---

func _build() -> void:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP   # les clics ne passent pas au jeu
	root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # textes déjà passés par tr()
	add_child(root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.08, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var pages: VBoxContainer = VBoxContainer.new()
	margin.add_child(pages)
	_main_page = _build_main_page()
	_options_page = _build_options_page()
	pages.add_child(_main_page)
	pages.add_child(_options_page)


func _build_main_page() -> VBoxContainer:
	var page: VBoxContainer = _page(tr("Pause"))
	_add_button(page, tr("Reprendre"), close)
	_add_button(page, tr("Options"), func() -> void: _show_page(_options_page))
	_invite_button = _add_button(page, tr("Inviter des amis"), NetworkManager.invite_friends)
	_add_button(page, tr("Quitter la partie"), _leave_game)
	_add_button(page, tr("Quitter le jeu"), _quit_game)
	return page


func _build_options_page() -> VBoxContainer:
	var page: VBoxContainer = _page(tr("Options graphiques"))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	page.add_child(grid)

	_add_row(grid, tr("Plein écran"), _check("Fullscreen", func(on: bool) -> void:
		_settings.fullscreen = on
		_changed()))
	_add_row(grid, tr("Synchronisation verticale"), _check("Vsync", func(on: bool) -> void:
		_settings.vsync = on
		_changed()))
	var fps_names: Array[String] = []
	for limit: int in GraphicsSettings.FPS_LIMITS:
		fps_names.append(str(limit) if limit > 0 else tr("Sans limite"))
	_add_row(grid, tr("Images par seconde max"), _choice("FpsLimit", fps_names, func(index: int) -> void:
		_settings.fps_limit = GraphicsSettings.FPS_LIMITS[index]
		_changed()))

	var scale_box: HBoxContainer = HBoxContainer.new()
	scale_box.name = "RenderScale"
	var slider: HSlider = HSlider.new()
	slider.name = "Slider"
	slider.min_value = GraphicsSettings.RENDER_SCALE_MIN * 100.0
	slider.max_value = 100.0
	slider.step = 5.0
	slider.custom_minimum_size = Vector2(150.0, 0.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_scale_value = Label.new()
	_scale_value.custom_minimum_size = Vector2(56.0, 0.0)
	scale_box.add_child(slider)
	scale_box.add_child(_scale_value)
	slider.value_changed.connect(func(value: float) -> void:
		_scale_value.text = tr("%d %%") % int(value)
		if not is_equal_approx(_settings.render_scale, value / 100.0):
			_settings.render_scale = value / 100.0
			_changed())
	_add_row(grid, tr("Résolution du rendu"), scale_box)

	_add_row(grid, tr("Ombres"), _choice("Shadows",
		[tr("Désactivées"), tr("Basses"), tr("Moyennes"), tr("Hautes")], func(index: int) -> void:
			_settings.shadows = index as GraphicsSettings.Shadows
			_changed()))
	_add_row(grid, tr("Anticrénelage"), _choice("Antialiasing",
		[tr("Aucun"), "FXAA", "MSAA 2x", "MSAA 4x"], func(index: int) -> void:
			_settings.antialiasing = index as GraphicsSettings.Antialiasing
			_changed()))

	_add_button(page, tr("Retour"), func() -> void:
		if _from_title:
			close()
		else:
			_show_page(_main_page))
	return page


## Remet les commandes de la page des options sur les réglages actuels (sans rien relancer).
func _refresh_options() -> void:
	if _options_page == null:
		return
	(_options_page.find_child("Fullscreen", true, false) as CheckButton).set_pressed_no_signal(_settings.fullscreen)
	(_options_page.find_child("Vsync", true, false) as CheckButton).set_pressed_no_signal(_settings.vsync)
	var fps_index: int = GraphicsSettings.FPS_LIMITS.find(_settings.fps_limit)
	(_options_page.find_child("FpsLimit", true, false) as OptionButton).select(fps_index if fps_index >= 0 else GraphicsSettings.FPS_LIMITS.size() - 1)
	(_options_page.find_child("Slider", true, false) as HSlider).set_value_no_signal(_settings.render_scale * 100.0)
	_scale_value.text = tr("%d %%") % roundi(_settings.render_scale * 100.0)
	(_options_page.find_child("Shadows", true, false) as OptionButton).select(_settings.shadows)
	(_options_page.find_child("Antialiasing", true, false) as OptionButton).select(_settings.antialiasing)


func _page(title_text: String) -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	var title: Label = Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	page.add_child(title)
	return page


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.name = "Button%d" % parent.get_child_count()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _add_row(grid: GridContainer, label_text: String, control: Control) -> void:
	var label: Label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)
	grid.add_child(control)


func _check(node_name: String, on_toggled: Callable) -> CheckButton:
	var check: CheckButton = CheckButton.new()
	check.name = node_name
	check.toggled.connect(on_toggled)
	return check


func _choice(node_name: String, items: Array, on_selected: Callable) -> OptionButton:
	var choice: OptionButton = OptionButton.new()
	choice.name = node_name
	for item: Variant in items:
		choice.add_item(str(item))
	choice.item_selected.connect(on_selected)
	return choice


func _leave_game() -> void:
	close()
	NetworkManager.leave_game()


func _quit_game() -> void:
	if NetworkManager.is_online():
		NetworkManager.leave_game()
	get_tree().quit()
