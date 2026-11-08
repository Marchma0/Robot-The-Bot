class_name DwarfViewArms
extends Node3D
## Bras de vue du joueur local (première personne, façon Lethal Company / Deep Rock Galactic) : un modèle de bras
## à part (`dwarf_fp_arms.glb`, même squelette et mêmes animations que le nain), accroché à la caméra. Ils
## montent dans le champ pendant un geste (appuyer, tenir un levier, lancer, emote, danse) et redescendent hors
## de la vue sinon : en marchant ou en regardant ses pieds, on ne voit pas ses bras pendre sur les côtés.
##
## Réseau : rien. Ne lit que l'état d'animation déjà synchronisé du nain ; n'existe que chez le joueur local
## (les autres voient le corps entier du nain, qui joue les mêmes animations).

const ARMS_SCENE: PackedScene = preload("res://assets/models/dwarf_fp_arms.glb")
## Yeux du nain dans le repère du modèle (comme `DwarfCamera.EYE_HEIGHT` / `EYE_FORWARD`) : ils sont posés sur
## la caméra, décalés de `VIEW_OFFSET` (repère de la caméra) pour que les gestes tombent dans le champ.
const EYE_IN_MODEL: Vector3 = Vector3(0.0, 0.95, -0.08)
const VIEW_OFFSET: Vector3 = Vector3(0.0, 0.05, -0.06)
## Les épaules du nain sont larges : les bras de vue sont resserrés vers le centre de l'écran.
const VIEW_SQUEEZE: float = 0.7
## Bras rangés : descendus de tant (m) sous la vue.
const LOWERED_DROP: float = 0.55
## Durée de montée / descente des bras (s).
const RAISE_TIME: float = 0.16
## Durée pendant laquelle les bras restent levés après un appui ou un lancer (s).
const PRESS_HOLD: float = 0.55
const THROW_HOLD: float = 0.8
## Cadrage propre à certaines emotes (décalage des bras, repère de la caméra) : un geste près de la tête ou sur
## les côtés est ramené devant soi pour qu'on le voie.
const EMOTE_OFFSETS: Dictionary[StringName, Vector3] = {
	&"emote_wave": Vector3(-0.12, -0.15, -0.4),
	&"emote_salute": Vector3(-0.05, 0.14, -0.1),
	&"emote_shrug": Vector3(0.0, 0.25, -0.35),
	&"emote_clap": Vector3(0.0, -0.02, -0.28),
	&"emote_dance": Vector3(0.0, -0.08, -0.38),
}
const OFFSET_SHARPNESS: float = 10.0

var dwarf: Dwarf

var _model: Node3D
var _skeleton: Skeleton3D
var _torso: int = -1
var _raise: float = 0.0
var _hold_timer: float = 0.0
var _last_press: int = 0
var _last_throw: int = 0
var _emote_offset: Vector3 = Vector3.ZERO


## Crée les bras sous la caméra `camera` du nain `p_dwarf`, à la couleur du joueur.
func setup(p_dwarf: Dwarf, camera: Camera3D, look: DwarfLook, slot: int) -> void:
	dwarf = p_dwarf
	name = "ViewArms"
	camera.add_child(self)
	_model = ARMS_SCENE.instantiate() as Node3D
	add_child(_model)
	_model.scale = Vector3(VIEW_SQUEEZE, 1.0, 1.0)
	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	_torso = _skeleton.find_bone("torso") if _skeleton != null else -1
	for mesh: MeshInstance3D in DwarfLook.meshes_of(_model):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	look.tint_model(_model, slot)
	var animator: DwarfAnimator = DwarfAnimator.new()
	animator.name = "ViewArmsAnimator"
	animator.dwarf = dwarf
	animator.body_model = _model
	animator.view_arms = true
	add_child(animator)
	_last_press = dwarf.anim_press_count
	_last_throw = dwarf.anim_throw_count
	visible = false


## Vrai quand les bras sont (au moins en partie) dans le champ.
func is_raised() -> bool:
	return _raise > 0.0


func _process(delta: float) -> void:
	if dwarf.anim_press_count != _last_press:
		_last_press = dwarf.anim_press_count
		_hold_timer = maxf(_hold_timer, PRESS_HOLD)
	if dwarf.anim_throw_count != _last_throw:
		_last_throw = dwarf.anim_throw_count
		_hold_timer = maxf(_hold_timer, THROW_HOLD)
	_hold_timer = maxf(_hold_timer - delta, 0.0)
	# (assis à un poste à écran, la caméra n'est plus celle des yeux : les bras ne se voient pas)
	var wanted: bool = (dwarf.anim_emote != Emotes.NONE or dwarf.anim_holding \
			or _hold_timer > 0.0)
	_raise = move_toward(_raise, 1.0 if wanted else 0.0, delta / RAISE_TIME)
	visible = _raise > 0.0
	if not visible:
		return
	# Le torse peut monter / descendre avec l'animation : on le garde fixe dans la vue.
	var torso_shift: Vector3 = Vector3.ZERO
	if _torso >= 0:
		torso_shift = _skeleton.get_bone_global_pose(_torso).origin - _skeleton.get_bone_global_rest(_torso).origin
	var wanted_offset: Vector3 = Vector3.ZERO
	if Emotes.is_valid(dwarf.anim_emote):
		wanted_offset = EMOTE_OFFSETS.get(Emotes.LIST[dwarf.anim_emote]["animation"], Vector3.ZERO)
	_emote_offset = _emote_offset.lerp(wanted_offset, 1.0 - exp(-OFFSET_SHARPNESS * delta))
	var drop: float = LOWERED_DROP * (1.0 - smoothstep(0.0, 1.0, _raise))
	_model.position = VIEW_OFFSET + _emote_offset - EYE_IN_MODEL - torso_shift + Vector3(0.0, -drop, 0.0)
