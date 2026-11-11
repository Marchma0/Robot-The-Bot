class_name MechaWalker
extends Node
## Marche en rythme du mécha (M7.1, voir docs/jeu.md « Les jambes »).
## Un coup de joystick = un pas de la jambe de ce joystick. Les pas alternés font avancer le robot.
##
## Accroupi et saut (M7.5) : voir `set_crouched` et `jump`, lancés par MechaManeuvers.
##
## Obstacles : le robot n'a pas de collision quand il marche (il pose ses pieds). Un pas, un saut ou un
## relèvement qui le ferait entrer dans un corps du calque physique « obstacle du robot » (`OBSTACLE_LAYER`)
## est refusé : le robot vacille sur place (`blocked`), sans remplir la jauge d'erreur. Avant de refuser un
## pas, on essaie un pas plus court (il s'approche du bord à petits pas). Deux contrôles :
## le trajet du pied (bas des murs, muret, fossé) et une boîte autour de la caisse du corps (murs, poutre basse).
##
## Réseau : tout est calculé sur l'hôte. Les clients n'envoient que leurs joysticks (Lever, déjà en place).
## L'hôte déplace le corps du mécha (synchronisé et lissé par le NetSmoother du mécha) et les deux
## cibles de pied (`FootL`, `FootR`, chacune avec son NetSmoother, même horloge que le corps).
## Les marques au sol (`landing_*`, `swinging_*`) sont synchronisées par le MultiplayerSynchronizer du nœud.
## Chaque peer calcule ensuite lui-même la pliure des jambes (LegIK).

signal stepped(leg: int)
signal stumbled
signal fell
signal got_up
## Pas, saut ou relèvement refusé : il entrerait dans un obstacle.
signal blocked

enum Leg { LEFT, RIGHT }
## WALKING : on marche (debout ou accroupi, voir `crouched`). FALLING / FALLEN : jauge d'erreur pleine, il
## s'effondre puis attend le QTE. GETTING_UP : QTE réussi, il se relève. JUMPING : saut (élan, vol, réception).
enum Phase { WALKING, FALLING, FALLEN, GETTING_UP, JUMPING }

## Hanches dans le repère du mécha (Godot), hauteur des hanches au-dessus du sol debout,
## et longueur max hanche -> cheville (jambes jamais tout à fait tendues).
const HIP_LOCAL: Array[Vector3] = [Vector3(-1.4, 2.2, 0.0), Vector3(1.4, 2.2, 0.0)]
const HIP_HEIGHT: float = 2.75
const ANKLE_HEIGHT: float = 0.35
const MAX_REACH: float = 2.45
## Seuils du joystick : au-delà de TRIGGER on fait un pas, il faut revenir sous RELEASE pour le suivant.
const TRIGGER: float = 0.6
const RELEASE: float = 0.3
## Élan : le corps ne s'écarte jamais de plus de ça (m) de sa place entre les pieds.
const MAX_MOMENTUM_LEAD: float = 0.9
## Calque physique 5 « obstacle du robot » (murs, poutres, fossés…) : le robot n'y entre pas.
const OBSTACLE_LAYER: int = 1 << 4
## Caisse du corps pour les obstacles (repère du robot) : demi-largeur (x) et demi-profondeur (z), bas et haut
## au-dessus du sol, debout (accroupi : le haut descend de `crouch_drop`). Le bas laisse passer les jambes
## au-dessus d'un fossé ; le haut est celui de la tête (la cheminée dépasse un peu, sans compter).
const BODY_HALF: Vector2 = Vector2(2.8, 2.4)
const BODY_BOTTOM: float = 2.0
const BODY_TOP: float = 9.1
## Hauteurs (au-dessus du sol) du trajet du pied contrôlées contre les obstacles.
const FOOT_CHECK_HEIGHTS: Array[float] = [0.3, 1.2]
## Pas essayés devant un obstacle : le pas entier, puis de plus en plus court.
const OBSTACLE_STEP_SCALES: Array[float] = [1.0, 0.5, 0.25]
## Le corps n'est « coincé dans un obstacle » (et libre d'en sortir) que s'il y est enfoncé de plus que ça (m).
const STUCK_MARGIN: float = 0.3

