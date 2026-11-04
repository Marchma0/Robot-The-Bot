class_name Dwarf
extends CharacterBody3D
## Nain contrôlé par un joueur, en vue première personne.
## Le nœud porte le peer id de son joueur comme nom, ce qui donne l'autorité.
## Seul le propriétaire simule le déplacement ; le MultiplayerSynchronizer réplique
## la position LOCALE (le nain est enfant du cockpit, donc il suit le mécha partout).

const SLOT_COLORS: Array[Color] = [
	Color(0.85, 0.25, 0.2),
	Color(0.2, 0.5, 0.9),
	Color(0.3, 0.75, 0.3),
	Color(0.95, 0.75, 0.2),
]
const MAX_PITCH: float = deg_to_rad(85.0)
## Nom du matériau Blender qui prend la couleur du joueur.
const TUNIC_MATERIAL: String = "Tunic"
## En dessous de cette hauteur locale, le nain est tombé du cockpit : on le replace.
const FALL_LIMIT: float = -10.0

@export var walk_speed: float = 3.5
@export var ground_acceleration: float = 30.0
@export var air_acceleration: float = 6.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.0025
## Vitesse de rotation au stick droit (rad/s).
@export var stick_look_speed: float = 3.0

var peer_id: int = 1
var slot: int = 0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _spawn_position: Vector3 = Vector3.ZERO

@onready var _head: Node3D = %Head
@onready var _camera: Camera3D = %Camera
@onready var _body_model: Node3D = %BodyModel
@onready var _head_model: Node3D = %HeadModel
@onready var _name_label: Label3D = %NameLabel


func _enter_tree() -> void:
	# Le nom est fixé par le spawner avant l'ajout à l'arbre, sur tous les peers.
	peer_id = name.to_int()
	set_multiplayer_authority(peer_id)


func _ready() -> void:
	_spawn_position = position
	# Le nain est déjà porté par le cockpit (son parent) : ne pas ajouter
	# en plus la vitesse de la plateforme, sinon il serait déplacé deux fois.
	platform_floor_layers = 0
	platform_wall_layers = 0
	platform_on_leave = PLATFORM_ON_LEAVE_DO_NOTHING
	_apply_slot_visuals()

	var is_local: bool = is_multiplayer_authority()
	set_physics_process(is_local)
	set_process_unhandled_input(is_local)
	_camera.current = is_local
	if is_local:
		# On ne voit pas son propre corps, mais il garde son ombre.
		for mesh: MeshInstance3D in _model_meshes():
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		_name_label.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		_look(-motion.relative * mouse_sensitivity)


func _physics_process(delta: float) -> void:
	var stick: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	_look(-stick * stick_look_speed * delta)

	# "Haut" du cockpit : la gravité et le saut suivent l'inclinaison du mécha.
	up_direction = global_basis.y.normalized()
	var vertical: Vector3 = up_direction * velocity.dot(up_direction)
	var horizontal: Vector3 = velocity - vertical

	if is_on_floor():
		vertical = Vector3.ZERO
		if Input.is_action_just_pressed("jump"):
			vertical = up_direction * jump_velocity
	else:
		vertical -= up_direction * _gravity * delta

	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish: Vector3 = global_basis * Vector3(input.x, 0.0, input.y) * walk_speed
	var accel: float = ground_acceleration if is_on_floor() else air_acceleration
	horizontal = horizontal.move_toward(wish, accel * delta)

	velocity = horizontal + vertical
	move_and_slide()

	if position.y < FALL_LIMIT:
		position = _spawn_position
		velocity = Vector3.ZERO


## Appelé par le spawner avant add_child, avec les mêmes données sur tous les peers.
func setup(p_peer_id: int, p_slot: int) -> void:
	peer_id = p_peer_id
	slot = p_slot
	name = str(p_peer_id)


## delta.x = lacet (corps), delta.y = tangage (tête), en radians.
func _look(delta: Vector2) -> void:
	rotation.y += delta.x
	_head.rotation.x = clampf(_head.rotation.x + delta.y, -MAX_PITCH, MAX_PITCH)


func _apply_slot_visuals() -> void:
	# La couleur du joueur remplace le matériau "Tunic" du modèle Blender.
	var tunic: StandardMaterial3D = StandardMaterial3D.new()
	tunic.albedo_color = SLOT_COLORS[slot % SLOT_COLORS.size()]
	tunic.roughness = 0.8
	for mesh: MeshInstance3D in _model_meshes():
		for i: int in mesh.get_surface_override_material_count():
			var source: Material = mesh.mesh.surface_get_material(i)
			if source and source.resource_name == TUNIC_MATERIAL:
				mesh.set_surface_override_material(i, tunic)
	_name_label.text = "Joueur %d" % (slot + 1)


func _model_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for model: Node3D in [_body_model, _head_model]:
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			meshes.append(node as MeshInstance3D)
	return meshes
