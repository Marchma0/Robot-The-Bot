class_name DwarfCamera
extends Node
## Caméra du joueur local, à la première personne façon Lethal Company : les yeux suivent l'os de la tête
## (la vue bouge avec la marche, l'accroupi, l'assise…), on ne voit de soi que ses bras (DwarfLook) ; pendant
## une emote, la caméra sort de trois quarts devant le nain, pour qu'on se voie la faire. Petit à-coup du « clac » des joysticks des jambes, et traveling
## jusqu'à l'écran d'un poste quand on s'y assoit (puis plein écran sur la caméra du bras).
##
## Réseau : rien. Purement local, actif seulement sur le nain du joueur (`activate`).

## Position des yeux devant le centre du corps (m, -Z = devant) : regard droit / regard vers le bas.
const EYE_FORWARD: float = -0.08
const EYE_FORWARD_LOOKING_DOWN: float = -0.3
## Inclinaison vers le bas (rad) à partir de laquelle les yeux sont tout à fait avancés.
const LOOK_DOWN_FULL: float = deg_to_rad(60.0)
## Hauteur des yeux debout / accroupi (m).
const EYE_HEIGHT: float = 0.95
const CROUCH_EYE_HEIGHT: float = 0.7
## Durée du traveling de caméra vers l'écran d'un poste (aller / retour), en secondes.
const CAMERA_TRAVEL_IN: float = 0.9
const CAMERA_TRAVEL_OUT: float = 0.55
## « Clac » du joystick des jambes : amplitude de l'à-coup de vue (rad) et vitesse d'amortissement.
const KICK_NUDGE: float = 0.035
const KICK_NUDGE_DAMP: float = 9.0
## Suivi de l'os de la tête : amorti (plus grand = plus collé aux mouvements de l'animation).
const HEAD_FOLLOW_SHARPNESS: float = 18.0
## Emote : caméra à la troisième personne, de trois quarts devant le nain (repère du nain, -Z = devant),
## qui regarde sa poitrine ; durée du passage d'une vue à l'autre (s).
const THIRD_PERSON_OFFSET: Vector3 = Vector3(0.55, 0.9, -1.4)
const THIRD_PERSON_TARGET: Vector3 = Vector3(0.0, 0.8, 0.0)
const THIRD_PERSON_BLEND: float = 0.3
## Distance gardée entre la caméra et un mur qui la gêne (m).
const WALL_MARGIN: float = 0.15

@export var dwarf: Dwarf
## Les yeux (tangage du regard) et la caméra qui y est accrochée.
@export var head: Node3D
@export var camera: Camera3D
@export var look: DwarfLook
## Os de la tête (avec l'inclinaison du regard) : les yeux le suivent.
@export var head_bone: Node3D

var _crosshair: Control = null
var _pov_active: bool = false
## Traveling : poste concerné, avancement (0 = yeux du nain, 1 = collé à l'écran),
## sens (+1 on s'assoit, -1 on se lève, 0 à l'arrêt), départ (repère du siège).
var _view_seat: Seat = null
var _travel: float = 0.0
var _travel_dir: int = 0
var _travel_from: Transform3D = Transform3D.IDENTITY
## Petit à-coup de la vue (rad, x = lacet, y = tangage) qui s'amortit.
var _kick_nudge: Vector2 = Vector2.ZERO
## Place des yeux dans le repère de l'os de la tête, et place lissée des yeux dans le repère du nain.
var _eye_in_head: Vector3 = Vector3.ZERO
var _eye_smoothed: Vector3 = Vector3.ZERO
var _eye_ready: bool = false
## Passage à la troisième personne (0 = yeux, 1 = vue de l'emote).
var _third: float = 0.0


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	# En baissant les yeux, le point de vue avance pour regarder par-dessus le ventre
	# (sinon le haut de la tunique bouche tout l'écran).
	var looking_down: float = clampf(-head.rotation.x / LOOK_DOWN_FULL, 0.0, 1.0)
	head.position.z = lerpf(EYE_FORWARD, EYE_FORWARD_LOOKING_DOWN, looking_down)
	# Les yeux descendent / remontent en douceur quand on s'accroupit / se relève.
	var eye_height: float = CROUCH_EYE_HEIGHT if dwarf.anim_crouching else EYE_HEIGHT
	head.position.y = move_toward(head.position.y, eye_height, delta * 2.5)
	camera.global_transform = _eyes_view(delta)
	_apply_kick_nudge(delta)
	_update_third_person(delta)
	_update_travel(delta)


## Joueur local : cette caméra devient la vue du jeu. `crosshair` : le viseur, caché sur l'image d'un poste.
func activate(crosshair: Control) -> void:
	_crosshair = crosshair
	camera.current = true
	# La caméra est replacée à chaque image : pas de lissage physique sur elle.
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_eye_in_head = _rest_eye_in_head()
	set_process(true)


## À chaque étape : assis à un poste, traveling jusqu'à son écran puis plein écran sur sa caméra.
## Debout (`seat` null ou simple siège) : caméra du nain.
func update_view(seat: Seat) -> void:
	var want_pov: bool = seat != null and seat.get_pov_camera() != null
	if want_pov == _pov_active:
		return
	_pov_active = want_pov
	if _crosshair != null:
		_crosshair.visible = not want_pov
	if want_pov:
		_view_seat = seat
		_travel = 0.0
		_travel_dir = 1
		_travel_from = seat.global_transform.affine_inverse() * camera.global_transform
	elif _view_seat != null:
		# On se lève : on quitte l'image du poste, la caméra recule de l'écran jusqu'aux yeux.
		_view_seat.set_overlay_visible(false)
		camera.current = true
		_travel_dir = -1