@export var body: Node3D
@export var stick_left: Lever
@export var stick_right: Lever
## Durée d'un pas (s) et hauteur du pied en l'air (m).
@export var step_time: float = 0.42
@export var lift_height: float = 0.45
## Longueur de pas : courte si on enchaîne lentement, longue à rythme soutenu.
@export var stride_slow: float = 1.0
@export var stride_fast: float = 1.4
@export var stride_back: float = 0.7
## Rotation par pas : diagonale (avance en tournant) et côté pur (pivot sur place), en degrés.
@export var turn_step_degrees: float = 20.0
@export var pivot_step_degrees: float = 25.0
## Écart max de direction entre deux pas successifs avant de trébucher (degrés).
@export var mismatch_degrees: float = 60.0
## Un pas demandé reste en attente tant qu'un pied est en l'air, puis au plus ce temps (s).
@export var buffer_time: float = 0.35

@export_group("Élan du corps")
## Part de la destination d'un pied en l'air déjà prise en compte pour placer le corps (0 = aucune).
@export_range(0.0, 1.0) var step_lead: float = 0.35
## Raideur du ressort qui tire le corps vers sa place (plus grand = plus vif).
@export var momentum_stiffness: float = 60.0
## Amortissement (1 = sans dépassement, < 1 = garde un peu d'élan et dépasse légèrement).
@export_range(0.3, 1.5) var momentum_damping: float = 0.7

@export_group("Jauge d'erreur et chute (M7.2)")
## QTE à faire pour relever le robot après une chute.
@export var recovery_qte: QteSequence
## Nombre de tours (joueur 1, joueur 2, …) du QTE de relèvement.
@export var recovery_turns: int = 4
## Écart de direction toléré sans remplir la jauge (degrés).
@export var error_free_degrees: float = 15.0
## Remplissage pour un pas dans la direction opposée (180°) ; proportionnel en dessous.
@export var error_per_opposite_step: float = 0.6
## Pénalité en plus quand le désaccord fait trébucher le robot (écart > mismatch_degrees).
@export var error_per_stumble: float = 0.1
## Vidange par seconde quand on marche bien (après error_calm_time sans erreur).
@export var error_decay: float = 0.035
@export var error_calm_time: float = 2.5
## Durées de l'effondrement et du relèvement (s).
@export var fall_time: float = 0.9
@export var get_up_time: float = 1.6

@export_group("Accroupi et saut (M7.5)")
## Accroupi : le corps descend de ça (m), les pas sont raccourcis d'autant, en ce temps (s).
@export var crouch_drop: float = 1.0
@export_range(0.2, 1.0) var crouch_stride_scale: float = 0.55
@export var crouch_time: float = 0.6
## Saut : distance vers l'avant (m), vers les côtés ou l'arrière, hauteur de la cloche (m).
@export var jump_distance: float = 5.5
@export var jump_distance_other: float = 4.0
@export var jump_height: float = 2.2
## Saut : temps d'élan (genoux pliés), de vol et de réception (s), et descente du corps à l'élan (m).
@export var jump_prep_time: float = 0.35
@export var jump_air_time: float = 1.0
@export var jump_land_time: float = 0.45
@export var jump_dip: float = 0.6

## Où le pied va se poser, et s'il est en l'air (pour la marque lumineuse). Autorité : hôte.
var landing_left: Vector3 = Vector3.ZERO
var landing_right: Vector3 = Vector3.ZERO
var swinging_left: bool = false
var swinging_right: bool = false
## Jauge d'erreur (0 = tout va bien, 1 = chute) et phase. Autorité : hôte (synchronisés).
var error_gauge: float = 0.0
var phase: Phase = Phase.WALKING
## À qui le tour de faire un pas (voyant vert sur la console) : 0 = gauche, 1 = droite, -1 = les deux.
## Autorité : hôte (synchronisé).
var next_leg: int = -1
## Accroupi (QTE de l'accroupi réussi, jusqu'à ce que les deux rappuient sur ↓). Autorité : hôte (synchronisé).
var crouched: bool = false

## Hôte : 0 = debout, 1 = tout à fait accroupi (suit `crouched` en douceur).
var _crouch_amount: float = 0.0
## Hôte : saut en cours (départ et arrivée du centre des hanches).
var _jump_from: Vector3 = Vector3.ZERO
var _jump_to: Vector3 = Vector3.ZERO
var _phase_time: float = 0.0
var _last_error_time: float = -10.0

