class_name InputGlyph
extends Control
## Dessine la touche (clavier / souris) ou le bouton de manette d'une action de la Input Map.
## Lu directement dans la Input Map : changer une touche dans project.godot change le dessin.
## Le lettrage des touches suit la disposition du clavier du joueur (AZERTY : Z, pas W).
## Bascule clavier / manette selon le dernier appareil utilisé (`use_gamepad`).

const HEIGHT: float = 34.0
const GAP: float = 4.0
const COLOR_FACE: Color = Color("f4e8cf")
const COLOR_SIDE: Color = Color("8c6a48")
const COLOR_INK: Color = Color("2b1d14")
const COLOR_COPPER: Color = Color("d9894a")
const COLOR_PAD: Color = Color("3a3631")
## Couleurs des boutons A, B, X, Y (manette type Xbox).
const FACE_BUTTONS: Array[Dictionary] = [
	{"text": "A", "color": Color("5bb24a")},
	{"text": "B", "color": Color("d9493c")},
	{"text": "X", "color": Color("3b82d1")},
	{"text": "Y", "color": Color("e8b923")},
]
const PAD_BUTTON_NAMES: Dictionary[int, String] = {
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
}
const KEY_NAMES: Dictionary[String, String] = {
	"Space": "Espace", "Escape": "Échap", "Ctrl": "Ctrl", "Shift": "Maj", "Enter": "Entrée",
}

## Vrai si le joueur utilise la manette (dernier appareil touché). Partagé par toutes les icônes.
static var use_gamepad: bool = false

var action: StringName = &"":
	set(value):
		action = value
		_rebuild()

## Morceaux à dessiner, de gauche à droite : {kind, text, color, width}.
var _parts: Array[Dictionary] = []
var _built_for_gamepad: bool = false


## À appeler avec chaque événement d'entrée (fait par HintBar) pour suivre l'appareil utilisé.
static func track_device(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		use_gamepad = true
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		use_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		use_gamepad = false
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 4.0:
		use_gamepad = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rebuild()


func _process(_delta: float) -> void:
	if use_gamepad != _built_for_gamepad:
		_rebuild()


func _draw() -> void:
	var x: float = 0.0
	var font: Font = get_theme_default_font()
	for part: Dictionary in _parts:
		var width: float = part["width"]
		var rect: Rect2 = Rect2(x, 0.0, width, HEIGHT)
		match part["kind"]:
			&"key":
				_draw_key(rect, part["text"], font)
			&"mouse":
				_draw_mouse(rect, part["text"])
			&"face":
				_draw_face_button(rect, part["text"], part["color"], font)
			&"pill":
				_draw_pill(rect, part["text"], font)
			&"stick":
				_draw_stick(rect, part["text"], font)
		x += width + GAP


func _rebuild() -> void:
	_built_for_gamepad = use_gamepad
	_parts.clear()
	if action == InputHint.LOOK:
		_parts.append(_part(&"stick", "R", HEIGHT) if use_gamepad else _part(&"mouse", "move", 26.0))
	elif action == InputHint.MOVE_VERTICAL:
		if use_gamepad:
			_parts.append(_part(&"stick", "L", HEIGHT))
		else:
			_add_event_part(&"move_forward")
			_add_event_part(&"move_back")
	elif action != &"":
		_add_event_part(action)
	var width: float = 0.0
	for part: Dictionary in _parts:
		width += float(part["width"]) + GAP
	custom_minimum_size = Vector2(maxf(width - GAP, 0.0), HEIGHT)
	update_minimum_size()
	queue_redraw()


## Ajoute le dessin de la première touche de `act` qui correspond à l'appareil utilisé.
func _add_event_part(act: StringName) -> void:
	if not InputMap.has_action(act):
		return
	for event: InputEvent in InputMap.action_get_events(act):
		var part: Dictionary = _part_for_event(event)
		if not part.is_empty():
			_parts.append(part)
			return


func _part_for_event(event: InputEvent) -> Dictionary:
	if use_gamepad:
		if event is InputEventJoypadButton:
			var index: int = (event as InputEventJoypadButton).button_index
			if index < FACE_BUTTONS.size():
				return _part(&"face", FACE_BUTTONS[index]["text"], HEIGHT, FACE_BUTTONS[index]["color"])
			return _pill(PAD_BUTTON_NAMES.get(index, "?"))
		if event is InputEventJoypadMotion:
			var axis: int = (event as InputEventJoypadMotion).axis
			if axis == JOY_AXIS_TRIGGER_RIGHT:
				return _pill("RT")
			if axis == JOY_AXIS_TRIGGER_LEFT:
				return _pill("LT")
			return _part(&"stick", "L" if axis <= JOY_AXIS_LEFT_Y else "R", HEIGHT)
		return {}
	if event is InputEventMouseButton:
		var button: int = (event as InputEventMouseButton).button_index
		return _part(&"mouse", "right" if button == MOUSE_BUTTON_RIGHT else "left", 26.0)
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		var code: Key = key.keycode
		if key.physical_keycode != KEY_NONE:
			code = DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
		var text: String = OS.get_keycode_string(code)
		text = tr(KEY_NAMES.get(text, text))
		var font: Font = get_theme_default_font()
		var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _key_font_size(text)).x
		return _part(&"key", text, maxf(HEIGHT, text_width + 18.0))
	return {}


