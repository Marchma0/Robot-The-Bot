class_name HintBar
extends HBoxContainer
## Petite rangée « touche → icône », discrète : sans fond, en fondu, posée à droite du point de visée
## (PlayerHud) ou en haut de l'écran (code du lobby). Chaque indice : le dessin de la touche / du bouton
## (InputGlyph) puis l'icône de l'action. Les gestes évidents sont déjà retirés (InputHint.shown).

const ICON_SIZE: float = 34.0
const COLOR_BG: Color = Color(0.11, 0.08, 0.06, 0.72)
const COLOR_BORDER: Color = Color("b87440")
## Opacité une fois affichée, et durée du fondu (s).
const SHOWN_ALPHA: float = 0.85
const FADE_TIME: float = 0.15

var _key: String = ""
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 12)


func _input(event: InputEvent) -> void:
	InputGlyph.track_device(event)


## Affiche ces indices (liste vide = rien), en fondu.
func show_hints(hints: Array[InputHint]) -> void:
	var key: String = InputHint.key_of(hints)
	if key == _key:
		return
	_key = key
	for child: Node in get_children():
		child.queue_free()
	for hint: InputHint in hints:
		add_child(make_row(hint))
	if _tween != null:
		_tween.kill()
	if hints.is_empty():
		modulate.a = 0.0
		return
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, ^"modulate:a", SHOWN_ALPHA, FADE_TIME)


## Efface la rangée en douceur au bout de `delay` secondes (ex. « Échap → quitter » en début de partie).
func fade_out_after(delay: float) -> void:
	if _tween != null:
		_tween.kill()
	modulate.a = SHOWN_ALPHA
	_tween = create_tween()
	_tween.tween_interval(delay)
	_tween.tween_property(self, ^"modulate:a", 0.0, 0.6)


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


## Style du panneau des postes et des cases d'inventaire : fond brun translucide, liseré cuivre.
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
