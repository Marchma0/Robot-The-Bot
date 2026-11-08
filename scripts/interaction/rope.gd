class_name Rope
extends Interactable
## Corde qui pend de la trappe du ventre jusqu'au sol : on l'attrape (maintenir clic / RT)
## pour grimper ou descendre. En haut, le nain se hisse sur le plancher du ventre.
## L'origine du nœud est le point d'accroche ; la corde pend le long de -Y.
##
## Réseau : l'hôte est autoritaire sur `holder_peer_id` (répliqué). Un seul grimpeur à la fois.
## Le grimpeur déplace lui-même son nain le long de la corde (il a l'autorité dessus).

## Longueur de la corde (m).
@export var length: float = 4.3
## Hauteur du plancher du ventre, dans le repère de la corde (négative : sous l'accroche).
@export var floor_height: float = -1.81
## Où le nain se retrouve après s'être hissé, dans le repère de la corde.
@export var exit_point: Vector3 = Vector3(0.0, -1.79, -0.95)
@export var rope_color: Color = Color(0.55, 0.4, 0.22)

## Peer qui grimpe (0 = personne). Autorité : hôte.
var holder_peer_id: int = 0

var _time: float = 0.0

@onready var _sway: Node3D = %Sway
@onready var _rope_mesh: MeshInstance3D = %RopeMesh
@onready var _knot: MeshInstance3D = %Knot
@onready var _grab_shape: CollisionShape3D = %GrabShape
@onready var _debug_label: Label3D = %DebugLabel


func _ready() -> void:
	super()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = rope_color
	material.roughness = 0.95
	_rope_mesh.material_override = material
	_knot.material_override = material
	_fit_to_length()
	add_to_group(Possession.GROUP)
	_debug_label.visible = show_debug
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.session_ended.connect(_on_session_ended)


func _physics_process(_delta: float) -> void:
	if multiplayer.is_server() and holder_peer_id != 0 and not _is_peer_near_rope(holder_peer_id, reach + 0.5):
		holder_peer_id = 0


func _process(delta: float) -> void:
	# Balancement purement visuel, plus faible quand quelqu'un est pendu dessus.
	_time += delta
	var amount: float = 0.015 if holder_peer_id != 0 else 0.05
	_sway.rotation = Vector3(sin(_time * 1.1) * amount, 0.0, sin(_time * 0.8 + 1.3) * amount)
	if show_debug:
		_debug_label.text = "%s\n%s" % [display_name, "libre" if holder_peer_id == 0 else "tenue par %d" % holder_peer_id]


func get_hints() -> Array[InputHint]:
	if is_held_locally():
		return [InputHint.make(InputHint.MOVE_VERTICAL, &"climb"), InputHint.make(&"jump", &"jump_off")]
	if holder_peer_id != 0:
		return [InputHint.state(&"locked")]
	return [InputHint.make(&"grab", &"climb")]


## Demande la main vide (voir Interactable.needs_empty_hands).
func needs_empty_hands() -> bool:
	return true


## Attraper la corde (clic / RT maintenu, mains libres) : on y grimpe.
func interact(_press: bool, grab: bool, hands_free: bool) -> Use:
	if not grab or not hands_free:
		return Use.NONE
	request_grab.rpc_id(1)
	return Use.CLAIM


func is_held_locally() -> bool:
	return holder_peer_id != 0 and holder_peer_id == multiplayer.get_unique_id()


## Hauteur d'un point le long de la corde (0 = accroche, négatif vers le bas).
func height_of(point: Vector3) -> float:
	return to_local(point).y


## Point de la corde à la hauteur `rope_height` (en global).
func point_at(rope_height: float) -> Vector3:
	return to_global(Vector3(0.0, clampf(rope_height, -length, 0.0), 0.0))


## Distance entre un point et la corde.
func distance_to_rope(point: Vector3) -> float:
	var local: Vector3 = to_local(point)
	var closest: Vector3 = Vector3(0.0, clampf(local.y, -length, 0.0), 0.0)
	return local.distance_to(closest)


@rpc("any_peer", "call_local", "reliable")
func request_grab() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if holder_peer_id == 0 and _is_peer_near_rope(sender, reach) and not Possession.is_peer_busy(get_tree(), sender):
		holder_peer_id = sender


@rpc("any_peer", "call_local", "reliable")
func request_release() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == holder_peer_id:
		holder_peer_id = 0


func _is_peer_near_rope(peer_id: int, max_distance: float) -> bool:
	var dwarf: Dwarf = Dwarf.of_peer(peer_id)
	# Mesuré depuis la poitrine du nain.
	return dwarf != null and distance_to_rope(dwarf.global_position + dwarf.global_basis.y * 0.7) <= max_distance


func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	return [_rope_mesh]


func _fit_to_length() -> void:
	var mesh: CylinderMesh = _rope_mesh.mesh as CylinderMesh
	mesh.height = length
	_rope_mesh.position.y = -length / 2.0
	_knot.position.y = -length
	var box: BoxShape3D = (_grab_shape.shape as BoxShape3D).duplicate()
	box.size.y = length
	_grab_shape.shape = box
	_grab_shape.position.y = -length / 2.0


func _on_player_left(peer_id: int) -> void:
	if multiplayer.is_server() and peer_id == holder_peer_id:
		holder_peer_id = 0


func _on_session_ended(_reason: String) -> void:
	holder_peer_id = 0
