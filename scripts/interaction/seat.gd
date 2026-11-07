class_name Seat
extends Interactable
## Place assise. Deux usages :
## - poste avec écran (grappin, foreuse) : seule exception aux commandes libres. On s'installe avec E :
##   le nain ne bouge plus, le joueur voit en plein écran par une caméra placée sur
##   `camera_anchor` (le poignet du bras) et ses entrées sont envoyées au poste.
##   L'écran de la cabine montre cette caméra à tout le monde, brouillée comme une vieille caméra ;
## - simple siège (`has_screen` = false, ex. le canapé) : on s'assoit et on regarde autour de soi.
##
## Réseau : l'hôte est autoritaire sur `occupant_peer_id` (répliqué). Les entrées de
## l'occupant arrivent en unreliable_ordered ; l'hôte ignore celles des autres.
## L'image brouillée (écran et plein écran) est calculée localement par chaque peer.

## Viseur dessiné en plein écran : pince du grappin ou cible de la foreuse.
enum Reticle { CLAW, DRILL }

const FEED_SCREEN_SHADER: Shader = preload("res://scenes/mecha/controls/camera_feed_screen.gdshader")
const FEED_OVERLAY_SHADER: Shader = preload("res://scenes/mecha/controls/camera_feed_overlay.gdshader")
## Grain permanent de l'image (0..1).
const FEED_NOISE: float = 0.55
## Vitesse à laquelle la neige d'allumage se dissipe (par seconde).
const BURST_FADE: float = 2.2
## Le point de vue du traveling s'arrête un peu plus près que « écran plein cadre » (il déborde un peu).
const SCREEN_VIEW_FILL: float = 0.9

## Point suivi par les caméras (posé par le bras du poste dans son _ready).
@export var camera_anchor: Node3D
@export var feed_resolution: Vector2i = Vector2i(320, 240)
## Faux = simple siège (canapé) : pas d'écran, pas de caméra, pas de commandes.
@export var has_screen: bool = true
## Teinte de l'image de ce poste (on reconnaît le poste d'un coup d'œil).
@export var feed_tint: Color = Color(1.0, 1.0, 1.0)
@export var reticle: Reticle = Reticle.CLAW
## Vrai si le saut lance quelque chose depuis ce poste (grappin) : affiche l'icône correspondante.
@export var can_launch: bool = false
## Mini-jeu joué assis (bras de fer) : chaque clic de l'occupant lui est envoyé (`submit_push`).
@export var game: Node

## Peer installé sur le siège (0 = libre). Autorité : hôte.
var occupant_peer_id: int = 0
## Dernières entrées de l'occupant (hôte uniquement) : déplacement, regard, bouton d'action.
var control_move: Vector2 = Vector2.ZERO
var control_look: Vector2 = Vector2.ZERO
var control_grab: bool = false
## Nombre d'appuis sur « lancer » de l'occupant : un compteur plutôt qu'un booléen,
## pour qu'un appui très bref ne se perde pas avec un paquet unreliable.
var control_fire_count: int = 0

var _burst: float = 0.0
var _screen_material: ShaderMaterial = null
var _overlay_material: ShaderMaterial = null
var _overlay_layer: CanvasLayer = null

@onready var _sit_point: Marker3D = %SitPoint
@onready var _screen: MeshInstance3D = %Screen
@onready var _feed_viewport: SubViewport = %FeedViewport
@onready var _feed_camera: Camera3D = %FeedCamera
@onready var _pov_camera: Camera3D = %PovCamera
@onready var _debug_label: Label3D = %DebugLabel


func _ready() -> void:
	super()
	add_to_group(&"seats")
	_feed_viewport.size = feed_resolution
	if not has_screen:
		_screen.visible = false
		_feed_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_screen_material = ShaderMaterial.new()
	_screen_material.shader = FEED_SCREEN_SHADER
	_screen_material.set_shader_parameter(&"feed", _feed_viewport.get_texture())
	_screen_material.set_shader_parameter(&"tint", feed_tint)
	_screen_material.set_shader_parameter(&"noise", FEED_NOISE)
	_screen.material_override = _screen_material
	if has_screen:
		_build_overlay()
	_debug_label.visible = show_debug
	# Les caméras sont replacées à chaque image (voir _process) : pas de lissage physique sur elles.
	_feed_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_pov_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.session_ended.connect(_on_session_ended)


func _process(delta: float) -> void:
	if _burst > 0.0:
		_burst = maxf(_burst - BURST_FADE * delta, 0.0)
		_apply_burst()
	# Les caméras suivent le point d'ancrage tel qu'il est affiché (lissé), pas de gameplay.
	if has_screen and camera_anchor != null:
		var anchor: Transform3D = camera_anchor.get_global_transform_interpolated()
		_feed_camera.global_transform = anchor
		_pov_camera.global_transform = anchor
	if show_debug:
		var who: String = "libre" if occupant_peer_id == 0 else "occupé par %d" % occupant_peer_id
		_debug_label.text = "%s\n%s\nmove %s look %s" % [display_name, who, control_move.snapped(Vector2.ONE * 0.01), control_look.snapped(Vector2.ONE * 0.01)]


