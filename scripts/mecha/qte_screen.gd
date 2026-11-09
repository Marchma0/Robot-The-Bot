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
## Taille du petit robot des icônes saut / accroupi.
const ROBOT_SCALE: float = 1.4

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
		_draw_text(tr("Prêt"), Vector2(w / 2.0, 30.0), 24, Color(MINE, pulse))
	elif maneuvers.waiting_leg == leg:
		_draw_text(tr("Attends l'autre…"), Vector2(w / 2.0, 30.0), 20, Color(OTHER, 0.85))
	else:
		var beat: float = 0.75 + 0.25 * sin(_time * 10.0)
		_draw_text(tr("Appuie aussi !"), Vector2(w / 2.0, 30.0), 24, Color(MINE, beat))
	var can_act: bool = walker.can_maneuver()
	var items: Array[Dictionary] = [
		{"arrow": QteSequence.Arrow.UP, "x": w * 0.27, "on": can_act and not walker.crouched},
		{"arrow": QteSequence.Arrow.DOWN, "x": w * 0.71, "on": can_act},
	]
	var ground: float = h * 0.88
	for item: Dictionary in items:
		var arrow: int = item["arrow"]
		var x: float = item["x"]
		var alpha: float = 0.95 if item["on"] else 0.25
		var radius: float = 13.0
		if waiting == arrow:
			radius *= 1.15 + 0.12 * sin(_time * 10.0)
			alpha = 1.0
		# La flèche de la croix à utiliser, et le petit robot qui montre ce qu'elle fait (animé en boucle).
		_draw_arrow(Vector2(x - 42.0, ground - 26.0), radius, ARROW_ANGLES[arrow], Color(MINE, alpha))
		draw_line(Vector2(x - 20.0, ground), Vector2(x + 40.0, ground), Color(BOTH_COLOR, alpha * 0.45), 2.0)
		var p: float = fmod(_time, 1.8) / 1.8 if item["on"] else 0.0
		var lift: float = 0.0
		var bend: float = 0.0
		if arrow == QteSequence.Arrow.UP:
			# Saut : il plie les genoux, bondit, retombe.
			if p < 0.2:
				bend = p / 0.2
			elif p < 0.7:
				var s: float = (p - 0.2) / 0.5
				lift = 34.0 * 4.0 * s * (1.0 - s)
				bend = 0.7
			else:
				bend = 0.6 * (1.0 - (p - 0.7) / 0.3)
		else:
			# Accroupi : il se tasse et reste en bas un moment (déjà accroupi : il se relève).
			var down: float = clampf(p / 0.25, 0.0, 1.0) * clampf((1.0 - p) / 0.15, 0.0, 1.0)
			bend = 1.0 - down if walker.crouched else down
		_draw_robot(Vector2(x + 10.0, ground - 2.0 - lift), bend, alpha)
		if arrow == QteSequence.Arrow.UP and lift > 4.0:
			# Petits traits de vitesse sous lui en l'air.
			for k: int in 3:
				var lx: float = x + 2.0 + 8.0 * k
				draw_line(Vector2(lx, ground - lift + 6.0), Vector2(lx, ground - lift + 14.0), Color(BOTH_COLOR, alpha * 0.6), 2.0)


## Petit robot de l'écran « Prêt » : corps à hublots, antenne, deux jambes ; `bend` (0 à 1) plie les genoux et
## le fait descendre. `feet` = milieu des pieds.
func _draw_robot(feet: Vector2, bend: float, alpha: float) -> void:
	# Dessiné à l'échelle ROBOT_SCALE autour de ses pieds.
	draw_set_transform(feet * (1.0 - ROBOT_SCALE), 0.0, Vector2.ONE * ROBOT_SCALE)
	var body_color: Color = Color(BOTH_COLOR, alpha)
	var ink: Color = Color(0.05, 0.03, 0.1, alpha)
	var leg_height: float = lerpf(18.0, 7.0, bend)
	var hip_y: float = feet.y - leg_height
	for side: float in [-1.0, 1.0]:
		var hip: Vector2 = Vector2(feet.x + side * 7.0, hip_y)
		var foot: Vector2 = Vector2(feet.x + side * 9.0, feet.y)
		var knee: Vector2 = (hip + foot) / 2.0 + Vector2(side * 7.0 * bend, 0.0)
		draw_polyline([hip, knee, foot], body_color, 4.0)
		draw_rect(Rect2(foot + Vector2(-5.0, -2.0), Vector2(10.0, 4.0)), body_color)
	var body: Rect2 = Rect2(feet.x - 14.0, hip_y - 22.0, 28.0, 22.0)
	draw_rect(body, body_color)
	draw_rect(body, ink, false, 1.5)
	for side: float in [-1.0, 1.0]:
		var eye: Vector2 = Vector2(feet.x + side * 6.5, hip_y - 13.0)
		draw_circle(eye, 4.2, ink)
		draw_circle(eye, 2.4, Color(MINE, alpha))
	draw_line(Vector2(feet.x, hip_y - 22.0), Vector2(feet.x + 3.0, hip_y - 29.0), body_color, 2.0)
	draw_circle(Vector2(feet.x + 3.0, hip_y - 30.0), 2.2, Color(BAD, alpha))
	draw_set_transform(Vector2.ZERO)


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
