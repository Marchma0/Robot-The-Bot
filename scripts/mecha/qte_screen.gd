class_name QteScreen
extends Control
## Écran du QTE d'une console des jambes, façon « Just Dance » : les flèches de la séquence défilent de
## droite à gauche jusqu'à la cible. Celles du pilote de cette console sont grandes et cyan, celles de
## l'autre pilote plus petites et violettes ; l'étape joystick (les deux ensemble) est un joystick doré. Jauge
## d'avancement en bas, flash rouge à chaque erreur (ou QTE qui traîne), « Bravo ! » à la fin. Au repos, « Prêt »
## avec ↑ saut et ↓ accroupi (MechaManeuvers), et « attends l'autre » / « appuie aussi » après un appui.
## Purement visuel : chaque peer le dessine à partir de l'état synchronisé de QteSequence
## (`sequence`, `step_index`, `progress_steps`, `mistake_count`). Placé dans un SubViewport (LegDashboard).

const TARGET_X: float = 66.0
const LANE_Y: float = 100.0
## Écart entre deux flèches qui défilent (pixels).
const SPACING: float = 64.0
const MINE: Color = Color(0.25, 0.95, 1.0)
const OTHER: Color = Color(0.78, 0.45, 1.0)
const GOOD: Color = Color(0.4, 1.0, 0.5)
const BAD: Color = Color(1.0, 0.25, 0.2)
const BG_TOP: Color = Color(0.02, 0.02, 0.09)
const BG_BOTTOM: Color = Color(0.13, 0.03, 0.2)
## Flèche « haut » de rayon 1 (pointe en haut), tournée pour les autres directions.
const ARROW_SHAPE: PackedVector2Array = [Vector2(0.0, -1.0), Vector2(0.9, -0.05), Vector2(0.38, -0.05),
	Vector2(0.38, 0.9), Vector2(-0.38, 0.9), Vector2(-0.38, -0.05), Vector2(-0.9, -0.05)]
## Angle de chaque flèche à l'écran, dans l'ordre de QteSequence.Arrow (haut, bas, gauche, droite).
const ARROW_ANGLES: Array[float] = [0.0, PI, -PI / 2.0, PI / 2.0]

## Étape joystick (les deux pilotes ensemble) et icônes ↑ saut / ↓ accroupi de l'écran « Prêt ».
const BOTH_COLOR: Color = Color(1.0, 0.8, 0.3)

var qte: QteSequence
## Jambe de cette console (0 = gauche, 1 = droite) : ses flèches sont « à moi ».
var leg: int = 0
## Saut et accroupi (facultatif) : icônes de l'écran « Prêt », et « attends l'autre » après un appui.
var maneuvers: MechaManeuvers
var walker: MechaWalker

var _time: float = 0.0
## Position affichée de la file (en étapes) : rattrape `step_index` en douceur, ce qui fait défiler.
var _scroll: float = 0.0
var _shown_progress: float = 0.0
var _flash_bad: float = 0.0
var _flash_good: float = 0.0
var _seen_mistakes: int = 0
var _was_active: bool = false


func setup(sequence: QteSequence, console_leg: int, console_maneuvers: MechaManeuvers = null,
		console_walker: MechaWalker = null) -> void:
	qte = sequence
	leg = console_leg
	maneuvers = console_maneuvers
	walker = console_walker
	_seen_mistakes = qte.mistake_count


func _process(delta: float) -> void:
	if qte == null:
		return
	_time += delta
	if qte.active and not _was_active:
		_scroll = -2.0   # la file arrive de la droite
	if _was_active and not qte.active and qte.step_count > 0 and qte.step_index >= qte.step_count:
		_flash_good = 1.0
	_was_active = qte.active
	if qte.mistake_count != _seen_mistakes:
		if qte.mistake_count > _seen_mistakes and qte.active:
			_flash_bad = 1.0
		_seen_mistakes = qte.mistake_count
	var k: float = 1.0 - exp(-9.0 * delta)
	_scroll = lerpf(_scroll, float(qte.step_index), k)
	_shown_progress = lerpf(_shown_progress, qte.get_progress() if qte.active else 0.0, k)
	_flash_bad = maxf(0.0, _flash_bad - delta * 2.5)
	_flash_good = maxf(0.0, _flash_good - delta * 0.5)
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_polygon([Vector2.ZERO, Vector2(w, 0.0), Vector2(w, h), Vector2(0.0, h)],
		[BG_TOP, BG_TOP, BG_BOTTOM, BG_BOTTOM])
	_draw_grid(w, h)
	if qte == null:
		return
	var shake: Vector2 = Vector2(sin(_time * 70.0), cos(_time * 55.0)) * 5.0 * _flash_bad
	draw_set_transform(shake)
	if qte.active:
		_draw_sequence(w)
	elif _flash_good > 0.0:
		_draw_text(tr("Bravo !"), Vector2(w / 2.0, h / 2.0 + 4.0), 40, GOOD.lerp(Color.WHITE, 0.3 * sin(_time * 12.0)))
	elif maneuvers != null and walker != null:
		_draw_ready(w, h)
	else:
		var pulse: float = 0.45 + 0.25 * sin(_time * 2.5)
		_draw_text(tr("Prêt"), Vector2(w / 2.0, h / 2.0 + 4.0), 26, Color(MINE, pulse))
	draw_set_transform(Vector2.ZERO)
	if _flash_bad > 0.0:
		draw_rect(Rect2(0.0, 0.0, w, h), Color(BAD, 0.35 * _flash_bad))
		_draw_text(tr("Raté !"), Vector2(w / 2.0, 34.0), 24, Color(BAD.lightened(0.4), _flash_bad))
	# lignes de balayage, façon vieil écran
	for y: int in range(0, int(h), 3):
		draw_line(Vector2(0.0, y), Vector2(w, y), Color(0.0, 0.0, 0.0, 0.18))


