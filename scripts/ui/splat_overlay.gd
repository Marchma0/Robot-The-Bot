class_name SplatOverlay
extends Control
## Taches marron sur l'écran quand on reçoit un caca (joueur local uniquement).
## Elles apparaissent d'un coup puis s'effacent et coulent un peu vers le bas.

const DURATION: float = 2.8
const COLOR: Color = Color(0.33, 0.2, 0.09)

var _time: float = 0.0
var _blobs: Array[Vector3] = []   # x, y (0..1 de l'écran), rayon (pixels)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func splat() -> void:
	_blobs.clear()
	var center: Vector2 = Vector2(randf_range(0.35, 0.65), randf_range(0.35, 0.6))
	for i: int in 9:
		var offset: Vector2 = Vector2(randf_range(-0.22, 0.22), randf_range(-0.2, 0.2)) * (0.4 if i < 3 else 1.0)
		_blobs.append(Vector3(center.x + offset.x, center.y + offset.y, randf_range(25.0, 90.0) * (1.6 if i < 3 else 1.0)))
	_time = DURATION
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_time -= delta
	if _time <= 0.0:
		_blobs.clear()
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _blobs.is_empty():
		return
	var alpha: float = clampf(_time / DURATION * 1.6, 0.0, 0.92)
	var drip: float = (DURATION - _time) * 18.0
	for blob: Vector3 in _blobs:
		var pos: Vector2 = Vector2(blob.x, blob.y) * size
		var color: Color = Color(COLOR, alpha)
		draw_circle(pos + Vector2(0.0, drip * 0.3), blob.z, color)
		# Coulure sous chaque grosse tache
		if blob.z > 50.0:
			draw_rect(Rect2(pos + Vector2(-blob.z * 0.15, 0.0), Vector2(blob.z * 0.3, blob.z * 0.6 + drip)), color)
			draw_circle(pos + Vector2(0.0, blob.z * 0.6 + drip), blob.z * 0.15, color)
