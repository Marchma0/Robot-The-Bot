class_name Dwarf
extends CharacterBody3D
## Nain contrôlé par un joueur, en vue première personne.
## Le nœud porte le peer id de son joueur comme nom, ce qui donne l'autorité.
## Seul le propriétaire simule le déplacement. Sa place est envoyée par le NetSmoother
## (lissée chez les autres) : dans le repère du cockpit tant qu'il est dedans (il suit le
## mécha partout), dans le monde quand il est dehors.

const SLOT_COLORS: Array[Color] = [
	Color(0.85, 0.25, 0.2),
	Color(0.2, 0.5, 0.9),
	Color(0.3, 0.75, 0.3),
	Color(0.95, 0.75, 0.2),
]
const MAX_PITCH: float = deg_to_rad(85.0)
## Assis sur un simple siège : rotation max du buste de chaque côté.
const MAX_SEAT_YAW: float = deg_to_rad(75.0)
## Nom du matériau Blender qui prend la couleur du joueur.
const TUNIC_MATERIAL: String = "Tunic"
## En dessous de cette hauteur locale, le nain est tombé du cockpit : on le replace.
const FALL_LIMIT: float = -10.0
## Temps sans sol (s) avant de jouer l'animation de saut / chute.
const AIRBORNE_DELAY: float = 0.15
## Longueur max du pseudo affiché au-dessus de la tête.
const MAX_NAME_LENGTH: int = 18
## Corde : distance entre la corde et le nain qui grimpe (m).
const CLIMB_DISTANCE: float = 0.22
## Corde : on se hisse quand les pieds sont à cette distance sous le plancher (m).
const CLIMB_TOP_BELOW_FLOOR: float = 0.55
## Durée du mouvement pour se hisser sur le plancher (s).
const PULLUP_DURATION: float = 0.45
## Position des yeux devant le centre du corps (m, -Z = devant) : regard droit / regard vers le bas.
const EYE_FORWARD: float = -0.08
const EYE_FORWARD_LOOKING_DOWN: float = -0.3
## Inclinaison vers le bas (rad) à partir de laquelle les yeux sont tout à fait avancés.
const LOOK_DOWN_FULL: float = deg_to_rad(60.0)
## Hauteur de la capsule de collision debout / accroupi (m). Accroupi, les jambes rentrent dans le corps.
const STAND_HEIGHT: float = 1.2
const CROUCH_HEIGHT: float = 0.72
## Hauteur des yeux debout / accroupi (m).
const EYE_HEIGHT: float = 0.95
## Position d'un objet tenu en main, par rapport aux yeux (m).
const HOLD_OFFSET: Vector3 = Vector3(0.2, -0.22, -0.4)
const CROUCH_EYE_HEIGHT: float = 0.7
## Bits de `anim_flags` (états d'animation envoyés ensemble, en un seul nombre).
const FLAG_AIRBORNE: int = 1
const FLAG_HOLDING: int = 2
const FLAG_SEATED: int = 4
const FLAG_FLOATING: int = 8
const FLAG_CLIMBING: int = 16
const FLAG_CROUCHING: int = 32
const FLAG_POOPING: int = 64

@export var walk_speed: float = 3.5
@export var ground_acceleration: float = 30.0
@export var air_acceleration: float = 6.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.0025
## Vitesse de rotation au stick droit (rad/s).
@export var stick_look_speed: float = 3.0
## Vitesse de grimpe à la corde (m/s).
@export var climb_speed: float = 1.4
## Vitesse accroupi (m/s).
@export var crouch_speed: float = 2.0

var peer_id: int = 1
var slot: int = 0
## Pseudo affiché au-dessus du nain (pseudo Steam), écrit par le propriétaire et répliqué.
## Vide = "Joueur N".
var player_name: String = "":
	set(value):
		player_name = value
		if is_node_ready():
			_update_name_label()