## Vrai pendant la vue à la troisième personne d'une emote (on ne vise plus rien).
func is_third_person() -> bool:
	return _third > 0.0

## « Clac » d'un joystick des jambes : la vue est poussée un instant dans son sens
## (avant = elle plonge, comme le robot qui part).
func kick(direction: Vector2) -> void:
	_kick_nudge = Vector2(-direction.x, -direction.y) * KICK_NUDGE


func _apply_kick_nudge(delta: float) -> void:
	if _kick_nudge.length_squared() < 0.000001:
		return
	camera.global_basis = camera.global_basis * Basis.from_euler(Vector3(_kick_nudge.y, _kick_nudge.x, 0.0))
	_kick_nudge = _kick_nudge.lerp(Vector2.ZERO, 1.0 - exp(-KICK_NUDGE_DAMP * delta))


## Traveling entre les yeux du nain et l'écran du poste (à chaque image, après la place des yeux).
func _update_travel(delta: float) -> void:
	if _view_seat != null and not is_instance_valid(_view_seat):
		_view_seat = null
		_travel_dir = 0
	# Pendant le traveling, la caméra passe à travers les bras du nain : on ne garde que son ombre.
	look.set_body_hidden(_view_seat != null)
	if _travel_dir == 0 or _view_seat == null:
		return
	var duration: float = CAMERA_TRAVEL_IN if _travel_dir > 0 else CAMERA_TRAVEL_OUT
	_travel = clampf(_travel + float(_travel_dir) * delta / duration, 0.0, 1.0)
	var screen: Transform3D = _view_seat.get_screen_view_transform(camera.fov)
	var from: Transform3D = camera.global_transform   # retour : les yeux, tels qu'ils sont maintenant
	if _travel_dir > 0:
		from = _view_seat.get_global_transform_interpolated() * _travel_from
	camera.global_transform = from.interpolate_with(screen, smoothstep(0.0, 1.0, _travel))
	if _travel_dir > 0 and _travel >= 1.0:
		# Arrivé contre l'écran : on bascule sur la caméra du bras, qui s'allume dans la neige.
		_travel_dir = 0
		_view_seat.get_pov_camera().current = true
		_view_seat.set_overlay_visible(true)
		_view_seat.flash_static(1.0)
	elif _travel_dir < 0 and _travel <= 0.0:
		_travel_dir = 0
		_view_seat = null


## Les yeux : sur l'os de la tête (animé), un peu amortis ; orientation = celle du regard (souris sans retard).
## Le corps est affiché lissé entre deux étapes physiques : on suit cette position lissée.
func _eyes_view(delta: float) -> Transform3D:
	var view: Transform3D = dwarf.view_transform()
	var body: Transform3D = dwarf.get_global_transform_interpolated()
	var eye_local: Vector3 = body.affine_inverse() * (head_bone.get_global_transform_interpolated() * _eye_in_head)
	if not _eye_ready:
		_eye_smoothed = eye_local
		_eye_ready = true
	_eye_smoothed = _eye_smoothed.lerp(eye_local, 1.0 - exp(-HEAD_FOLLOW_SHARPNESS * delta))
	return Transform3D(view.basis, body * _eye_smoothed)


## Place des yeux (`head`, au repos) dans le repère de l'os de la tête au repos.
func _rest_eye_in_head() -> Vector3:
	var skeleton: Skeleton3D = head_bone.get_parent().get_parent() as Skeleton3D
	var bone: int = skeleton.find_bone("head")
	var head_rest: Transform3D = skeleton.global_transform * skeleton.get_bone_global_rest(bone)
	var rest_eye: Vector3 = dwarf.global_transform * Vector3(0.0, EYE_HEIGHT, EYE_FORWARD)
	return head_rest.affine_inverse() * rest_eye


## Emote en cours : la caméra glisse jusqu'à une vue de trois quarts devant le nain (sans traverser les murs),
## puis revient aux yeux quand l'emote s'arrête.
func _update_third_person(delta: float) -> void:
	var want: bool = dwarf.anim_emote != Emotes.NONE and _view_seat == null and not _pov_active
	_third = move_toward(_third, 1.0 if want else 0.0, delta / THIRD_PERSON_BLEND)
	look.set_third_person(_third > 0.2)
	if _crosshair != null:
		_crosshair.visible = not _pov_active and _third <= 0.0
	if _third <= 0.0:
		return
	var body: Transform3D = dwarf.get_global_transform_interpolated()
	var target: Vector3 = body * THIRD_PERSON_TARGET
	var spot: Vector3 = body * THIRD_PERSON_OFFSET
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(target, spot, 1, [dwarf.get_rid()])
	var hit: Dictionary = dwarf.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		spot = (hit["position"] as Vector3) + (target - spot).normalized() * WALL_MARGIN
	var third: Transform3D = Transform3D(Basis.looking_at(target - spot, body.basis.y), spot)
	camera.global_transform = camera.global_transform.interpolate_with(third, smoothstep(0.0, 1.0, _third))