func _pill(text: String) -> Dictionary:
	return _part(&"pill", text, 44.0)


func _part(kind: StringName, text: String, width: float, color: Color = Color.WHITE) -> Dictionary:
	return {"kind": kind, "text": text, "width": width, "color": color}


func _key_font_size(text: String) -> int:
	return 20 if text.length() <= 2 else 15


## Touche de clavier : dessus clair, tranche foncée en dessous (effet de relief).
func _draw_key(rect: Rect2, text: String, font: Font) -> void:
	_draw_round(rect, COLOR_SIDE, 7)
	_draw_round(Rect2(rect.position, rect.size - Vector2(0.0, 5.0)), COLOR_FACE, 7, COLOR_INK, 2)
	var size: int = _key_font_size(text)
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var baseline: float = (HEIGHT - 5.0) / 2.0 + size * 0.36
	draw_string(font, Vector2(rect.position.x + (rect.size.x - text_width) / 2.0, baseline), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, COLOR_INK)


## Souris : bouton gauche / droit en cuivre, ou petites flèches pour « bouger la souris ».
func _draw_mouse(rect: Rect2, which: String) -> void:
	var body: Rect2 = Rect2(rect.position + Vector2(1.0, 0.0), Vector2(rect.size.x - 2.0, HEIGHT))
	_draw_round(body, COLOR_FACE, 11, COLOR_INK, 2)
	var top: float = body.position.y + 13.0
	var mid: float = body.get_center().x
	if which == "left" or which == "right":
		var half: Rect2 = Rect2(body.position.x + 2.0 if which == "left" else mid, body.position.y + 2.0, body.size.x / 2.0 - 2.0, 11.0)
		_draw_round(half, COLOR_COPPER, 8)
	draw_line(Vector2(body.position.x + 1.0, top), Vector2(body.end.x - 1.0, top), COLOR_INK, 2.0)
	draw_line(Vector2(mid, body.position.y + 1.0), Vector2(mid, top), COLOR_INK, 2.0)
	if which == "move":
		var c: Vector2 = Vector2(mid, top + 10.0)
		for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT]:
			var tip: Vector2 = c + dir * 7.0
			draw_colored_polygon(PackedVector2Array([tip, tip - dir * 5.0 + Vector2(0, 4), tip - dir * 5.0 - Vector2(0, 4)]), COLOR_COPPER)


func _draw_face_button(rect: Rect2, text: String, color: Color, font: Font) -> void:
	var center: Vector2 = rect.get_center()
	draw_circle(center, HEIGHT / 2.0, COLOR_INK)
	draw_circle(center, HEIGHT / 2.0 - 2.5, color)
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string_outline(font, center + Vector2(-text_width / 2.0, 6.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, COLOR_INK)
	draw_string(font, center + Vector2(-text_width / 2.0, 6.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)


## Gâchette, bouton d'épaule, View / Menu : pastille grise avec le nom.
func _draw_pill(rect: Rect2, text: String, font: Font) -> void:
	_draw_round(rect, COLOR_PAD, 12, COLOR_INK, 2)
	var size: int = 15
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, rect.get_center() + Vector2(-text_width / 2.0, 5.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, COLOR_FACE)


## Stick : rond gris avec sa lettre et quatre petites flèches.
func _draw_stick(rect: Rect2, text: String, font: Font) -> void:
	var center: Vector2 = rect.get_center()
	draw_circle(center, HEIGHT / 2.0, COLOR_INK)
	draw_circle(center, HEIGHT / 2.0 - 2.5, COLOR_PAD)
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var tip: Vector2 = center + dir * 13.0
		var side: Vector2 = Vector2(dir.y, dir.x) * 3.5
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 4.0 + side, tip - dir * 4.0 - side]), COLOR_COPPER)
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, center + Vector2(-text_width / 2.0, 5.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, COLOR_FACE)


func _draw_round(rect: Rect2, color: Color, radius: int, border: Color = Color.TRANSPARENT, border_width: int = 0) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	if border_width > 0:
		box.border_color = border
		box.set_border_width_all(border_width)
	draw_style_box(box, rect)