# --- État d'animation : écrit par le propriétaire, répliqué par le MultiplayerSynchronizer,
# --- lu par DwarfAnimator sur chaque peer.
## Vitesse au sol (m/s, relative au cockpit).
var anim_speed: float = 0.0
var anim_airborne: bool = false
var anim_holding: bool = false
var anim_seated: bool = false
## Augmente à chaque appui sur un bouton (déclenche l'animation "press" chez tout le monde).
var anim_press_count: int = 0
## Porté par le rayon tracteur.
var anim_floating: bool = false
## Grimpe à la corde (anim_speed = vitesse de grimpe).
var anim_climbing: bool = false
## Emote en cours (index dans Emotes.LIST, Emotes.NONE = aucune).
var anim_emote: int = Emotes.NONE
## Augmente à chaque emote lancée (permet de rejouer la même emote chez tout le monde).
var anim_emote_count: int = 0
## Assis sur les toilettes (animation "poop").
var anim_pooping: bool = false
## Augmente à chaque lancer (animation "throw" chez tout le monde).
var anim_throw_count: int = 0
## Augmente à chaque caca reçu (animation "hit" chez tout le monde).
var anim_hit_count: int = 0
## Mini-jeu des toilettes : raté (soupir) / caca légendaire réussi.
var anim_sigh_count: int = 0
var anim_golden_count: int = 0
## Accroupi (maintenir Ctrl / B). Change aussi la collision du nain, chez tout le monde.
var anim_crouching: bool = false:
	set(value):
		anim_crouching = value
		if is_node_ready():
			_apply_crouch_shape()
## Tous les états oui / non ci-dessus en un seul nombre : c'est lui qui est répliqué.
## Le propriétaire le calcule à la lecture, les autres le décodent à la réception.
var anim_flags: int:
	get:
		return (FLAG_AIRBORNE if anim_airborne else 0) | (FLAG_HOLDING if anim_holding else 0) \
			| (FLAG_SEATED if anim_seated else 0) | (FLAG_FLOATING if anim_floating else 0) \
			| (FLAG_CLIMBING if anim_climbing else 0) | (FLAG_CROUCHING if anim_crouching else 0) \
			| (FLAG_POOPING if anim_pooping else 0)
	set(value):
		anim_airborne = value & FLAG_AIRBORNE != 0
		anim_holding = value & FLAG_HOLDING != 0
		anim_seated = value & FLAG_SEATED != 0
		anim_floating = value & FLAG_FLOATING != 0
		anim_climbing = value & FLAG_CLIMBING != 0
		anim_crouching = value & FLAG_CROUCHING != 0
		anim_pooping = value & FLAG_POOPING != 0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _spawn_position: Vector3 = Vector3.ZERO
## Regard accumulé pendant qu'on est assis (envoyé à la station à chaque frame physique).
var _seat_look: Vector2 = Vector2.ZERO
var _pov_active: bool = false
## Assis sur un simple siège (canapé) : on tourne la tête / le buste de cet angle (rad).
var _seat_yaw: float = 0.0
## Dernière partie du mini-jeu des toilettes lancée chez nous (numéro donné par l'hôte).
var _poop_round: int = 0
## Temps passé sans toucher le sol (évite l'animation de saut sur une marche ou un cahot).
var _air_time: float = 0.0
## Levier tenu : décalage de vue déjà appliqué (rad) et position du levier au moment de l'attraper.
var _hold_look: Vector2 = Vector2.ZERO
var _hold_origin: Vector2 = Vector2.ZERO
var _was_holding: bool = false
## Dehors : vrai si le nain était hors du mécha à la frame précédente, et sa place dans le monde.
var _was_outside: bool = false
var _world_position: Vector3 = Vector3.ZERO
var _world_yaw: float = 0.0
## Se hisser en haut de la corde : avancement (0..1, -1 = inactif), départ et arrivée (repère du parent).
var _pullup_time: float = -1.0
var _pullup_from: Vector3 = Vector3.ZERO
var _pullup_to: Vector3 = Vector3.ZERO
## Emote : temps restant (s) avant la fin d'un geste.
var _emote_time: float = 0.0

