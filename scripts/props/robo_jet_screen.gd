class_name RoboJetScreen
extends Control
## Dessin du jeu de la télé (RoboJetGame), dans le SubViewport de la télé : mine sombre qui défile, stalactites
## en haut et poutres de mine en bas, notre petit robot jaune (RobotPictogram) avec sa flamme de réacteur,
## score, écran titre avec le record, « Boum ! » à la fin. Purement visuel : tout est lu dans RoboJetGame.

const BG_TOP: Color = Color(0.05, 0.03, 0.12)
const BG_BOTTOM: Color = Color(0.16, 0.07, 0.2)
const ROCK: Color = Color(0.42, 0.36, 0.38)
const ROCK_DARK: Color = Color(0.22, 0.18, 0.22)
const WOOD: Color = Color(0.62, 0.4, 0.2)
const WOOD_DARK: Color = Color(0.33, 0.2, 0.1)
const NEON: Color = Color(0.25, 0.95, 1.0)
const GOLD: Color = Color(1.0, 0.8, 0.3)
const RED: Color = Color(1.0, 0.3, 0.25)
const FLAME: Color = Color(1.0, 0.55, 0.15)
## Taille du robot à l'écran (son dessin fait environ 48 px de haut à l'échelle 1).
const ROBOT_SCALE: float = 0.75

var game: RoboJetGame

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_polygon([Vector2.ZERO, Vector2(w, 0.0), Vector2(w, h), Vector2(0.0, h)], [BG_TOP, BG_TOP, BG_BOTTOM, BG_BOTTOM])
	if game == null:
		return
	var dist: float = game.distance
	_draw_cave(w, dist)
	var first: int = maxi(0, int(floor((dist - RoboJetGame.FIRST_OBSTACLE_X - RoboJetGame.OBSTACLE_W) / RoboJetGame.SPACING)))
	for index: int in range(first, first + 4):
		var x: float = game.obstacle_x(index)
		if x > w + 4.0:
			break
		_draw_obstacle(x, game.gap_center(index))
	_draw_floor(w, dist)
	var showing_crash: bool = game.since_crash >= 0.0 and game.since_crash < RoboJetGame.CRASH_SHOW_TIME
	if game.running or showing_crash:
		_draw_robot(game.robot_y, game.robot_vy, showing_crash)
		_draw_text(str(game.score), Vector2(w / 2.0, 30.0), 30, Color.WHITE)
		if game.running and game.player_peer != multiplayer.get_unique_id():
			_draw_text(game.player_name, Vector2(w / 2.0, h - 6.0), 14, Color(NEON, 0.8))
		if showing_crash:
			_draw_text(tr("Boum !"), Vector2(w / 2.0, h / 2.0 - 10.0), 40, RED.lerp(Color.WHITE, 0.3 * sin(_time * 14.0)))
	else:
		_draw_title(w, h)


## Écran titre : nom du jeu, robot qui flotte, « clic pour jouer », record.
func _draw_title(w: float, h: float) -> void:
	_draw_text(tr("Robo-Jet"), Vector2(w / 2.0, 52.0), 38, GOLD)
	var bob: float = sin(_time * 3.0) * 6.0
	_draw_flame(Vector2(w / 2.0, 130.0 + bob), 0.6 + 0.4 * absf(sin(_time * 9.0)))
	RobotPictogram.draw(self, Vector2(w / 2.0, 130.0 + bob), 0.8, 1.0, ROBOT_SCALE * 1.3)
	var pulse: float = 0.55 + 0.45 * sin(_time * 4.0)
	_draw_text(tr("Clic pour jouer"), Vector2(w / 2.0, 172.0), 18, Color(NEON, pulse))
	if game.best_score > 0:
		_draw_text(tr("Record : %d") % game.best_score + "  " + game.best_name, Vector2(w / 2.0, 200.0), 14,
			Color(GOLD, 0.85))


func _draw_robot(y: float, vy: float, crashed: bool) -> void:
	var feet: Vector2 = Vector2(RoboJetGame.ROBOT_X, y + 15.0)
	var tilt: float = clampf(vy / 600.0, -0.35, 0.55)
	if not crashed:
		var jet: float = 1.0 if game.since_jet < 0.2 else 0.45 + 0.15 * sin(_time * 30.0)
		_draw_flame(feet, jet)
	RobotPictogram.draw(self, feet, 0.85, 0.5 if crashed else 1.0, ROBOT_SCALE, tilt)