func get_hints() -> Array[InputHint]:
	if is_seated_locally():
		if has_screen:
			var station_hints: Array[InputHint] = [
				InputHint.make(InputHint.LOOK, &"move"),
				InputHint.make(InputHint.MOVE_VERTICAL, &"climb"),
				InputHint.make(&"grab", &"drill" if reticle == Reticle.DRILL else &"hand_grab"),
			]
			if can_launch:
				station_hints.append(InputHint.make(&"jump", &"throw"))
			station_hints.append(InputHint.make(&"interact", &"stand_up"))
			return station_hints
		if game != null:
			return [InputHint.make(&"grab", &"hand_grab"), InputHint.make(&"interact", &"stand_up")]
		return [InputHint.make(&"interact", &"stand_up")]
	if occupant_peer_id != 0:
		return [InputHint.state(&"locked")]
	return [InputHint.make(&"grab", &"sit")]


func is_seated_locally() -> bool:
	return occupant_peer_id != 0 and occupant_peer_id == multiplayer.get_unique_id()


## Où placer le nain assis (repère global).
func get_sit_transform() -> Transform3D:
	return _sit_point.global_transform


## Caméra plein écran de la station, null pour un simple siège.
func get_pov_camera() -> Camera3D:
	return _pov_camera if has_screen else null


## Point de vue juste devant l'écran du poste, qui le remplit presque (repère global, lissé).
## Sert au traveling de caméra quand on s'assoit / se lève.
func get_screen_view_transform(fov_degrees: float) -> Transform3D:
	var screen_xf: Transform3D = _screen.get_global_transform_interpolated()
	var half_height: float = (_screen.mesh as QuadMesh).size.y * 0.5
	var distance: float = half_height / tan(deg_to_rad(fov_degrees) * 0.5) * SCREEN_VIEW_FILL
	var screen_basis: Basis = screen_xf.basis.orthonormalized()
	return Transform3D(screen_basis, screen_xf.origin + screen_basis.z * distance)


## Affiche / masque l'image brouillée en plein écran (chez le joueur assis ici seulement).
func set_overlay_visible(value: bool) -> void:
	if _overlay_layer != null:
		_overlay_layer.visible = value


## Neige forte qui se dissipe : allumage de la caméra, coupure.
func flash_static(amount: float = 1.0) -> void:
	_burst = maxf(_burst, amount)
	_apply_burst()


@rpc("any_peer", "call_local", "reliable")
func request_sit() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if occupant_peer_id != 0 or not is_peer_in_reach(sender, reach):
		return
	for node: Node in get_tree().get_nodes_in_group(&"seats"):
		if (node as Seat).occupant_peer_id == sender:
			return
	occupant_peer_id = sender


@rpc("any_peer", "call_local", "reliable")
func request_leave() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == occupant_peer_id:
		_free_seat()


@rpc("any_peer", "call_local", "unreliable_ordered")
func submit_controls(move: Vector2, look: Vector2, grab: bool = false, fire_count: int = 0) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == occupant_peer_id:
		control_move = move.limit_length(1.0)
		control_look = look
		control_grab = grab
		control_fire_count = fire_count


func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	# Pas de surbrillance sur le siège (un gros bloc lumineux, peu joli) : le texte suffit.
	return []


func _free_seat() -> void:
	occupant_peer_id = 0
	control_move = Vector2.ZERO
	control_look = Vector2.ZERO
	control_grab = false
	control_fire_count = 0   # le nain remet aussi son compteur à 0 en s'asseyant


func _build_overlay() -> void:
	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = FEED_OVERLAY_SHADER
	_overlay_material.set_shader_parameter(&"tint", feed_tint)
	_overlay_material.set_shader_parameter(&"noise", FEED_NOISE)
	_overlay_material.set_shader_parameter(&"reticle", int(reticle))
	_overlay_material.set_shader_parameter(&"reticle_color", feed_tint.lerp(Color.WHITE, 0.5))
	var rect: ColorRect = ColorRect.new()
	rect.material = _overlay_material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Sous l'interface du nain (icônes d'aide), au-dessus de l'image 3D.
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 0
	_overlay_layer.visible = false
	_overlay_layer.add_child(rect)
	add_child(_overlay_layer)


func _apply_burst() -> void:
	_screen_material.set_shader_parameter(&"burst", _burst)
	if _overlay_material != null:
		_overlay_material.set_shader_parameter(&"burst", _burst)


func _on_player_left(peer_id: int) -> void:
	if multiplayer.is_server() and peer_id == occupant_peer_id:
		_free_seat()


func _on_session_ended(_reason: String) -> void:
	_free_seat()