@onready var _head: Node3D = %Head
@onready var _camera: Camera3D = %Camera
@onready var _body_model: Node3D = %BodyModel
@onready var _head_model: Node3D = %HeadModel
@onready var _name_label: Label3D = %NameLabel
@onready var _interactor: Interactor = %Interactor
@onready var _hud: CanvasLayer = %Hud
@onready var _prompt_label: Label = %PromptLabel
@onready var _crosshair: Control = %Crosshair
@onready var _emote_wheel: EmoteWheel = %EmoteWheel
@onready var _head_pitch: Node3D = %HeadPitch
@onready var _body_shape: CollisionShape3D = %CollisionShape3D
@onready var _state_bubble: StateBubble = %StateBubble
@onready var _splat_overlay: SplatOverlay = %SplatOverlay
@onready var _poop_game: PoopMinigame = %PoopMinigame
@onready var _smoother: NetSmoother = %NetSmoother


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
	# Chaque nain a sa propre capsule (elle rétrécit quand il s'accroupit).
	_body_shape.shape = _body_shape.shape.duplicate()
	_apply_crouch_shape()
	# Permet à l'hôte de retrouver le nain d'un joueur (validation de portée des commandes).
	add_to_group(&"dwarves")

	var is_local: bool = is_multiplayer_authority()
	set_physics_process(is_local)
	set_process_unhandled_input(is_local)
	_camera.current = is_local
	# La caméra est replacée à chaque image (voir _process) : pas de lissage physique sur elle.
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_hud.visible = is_local
	if not is_local:
		# La bulle d'état (portrait 3D) ne sert qu'au joueur local : inutile de la rendre ailleurs.
		_state_bubble.queue_free()
	if is_local:
		_state_bubble.setup(self)
		player_name = NetworkManager.get_local_player_name()
		_interactor.add_exception(self)
		_interactor.set_active(true)
		_interactor.prompt_changed.connect(_on_prompt_changed)
		_interactor.button_pressed.connect(_on_button_pressed)
		_interactor.thrown.connect(_on_thrown)
		_poop_game.finished.connect(_on_poop_game_finished)
		# Vue à la première personne : on voit son corps (en baissant les yeux, ses gestes),
		# mais pas sa propre tête, qui boucherait la vue (elle garde son ombre).
		for mesh: MeshInstance3D in _meshes_of(_head_model):
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
		# Roue d'emotes ouverte : la souris choisit. Assis : elle pilote la station.
		# Levier tenu : elle bouge le levier. Pendant une emote : elle tourne autour du nain.
		if _emote_wheel.is_open():
			_emote_wheel.push_mouse(motion.relative)
		elif _interactor.get_seat() != null and _interactor.get_seat().has_screen:
			_seat_look += Vector2(motion.relative.x, -motion.relative.y) * mouse_sensitivity
		elif _interactor.is_holding():
			_interactor.drive_mouse(Vector2(motion.relative.x, -motion.relative.y))
		else:
			_look(-motion.relative * mouse_sensitivity)


func _process(_delta: float) -> void:
	# La tête visible (accrochée à l'os "head", animé) suit aussi l'inclinaison du regard (répliquée).
	_head_pitch.rotation.x = _head.rotation.x
	if is_multiplayer_authority():
		# Vue à la première personne : en baissant les yeux, le point de vue avance pour
		# regarder par-dessus le ventre (sinon le haut de la tunique bouche tout l'écran).
		var looking_down: float = clampf(-_head.rotation.x / LOOK_DOWN_FULL, 0.0, 1.0)
		_head.position.z = lerpf(EYE_FORWARD, EYE_FORWARD_LOOKING_DOWN, looking_down)
		# Les yeux descendent / remontent en douceur quand on s'accroupit / se relève.
		var eye_height: float = CROUCH_EYE_HEIGHT if anim_crouching else EYE_HEIGHT
		_head.position.y = move_toward(_head.position.y, eye_height, _delta * 2.5)
		# Le corps est affiché lissé entre deux étapes physiques ; la caméra suit cette
		# position lissée, mais garde l'orientation la plus récente (souris sans retard).
		_camera.global_transform = _view_transform()


