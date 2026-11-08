class_name CheckersClock
extends Interactable
## Pendule d'échecs posée à côté du damier de la table basse. Elle montre à qui de jouer, comme une vraie :
## le poussoir du côté qui doit jouer est levé et l'aiguille de son cadran tourne (rouge à gauche, crème à
## droite). Partie finie : les deux poussoirs se lèvent et la pendule sonne (elle tremble). On appuie dessus
## pour une nouvelle partie.
##
## Réseau : appuyer passe par la demande de nouvelle partie de CheckersGame (vérifiée par l'hôte) ; tout le
## reste est lu dans l'état synchronisé du jeu, chaque peer anime la pendule lui-même.

## Poussoirs et cadrans (repère de la pendule, mêmes mesures que blender/props/chess_clock.py).
const DIAL_X: float = 0.038
const DIAL_Y: float = 0.042
const DIAL_FRONT_Z: float = -0.0405
const PLUNGER_UP_Y: float = 0.104
const PLUNGER_DOWN_Y: float = 0.094
const PLUNGER_SPEED: float = 0.12
## Tour de cadran de l'aiguille de celui qui joue (s).
const HAND_TURN_TIME: float = 60.0
const PRESS_TIME: float = 0.2

@export var game: CheckersGame

var _plungers: Array[MeshInstance3D] = []
var _hands: Array[Node3D] = []
var _press_timer: float = 0.0
var _ring_time: float = 0.0

@onready var _model: Node3D = $Model


func _ready() -> void:
	super()
	for side: int in 2:
		var x: float = -DIAL_X if side == CheckersRules.Side.RED else DIAL_X
		var plunger: MeshInstance3D = MeshInstance3D.new()
		var cap: CylinderMesh = CylinderMesh.new()
		cap.top_radius = 0.0075
		cap.bottom_radius = 0.0085
		cap.height = 0.025
		cap.radial_segments = 12
		cap.rings = 1
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = CheckersGame.SIDE_COLORS[side]
		material.roughness = 0.4
		cap.material = material
		plunger.mesh = cap
		plunger.position = Vector3(x, PLUNGER_UP_Y, 0.0)
		add_child(plunger)
		_plungers.append(plunger)
		var pivot: Node3D = Node3D.new()
		pivot.position = Vector3(x, DIAL_Y, DIAL_FRONT_Z)
		var hand: MeshInstance3D = MeshInstance3D.new()
		var needle: BoxMesh = BoxMesh.new()
		needle.size = Vector3(0.0025, 0.019, 0.001)
		var black: StandardMaterial3D = StandardMaterial3D.new()
		black.albedo_color = Color(0.07, 0.07, 0.07)
		needle.material = black
		hand.mesh = needle
		hand.position = Vector3(0.0, 0.0085, 0.0)
		pivot.add_child(hand)
		add_child(pivot)
		_hands.append(pivot)


func _process(delta: float) -> void:
	if game == null:
		return
	_press_timer = maxf(_press_timer - delta, 0.0)
	var over: bool = game.winner >= 0
	for side: int in 2:
		var up: bool = over or game.turn == side
		var target: float = PLUNGER_UP_Y if up and _press_timer <= 0.0 else PLUNGER_DOWN_Y
		_plungers[side].position.y = move_toward(_plungers[side].position.y, target, PLUNGER_SPEED * delta)
		if not over and game.turn == side:
			_hands[side].rotation.z -= TAU * delta / HAND_TURN_TIME
	# Partie finie : la pendule sonne (petits tremblements par salves).
	_ring_time = _ring_time + delta if over else 0.0
	var ringing: bool = over and fmod(_ring_time, 1.6) < 0.5
	_model.rotation.z = sin(_ring_time * 70.0) * 0.04 if ringing else 0.0


func interact(press: bool, grab: bool, _hands_free: bool) -> Use:
	if not (press or grab) or game == null:
		return Use.NONE
	game.request_new_game.rpc_id(1)
	_press_timer = PRESS_TIME
	return Use.DONE


func get_hints() -> Array[InputHint]:
	return [InputHint.make(&"grab", &"press")]


func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	var meshes: Array[GeometryInstance3D] = []
	for mesh: MeshInstance3D in DwarfLook.meshes_of(_model):
		meshes.append(mesh)
	meshes.append_array(_plungers)
	return meshes