## Écran « Prêt » : le mot, puis ↑ saut et ↓ accroupi (↓ relève quand le robot est accroupi ; pas de saut
## accroupi). Après l'appui d'un pilote, sa flèche bat chez les deux et on dit qui doit appuyer.
func _draw_ready(w: float, h: float) -> void:
	var waiting: int = maneuvers.waiting_arrow
	var pulse: float = 0.45 + 0.25 * sin(_time * 2.5)
	if waiting < 0:
		_draw_text(tr("Prêt"), Vector2(w / 2.0, 36.0), 24, Color(MINE, pulse))
	elif maneuvers.waiting_leg == leg:
		_draw_text(tr("Attends l'autre…"), Vector2(w / 2.0, 36.0), 20, Color(OTHER, 0.85))
	else:
		var beat: float = 0.75 + 0.25 * sin(_time * 10.0)
		_draw_text(tr("Appuie aussi !"), Vector2(w / 2.0, 36.0), 24, Color(MINE, beat))
	var can_act: bool = walker.can_maneuver()
	var items: Array[Dictionary] = [
		{"arrow": QteSequence.Arrow.UP, "x": w * 0.3, "on": can_act and not walker.crouched},
		{"arrow": QteSequence.Arrow.DOWN, "x": w * 0.7, "on": can_act},
	]
	for item: Dictionary in items:
		var arrow: int = item["arrow"]
		var center: Vector2 = Vector2(item["x"], h * 0.62)
		var alpha: float = 0.9 if item["on"] else 0.25
		var radius: float = 17.0
		if waiting == arrow:
			radius *= 1.15 + 0.12 * sin(_time * 10.0)
			alpha = 1.0
		_draw_arrow(center + Vector2(-16.0, 0.0), radius, ARROW_ANGLES[arrow], Color(MINE, alpha))
		var glyph: Vector2 = center + Vector2(22.0, 0.0)
		var ink: Color = Color(BOTH_COLOR, alpha)
		if arrow == QteSequence.Arrow.UP:
			# Saut : une cloche en pointillés.
			for i: int in 5:
				var u: float = float(i) / 4.0
				draw_circle(glyph + Vector2(-14.0 + 28.0 * u, 8.0 - 26.0 * u * (1.0 - u) * 1.6), 2.6, ink)
		elif walker.crouched:
			# Accroupi : ↓ le relève (barre en haut, flèche vers le haut à côté).
			draw_line(glyph + Vector2(-12.0, -12.0), glyph + Vector2(12.0, -12.0), ink, 4.0)
			draw_line(glyph + Vector2(0.0, 12.0), glyph + Vector2(0.0, -6.0), ink, 3.0)
		else:
			# S'accroupir : une barre écrasée par deux chevrons.
			draw_line(glyph + Vector2(-13.0, 12.0), glyph + Vector2(13.0, 12.0), ink, 4.0)
			draw_polyline([glyph + Vector2(-8.0, -6.0), glyph + Vector2(0.0, 2.0), glyph + Vector2(8.0, -6.0)], ink, 3.0)


## Étape joystick : un joystick sur son socle, à pousser par les deux pilotes ensemble.
func _draw_stick(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center + Vector2(0.0, radius * 0.55), radius * 0.75, Color(color, color.a * 0.35))
	draw_line(center + Vector2(0.0, radius * 0.55), center + Vector2(radius * 0.2, -radius * 0.45), color, 4.0)
	draw_circle(center + Vector2(radius * 0.2, -radius * 0.55), radius * 0.38, color)