func _physics_process(delta: float) -> void:
	var stick: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	var seat: Seat = _interactor.get_seat()
	_update_view(seat)
	if not (seat is Toilet) and _poop_game.is_active():
		_poop_game.stop()   # on s'est levé en pleine partie
	var busy: bool = seat != null or _interactor.get_rope() != null or _pullup_time >= 0.0 or _interactor.is_holding()
	_update_emotes(delta, stick, busy)
	if _emote_wheel.is_open():
		stick = Vector2.ZERO   # le stick droit sert à choisir dans la roue
	if seat != null:
		_stay_seated(seat, Vector2(stick.x, -stick.y) * stick_look_speed * delta)
		return
	if _pullup_time >= 0.0:
		_update_pullup(delta)
		return
	var rope: Rope = _interactor.get_rope()
	if rope == null:
		_update_outside()
	if _interactor.is_holding():
		_interactor.drive_stick(Vector2(stick.x, -stick.y), delta)
		_follow_held_lever()
	else:
		_was_holding = false
		_look(-stick * stick_look_speed * delta)
	if rope != null:
		_climb(rope, delta)
		return

	# "Haut" du cockpit : la gravité et le saut suivent l'inclinaison du mécha (dehors : celle du monde).
	up_direction = Vector3.UP if _was_outside else global_basis.y.normalized()
	var vertical: Vector3 = up_direction * velocity.dot(up_direction)
	var horizontal: Vector3 = velocity - vertical
	_update_crouch()
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish: Vector3 = global_basis * Vector3(input.x, 0.0, input.y) * (crouch_speed if anim_crouching else walk_speed)
	var beam: TractorBeam = _find_beam()
	# Arrivé en bas d'un rayon qui descend : on est posé au sol, la gravité normale reprend.
	if beam != null and not beam.going_up and not beam.is_travelling(global_position):
		beam = null

	if beam != null:
		# Dans le rayon : il porte le nain vers le haut ou le bas et le recentre pendant le trajet.
		var travelling: bool = beam.is_travelling(global_position)
		vertical = beam.global_basis.y * beam.get_lift_speed(global_position)
		if travelling:
			wish *= 0.3
		horizontal = horizontal.move_toward(wish + beam.get_centering(global_position), ground_acceleration * delta)
		anim_floating = travelling or not is_on_floor()
	else:
		anim_floating = false
		if is_on_floor():
			vertical = Vector3.ZERO
			if Input.is_action_just_pressed("jump") and not anim_crouching:
				vertical = up_direction * jump_velocity
		else:
			vertical -= up_direction * _gravity * delta
		var accel: float = ground_acceleration if is_on_floor() else air_acceleration
		horizontal = horizontal.move_toward(wish, accel * delta)

	velocity = horizontal + vertical
	move_and_slide()
	if _was_outside:
		_world_position = global_position

	if position.y < FALL_LIMIT:
		position = _spawn_position
		velocity = Vector3.ZERO
		_was_outside = false
		reset_physics_interpolation()   # téléportation : pas de glissé à l'écran

	_air_time = 0.0 if is_on_floor() or anim_floating else _air_time + delta
	anim_speed = horizontal.length()
	anim_airborne = _air_time > AIRBORNE_DELAY
	anim_holding = _interactor.is_holding() or _interactor.is_holding_poop()
	anim_seated = false
	anim_pooping = false
	anim_climbing = false
	_smoother.world_space = _was_outside


## Appelé par le spawner avant add_child, avec les mêmes données sur tous les peers.
func setup(p_peer_id: int, p_slot: int) -> void:
	peer_id = p_peer_id
	slot = p_slot
	name = str(p_peer_id)


func _on_prompt_changed(text: String) -> void:
	_prompt_label.text = text


func _on_button_pressed() -> void:
	anim_press_count += 1