var _feet: Array[Foot] = []
var _armed: Array[bool] = [true, true]
## Angle de pas demandé par chaque joystick, en attente (NAN = rien).
var _pending: Array[float] = [NAN, NAN]
var _pending_time: Array[float] = [0.0, 0.0]
var _last_step_time: float = -10.0
var _last_step_angle: float = 0.0
var _last_step_leg: int = -1
var _stumble: float = 0.0
var _time: float = 0.0
var _yaw: float = 0.0
var _hip_center: Vector3
## Vitesse du corps au sol (x, z), pour l'élan entre deux pas.
var _body_velocity: Vector2 = Vector2.ZERO
var _ready_done: bool = false

@onready var _foot_nodes: Array[Node3D] = [$FootL as Node3D, $FootR as Node3D]


func _ready() -> void:
	for node: Node3D in _foot_nodes:
		node.top_level = true
		(node.get_node("NetSmoother") as NetSmoother).world_space = true   # les pieds restent dans le monde
	if recovery_qte != null:
		recovery_qte.completed.connect(_on_recovery_completed)
	# Les pieds se posent au sol une fois le mécha placé (après le premier tour de physique).
	_init_feet.call_deferred()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not _ready_done:
		return
	_time += delta
	_phase_time += delta
	_stumble = maxf(0.0, _stumble - delta)
	_crouch_amount = move_toward(_crouch_amount, 1.0 if crouched else 0.0, delta / crouch_time)
	match phase:
		Phase.WALKING:
			if recovery_qte != null and recovery_qte.active:
				# QTE du saut ou de l'accroupi : les joysticks servent au QTE, pas à marcher. Il faudra les
				# relâcher avant le prochain pas.
				_armed = [false, false]
				_pending = [NAN, NAN]
			else:
				_read_stick(Leg.LEFT, stick_left)
				_read_stick(Leg.RIGHT, stick_right)
			for leg: int in 2:
				_try_pending(leg)
			# Plus de pas depuis un moment : les deux peuvent repartir.
			if _time - _last_step_time > 2.0 or _stumble > 0.0:
				next_leg = -1
			if _time - _last_error_time > error_calm_time:
				error_gauge = maxf(0.0, error_gauge - error_decay * delta)
		Phase.FALLING:
			if _phase_time >= fall_time:
				_set_phase(Phase.FALLEN)
				if recovery_qte != null:
					recovery_qte.start_random(recovery_turns)
		Phase.GETTING_UP:
			if _phase_time >= get_up_time:
				_set_phase(Phase.WALKING)
				got_up.emit()
		Phase.JUMPING:
			if _phase_time >= jump_prep_time + jump_air_time + jump_land_time:
				_end_jump()
	if phase == Phase.JUMPING:
		_place_jump()
	else:
		for leg: int in 2:
			_advance_swing(leg, delta)
		_place_body(delta)
	_publish()


## Vrai si le robot peut lancer un saut ou s'accroupir (il marche, aucun pied en l'air).
func can_maneuver() -> bool:
	return _ready_done and phase == Phase.WALKING and not _feet[Leg.LEFT].swing and not _feet[Leg.RIGHT].swing


## Hôte : la jauge d'erreur monte de `amount` (QTE raté…) ; pleine, le robot tombe.
func add_error(amount: float) -> void:
	if phase != Phase.WALKING:
		return
	error_gauge = minf(1.0, error_gauge + amount)
	_last_error_time = _time
	if error_gauge >= 1.0:
		fall()


## Hôte : le robot s'accroupit (QTE réussi) ou se relève. Le corps descend / remonte en douceur.
func set_crouched(value: bool) -> void:
	if not value and crouched and not _can_stand():
		_refuse()   # sous une poutre : il reste accroupi
		return
	crouched = value


## Hôte : le robot saute vers `angle` (radians, repère du robot : 0 = vers l'avant, positif = vers la droite).
## Élan genoux pliés, vol en cloche, réception amortie ; les pieds se posent à l'arrivée.
func jump(angle: float) -> void:
	if not can_maneuver():
		return
	var forward: bool = absf(angle) <= deg_to_rad(30.0)
	var distance: float = jump_distance if forward else jump_distance_other
	var move: Vector3 = Basis(Vector3.UP, _yaw) * Vector3(sin(angle), 0.0, -cos(angle)) * distance
	# Il ne saute ni dans un obstacle (fossé, mur), ni en se relevant sous une poutre.
	var landing: Array[Vector3] = [_ground_at(_feet[Leg.LEFT].pos + move), _ground_at(_feet[Leg.RIGHT].pos + move)]
	var landing_mid: Vector3 = (landing[0] + landing[1]) / 2.0
	if (crouched and not _can_stand()) or _feet_in_obstacle(landing) \
			or _body_hits_obstacle(landing_mid, _feet_yaw(), BODY_TOP):
		_refuse()
		return
	crouched = false
	_crouch_amount = 0.0
	for foot: Foot in _feet:
		foot.from = foot.pos
		foot.to = _ground_at(foot.pos + move)
		foot.from_yaw = foot.yaw
		foot.to_yaw = foot.yaw
		foot.t = 0.0
	_jump_from = _hip_center
	var ground_y: float = (_feet[Leg.LEFT].to.y + _feet[Leg.RIGHT].to.y) / 2.0
	var mid: Vector3 = (_feet[Leg.LEFT].to + _feet[Leg.RIGHT].to) / 2.0
	_jump_to = Vector3(mid.x, ground_y + HIP_HEIGHT, mid.z)
	_set_phase(Phase.JUMPING)