func _draw_sequence(w: float) -> void:
	var mine_now: bool = qte.current_leg == leg or qte.current_leg == QteSequence.BOTH
	if _flash_bad <= 0.0:
		if qte.current_leg == QteSequence.BOTH:
			var beat_both: float = 0.75 + 0.25 * sin(_time * 10.0)
			_draw_text(tr("Ensemble !"), Vector2(w / 2.0, 34.0), 26, Color(BOTH_COLOR, beat_both))
		elif mine_now:
			var beat: float = 0.75 + 0.25 * sin(_time * 10.0)
			_draw_text(tr("À toi !"), Vector2(w / 2.0, 34.0), 26, Color(MINE, beat))
		else:
			_draw_text(tr("À l'autre…"), Vector2(w / 2.0, 34.0), 20, Color(OTHER, 0.8))
	# piste et cible
	draw_line(Vector2(TARGET_X, LANE_Y), Vector2(w, LANE_Y), Color(1.0, 1.0, 1.0, 0.08), 26.0)
	var ring_color: Color = BOTH_COLOR if qte.current_leg == QteSequence.BOTH else (MINE if mine_now else OTHER)
	var ring_pulse: float = 1.0 + (0.08 * sin(_time * 10.0) if mine_now else 0.0)
	draw_arc(Vector2(TARGET_X, LANE_Y), 30.0 * ring_pulse, 0.0, TAU, 32, Color(ring_color, 0.9), 3.0)
	draw_arc(Vector2(TARGET_X, LANE_Y), 36.0 * ring_pulse, 0.0, TAU, 32, Color(ring_color, 0.25), 4.0)
	# flèches, de la plus lointaine à la plus proche (la flèche en cours passe devant)
	for i: int in range(qte.sequence.size() - 1, -1, -1):
		var x: float = TARGET_X + (float(i) - _scroll) * SPACING
		if x < -40.0 or x > w + 40.0:
			continue
		var step_leg: int = qte.sequence[i] >> 2
		var arrow: int = qte.sequence[i] & 3
		var both: bool = step_leg == QteSequence.BOTH
		var mine: bool = step_leg == leg or both
		var color: Color = BOTH_COLOR if both else (MINE if mine else OTHER)
		var radius: float = 24.0 if mine else 16.0
		var alpha: float = 1.0
		if i < qte.step_index:
			# déjà faite : elle part vers la gauche en s'effaçant, en vert
			color = GOOD
			alpha = clampf(1.0 - (TARGET_X - x) / 60.0, 0.0, 1.0)
		elif i == qte.step_index:
			radius *= 1.15 + (0.1 * sin(_time * 10.0) if mine else 0.0)
		else:
			alpha = clampf(1.0 - (x - TARGET_X) / (w * 1.1), 0.35, 1.0)
		if alpha > 0.0 and both:
			_draw_stick(Vector2(x, LANE_Y), radius, Color(color, alpha))
		elif alpha > 0.0:
			_draw_arrow(Vector2(x, LANE_Y), radius, ARROW_ANGLES[arrow], Color(color, alpha))
	# jauge d'avancement
	var bar: Rect2 = Rect2(24.0, size.y - 24.0, w - 48.0, 10.0)
	draw_rect(bar, Color(1.0, 1.0, 1.0, 0.12))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _shown_progress, bar.size.y)), MINE.lerp(GOOD, _shown_progress))
	draw_rect(bar, Color(1.0, 1.0, 1.0, 0.4), false, 1.5)


func _draw_arrow(center: Vector2, radius: float, angle: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var glow: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in ARROW_SHAPE:
		points.append(center + p.rotated(angle) * radius)
		glow.append(center + p.rotated(angle) * radius * 1.3)
	draw_colored_polygon(glow, Color(color, color.a * 0.25))
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, Color(1.0, 1.0, 1.0, color.a * 0.9), 2.0)


## Sol quadrillé qui défile, façon années 80.
func _draw_grid(w: float, h: float) -> void:
	var horizon: float = h * 0.45
	var line: Color = Color(0.9, 0.2, 0.9, 0.18)
	for i: int in 7:
		var t: float = fmod(float(i) / 7.0 + _time * 0.15, 1.0)
		var y: float = horizon + (h - horizon) * t * t
		draw_line(Vector2(0.0, y), Vector2(w, y), line)
	for i: int in range(-6, 7):
		draw_line(Vector2(w / 2.0 + i * 14.0, horizon), Vector2(w / 2.0 + i * 70.0, h), line)


func _draw_text(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var font: Font = get_theme_default_font()
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var pos: Vector2 = center + Vector2(-width / 2.0, font_size * 0.35)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 4, Color(0.0, 0.0, 0.0, color.a))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
