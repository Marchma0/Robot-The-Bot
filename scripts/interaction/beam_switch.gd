class_name BeamSwitch
extends Interactable
## Interrupteur mural qui inverse le sens du rayon tracteur (un par étage, même rayon).
## La manette est relevée quand le rayon monte, abaissée quand il descend.
##
## Réseau : l'appui part en RPC vers l'hôte, qui vérifie la portée et inverse le rayon.
## La position de la manette se déduit du sens du rayon (déjà synchronisé).

const HANDLE_ANGLE: float = deg_to_rad(35.0)

@export var beam: TractorBeam

var _lamp_material: StandardMaterial3D

@onready var _pivot: Node3D = %Pivot
@onready var _handle: MeshInstance3D = %Handle
@onready var _knob: MeshInstance3D = %Knob
@onready var _lamp: MeshInstance3D = %Lamp
@onready var _debug_label: Label3D = %DebugLabel


func _ready() -> void:
	super()
	_lamp_material = StandardMaterial3D.new()
	_lamp_material.emission_enabled = true
	_lamp.material_override = _lamp_material
	_debug_label.visible = show_debug
	_pivot.rotation.x = _wanted_angle()


func _process(delta: float) -> void:
	# Animation purement visuelle : la manette bascule, la lampe prend la couleur du rayon.
	_pivot.rotation.x = move_toward(_pivot.rotation.x, _wanted_angle(), delta * 8.0)
	var color: Color = beam.up_color if beam.going_up else beam.down_color
	_lamp_material.albedo_color = color
	_lamp_material.emission = color
	if show_debug:
		_debug_label.text = "%s\n%s" % [display_name, "monte" if beam.going_up else "descend"]


func get_hints() -> Array[InputHint]:
	return [InputHint.make(&"interact", &"beam_down" if beam.going_up else &"beam_up")]


@rpc("any_peer", "call_local", "reliable")
func request_press() -> void:
	if not multiplayer.is_server():
		return
	if not is_peer_in_reach(multiplayer.get_remote_sender_id(), reach):
		return
	beam.toggle_direction()


func _wanted_angle() -> float:
	# Rotation négative autour de X = manette vers le haut.
	return -HANDLE_ANGLE if beam.going_up else HANDLE_ANGLE


func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	return [_handle, _knob]
