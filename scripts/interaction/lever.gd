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
## Vitesse à laquelle le manche affiché rattrape sa valeur (plus grand = plus sec).
const KNOB_FOLLOW: float = 28.0
## « Clac » en butée : durée et amplitude du rebond (fraction de l'inclinaison).
const KICK_DURATION: float = 0.14
const KICK_OVERSHOOT: float = 0.18

@export var axes: Axes = Axes.ONE
## Revient au centre quand personne ne le tient.
@export var spring_back: bool = true
## Joystick à ressort même quand on le tient (joysticks des jambes) : il revient au centre dès qu'on
## ne le pousse plus (un coup de souris = une poussée), et à la manette il suit directement le stick.
@export var self_centering: bool = false
@export var return_speed: float = 3.0
@export var max_angle_degrees: float = 30.0
@export var knob_color: Color = Color(0.45, 0.28, 0.14)
## Longueur de la tige (m), à l'échelle des nains : ~0.3 pour un levier, ~0.2 pour un joystick.
@export var handle_length: float = 0.3
## Levier à 1 axe : valeur minimale (0 = le levier ne va pas en arrière, ex. profondeur de la foreuse).
@export_range(-1.0, 0.0) var one_axis_min: float = -1.0

## Position du levier, chaque axe dans [-1, 1]. y = avant (+) / arrière (-), x = droite (+) / gauche (-).
var value: Vector2 = Vector2.ZERO
## Peer qui tient le levier (0 = personne).
var holder_peer_id: int = 0

var _local_value: Vector2 = Vector2.ZERO
## Inclinaison affichée (suit la valeur avec un peu d'inertie, comme un vrai manche).
var _shown: Vector2 = Vector2.ZERO
## « Clac » : temps restant du petit rebond du pommeau en butée (s).
var _kick_time: float = 0.0

@onready var _pivot: Node3D = %Pivot
@onready var _rod: MeshInstance3D = %Rod
@onready var _knob: MeshInstance3D = %Knob
@onready var _debug_label: Label3D = %DebugLabel
@onready var _grab_shape: CollisionShape3D = %GrabShape


func _ready() -> void:
	super()
	add_to_group(Possession.GROUP)
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


func _process(delta: float) -> void:
	# Le porteur voit sa propre valeur tout de suite ; les autres voient celle de l'hôte.
	var wanted: Vector2 = _local_value if is_held_locally() else value
	_shown = _shown.lerp(wanted, 1.0 - exp(-KNOB_FOLLOW * delta))
	var shown: Vector2 = _shown
	if _kick_time > 0.0:
		# Le pommeau tape en butée et rebondit un peu.
		_kick_time = maxf(_kick_time - delta, 0.0)
		shown *= 1.0 + KICK_OVERSHOOT * sin(PI * (1.0 - _kick_time / KICK_DURATION))
	var max_angle: float = deg_to_rad(max_angle_degrees)
	_pivot.rotation = Vector3(-shown.y * max_angle, 0.0, -shown.x * max_angle)
	if show_debug:
		var holder: String = "libre" if holder_peer_id == 0 else "tenu par %d" % holder_peer_id
		_debug_label.text = "%s\n%s\n(%.2f, %.2f)" % [display_name, holder, value.x, value.y]


func get_hints() -> Array[InputHint]:
	if is_held_locally():
		return [InputHint.make(InputHint.LOOK, &"move"), InputHint.make(&"grab", &"hand_open")]
	if holder_peer_id != 0:
		return [InputHint.state(&"locked")]
	return [InputHint.make(&"grab", &"hand_grab")]


## Attraper (clic / RT maintenu, mains libres) : on va le tenir.
func interact(_press: bool, grab: bool, hands_free: bool) -> Use:
	if not grab or not hands_free:
		return Use.NONE
	request_grab.rpc_id(1)
	return Use.CLAIM


func is_held_locally() -> bool:
	return holder_peer_id != 0 and holder_peer_id == multiplayer.get_unique_id()


## Valeur voulue par le joueur local qui tient le levier (affichage immédiat).
func set_local_value(local_value: Vector2) -> void:
	_local_value = _constrain(local_value)


## Petit rebond du pommeau en butée (joueur local, au moment où le pas part).
func kick() -> void:
	_kick_time = KICK_DURATION


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
	if Possession.is_peer_busy(get_tree(), sender):
		return   # il tient ou occupe déjà autre chose
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
		return Vector2(0.0, clampf(raw.y, one_axis_min, 1.0))
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