func _on_poop_game_finished(success: bool) -> void:
	var toilet: Toilet = _interactor.get_seat() as Toilet
	if toilet == null:
		return
	toilet.submit_result.rpc_id(1, _poop_round, success)
	if not success:
		anim_sigh_count += 1
	elif toilet.local_round_golden:
		anim_golden_count += 1


func _on_thrown() -> void:
	anim_throw_count += 1


## Où se trouve un objet tenu en main (devant soi, en bas à droite de la vue), en global.
## Suit l'inclinaison du regard, pour que l'objet reste visible.
func get_hold_transform() -> Transform3D:
	return _view_transform() * Transform3D(Basis.IDENTITY, HOLD_OFFSET)


## Envoyé par l'hôte quand un caca lancé touche ce nain : écran taché + animation "hit".
@rpc("any_peer", "call_local", "reliable")
func receive_splat() -> void:
	if multiplayer.get_remote_sender_id() != 1 or not is_multiplayer_authority():
		return
	anim_hit_count += 1
	_splat_overlay.splat()


## Assis : le nain reste sur le siège. À une station (écran), ses entrées partent vers
## la station (hôte) ; sur un simple siège (canapé), il regarde autour de lui.
func _stay_seated(seat: Seat, stick_look: Vector2) -> void:
	velocity = Vector3.ZERO
	if seat.has_screen:
		global_transform = seat.get_sit_transform()
		# Tête droite face à l'écran (sinon elle garde l'inclinaison prise en visant le siège).
		_head.rotation.x = 0.0
		var move: Vector2 = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		seat.submit_controls.rpc_id(1, move, _seat_look + stick_look)
		_seat_look = Vector2.ZERO
	else:
		_look(Vector2(-stick_look.x, stick_look.y))
		global_transform = seat.get_sit_transform() * Transform3D(Basis(Vector3.UP, _seat_yaw), Vector3.ZERO)
	_smoother.world_space = false
	anim_seated = true
	anim_pooping = seat is Toilet
	if seat is Toilet:
		# Nouvelle partie du mini-jeu « Poussée » envoyée par l'hôte.
		var toilet: Toilet = seat as Toilet
		if toilet.local_round_id != _poop_round:
			_poop_round = toilet.local_round_id
			_poop_game.start(toilet.local_round_golden)
	anim_speed = 0.0
	anim_airborne = false
	anim_holding = false
	anim_floating = false
	anim_climbing = false
	anim_crouching = false


## Plein écran sur la caméra de la station quand on est assis, sinon caméra du nain.
func _update_view(seat: Seat) -> void:
	if seat == null:
		_seat_yaw = 0.0   # prochain siège : on part face à l'avant du siège
	var want_pov: bool = seat != null and seat.get_pov_camera() != null
	if want_pov == _pov_active:
		return
	_pov_active = want_pov
	if want_pov:
		seat.get_pov_camera().current = true
	else:
		_camera.current = true
	_crosshair.visible = not want_pov


## Sur la corde : avancer / reculer = monter / descendre, saut = lâcher.
## Arrivé en haut, le nain se hisse sur le plancher du ventre.
func _climb(rope: Rope, delta: float) -> void:
	_was_outside = false
	rotation = Vector3(0.0, rotation.y, 0.0)
	var climb_input: float = Input.get_axis("move_back", "move_forward")
	var top: float = rope.floor_height - CLIMB_TOP_BELOW_FLOOR
	var rope_height: float = clampf(rope.height_of(global_position) + climb_input * climb_speed * delta, -rope.length, top)
	# Le nain se tient juste derrière la corde, face à elle.
	var rope_up: Vector3 = rope.global_basis.y
	var back: Vector3 = global_basis.z - rope_up * global_basis.z.dot(rope_up)
	global_position = rope.point_at(rope_height) + back.normalized() * CLIMB_DISTANCE
	velocity = Vector3.ZERO
	_smoother.world_space = false
	anim_climbing = true
	anim_crouching = false
	anim_speed = absf(climb_input) * climb_speed
	anim_floating = false
	anim_airborne = false
	anim_holding = false
	anim_seated = false
	if Input.is_action_just_pressed("jump"):
		_interactor.release_rope()
		velocity = back.normalized() * 1.5 + rope_up * 1.5
	elif rope_height >= top - 0.001 and climb_input > 0.0:
		# Se hisser : court trajet en arc jusqu'au plancher, dans le repère du mécha.
		_pullup_from = position
		_pullup_to = get_parent().to_local(rope.to_global(rope.exit_point))
		_pullup_time = 0.0
		_interactor.release_rope()