## Hôte : fait tomber le robot tout de suite (utilisé par la jauge pleine, et pour les tests).
func fall() -> void:
	if phase != Phase.WALKING:
		return
	crouched = crouched and not _can_stand()   # sous une poutre, il se relèvera accroupi
	error_gauge = 1.0
	_pending = [NAN, NAN]
	_set_phase(Phase.FALLING)
	fell.emit()


## Hôte : replace le robot debout en `xform` (changement de niveau : camp ↔ mission), pieds reposés au sol.
## Attend une étape physique pour que le sol d'un niveau tout juste chargé soit pris en compte.
func reset_to(xform: Transform3D) -> void:
	if not multiplayer.is_server():
		return
	_ready_done = false
	body.global_transform = xform
	body.reset_physics_interpolation()
	await get_tree().physics_frame
	_pending = [NAN, NAN]
	_stumble = 0.0
	error_gauge = 0.0
	crouched = false
	_crouch_amount = 0.0
	_body_velocity = Vector2.ZERO
	_last_step_leg = -1
	_set_phase(Phase.WALKING)
	_init_feet()


## Pied (contact au sol) et orientation, en global, tels qu'affichés (lissés chez les clients).
func get_foot_transform(leg: int) -> Transform3D:
	return _foot_nodes[leg].get_global_transform_interpolated()


func _init_feet() -> void:
	_yaw = body.global_rotation.y
	var basis: Basis = Basis(Vector3.UP, _yaw)
	_hip_center = body.global_position + basis * Vector3(0.0, HIP_LOCAL[0].y, 0.0)
	_feet.clear()
	for leg: int in 2:
		var hip: Vector3 = body.global_position + basis * HIP_LOCAL[leg]
		var ground: Vector3 = _ground_at(hip)
		_feet.append(Foot.new(ground, _yaw))
	_ready_done = true
	if multiplayer.is_server():
		_place_body(1.0)
		_publish()


func _read_stick(leg: int, stick: Lever) -> void:
	if stick == null:
		return
	var value: Vector2 = stick.value
	if value.length() < RELEASE:
		_armed[leg] = true
	elif value.length() > TRIGGER and _armed[leg]:
		_armed[leg] = false
		# 0 = vers l'avant (le hublot), positif = vers la droite.
		_pending[leg] = atan2(value.x, value.y)
		_pending_time[leg] = _time


func _try_pending(leg: int) -> void:
	if is_nan(_pending[leg]):
		return
	if _stumble > 0.0:
		_pending[leg] = NAN
		return
	var other: int = 1 - leg
	if _feet[leg].swing or _feet[other].swing:
		# Deux pieds en l'air : interdit, on attend. Le délai ne court qu'une fois les pieds posés (un pas dure
		# plus longtemps que `buffer_time` : poussé juste après l'autre joueur, le pas était perdu).
		_pending_time[leg] = _time
		return
	if _time - _pending_time[leg] > buffer_time:
		_pending[leg] = NAN
		return
	var angle: float = _pending[leg]
	_pending[leg] = NAN
	# Décalage avec le pas précédent de l'autre jambe : la jauge d'erreur monte selon l'écart.
	if _last_step_leg == other and _time - _last_step_time < 1.5:
		var gap: float = rad_to_deg(absf(angle_difference(angle, _last_step_angle)))
		if gap > error_free_degrees:
			var penalty: float = (gap - error_free_degrees) / (180.0 - error_free_degrees) * error_per_opposite_step
			# Gros désaccord : en plus, il trébuche (pénalité en plus, et le pas est perdu).
			if gap > mismatch_degrees:
				penalty += error_per_stumble
			error_gauge = minf(1.0, error_gauge + penalty)
			_last_error_time = _time
			if error_gauge >= 1.0:
				fall()
				return
		if gap > mismatch_degrees:
			_stumble = 0.9
			_last_step_leg = -1
			stumbled.emit()
			return
	_start_step(leg, angle)


