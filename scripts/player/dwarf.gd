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
## Temps sans sol (s) avant de jouer l'animation de saut / chute.
const AIRBORNE_DELAY: float = 0.15

@export var walk_speed: float = 3.5
@export var ground_acceleration: float = 30.0
@export var air_acceleration: float = 6.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.0025
## Vitesse de rotation au stick droit (rad/s).
@export var stick_look_speed: float = 3.0

var peer_id: int = 1
var slot: int = 0

# --- État d'animation : écrit par le propriétaire, répliqué par le MultiplayerSynchronizer,
# --- lu par DwarfAnimator sur chaque peer.
## Vitesse au sol (m/s, relative au cockpit).
var anim_speed: float = 0.0
var anim_airborne: bool = false
var anim_holding: bool = false
var anim_seated: bool = false
## Augmente à chaque appui sur un bouton (déclenche l'animation "press" chez tout le monde).
var anim_press_count: int = 0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _spawn_position: Vector3 = Vector3.ZERO
## Regard accumulé pendant qu'on est assis (envoyé à la station à chaque frame physique).
var _seat_look: Vector2 = Vector2.ZERO
var _pov_active: bool = false
## Temps passé sans toucher le sol (évite l'animation de saut sur une marche ou un cahot).
var _air_time: float = 0.0

@onready var _head: Node3D = %Head
@onready var _camera: Camera3D = %Camera
@onready var _body_model: Node3D = %BodyModel
@onready var _head_model: Node3D = %HeadModel
@onready var _name_label: Label3D = %NameLabel
@onready var _interactor: Interactor = %Interactor
@onready var _hud: CanvasLayer = %Hud
@onready var _prompt_label: Label = %PromptLabel
@onready var _crosshair: Control = %Crosshair


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
	# Permet à l'hôte de retrouver le nain d'un joueur (validation de portée des commandes).
	add_to_group(&"dwarves")

	var is_local: bool = is_multiplayer_authority()
	set_physics_process(is_local)
	set_process_unhandled_input(is_local)
	_camera.current = is_local
	_hud.visible = is_local
	if is_local:
		_interactor.add_exception(self)
		_interactor.set_active(true)
		_interactor.prompt_changed.connect(_on_prompt_changed)
		_interactor.button_pressed.connect(_on_button_pressed)
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
		# Assis : la souris pilote la station. Levier tenu : elle bouge le levier.
		if _interactor.get_seat() != null:
			_seat_look += Vector2(motion.relative.x, -motion.relative.y) * mouse_sensitivity
		elif _interactor.is_holding():
			_interactor.drive_mouse(Vector2(motion.relative.x, -motion.relative.y))
		else:
			_look(-motion.relative * mouse_sensitivity)


func _physics_process(delta: float) -> void:
	var stick: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	var seat: Seat = _interactor.get_seat()
	_update_view(seat)
	if seat != null:
		_stay_seated(seat, Vector2(stick.x, -stick.y) * stick_look_speed * delta)
		return
	if _interactor.is_holding():
		_interactor.drive_stick(Vector2(stick.x, -stick.y), delta)
	else:
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

	_air_time = 0.0 if is_on_floor() else _air_time + delta
	anim_speed = horizontal.length()
	anim_airborne = _air_time > AIRBORNE_DELAY
	anim_holding = _interactor.is_holding()
	anim_seated = false


## Appelé par le spawner avant add_child, avec les mêmes données sur tous les peers.
func setup(p_peer_id: int, p_slot: int) -> void:
	peer_id = p_peer_id
	slot = p_slot
	name = str(p_peer_id)


func _on_prompt_changed(text: String) -> void:
	_prompt_label.text = text


func _on_button_pressed() -> void:
	anim_press_count += 1


## Assis : le nain reste sur le siège et ses entrées partent vers la station (hôte).
func _stay_seated(seat: Seat, stick_look: Vector2) -> void:
	global_transform = seat.get_sit_transform()
	velocity = Vector3.ZERO
	anim_seated = true
	anim_speed = 0.0
	anim_airborne = false
	anim_holding = false
	var move: Vector2 = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	seat.submit_controls.rpc_id(1, move, _seat_look + stick_look)
	_seat_look = Vector2.ZERO


## Plein écran sur la caméra de la station quand on est assis, sinon caméra du nain.
func _update_view(seat: Seat) -> void:
	var want_pov: bool = seat != null
	if want_pov == _pov_active:
		return
	_pov_active = want_pov
	if want_pov:
		seat.get_pov_camera().current = true
	else:
		_camera.current = true
	_crosshair.visible = not want_pov


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
