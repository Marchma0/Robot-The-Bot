class_name ChalkScoreboard
extends Node3D
## Ardoise des scores des fléchettes, à côté de la cible : la manche en cours (lanceur, ses 3 lancers,
## « dans le mille » entouré, total souligné) et les dernières manches, écrites à la craie.
## Chaque lancer s'écrit quand la fléchette se plante (pas avant).
##
## Le texte est dessiné dans une image 2D (`SubViewport`) posée sur l'ardoise, rongée par un grain de craie
## (`chalk.gdshader`). Réseau : rien. Tout est lu dans l'état déjà synchronisé de `DartsGame`.

## Taille de l'image (px) et de la surface d'ardoise qu'elle couvre (m).
const CANVAS_SIZE: Vector2i = Vector2i(600, 720)
const SLATE_SIZE: Vector2 = Vector2(0.4, 0.48)
## Devant de l'ardoise (le cadre la dépasse de 4 mm) : la craie est posée 1 mm devant.
const SLATE_FRONT_Z: float = -0.022
## Manches passées affichées sous la manche en cours.
const HISTORY_LINES: int = 3
## Longueur max d'un pseudo (lettres) : au-delà il est coupé avec « … » (manche en cours, manches passées).
const NAME_MAX: int = 11
const HISTORY_NAME_MAX: int = 9
## Durée d'écriture d'un texte (s).
const WRITE_TIME: float = 0.35
const FONT: Font = preload("res://assets/fonts/caveat.tres")

@export var game: DartsGame

var _canvas: SubViewport
var _name: Label
var _throws: Array[Label] = []
var _bull_rings: Array[Line2D] = []
var _total: Label
var _total_line: Line2D
var _history: Array[Label] = []
var _history_totals: Array[Label] = []
## Dernier état dessiné (on ne réécrit que ce qui change).
var _drawn: Dictionary = {}

@onready var _chalk: MeshInstance3D = %Chalk


func _ready() -> void:
	_canvas = SubViewport.new()
	_canvas.size = CANVAS_SIZE
	_canvas.transparent_bg = true
	_canvas.disable_3d = true
	_canvas.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_canvas)
	_build_layout()
	var material: ShaderMaterial = _chalk.get_active_material(0) as ShaderMaterial
	material.set_shader_parameter("chalk", _canvas.get_texture())
	(_chalk.mesh as QuadMesh).size = SLATE_SIZE
	_chalk.position.z = SLATE_FRONT_Z


func _process(_delta: float) -> void:
	if game == null:
		return
	var shown: int = maxi(game.round_scores.size() - game.flying_count(), 0)
	var active: bool = game.thrower_peer_id != 0 or not game.round_scores.is_empty()
	_set_text(_name, "name", _short(game.thrower_name, NAME_MAX) if active else "")
	for i: int in _throws.size():
		var score: int = game.round_scores[i] if i < shown else -1
		_set_text(_throws[i], "throw%d" % i, str(score) if score >= 0 else "")
		_set_visible(_bull_rings[i], "bull%d" % i, score == DartsGame.BULLSEYE_POINTS)
	var done: bool = game.round_done and shown == game.round_scores.size()
	_set_text(_total, "total", "= %d" % game.round_total() if done else "")
	_set_visible(_total_line, "total_line", done)
	# Manches passées : la plus récente est déjà en haut si la manche affichée est finie.
	var skip: int = 1 if game.round_done else 0
	for i: int in HISTORY_LINES:
		var k: int = i + skip
		var has: bool = k < game.history_names.size()
		_set_text(_history[i], "hist%d" % i, _short(game.history_names[k], HISTORY_NAME_MAX) if has else "")
		_set_text(_history_totals[i], "hist_total%d" % i, str(game.history_totals[k]) if has else "")


func _build_layout() -> void:
	var title: Label = _label(Vector2(0, 8), Vector2(CANVAS_SIZE.x, 110), 116, HORIZONTAL_ALIGNMENT_CENTER)
	title.text = tr("Fléchettes")
	_canvas.add_child(_wobbly_line([Vector2(150, 110), Vector2(300, 104), Vector2(452, 112)], 5.0))
	_name = _label(Vector2(36, 130), Vector2(530, 100), 96, HORIZONTAL_ALIGNMENT_LEFT)
	for i: int in 3:
		var center_x: float = 110.0 + 150.0 * i
		_throws.append(_label(Vector2(center_x - 70, 225), Vector2(140, 110), 104, HORIZONTAL_ALIGNMENT_CENTER))
		var ring: Line2D = _wobbly_ring(Vector2(center_x, 284), Vector2(70, 56))
		ring.visible = false
		_canvas.add_child(ring)
		_bull_rings.append(ring)
	_total = _label(Vector2(215, 330), Vector2(300, 110), 112, HORIZONTAL_ALIGNMENT_RIGHT)
	_total_line = _wobbly_line([Vector2(355, 432), Vector2(435, 428), Vector2(517, 435)], 5.0)
	_total_line.visible = false
	_canvas.add_child(_total_line)
	_canvas.add_child(_wobbly_line([Vector2(40, 478), Vector2(300, 470), Vector2(560, 480)], 4.0))
	for i: int in HISTORY_LINES:
		var y: float = 490.0 + 75.0 * i
		_history.append(_label(Vector2(40, y), Vector2(380, 80), 78, HORIZONTAL_ALIGNMENT_LEFT))
		_history_totals.append(_label(Vector2(385, y), Vector2(140, 80), 78, HORIZONTAL_ALIGNMENT_RIGHT))


func _label(pos: Vector2, size: Vector2, font_size: int, align: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.position = pos
	label.size = size
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS   # sécurité si un texte est encore trop large
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # noms et nombres, traduits à la main
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", Color.WHITE)
	_canvas.add_child(label)
	return label


## Trait de craie un peu tremblé passant par `points`.
func _wobbly_line(points: Array[Vector2], width: float) -> Line2D:
	var line: Line2D = Line2D.new()
	line.width = width
	line.default_color = Color.WHITE
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	for p: Vector2 in points:
		line.add_point(p)
	return line


## Cercle à la craie autour d'un « dans le mille », tracé à la main (il ne se referme pas tout à fait).
func _wobbly_ring(center: Vector2, radius: Vector2) -> Line2D:
	var points: Array[Vector2] = []
	var steps: int = 28
	for k: int in steps + 3:
		var a: float = -2.2 + TAU * float(k) / float(steps)
		var r: float = 1.0 + 0.06 * sin(a * 3.0) + 0.04 * float(k) / float(steps)
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y) * r)
	return _wobbly_line(points, 4.5)


## Écrit `text` dans `label` s'il a changé, lettre après lettre comme à la craie.
## Pseudo coupé à `max_chars` lettres, avec « … » s'il est plus long.
static func _short(player_name: String, max_chars: int) -> String:
	if player_name.length() <= max_chars:
		return player_name
	return player_name.left(max_chars - 1).strip_edges() + "…"


func _set_text(label: Label, key: String, text: String) -> void:
	if _drawn.get(key, null) == text:
		return
	_drawn[key] = text
	label.text = text
	label.visible_ratio = 0.0
	if text.is_empty():
		return
	create_tween().tween_property(label, "visible_ratio", 1.0, WRITE_TIME)


## Montre / efface un trait, qui apparaît en fondu (le temps de le tracer).
func _set_visible(item: CanvasItem, key: String, value: bool) -> void:
	if _drawn.get(key, null) == value:
		return
	_drawn[key] = value
	item.visible = value
	if value:
		item.modulate.a = 0.0
		create_tween().tween_property(item, "modulate:a", 1.0, WRITE_TIME)
