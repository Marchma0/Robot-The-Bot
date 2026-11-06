class_name EmoteWheel
extends Control
## Roue d'emotes (affichage local uniquement, rien de réseau ici).
## Le nain l'ouvre quand on maintient B / LB, lui envoie les mouvements de souris
## ou le stick droit, et lit l'emote choisie au relâchement.

const RADIUS_OUTER: float = 190.0
const RADIUS_INNER: float = 55.0
## Distance (en pixels de souris accumulés) avant qu'une part soit choisie.
const MOUSE_DEADZONE: float = 25.0
const MOUSE_MAX: float = 120.0
const STICK_DEADZONE: float = 0.4
const COLOR_BG: Color = Color(0.1, 0.09, 0.08, 0.75)
const COLOR_HOVER: Color = Color(0.85, 0.55, 0.2, 0.9)
const COLOR_LINE: Color = Color(1.0, 0.9, 0.7, 0.35)

var _pointer: Vector2 = Vector2.ZERO
var _stick: Vector2 = Vector2.ZERO
var _selected: int = Emotes.NONE


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open() -> void:
	_pointer = Vector2.ZERO
	_stick = Vector2.ZERO
	_selected = Emotes.NONE
	visible = true
	queue_redraw()


## Ferme la roue et renvoie l'emote choisie (Emotes.NONE si aucune).
func close() -> int:
	visible = false
	return _selected


func is_open() -> bool:
	return visible


## Mouvement de souris en pixels (y vers le bas, comme à l'écran).
func push_mouse(motion: Vector2) -> void:
	_pointer = (_pointer + motion).limit_length(MOUSE_MAX)
	_update_selection()


## Stick droit (-1..1, y vers le bas).
func set_stick(stick: Vector2) -> void:
	_stick = stick
	_update_selection()


func _update_selection() -> void:
	var direction: Vector2 = Vector2.ZERO
	if _stick.length() > STICK_DEADZONE:
		direction = _stick
	elif _pointer.length() > MOUSE_DEADZONE:
		direction = _pointer
	var selected: int = Emotes.NONE
	if direction != Vector2.ZERO:
		selected = _sector_at(direction)
	if selected != _selected:
		_selected = selected
		queue_redraw()


## Part de la roue dans cette direction (0 = en haut, sens des aiguilles d'une montre).
func _sector_at(direction: Vector2) -> int:
	var step: float = TAU / Emotes.count()
	var angle: float = fposmod(atan2(direction.x, -direction.y) + step / 2.0, TAU)
	return int(angle / step) % Emotes.count()


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var n: int = Emotes.count()
	var step: float = TAU / n
	var font: Font = get_theme_default_font()
	for i: int in n:
		# Angle 0 en haut, sens des aiguilles d'une montre (y écran vers le bas).
		var a0: float = -PI / 2.0 + i * step - step / 2.0
		var points: PackedVector2Array = []
		for k: int in 13:
			var a: float = a0 + step * k / 12.0
			points.append(center + Vector2(cos(a), sin(a)) * RADIUS_OUTER)
		for k: int in range(12, -1, -1):
			var a: float = a0 + step * k / 12.0
			points.append(center + Vector2(cos(a), sin(a)) * RADIUS_INNER)
		draw_colored_polygon(points, COLOR_HOVER if i == _selected else COLOR_BG)
		draw_line(center + Vector2(cos(a0), sin(a0)) * RADIUS_INNER,
			center + Vector2(cos(a0), sin(a0)) * RADIUS_OUTER, COLOR_LINE, 2.0)
		var mid: float = a0 + step / 2.0
		var label: String = Emotes.LIST[i]["label"]
		var font_size: int = 17
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var pos: Vector2 = center + Vector2(cos(mid), sin(mid)) * (RADIUS_INNER + RADIUS_OUTER) / 2.0
		draw_string_outline(font, pos + Vector2(-text_size.x / 2.0, font_size / 3.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color.BLACK)
		draw_string(font, pos + Vector2(-text_size.x / 2.0, font_size / 3.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	# Centre : un point de visée cuivré (plus de consigne écrite).
	draw_circle(center, 6.0, Color("d9894a"))
