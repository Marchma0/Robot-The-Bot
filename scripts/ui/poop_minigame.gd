class_name PoopMinigame
extends Control
## Mini-jeu « Poussée » des toilettes (joueur local uniquement, affiché sur le côté de l'écran).
## Une icône de caca monte et descend dans une jauge verticale ; le joueur garde sa zone
## (maintenir clic / RT pour la faire monter, elle retombe toute seule) sur le caca.
## La barre de progression se remplit quand le caca est dans la zone, se vide sinon.
## Pleine : réussi. Vide : raté. Version dorée (légendaire) : plus rapide, zone plus petite.

## Fin de partie : réussie ou non.
signal finished(success: bool)

const GAUGE_HEIGHT: float = 320.0
const GAUGE_WIDTH: float = 46.0
const BAR_WIDTH: float = 14.0
const COLOR_FRAME: Color = Color(0.78, 0.45, 0.22)
const COLOR_BACK: Color = Color(0.12, 0.1, 0.09, 0.9)
const COLOR_ZONE: Color = Color(0.45, 0.85, 0.35, 0.55)
const COLOR_POOP: Color = Color(0.4, 0.24, 0.1)
const COLOR_GOLD: Color = Color(1.0, 0.8, 0.2)

var _active: bool = false
var _golden: bool = false
var _zone_pos: float = 0.0        # bas de la zone, 0..1
var _zone_speed: float = 0.0
var _zone_size: float = 0.28
var _target: float = 0.5          # position du caca, 0..1
var _target_speed: float = 0.0
var _target_goal: float = 0.5
var _target_wait: float = 0.0
var _progress: float = 0.3
var _result_text: String = ""
var _result_time: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func start(golden: bool) -> void:
	_golden = golden
	_active = true
	visible = true
	_zone_pos = 0.0
	_zone_speed = 0.0
	_zone_size = 0.22 if golden else 0.28
	_target = 0.5
	_target_speed = 0.0
	_target_goal = randf()
	_target_wait = 0.0
	_progress = 0.3
	_result_time = 0.0
	_time = 0.0


func stop() -> void:
	_active = false
	visible = false
	_result_time = 0.0


func is_active() -> bool:
	return _active


func _process(delta: float) -> void:
	_time += delta
	if _result_time > 0.0:
		_result_time -= delta
		if _result_time <= 0.0 and not _active:
			visible = false
	if _active:
		_update_zone(delta)
		_update_target(delta)
		var inside: bool = _target >= _zone_pos and _target <= _zone_pos + _zone_size
		_progress += (0.32 if inside else (-0.27 if _golden else -0.24)) * delta
		if _progress >= 1.0:
			_finish(true)
		elif _progress <= 0.0:
			_finish(false)
	queue_redraw()


func _update_zone(delta: float) -> void:
	# Maintenir clic / RT : la zone monte ; relâcher : elle retombe (avec un petit rebond en bas).
	var push: float = 2.6 if Input.is_action_pressed("grab") else -2.2
	_zone_speed = clampf(_zone_speed + push * delta, -1.4, 1.4)
	_zone_pos += _zone_speed * delta
	if _zone_pos < 0.0:
		_zone_pos = 0.0
		_zone_speed = -_zone_speed * 0.35
	elif _zone_pos > 1.0 - _zone_size:
		_zone_pos = 1.0 - _zone_size
		_zone_speed = 0.0


func _update_target(delta: float) -> void:
	# Le caca file vers un but au hasard, s'arrête un peu, repart (plus vif quand il est doré).
	var nervous: float = 1.35 if _golden else 1.0
	if _target_wait > 0.0:
		_target_wait -= delta
		_target_speed = move_toward(_target_speed, 0.0, 3.0 * delta)
	else:
		var wanted: float = clampf((_target_goal - _target) * 3.0, -0.9, 0.9) * nervous
		_target_speed = move_toward(_target_speed, wanted, 2.5 * nervous * delta)
		if absf(_target_goal - _target) < 0.03:
			_target_goal = randf_range(0.05, 0.95)
			_target_wait = randf_range(0.0, 0.7) / nervous
	_target = clampf(_target + _target_speed * delta, 0.02, 0.98)


