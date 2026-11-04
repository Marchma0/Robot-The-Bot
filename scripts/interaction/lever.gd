class_name Lever
extends Interactable
## Levier (1 axe) ou joystick (2 axes) qu'on attrape en maintenant clic / RT.
## Pendant qu'on le tient, la souris (ou le stick droit) le bouge ; on peut marcher à portée.
##
## Réseau : l'hôte est autoritaire sur `holder_peer_id` et `value`, répliqués par le
## MultiplayerSynchronizer. Le joueur qui tient le levier envoie la valeur voulue
## (unreliable_ordered) ; l'hôte l'ignore si l'expéditeur n'est pas le porteur.

enum Axes { ONE, TWO }

## Marge au-delà de la portée avant que l'hôte force le lâcher.
const RELEASE_MARGIN: float = 0.5

@export var axes: Axes = Axes.ONE
## Revient au centre quand personne ne le tient.
@export var spring_back: bool = true
@export var return_speed: float = 3.0
@export var max_angle_degrees: float = 30.0
@export var knob_color: Color = Color(0.45, 0.28, 0.14)
## Longueur de la tige (m), à l'échelle des nains : ~0.3 pour un levier, ~0.2 pour un joystick.
@export var handle_length: float = 0.3

## Position du levier, chaque axe dans [-1, 1]. y = avant (+) / arrière (-), x = droite (+) / gauche (-).
var value: Vector2 = Vector2.ZERO
## Peer qui tient le levier (0 = personne).
var holder_peer_id: int = 0

var _local_value: Vector2 = Vector2.ZERO

@onready var _pivot: Node3D = %Pivot
@onready var _rod: MeshInstance3D = %Rod
@onready var _knob: MeshInstance3D = %Knob
@onready var _debug_label: Label3D = %DebugLabel
@onready var _grab_shape: CollisionShape3D = %GrabShape


func _ready() -> void:
	super()
	add_to_group(&"levers")
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = knob_color
	material.roughness = 0.6
	_knob.material_override = material
	_fit_to_length()
	_debug_label.visible = show_debug
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.session_ended.connect(_on_session_ended)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if holder_peer_id != 0 and not is_peer_in_reach(holder_peer_id, reach + RELEASE_MARGIN):
		holder_peer_id = 0
	if holder_peer_id == 0 and spring_back:
		value = value.move_toward(Vector2.ZERO, return_speed * delta)


func _process(_delta: float) -> void:
	# Le porteur voit sa propre valeur tout de suite ; les autres voient celle de l'hôte.
	var shown: Vector2 = _local_value if is_held_locally() else value
	var max_angle: float = deg_to_rad(max_angle_degrees)
	_pivot.rotation = Vector3(-shown.y * max_angle, 0.0, -shown.x * max_angle)
	if show_debug:
		var holder: String = "libre" if holder_peer_id == 0 else "tenu par %d" % holder_peer_id
		_debug_label.text = "%s\n%s\n(%.2f, %.2f)" % [display_name, holder, value.x, value.y]


func get_prompt() -> String:
	if is_held_locally():
		return "Bouge la souris / le stick — relâche pour lâcher"
	if holder_peer_id != 0:
		return "%s — déjà tenu" % display_name
	return "[maintenir clic / RT] attraper — %s" % display_name


func is_held_locally() -> bool:
	return holder_peer_id != 0 and holder_peer_id == multiplayer.get_unique_id()


## Valeur voulue par le joueur local qui tient le levier (affichage immédiat).
func set_local_value(local_value: Vector2) -> void:
	_local_value = _constrain(local_value)


## Limite une valeur aux axes autorisés et à [-1, 1].
func constrain(raw: Vector2) -> Vector2:
	return _constrain(raw)


@rpc("any_peer", "call_local", "reliable")
func request_grab() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if holder_peer_id != 0 or not is_peer_in_reach(sender, reach):
		return
	for node: Node in get_tree().get_nodes_in_group(&"levers"):
		if (node as Lever).holder_peer_id == sender:
			return
	holder_peer_id = sender


@rpc("any_peer", "call_local", "reliable")
func request_release() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == holder_peer_id:
		holder_peer_id = 0


@rpc("any_peer", "call_local", "unreliable_ordered")
func submit_value(wanted: Vector2) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == holder_peer_id:
		value = _constrain(wanted)


func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	return [_rod, _knob]


func _constrain(raw: Vector2) -> Vector2:
	if axes == Axes.ONE:
		return Vector2(0.0, clampf(raw.y, -1.0, 1.0))
	# Joystick : débattement circulaire (la diagonale ne va pas plus loin que tout droit).
	return raw.limit_length(1.0)


## Place la tige, le pommeau, la zone de prise et l'étiquette selon `handle_length`.
func _fit_to_length() -> void:
	var rod_mesh: CylinderMesh = _rod.mesh as CylinderMesh
	_rod.scale.y = handle_length / rod_mesh.height
	_rod.position.y = handle_length / 2.0
	_knob.position.y = handle_length
	var box: BoxShape3D = (_grab_shape.shape as BoxShape3D).duplicate()
	box.size.y = handle_length + 0.15
	_grab_shape.shape = box
	_grab_shape.position.y = box.size.y / 2.0
	_debug_label.position.y = handle_length + 0.3


func _on_player_left(peer_id: int) -> void:
	if multiplayer.is_server() and peer_id == holder_peer_id:
		holder_peer_id = 0


func _on_session_ended(_reason: String) -> void:
	holder_peer_id = 0
	value = Vector2.ZERO