func _start_step(leg: int, angle: float) -> void:
	var other: int = 1 - leg
	var a: float = absf(angle)
	var side: float = signf(angle)
	var advance: float = 0.0
	var turn: float = 0.0
	# Plus on enchaîne vite après l'autre jambe, plus le pas est long.
	var since: float = _time - _last_step_time if _last_step_leg == other else 10.0
	var stride: float = lerpf(stride_fast, stride_slow, clampf((since - 0.45) / 0.8, 0.0, 1.0))
	stride *= lerpf(1.0, crouch_stride_scale, _crouch_amount)   # accroupi : petits pas
	if a <= deg_to_rad(30.0):
		advance = stride
	elif a <= deg_to_rad(70.0):
		advance = stride * 0.8
		turn = turn_step_degrees
	elif a <= deg_to_rad(110.0):
		turn = pivot_step_degrees
	elif a <= deg_to_rad(150.0):
		advance = -stride_back * 0.8
		turn = turn_step_degrees
	else:
		advance = -stride_back
	# Vers la droite (angle positif) = rotation horaire vue de dessus = lacet négatif.
	# La rotation part du pied resté au sol : en alternant, chaque pas tourne le robot de `turn` ;
	# un seul joueur ne peut pas dépasser `turn` d'écart avec l'autre pied (il piétine).
	var other_yaw: float = _feet[other].yaw
	var new_yaw: float = other_yaw - side * deg_to_rad(turn)
	var basis: Basis = Basis(Vector3.UP, new_yaw)
	var lateral: float = (HIP_LOCAL[leg].x - HIP_LOCAL[other].x)
	var target: Vector3 = Vector3.ZERO
	var free: bool = false
	# Devant un obstacle, on essaie un pas plus court (le robot s'approche à petits pas du bord d'un trou,
	# d'un mur…), tant que ce pas fait encore avancer le pied.
	for scale: float in OBSTACLE_STEP_SCALES:
		target = _ground_at(_feet[other].pos + basis * Vector3(lateral, 0.0, -advance * scale))
		var gain: float = (target - _feet[leg].pos).dot(basis * Vector3(0.0, 0.0, -signf(advance)))
		if scale < 1.0 and (is_zero_approx(advance) or gain < 0.1):
			break
		if not _step_hits_obstacle(_feet[leg].pos, target, _feet[other].pos,
				lerp_angle(other_yaw, new_yaw, 0.5)):
			free = true
			break
	if not free:
		_refuse()
		return
	var foot: Foot = _feet[leg]
	foot.swing = true
	foot.t = 0.0
	foot.from = foot.pos
	foot.to = target
	foot.from_yaw = foot.yaw
	foot.to_yaw = new_yaw
	_last_step_time = _time
	_last_step_angle = angle
	_last_step_leg = leg
	next_leg = 1 - leg   # son voyant s'éteint, feu vert pour l'autre
	stepped.emit(leg)


func _advance_swing(leg: int, delta: float) -> void:
	var foot: Foot = _feet[leg]
	if not foot.swing:
		return
	var t: float = minf(1.0, foot.t + delta / step_time)
	foot.t = t
	var eased: float = t * t * (3.0 - 2.0 * t)
	var pos: Vector3 = (foot.from as Vector3).lerp(foot.to, eased)
	pos.y += sin(PI * t) * lift_height
	foot.pos = pos
	foot.yaw = lerp_angle(foot.from_yaw, foot.to_yaw, eased)
	if t >= 1.0:
		foot.swing = false
		foot.pos = foot.to


