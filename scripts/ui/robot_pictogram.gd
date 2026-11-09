class_name RobotPictogram
extends RefCounted
## Petit robot jaune dessiné en 2D (corps à hublots, antenne, deux jambes) : icônes ↑ saut / ↓ accroupi de
## l'écran des consoles (QteScreen) et héros du jeu de la télé (RoboJetScreen). Un seul dessin, partout pareil.

const BODY: Color = Color(1.0, 0.8, 0.3)
const INK: Color = Color(0.05, 0.03, 0.1)
const EYE: Color = Color(0.25, 0.95, 1.0)
const ANTENNA_TIP: Color = Color(1.0, 0.25, 0.2)


## Dessine le robot sur `canvas`, pieds en `feet`, à l'échelle `scale`. `bend` (0 à 1) plie les genoux et
## le fait descendre. `tilt` (radians) le penche autour de ses pieds.
static func draw(canvas: CanvasItem, feet: Vector2, bend: float, alpha: float, scale: float = 1.0,
		tilt: float = 0.0) -> void:
	canvas.draw_set_transform(feet, tilt, Vector2.ONE * scale)
	var body_color: Color = Color(BODY, alpha)
	var ink: Color = Color(INK, alpha)
	var leg_height: float = lerpf(18.0, 7.0, bend)
	var hip_y: float = -leg_height
	for side: float in [-1.0, 1.0]:
		var hip: Vector2 = Vector2(side * 7.0, hip_y)
		var foot: Vector2 = Vector2(side * 9.0, 0.0)
		var knee: Vector2 = (hip + foot) / 2.0 + Vector2(side * 7.0 * bend, 0.0)
		canvas.draw_polyline([hip, knee, foot], body_color, 4.0)
		canvas.draw_rect(Rect2(foot + Vector2(-5.0, -2.0), Vector2(10.0, 4.0)), body_color)
	var body: Rect2 = Rect2(-14.0, hip_y - 22.0, 28.0, 22.0)
	canvas.draw_rect(body, body_color)
	canvas.draw_rect(body, ink, false, 1.5)
	for side: float in [-1.0, 1.0]:
		var eye: Vector2 = Vector2(side * 6.5, hip_y - 13.0)
		canvas.draw_circle(eye, 4.2, ink)
		canvas.draw_circle(eye, 2.4, Color(EYE, alpha))
	canvas.draw_line(Vector2(0.0, hip_y - 22.0), Vector2(3.0, hip_y - 29.0), body_color, 2.0)
	canvas.draw_circle(Vector2(3.0, hip_y - 30.0), 2.2, Color(ANTENNA_TIP, alpha))
	canvas.draw_set_transform(Vector2.ZERO)
