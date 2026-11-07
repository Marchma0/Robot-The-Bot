class_name HintBar
extends HBoxContainer
## Rangée de pastilles « touche → icône » (remplace les textes d'aide à l'écran).
## Chaque pastille : le dessin de la touche / du bouton (InputGlyph) puis l'icône de l'action.

const ICON_SIZE: float = 34.0
const COLOR_BG: Color = Color(0.11, 0.08, 0.06, 0.72)
const COLOR_BORDER: Color = Color("b87440")

var _key: String = ""
var _chip_style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 10)
	_chip_style = make_style()


func _input(event: InputEvent) -> void:
	InputGlyph.track_device(event)


## Affiche ces indices (liste vide = rien).
func show_hints(hints: Array[InputHint]) -> void:
	var key: String = InputHint.key_of(hints)
	if key == _key:
		return
	_key = key
	for child: Node in get_children():
		child.queue_free()
	for hint: InputHint in hints:
		add_child(_make_chip(hint))


func _make_chip(hint: InputHint) -> Control:
	var chip: PanelContainer = PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override(&"panel", _chip_style)
	chip.add_child(make_row(hint))
	return chip


## Une ligne « dessin de la touche → icône de l'action » (sert aussi au panneau des postes).
static func make_row(hint: InputHint) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if hint.action != &"":
		var glyph: InputGlyph = InputGlyph.new()
		glyph.action = hint.action
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
	var icon: TextureRect = TextureRect.new()
	icon.texture = InputHint.get_icon(hint.icon)
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	return row


## Style des pastilles et du panneau : fond brun translucide, liseré cuivre.
static func make_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(7.0)
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	style.anti_aliasing = true
	return style
