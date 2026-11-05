class_name Seat
extends Interactable
## Place assise. Deux usages :
## - station avec écran (grappin) : seule exception aux commandes libres. On s'installe avec E :
##   le nain ne bouge plus, le joueur voit en plein écran par une caméra placée sur
##   `camera_anchor` (ex. la main du grappin) et ses entrées sont envoyées à la station.
##   L'écran de la cabine montre cette caméra à tout le monde ;
## - simple siège (`has_screen` = false, ex. le canapé) : on s'assoit et on regarde autour de soi.
##
## Réseau : l'hôte est autoritaire sur `occupant_peer_id` (répliqué). Les entrées de
## l'occupant arrivent en unreliable_ordered ; l'hôte ignore celles des autres.

## Point suivi par les caméras (sera porté par le bras du grappin en M9).
@export var camera_anchor: Node3D
@export var feed_resolution: Vector2i = Vector2i(320, 240)
## Faux = simple siège (canapé) : pas d'écran, pas de caméra, pas de commandes.
@export var has_screen: bool = true

## Peer installé sur le siège (0 = libre). Autorité : hôte.
var occupant_peer_id: int = 0
## Dernières entrées de l'occupant (hôte uniquement) : déplacement et regard, -1..1 / delta.
var control_move: Vector2 = Vector2.ZERO
var control_look: Vector2 = Vector2.ZERO

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
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _feed_viewport.get_texture()
	_screen.material_override = material
	_debug_label.visible = show_debug
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.session_ended.connect(_on_session_ended)


func _process(_delta: float) -> void:
	# Les caméras suivent le point d'ancrage (visuel, pas de gameplay).
	if has_screen and camera_anchor != null:
		_feed_camera.global_transform = camera_anchor.global_transform
		_pov_camera.global_transform = camera_anchor.global_transform
	if show_debug:
		var who: String = "libre" if occupant_peer_id == 0 else "occupé par %d" % occupant_peer_id
		_debug_label.text = "%s\n%s\nmove %s look %s" % [display_name, who, control_move.snapped(Vector2.ONE * 0.01), control_look.snapped(Vector2.ONE * 0.01)]


func get_prompt() -> String:
	if is_seated_locally():
		return "[E] se lever — %s" % display_name
	if occupant_peer_id != 0:
		return "%s — occupé" % display_name
	return "[E / clic] s'installer — %s" % display_name


func is_seated_locally() -> bool:
	return occupant_peer_id != 0 and occupant_peer_id == multiplayer.get_unique_id()


## Où placer le nain assis (repère global).
func get_sit_transform() -> Transform3D:
	return _sit_point.global_transform


## Caméra plein écran de la station, null pour un simple siège.
func get_pov_camera() -> Camera3D:
	return _pov_camera if has_screen else null


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
func submit_controls(move: Vector2, look: Vector2) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == occupant_peer_id:
		control_move = move.limit_length(1.0)
		control_look = look


func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	# Pas de surbrillance sur le siège (un gros bloc lumineux, peu joli) : le texte suffit.
	return []


func _free_seat() -> void:
	occupant_peer_id = 0
	control_move = Vector2.ZERO
	control_look = Vector2.ZERO


func _on_player_left(peer_id: int) -> void:
	if multiplayer.is_server() and peer_id == occupant_peer_id:
		_free_seat()


func _on_session_ended(_reason: String) -> void:
	_free_seat()
