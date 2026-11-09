class_name HintPanel
extends VBoxContainer
## Petit panneau en haut à gauche avec les touches d'un poste (assis au grappin / à la foreuse,
## ou un joystick en main) : une ligne « touche → icône » par action.
## Ouvert en arrivant au poste, il se replie tout seul au bout de AUTO_COLLAPSE secondes en un petit onglet
## « Tab ? » ; Tab (RB à la manette) le rouvre ou le replie.
## Purement local (interface du joueur), rien sur le réseau.

## Temps (s) pendant lequel le panneau reste ouvert en arrivant à un poste.
const AUTO_COLLAPSE: float = 5.0

var collapsed: bool = false

var _key: String = ""
var _open_time: float = 0.0
var _panel: PanelContainer
var _rows: VBoxContainer
var _tab_chip: PanelContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 6)
	var style: StyleBoxFlat = HintBar.make_style()
	style.set_content_margin_all(10.0)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override(&"panel", style)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 8)
	_panel.add_child(column)
	# En-tête : la touche qui replie le panneau.
	var header: HBoxContainer = HintBar.make_row(InputHint.make(&"toggle_help", &"help"))
	header.modulate = Color(1.0, 1.0, 1.0, 0.6)
	column.add_child(header)
	var line: ColorRect = ColorRect.new()
	line.color = HintBar.COLOR_BORDER
	line.custom_minimum_size = Vector2(0.0, 2.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(line)
	_rows = VBoxContainer.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override(&"separation", 8)
	column.add_child(_rows)
	add_child(_panel)

	_tab_chip = PanelContainer.new()
	_tab_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_chip.add_theme_stylebox_override(&"panel", HintBar.make_style())
	_tab_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_tab_chip.add_child(HintBar.make_row(InputHint.make(&"toggle_help", &"help")))
	add_child(_tab_chip)

	visible = false
	_apply_collapsed()


func _process(delta: float) -> void:
	if not visible or collapsed or _open_time <= 0.0:
		return
	_open_time -= delta
	if _open_time <= 0.0:
		collapsed = true
		_apply_collapsed()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"toggle_help"):
		collapsed = not collapsed
		_open_time = 0.0   # rouvert à la main : il reste ouvert
		_apply_collapsed()
		get_viewport().set_input_as_handled()


## Affiche les touches de ce poste (liste vide = panneau masqué).
func show_hints(hints: Array[InputHint]) -> void:
	var key: String = InputHint.key_of(hints)
	if key == _key:
		return
	_key = key
	for child: Node in _rows.get_children():
		child.queue_free()
	for hint: InputHint in hints:
		_rows.add_child(HintBar.make_row(hint))
	var arriving: bool = not visible and not hints.is_empty()
	visible = not hints.is_empty()
	if arriving:
		# On arrive à un poste : le panneau s'ouvre, puis se replie tout seul.
		collapsed = false
		_open_time = AUTO_COLLAPSE
		_apply_collapsed()


func _apply_collapsed() -> void:
	_panel.visible = not collapsed
	_tab_chip.visible = collapsed
