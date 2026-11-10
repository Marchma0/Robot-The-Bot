class_name DwarfCamera
extends Node
## Caméra du joueur local, à la première personne façon Lethal Company : les yeux suivent en partie l'os de
## la tête (la vue vit avec la marche, l'accroupi, l'assise), on voit son propre corps en baissant les yeux,
## la tête ne garde que son ombre (DwarfLook). Petit à-coup du « clac » des
## joysticks des jambes, et traveling jusqu'à l'écran d'un poste quand on s'y assoit (puis plein écran sur la
## caméra du bras).
##
## Réseau : rien. Purement local, actif seulement sur le nain du joueur (`activate`).

## Position des yeux devant le centre du corps (m, -Z = devant) : regard droit / regard vers le bas.
## Les yeux sont au-dessus de l'avant du torse (qui va à 0,25 m, 0,29 m penché en marchant) : sinon
## le haut des épaules entre dans le bas de l'image avec l'angle de vue de 90°.
const EYE_FORWARD: float = -0.2
const EYE_FORWARD_LOOKING_DOWN: float = -0.36
## Objet tenu à une main (bras tendu devant soi) : les yeux reculent, sinon la main passe sous le bas de
## l'image (et à côté en regardant en haut) ; le bras tendu cache déjà le haut de l'épaule.
const EYE_FORWARD_HOLDING: float = -0.08
## Vitesse à laquelle les yeux avancent ou reculent quand on prend / range un objet (m/s).
const EYE_SHIFT_SPEED: float = 0.6
## Inclinaison vers le bas (rad) à partir de laquelle les yeux sont tout à fait avancés.
const LOOK_DOWN_FULL: float = Dwarf.MAX_PITCH_DOWN
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
## Part du mouvement de la tête suivie par les yeux (1 = tout, la vue balancerait trop en marchant).
const HEAD_FOLLOW_AMOUNT: float = 0.5

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
## Avancée des yeux en regard droit (EYE_FORWARD, ou EYE_FORWARD_HOLDING avec un objet en main), lissée.
var _eye_forward: float = EYE_FORWARD


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	# En baissant les yeux, le point de vue avance un peu (on regarde par-dessus son ventre).
	var looking_down: float = clampf(-head.rotation.x / LOOK_DOWN_FULL, 0.0, 1.0)
	var wanted_forward: float = EYE_FORWARD_HOLDING if dwarf.anim_hold_item else EYE_FORWARD
	_eye_forward = move_toward(_eye_forward, wanted_forward, delta * EYE_SHIFT_SPEED)
	head.position.z = lerpf(_eye_forward, EYE_FORWARD_LOOKING_DOWN, looking_down)
	# Les yeux descendent / remontent en douceur quand on s'accroupit / se relève.
	var eye_height: float = CROUCH_EYE_HEIGHT if dwarf.anim_crouching else EYE_HEIGHT
	head.position.y = move_toward(head.position.y, eye_height, delta * 2.5)
	camera.global_transform = _eyes_view(delta)
	_apply_kick_nudge(delta)
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
	var rest_eye: Vector3 = Vector3(0.0, head.position.y, head.position.z)
	eye_local = rest_eye.lerp(eye_local, HEAD_FOLLOW_AMOUNT)
	# L'avancée du regard vers le bas ne doit pas être amortie par l'os de la tête (qui ne la connaît pas) :
	# sinon les yeux restent au-dessus des épaules et on ne voit que le haut de son torse.
	eye_local.z += (head.position.z - EYE_FORWARD) * HEAD_FOLLOW_AMOUNT
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