## Le corps se place entre les pieds, à la bonne hauteur, et regarde dans leur direction moyenne.
## Élan : un pied qui part compte déjà en partie là où il va se poser (le corps part dès la poussée),
## et le corps suit cette cible avec un ressort amorti qui garde sa vitesse d'un pas à l'autre.
func _place_body(delta: float) -> void:
	var left: Foot = _feet[Leg.LEFT]
	var right: Foot = _feet[Leg.RIGHT]
	var mid: Vector3 = (_lead_pos(left) + _lead_pos(right)) / 2.0
	var roll: float = 0.0
	var dip: float = 0.0
	for leg: int in 2:
		var foot: Foot = _feet[leg]
		if foot.swing:
			var s: float = sin(PI * float(foot.t))
			var planted: Vector3 = _feet[1 - leg].pos
			mid = mid.lerp(Vector3(planted.x, mid.y, planted.z), 0.12 * s)   # un peu de poids sur le pied d'appui
			roll += (-1.0 if leg == Leg.RIGHT else 1.0) * deg_to_rad(3.0) * s
			dip += 0.06 * s
	var target_yaw: float = lerp_angle(left.yaw, right.yaw, 0.5)
	var k: float = 1.0 - exp(-10.0 * delta)
	_yaw = lerp_angle(_yaw, target_yaw, k)
	# Hauteur : hanches à HIP_HEIGHT au-dessus du sol moyen, sans dépasser la portée des jambes.
	var ground_y: float = (minf(left.pos.y, left.to.y) + minf(right.pos.y, right.to.y)) / 2.0
	var crouch: float = _crouch_amount * _crouch_amount * (3.0 - 2.0 * _crouch_amount)
	var hip_y: float = ground_y + HIP_HEIGHT - dip - crouch_drop * crouch
	var basis: Basis = Basis(Vector3.UP, _yaw)
	for leg: int in 2:
		if _feet[leg].swing:
			continue
		var hip: Vector3 = mid + basis * Vector3(HIP_LOCAL[leg].x, 0.0, 0.0)
		var ankle: Vector3 = (_feet[leg].pos as Vector3) + Vector3.UP * ANKLE_HEIGHT
		var flat: float = Vector2(hip.x - ankle.x, hip.z - ankle.z).length()
		hip_y = minf(hip_y, ankle.y + sqrt(maxf(0.0, MAX_REACH * MAX_REACH - flat * flat)))
	# Effondrement (M7.2) : il tombe à genoux, penché vers l'avant, et se relève après le QTE.
	var slump: float = _slump_amount()
	var pitch: float = -deg_to_rad(22.0) * slump
	roll += deg_to_rad(4.0) * slump
	hip_y = lerpf(hip_y, ground_y + 1.35, slump)
	mid += basis * Vector3(0.0, 0.0, -0.45 * slump)
	if phase == Phase.FALLEN:
		pitch += sin(_time * 2.3) * deg_to_rad(0.6)   # il grince un peu par terre
	var wanted: Vector3 = Vector3(mid.x, hip_y, mid.z)
	var follow: float = 1.0 - exp(-(18.0 if phase == Phase.FALLING else 10.0) * delta)
	if delta >= 1.0:
		_hip_center = wanted
		_body_velocity = Vector2.ZERO
	elif phase == Phase.WALKING:
		_hip_center.y = lerpf(_hip_center.y, wanted.y, follow)
		_follow_with_momentum(Vector2(wanted.x, wanted.z), delta)
	else:
		_hip_center = _hip_center.lerp(wanted, follow)
		_body_velocity = Vector2.ZERO
	# Trébuche : le robot vacille.
	if _stumble > 0.0:
		var shake: float = _stumble / 0.9
		roll += sin(_time * 18.0) * deg_to_rad(5.0) * shake
		pitch += sin(_time * 13.0) * deg_to_rad(3.0) * shake
	var full: Basis = Basis.from_euler(Vector3(pitch, _yaw, roll))
	body.global_transform = Transform3D(full, _hip_center - full * Vector3(0.0, HIP_LOCAL[0].y, 0.0))