## Flamme du réacteur sous les pieds du robot ; `power` (0 à 1) : sa longueur.
func _draw_flame(feet: Vector2, power: float) -> void:
	var length: float = 8.0 + 16.0 * power
	var flicker: float = 1.0 + 0.15 * sin(_time * 45.0)
	draw_colored_polygon([feet + Vector2(-6.0, -2.0), feet + Vector2(6.0, -2.0), feet + Vector2(0.0, length * flicker)],
		Color(FLAME, 0.9))
	draw_colored_polygon([feet + Vector2(-3.0, -2.0), feet + Vector2(3.0, -2.0), feet + Vector2(0.0, length * 0.55 * flicker)],
		Color(GOLD, 0.95))


## Stalactite (de 0 au haut de l'ouverture) et poutre de mine (du bas de l'ouverture au sol).
func _draw_obstacle(x: float, center: float) -> void:
	var top: float = center - RoboJetGame.GAP / 2.0
	var bottom: float = center + RoboJetGame.GAP / 2.0
	var ow: float = RoboJetGame.OBSTACLE_W
	# Stalactite : bloc de roche terminé par une pointe.
	var tip: float = minf(14.0, top)
	draw_rect(Rect2(x, 0.0, ow, top - tip), ROCK)
	draw_colored_polygon([Vector2(x, top - tip), Vector2(x + ow, top - tip), Vector2(x + ow * 0.55, top)], ROCK)
	draw_line(Vector2(x + 6.0, 0.0), Vector2(x + 6.0, top - tip - 4.0), ROCK_DARK, 3.0)
	draw_polyline([Vector2(x, 0.0), Vector2(x, top - tip), Vector2(x + ow * 0.55, top), Vector2(x + ow, top - tip),
		Vector2(x + ow, 0.0)], ROCK_DARK, 2.0)
	# Poutre de mine : pilier en bois, croisillon, chapeau.
	var height: float = RoboJetGame.FLOOR_Y - bottom
	draw_rect(Rect2(x + 4.0, bottom + 6.0, ow - 8.0, height - 6.0), WOOD)
	draw_rect(Rect2(x - 3.0, bottom, ow + 6.0, 8.0), WOOD)
	draw_rect(Rect2(x - 3.0, bottom, ow + 6.0, 8.0), WOOD_DARK, false, 2.0)
	draw_line(Vector2(x + 4.0, bottom + 8.0), Vector2(x + ow - 4.0, RoboJetGame.FLOOR_Y), WOOD_DARK, 2.0)
	draw_line(Vector2(x + ow - 4.0, bottom + 8.0), Vector2(x + 4.0, RoboJetGame.FLOOR_Y), WOOD_DARK, 2.0)
	draw_rect(Rect2(x + 4.0, bottom + 6.0, ow - 8.0, height - 6.0), WOOD_DARK, false, 2.0)


## Paroi de la mine qui défile lentement (pierres et lanternes).
func _draw_cave(w: float, dist: float) -> void:
	var slow: float = dist * 0.3 + _time * (0.0 if game.running else 12.0)
	for i: int in 9:
		var x: float = fposmod(i * 47.0 - slow, w + 40.0) - 20.0
		var y: float = 40.0 + fmod(i * 73.0, 150.0)
		draw_circle(Vector2(x, y), 3.0 + fmod(i * 1.7, 3.0), Color(0.3, 0.2, 0.35, 0.6))
	for i: int in 3:
		var lx: float = fposmod(i * 130.0 + 60.0 - slow * 1.4, w + 60.0) - 30.0
		draw_circle(Vector2(lx, 70.0), 9.0, Color(GOLD, 0.12))
		draw_circle(Vector2(lx, 70.0), 3.0, Color(GOLD, 0.7))


## Sol : rails de wagonnet qui défilent.
func _draw_floor(w: float, dist: float) -> void:
	var floor_y: float = RoboJetGame.FLOOR_Y
	draw_rect(Rect2(0.0, floor_y, w, size.y - floor_y), Color(0.12, 0.08, 0.1))
	var offset: float = fposmod(dist + (0.0 if game.running else _time * 40.0), 20.0)
	for i: int in int(w / 20.0) + 2:
		var x: float = i * 20.0 - offset
		draw_rect(Rect2(x, floor_y + 4.0, 10.0, 4.0), WOOD_DARK)
	draw_line(Vector2(0.0, floor_y + 3.0), Vector2(w, floor_y + 3.0), Color(0.7, 0.7, 0.75), 2.0)
	draw_line(Vector2(0.0, floor_y), Vector2(w, floor_y), Color(NEON, 0.5), 1.5)


func _draw_text(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var font: Font = get_theme_default_font()
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var pos: Vector2 = center + Vector2(-width / 2.0, font_size * 0.35)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 5, Color(0.0, 0.0, 0.0, color.a))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