func _update_pullup(delta: float) -> void:
	_pullup_time += delta / PULLUP_DURATION
	var t: float = minf(_pullup_time, 1.0)
	position = _pullup_from.lerp(_pullup_to, ease(t, -1.6)) + Vector3.UP * sin(PI * t) * 0.25
	velocity = Vector3.ZERO
	anim_climbing = t < 1.0
	anim_speed = climb_speed
	if t >= 1.0:
		_pullup_time = -1.0


## Dehors (hors du volume intérieur du mécha), le nain ne suit plus le mécha : il reste
## enfant du mécha (pour le réseau) mais annule chaque frame le déplacement de celui-ci.
func _update_outside() -> void:
	var outside: bool = not _is_inside_mecha()
	if outside:
		if not _was_outside:
			# On vient de sortir : on mémorise sa place et son orientation dans le monde.
			_world_position = global_position
			_world_yaw = global_basis.get_euler().y
		_apply_world_place()
	elif _was_outside:
		# De retour dedans : debout par rapport au mécha.
		rotation = Vector3(0.0, rotation.y, 0.0)
	_was_outside = outside


## Point de vue (les yeux) tel qu'il est affiché : position lissée par le lissage physique,
## orientation la plus récente. Sert à la caméra et aux objets tenus en main.
func _view_transform() -> Transform3D:
	return Transform3D(global_basis * _head.basis, get_global_transform_interpolated() * _head.position)


## Dehors : place le nain à sa position mémorisée dans le monde, debout, tourné de `_world_yaw`.
func _apply_world_place() -> void:
	global_transform = Transform3D(Basis(Vector3.UP, _world_yaw), _world_position)


func _is_inside_mecha() -> bool:
	var volumes: Array[Node] = get_tree().get_nodes_in_group(&"mecha_interiors")
	if volumes.is_empty():
		return true   # scène sans mécha (bac à sable)
	var center: Vector3 = global_position + global_basis.y * 0.6
	for volume: Node in volumes:
		if (volume as InteriorVolume).contains(center):
			return true
	return false


func _find_beam() -> TractorBeam:
	for node: Node in get_tree().get_nodes_in_group(&"tractor_beams"):
		var beam: TractorBeam = node as TractorBeam
		if beam.contains(global_position):
			return beam
	return null


## Roue d'emotes (maintenir B / LB, relâcher pour jouer) et fin des emotes.
## `busy` : assis, sur la corde ou en train de tenir un levier (pas d'emote possible).
func _update_emotes(delta: float, stick: Vector2, busy: bool) -> void:
	if _emote_wheel.is_open():
		_emote_wheel.set_stick(stick)
		if busy or not Input.is_action_pressed("emote_wheel"):
			var chosen: int = _emote_wheel.close()
			if not busy and Emotes.is_valid(chosen):
				_play_emote(chosen)
	elif Input.is_action_just_pressed("emote_wheel") and not busy:
		_emote_wheel.open()

	if anim_emote != Emotes.NONE:
		_emote_time -= delta
		var moving: bool = Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.1 \
			or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("crouch")
		# Un geste s'arrête tout seul ; la danse s'arrête dès qu'on bouge.
		if busy or _emote_time <= 0.0 or (Emotes.is_loop(anim_emote) and moving):
			anim_emote = Emotes.NONE