## Saut : élan (le corps descend, genoux pliés), vol en cloche des hanches et des pieds (pieds un peu repliés),
## réception (le corps descend puis remonte). Les jambes se plient d'elles-mêmes (LegIK, chez chaque peer).
func _place_jump() -> void:
	var t: float = _phase_time
	var up: Vector3 = Vector3.UP
	var low_from: Vector3 = _jump_from - up * jump_dip
	var low_to: Vector3 = _jump_to - up * jump_dip
	var s: float = 0.0   # avancement du vol, 0 à 1
	if t < jump_prep_time:
		_hip_center = _jump_from.lerp(low_from, _smooth(t / jump_prep_time))
	elif t < jump_prep_time + jump_air_time:
		s = (t - jump_prep_time) / jump_air_time
		var arc: float = jump_height * 4.0 * s * (1.0 - s)
		_hip_center = low_from.lerp(low_to, s) + up * arc
		for foot: Foot in _feet:
			foot.swing = true
			foot.pos = (foot.from as Vector3).lerp(foot.to, s) + up * (arc + 0.3 * sin(PI * s))
	else:
		s = 1.0
		for foot: Foot in _feet:
			foot.swing = false
			foot.pos = foot.to
		_hip_center = low_to.lerp(_jump_to, _smooth((t - jump_prep_time - jump_air_time) / jump_land_time))
	_body_velocity = Vector2.ZERO
	# Un peu penché vers l'avant pendant le vol.
	var pitch: float = -deg_to_rad(6.0) * sin(PI * s)
	var full: Basis = Basis.from_euler(Vector3(pitch, _yaw, 0.0))
	body.global_transform = Transform3D(full, _hip_center - full * Vector3(0.0, HIP_LOCAL[0].y, 0.0))


## Fin du saut : pieds posés à l'arrivée, le robot remarche.
func _end_jump() -> void:
	for foot: Foot in _feet:
		foot.swing = false
		foot.pos = foot.to
		foot.from = foot.to
	_hip_center = _jump_to
	_last_step_leg = -1
	_armed = [false, false]
	_set_phase(Phase.WALKING)


