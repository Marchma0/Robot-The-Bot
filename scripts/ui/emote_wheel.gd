class_name EmoteWheel
extends Control
## Roue d'emotes (affichage local uniquement, rien de réseau ici) : chaque part montre une petite image de son
## nain qui fait l'emote (rendue une fois au départ, à la couleur du joueur) et le nom de l'emote.
## Le nain l'ouvre quand on maintient B / LB, lui envoie les mouvements de souris
## ou le stick droit, et lit l'emote choisie au relâchement.

const RADIUS_OUTER: float = 235.0
const RADIUS_INNER: float = 62.0
const BODY_SCENE: PackedScene = preload("res://assets/models/dwarf_body.glb")
const HEAD_SCENE: PackedScene = preload("res://assets/models/dwarf_head.glb")
## Taille des images (px, rendu et affichage) ; part de chaque animation où le nain est photographié.
const ICON_RENDER: int = 192
const ICON_SIZE: float = 96.0
const ICON_SIZE_SELECTED: float = 112.0
const POSE_AT: Dictionary[StringName, float] = {
	&"emote_wave": 0.3, &"emote_clap": 0.42, &"emote_dance": 0.3,
}
const DEFAULT_POSE_AT: float = 0.5
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
var _icons: Array[Texture2D] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Prépare les images des emotes avec le nain du joueur (appelé une fois par le nain local).
func setup(dwarf: Dwarf) -> void:
	for i: int in Emotes.count():
		_icons.append(_render_icon(dwarf, Emotes.LIST[i]["animation"]))
	# Les images sont prises une fois les poses en place, puis on arrête de les rendre.
	await get_tree().create_timer(0.5).timeout
	for viewport: SubViewport in find_children("*", "SubViewport", false, false):
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


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
	var labels: Array[Array] = []
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
		var pos: Vector2 = center + Vector2(cos(mid), sin(mid)) * (RADIUS_INNER + RADIUS_OUTER) / 2.0
		var icon_size: float = ICON_SIZE_SELECTED if i == _selected else ICON_SIZE
		if i < _icons.size():
			draw_texture_rect(_icons[i], Rect2(pos - Vector2(icon_size / 2.0, icon_size / 2.0 + 12.0),
				Vector2(icon_size, icon_size)), false)
		labels.append([tr(Emotes.LIST[i]["label"]), pos + Vector2(0.0, icon_size / 2.0 + 4.0)])
	# Les noms par-dessus les images (celle de la part survolée est plus grande).
	for entry: Array in labels:
		var label: String = entry[0]
		var font_size: int = 18
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos: Vector2 = (entry[1] as Vector2) - Vector2(text_size.x / 2.0, 0.0)
		draw_string_outline(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color.BLACK)
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	# Centre : un point de visée cuivré (plus de consigne écrite).
	draw_circle(center, 6.0, Color("d9894a"))


## Petite scène 3D à part (son propre monde) : le nain du joueur, de trois quarts, figé au milieu de l'emote.
func _render_icon(dwarf: Dwarf, animation: StringName) -> Texture2D:
	var viewport: SubViewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.size = Vector2i(ICON_RENDER, ICON_RENDER)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1.0, 0.95, 0.85)
	environment.ambient_light_energy = 0.7
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(30.0), 0.0)
	light.light_energy = 1.2
	viewport.add_child(light)
	var camera: Camera3D = Camera3D.new()
	camera.fov = 32.0
	camera.position = Vector3(0.0, 0.7, 2.2)
	viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 0.62, 0.0))
	var puppet: Node3D = BODY_SCENE.instantiate() as Node3D
	puppet.rotation.y = PI - 0.45   # de trois quarts, face à la caméra
	viewport.add_child(puppet)
	var skeleton: Skeleton3D = puppet.find_child("Skeleton3D", true, false) as Skeleton3D
	var head_bone: BoneAttachment3D = BoneAttachment3D.new()
	skeleton.add_child(head_bone)
	head_bone.bone_name = "head"
	head_bone.add_child(HEAD_SCENE.instantiate())
	dwarf.tint_model(puppet)
	var player: AnimationPlayer = puppet.find_children("*", "AnimationPlayer", true, false)[0]
	if player.has_animation(animation):
		player.play(animation)
		player.seek(player.get_animation(animation).length * POSE_AT.get(animation, DEFAULT_POSE_AT), true)
		player.pause()
	return viewport.get_texture()