## S'accroupir tant que Ctrl / B est maintenu ; on ne se relève que s'il y a la place.
func _update_crouch() -> void:
	var wanted: bool = Input.is_action_pressed("crouch")
	if wanted and not anim_crouching:
		anim_crouching = true
		if Emotes.is_loop(anim_emote):
			anim_emote = Emotes.NONE   # on ne danse pas accroupi
	elif not wanted and anim_crouching and _can_stand():
		anim_crouching = false


## Vrai si rien n'empêche de se relever (plafond, table…).
func _can_stand() -> bool:
	return not test_move(global_transform, up_direction * (STAND_HEIGHT - CROUCH_HEIGHT + 0.02))


func _apply_crouch_shape() -> void:
	var capsule: CapsuleShape3D = _body_shape.shape as CapsuleShape3D
	capsule.height = CROUCH_HEIGHT if anim_crouching else STAND_HEIGHT
	_body_shape.position.y = capsule.height / 2.0


func _play_emote(index: int) -> void:
	if Emotes.is_loop(index) and anim_crouching:
		if not _can_stand():
			return   # pas la place de se relever pour danser
		anim_crouching = false
	anim_emote = index
	anim_emote_count += 1
	_emote_time = INF if Emotes.is_loop(index) else float(Emotes.LIST[index]["duration"])


## Levier tenu : la vue tourne exactement du même angle que le levier, en même temps
## (relatif à sa position quand on l'a attrapé). Au lâcher, la vue reste où elle est.
func _follow_held_lever() -> void:
	var tilt: Vector2 = _interactor.get_held_tilt()
	if not _was_holding:
		_was_holding = true
		_hold_origin = tilt
		_hold_look = Vector2.ZERO
	var target: Vector2 = tilt - _hold_origin
	var change: Vector2 = target - _hold_look
	_hold_look = target
	# Levier à droite = regarder à droite (lacet négatif), levier en avant = regarder en haut.
	_look(Vector2(-change.x, change.y))


## delta.x = lacet (corps), delta.y = tangage (tête), en radians.
func _look(delta: Vector2) -> void:
	if _interactor.get_seat() != null:
		# Assis sur le canapé : on tourne le buste, sans pouvoir se retourner complètement.
		_seat_yaw = clampf(_seat_yaw + delta.x, -MAX_SEAT_YAW, MAX_SEAT_YAW)
	elif _was_outside:
		# Dehors, l'orientation du nain est mémorisée dans le monde (le mécha ne le tourne plus).
		_world_yaw += delta.x
		_apply_world_place()
	else:
		rotation.y += delta.x
	_head.rotation.x = clampf(_head.rotation.x + delta.y, -MAX_PITCH, MAX_PITCH)


## Donne la couleur du joueur (matériau "Tunic" du modèle Blender) à un modèle de nain
## (le sien, ou celui du portrait de la bulle d'état).
func tint_model(model: Node3D) -> void:
	var tunic: StandardMaterial3D = StandardMaterial3D.new()
	tunic.albedo_color = SLOT_COLORS[slot % SLOT_COLORS.size()]
	tunic.roughness = 0.8
	for mesh: MeshInstance3D in _meshes_of(model):
		for i: int in mesh.get_surface_override_material_count():
			var source: Material = mesh.mesh.surface_get_material(i)
			if source and source.resource_name == TUNIC_MATERIAL:
				mesh.set_surface_override_material(i, tunic)


func _apply_slot_visuals() -> void:
	tint_model(_body_model)
	tint_model(_head_model)
	_update_name_label()


func _update_name_label() -> void:
	var shown: String = player_name.strip_edges()
	if shown.is_empty():
		shown = "Joueur %d" % (slot + 1)
	elif shown.length() > MAX_NAME_LENGTH:
		shown = shown.left(MAX_NAME_LENGTH - 1) + "…"
	_name_label.text = shown


func _model_meshes() -> Array[MeshInstance3D]:
	return _meshes_of(_body_model) + _meshes_of(_head_model)


func _meshes_of(model: Node3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	return meshes