func _finish(success: bool) -> void:
	_active = false
	if success:
		_result_text = "CACA LÉGENDAIRE !" if _golden else "Plop !"
	else:
		_result_text = "… rien."
	_result_time = 1.6
	finished.emit(success)


func _draw() -> void:
	var origin: Vector2 = Vector2(size.x - 270.0, (size.y - GAUGE_HEIGHT) / 2.0 + 30.0)
	# Tremblement quand la barre est presque vide.
	if _active and _progress < 0.25:
		var shake: float = (0.25 - _progress) * 24.0
		origin += Vector2(sin(_time * 61.0), cos(_time * 47.0)) * shake
	var title: String = "LÉGENDAIRE !" if _golden else "Pousse !"
	var font: Font = get_theme_default_font()
	var title_color: Color = COLOR_GOLD if _golden else Color.WHITE
	draw_string_outline(font, origin + Vector2(-30.0, -14.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color.BLACK)
	draw_string(font, origin + Vector2(-30.0, -14.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, title_color)
	# Jauge : tuyau de cuivre riveté
	var gauge: Rect2 = Rect2(origin, Vector2(GAUGE_WIDTH, GAUGE_HEIGHT))
	draw_rect(gauge.grow(6.0), COLOR_FRAME)
	draw_rect(gauge, COLOR_BACK)
	for k: int in 6:
		var y: float = origin.y - 3.0 + k * (GAUGE_HEIGHT + 6.0) / 5.0
		draw_circle(Vector2(origin.x - 3.0, y), 2.5, Color(0.35, 0.2, 0.1))
		draw_circle(Vector2(origin.x + GAUGE_WIDTH + 3.0, y), 2.5, Color(0.35, 0.2, 0.1))
	# Zone du joueur
	var zone_top: float = origin.y + (1.0 - _zone_pos - _zone_size) * GAUGE_HEIGHT
	draw_rect(Rect2(origin.x + 3.0, zone_top, GAUGE_WIDTH - 6.0, _zone_size * GAUGE_HEIGHT), COLOR_ZONE)
	# Caca (trois boules empilées), doré s'il est légendaire
	var poop_color: Color = COLOR_GOLD if _golden else COLOR_POOP
	var c: Vector2 = Vector2(origin.x + GAUGE_WIDTH / 2.0, origin.y + (1.0 - _target) * GAUGE_HEIGHT)
	draw_circle(c + Vector2(0, 6), 11.0, poop_color)
	draw_circle(c + Vector2(1, -3), 8.0, poop_color)
	draw_circle(c + Vector2(-1, -10), 5.0, poop_color)
	if _golden:
		var sparkle: float = 0.5 + 0.5 * sin(_time * 9.0)
		draw_circle(c + Vector2(8, -12), 2.5 * sparkle, Color.WHITE)
		draw_circle(c + Vector2(-9, 4), 2.0 * (1.0 - sparkle), Color.WHITE)
	# Barre de progression
	var bar: Rect2 = Rect2(origin + Vector2(GAUGE_WIDTH + 14.0, 0.0), Vector2(BAR_WIDTH, GAUGE_HEIGHT))
	draw_rect(bar.grow(3.0), COLOR_FRAME)
	draw_rect(bar, COLOR_BACK)
	var filled: float = clampf(_progress, 0.0, 1.0) * GAUGE_HEIGHT
	var bar_color: Color = Color(0.9, 0.25, 0.15).lerp(Color(0.4, 0.9, 0.3), clampf(_progress, 0.0, 1.0))
	draw_rect(Rect2(bar.position.x, bar.end.y - filled, BAR_WIDTH, filled), bar_color)
	# Résultat
	if _result_time > 0.0:
		var result_color: Color = COLOR_GOLD if _golden and _result_text.begins_with("CACA") else Color.WHITE
		var pos: Vector2 = Vector2(size.x / 2.0 - 120.0, size.y * 0.35)
		draw_string_outline(font, pos, _result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 8, Color.BLACK)
		draw_string(font, pos, _result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, result_color)
