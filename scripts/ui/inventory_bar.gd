class_name InventoryBar
extends HBoxContainer
## Barre d'inventaire en bas de l'écran : une case par place (Inventory.SIZE), avec son numéro (touche 1 à 5),
## l'icône de l'objet et leur nombre s'il y en a plusieurs (fléchettes). La case choisie (objet en main)
## est surlignée et un peu plus haute.
## Purement local (interface du joueur) : elle affiche ce que le nain déduit de l'état synchronisé.

const SLOT_SIZE: float = 62.0
const ICON_SIZE: float = 42.0
const COLOR_SELECTED_BG: Color = Color(0.32, 0.2, 0.11, 0.9)
const COLOR_SELECTED_BORDER: Color = Color("f2b36b")
const COLOR_TEXT: Color = Color("f4e8cf")
const COLOR_OUTLINE: Color = Color(0.11, 0.08, 0.06, 1.0)
## Montée de la case choisie (px).
const SELECTED_LIFT: float = 8.0

var _key: String = ""
var _style: StyleBoxFlat
var _selected_style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 8)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_style = HintBar.make_style()
	_selected_style = HintBar.make_style()
	_selected_style.bg_color = COLOR_SELECTED_BG
	_selected_style.border_color = COLOR_SELECTED_BORDER
	_selected_style.set_border_width_all(3)
	show_slots([], 0)


## Affiche les cases (voir Inventory.slots_of) et surligne `selected`.
## Peut être appelé à chaque image : ne refait l'affichage que si quelque chose a changé.
func show_slots(slots: Array[Dictionary], selected: int) -> void:
	var parts: PackedStringArray = [str(selected)]
	for i: int in Inventory.SIZE:
		var slot: Dictionary = slots[i] if i < slots.size() else {}
		parts.append("" if slot.is_empty() else "%s:%d" % [slot["icon"], slot["count"]])
	var key: String = ",".join(parts)
	if key == _key:
		return
	_key = key
	for child: Node in get_children():
		child.queue_free()
	for i: int in Inventory.SIZE:
		add_child(_make_slot(i, slots[i] if i < slots.size() else {}, i == selected))


func _make_slot(index: int, slot: Dictionary, selected: bool) -> Control:
	# Un support qui garde la même hauteur pour toutes les cases ; la case choisie y monte un peu.
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE + SELECTED_LIFT)
	var panel: Panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(&"panel", _selected_style if selected else _style)
	panel.position = Vector2(0.0, 0.0 if selected else SELECTED_LIFT)
	panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	holder.add_child(panel)
	if not slot.is_empty():
		var icon: TextureRect = TextureRect.new()
		icon.texture = InputHint.get_icon(slot["icon"])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2.ONE * (SLOT_SIZE - ICON_SIZE) / 2.0
		icon.size = Vector2(ICON_SIZE, ICON_SIZE)
		if not selected:
			icon.modulate = Color(1.0, 1.0, 1.0, 0.75)
		panel.add_child(icon)
		if int(slot["count"]) > 1:
			var count: Label = _label("×%d" % slot["count"], 17)
			count.position = Vector2(SLOT_SIZE - 30.0, SLOT_SIZE - 26.0)
			panel.add_child(count)
	var number: Label = _label(str(index + 1), 14)
	number.position = Vector2(7.0, 2.0)
	number.modulate = Color(1.0, 1.0, 1.0, 1.0 if selected else 0.6)
	panel.add_child(number)
	return holder


func _label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", COLOR_TEXT)
	label.add_theme_color_override(&"font_outline_color", COLOR_OUTLINE)
	label.add_theme_constant_override(&"outline_size", 5)
	return label