static func _smooth(x: float) -> float:
	var c: float = clampf(x, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


## Position d'un pied pour placer le corps : s'il est en l'air, on regarde déjà vers où il va.
func _lead_pos(foot: Foot) -> Vector3:
	if not foot.swing:
		return foot.pos
	return (foot.pos as Vector3).lerp(foot.to, step_lead)


## Ressort amorti (au sol, x et z) : le corps accélère vers sa place et garde un peu d'élan,
## sans jamais s'éloigner de plus de MAX_MOMENTUM_LEAD de sa place entre les pieds.
func _follow_with_momentum(target: Vector2, delta: float) -> void:
	var current: Vector2 = Vector2(_hip_center.x, _hip_center.z)
	var damping: float = 2.0 * momentum_damping * sqrt(momentum_stiffness)
	var accel: Vector2 = (target - current) * momentum_stiffness - _body_velocity * damping
	_body_velocity += accel * delta
	current += _body_velocity * delta
	var offset: Vector2 = current - target
	if offset.length() > MAX_MOMENTUM_LEAD:
		current = target + offset.limit_length(MAX_MOMENTUM_LEAD)
	_hip_center.x = current.x
	_hip_center.z = current.y


## 0 = debout, 1 = effondré à genoux. Petit rebond à l'impact, relèvement en douceur.
func _slump_amount() -> float:
	match phase:
		Phase.FALLING:
			var t: float = clampf(_phase_time / fall_time, 0.0, 1.0)
			return minf(1.0, t * t * 1.15) - 0.08 * sin(PI * clampf((t - 0.75) / 0.25, 0.0, 1.0))
		Phase.FALLEN:
			return 1.0
		Phase.GETTING_UP:
			var u: float = clampf(_phase_time / get_up_time, 0.0, 1.0)
			return 1.0 - u * u * (3.0 - 2.0 * u)
	return 0.0


func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	_phase_time = 0.0
	next_leg = -1
	if new_phase == Phase.FALLING:
		# Un pied en l'air se repose là où il est.
		for foot: Foot in _feet:
			if foot.swing:
				foot.to = _ground_at(foot.pos)
				foot.from = foot.pos
				foot.t = 0.5


func _on_recovery_completed() -> void:
	if phase != Phase.FALLEN:
		return
	error_gauge = 0.0
	_set_phase(Phase.GETTING_UP)


func _publish() -> void:
	for leg: int in 2:
		var foot: Foot = _feet[leg]
		_foot_nodes[leg].global_transform = Transform3D(Basis(Vector3.UP, foot.yaw), foot.pos)
	swinging_left = _feet[Leg.LEFT].swing
	swinging_right = _feet[Leg.RIGHT].swing
	landing_left = _feet[Leg.LEFT].to
	landing_right = _feet[Leg.RIGHT].to


## Pas refusé (obstacle) : il vacille sur place et oublie les pas demandés.
func _refuse() -> void:
	_stumble = maxf(_stumble, 0.4)
	_pending = [NAN, NAN]
	blocked.emit()


## Direction du corps une fois les pieds posés : la moyenne de celles des deux pieds.
func _feet_yaw() -> float:
	return lerp_angle(_feet[Leg.LEFT].to_yaw, _feet[Leg.RIGHT].to_yaw, 0.5)


## Vrai si un pas de `from` à `to` (l'autre pied resté en `planted`, le corps tourné vers `yaw` une fois le
## pied posé) entre dans un obstacle : trajet du pied, ou caisse du corps à sa nouvelle place.
func _step_hits_obstacle(from: Vector3, to: Vector3, planted: Vector3, yaw: float) -> bool:
	if _foot_path_blocked(from, to):
		return true
	var top: float = BODY_TOP - (crouch_drop if crouched else 0.0)
	return _body_hits_obstacle((planted + to) / 2.0, yaw, top)


## Vrai si le robot peut se tenir debout là où il est (rien au-dessus de sa tête).
func _can_stand() -> bool:
	if not _ready_done:
		return true
	var ground: Vector3 = (_feet[Leg.LEFT].to + _feet[Leg.RIGHT].to) / 2.0
	return not _body_hits_obstacle(ground, _feet_yaw(), BODY_TOP, true)


func _foot_path_blocked(from: Vector3, to: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	for height: float in FOOT_CHECK_HEIGHTS:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			from + Vector3.UP * height, to + Vector3.UP * height, OBSTACLE_LAYER)
		query.exclude = _own_bodies()
		if not space.intersect_ray(query).is_empty():
			return true
	return false


func _feet_in_obstacle(points: Array[Vector3]) -> bool:
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	for point: Vector3 in points:
		var query: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
		query.position = point + Vector3.UP * FOOT_CHECK_HEIGHTS[0]
		query.collision_mask = OBSTACLE_LAYER
		query.exclude = _own_bodies()
		if not space.intersect_point(query, 1).is_empty():
			return true
	return false


## Vrai si la caisse du corps, posée au-dessus du point du sol `ground` et tournée vers `yaw`, touche un
## obstacle. Si le corps est déjà franchement dans un obstacle là où il est (plus de STUCK_MARGIN : il y est
## entré par un autre chemin, niveau chargé autour de lui…), on le laisse en sortir, sauf `strict`.
func _body_hits_obstacle(ground: Vector3, yaw: float, top: float, strict: bool = false) -> bool:
	if not strict and _ready_done:
		var here: Vector3 = (_feet[Leg.LEFT].to + _feet[Leg.RIGHT].to) / 2.0
		var here_top: float = BODY_TOP - (crouch_drop if crouched else 0.0)
		if _box_overlaps(here, _feet_yaw(), here_top, STUCK_MARGIN):
			return false
	return _box_overlaps(ground, yaw, top)


## `shrink` : la caisse est rentrée d'autant sur chaque face.
func _box_overlaps(ground: Vector3, yaw: float, top: float, shrink: float = 0.0) -> bool:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(BODY_HALF.x * 2.0, top - BODY_BOTTOM, BODY_HALF.y * 2.0) - Vector3.ONE * 2.0 * shrink
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(Vector3.UP, yaw), ground + Vector3.UP * (BODY_BOTTOM + top) / 2.0)
	query.collision_mask = OBSTACLE_LAYER
	query.exclude = _own_bodies()
	return not body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## Point du sol sous `point` (rayon vertical qui ignore le mécha lui-même).
func _ground_at(point: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * 1.5, point + Vector3.DOWN * 4.0, 1)
	query.exclude = _own_bodies()
	var hit: Dictionary = space.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else Vector3(point.x, point.y - ANKLE_HEIGHT, point.z)


func _own_bodies() -> Array[RID]:
	var rids: Array[RID] = []
	for node: Node in body.find_children("*", "CollisionObject3D", true, false):
		rids.append((node as CollisionObject3D).get_rid())
	for node: Node in get_tree().get_nodes_in_group(&"dwarves"):
		if node is CollisionObject3D:
			rids.append((node as CollisionObject3D).get_rid())
	return rids


## Un pied (hôte) : place et orientation au sol, et le pas en cours quand il est en l'air.
class Foot:
	var pos: Vector3
	var yaw: float
	## En l'air, avancement du pas (0..1), départ et arrivée.
	var swing: bool = false
	var t: float = 0.0
	var from: Vector3
	var to: Vector3
	var from_yaw: float
	var to_yaw: float

	func _init(ground: Vector3, ground_yaw: float) -> void:
		pos = ground
		from = ground
		to = ground
		yaw = ground_yaw
		from_yaw = ground_yaw
		to_yaw = ground_yaw
