class_name DwarfAnimator
extends Node
## Anime le corps du nain à partir de son ÉTAT (vitesse, en l'air, tient un levier,
## assis, compteur d'appuis). Cet état est synchronisé par le nain ; chaque peer
## joue l'animation localement (on ne synchronise jamais l'animation elle-même).
##
## AnimationTree construit en code :
##   base  = machine à états idle / walk / air / sit (fondus)
##   grab  = Blend2 filtré sur le bras droit (tenir un levier, même en marchant)
##   press = OneShot filtré sur le bras droit (appuyer sur un bouton)

const LOOPING: Array[StringName] = [&"idle", &"walk"]
const STATE_ANIMATIONS: Dictionary[StringName, StringName] = {
	&"idle": &"idle", &"walk": &"walk", &"air": &"jump", &"sit": &"sit",
}
## Os animés par la couche haut du corps (tenir / appuyer).
const ARM_TRACK: NodePath = ^"DwarfRig/Skeleton3D:arm_R"
const CROSSFADE: float = 0.15
## En dessous de cette vitesse (m/s), le nain est considéré à l'arrêt.
const WALK_THRESHOLD: float = 0.3

@export var dwarf: Dwarf
@export var body_model: Node3D
## Vitesse (m/s) à laquelle l'animation de marche joue à vitesse normale.
@export var walk_reference_speed: float = 2.0
## Bac à sable : force un état ("idle", "walk", "air", "sit", "grab", "press"), sinon vide.
@export var preview_state: String = ""

var _tree: AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var _grab_amount: float = 0.0
var _last_press_count: int = 0
var _preview_timer: float = 0.0


func _ready() -> void:
	var player: AnimationPlayer = body_model.find_children("*", "AnimationPlayer", true, false)[0]
	for anim_name: StringName in LOOPING:
		player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	body_model.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(player)
	_tree.tree_root = _build_tree()
	_tree.active = true
	_playback = _tree.get("parameters/base/playback")


func _process(delta: float) -> void:
	# Purement visuel : lit l'état et pilote l'AnimationTree.
	var speed: float = dwarf.anim_speed
	var airborne: bool = dwarf.anim_airborne
	var seated: bool = dwarf.anim_seated
	var holding: bool = dwarf.anim_holding
	var press_count: int = dwarf.anim_press_count
	if preview_state != "":
		_preview_timer += delta
		speed = walk_reference_speed if preview_state == "walk" else 0.0
		airborne = preview_state == "air"
		seated = preview_state == "sit"
		holding = preview_state == "grab"
		press_count = int(_preview_timer / 1.2) if preview_state == "press" else 0

	var target: StringName = &"idle"
	if seated:
		target = &"sit"
	elif airborne:
		target = &"air"
	elif speed > WALK_THRESHOLD:
		target = &"walk"
	if _playback.get_current_node() != target:
		_playback.travel(target)
	_tree.set("parameters/base/walk/scale/scale", clampf(speed / walk_reference_speed, 0.6, 2.0))

	_grab_amount = move_toward(_grab_amount, 1.0 if holding else 0.0, delta * 6.0)
	_tree.set("parameters/grab/blend_amount", _grab_amount)

	if press_count != _last_press_count:
		_last_press_count = press_count
		_tree.set("parameters/press/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _build_tree() -> AnimationNodeBlendTree:
	var machine: AnimationNodeStateMachine = AnimationNodeStateMachine.new()
	var x: float = 0.0
	for state: StringName in STATE_ANIMATIONS:
		var node: AnimationRootNode = _animation_node(STATE_ANIMATIONS[state])
		if state == &"walk":
			# La marche passe par un TimeScale pour suivre la vitesse du nain.
			var walk_tree: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
			walk_tree.add_node(&"anim", node)
			walk_tree.add_node(&"scale", AnimationNodeTimeScale.new())
			walk_tree.connect_node(&"scale", 0, &"anim")
			walk_tree.connect_node(&"output", 0, &"scale")
			node = walk_tree
		machine.add_node(state, node, Vector2(x, 0.0))
		x += 200.0
	var start: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
	start.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	machine.add_transition(&"Start", &"idle", start)
	for from: StringName in STATE_ANIMATIONS:
		for to: StringName in STATE_ANIMATIONS:
			if from != to:
				var transition: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
				transition.xfade_time = CROSSFADE
				machine.add_transition(from, to, transition)

	var root: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	root.add_node(&"base", machine)
	var grab: AnimationNodeBlend2 = AnimationNodeBlend2.new()
	grab.filter_enabled = true
	grab.set_filter_path(ARM_TRACK, true)
	root.add_node(&"grab", grab)
	root.add_node(&"grab_anim", _animation_node(&"grab"))
	root.connect_node(&"grab", 0, &"base")
	root.connect_node(&"grab", 1, &"grab_anim")
	var press: AnimationNodeOneShot = AnimationNodeOneShot.new()
	press.filter_enabled = true
	press.set_filter_path(ARM_TRACK, true)
	press.fadein_time = 0.05
	press.fadeout_time = 0.1
	root.add_node(&"press", press)
	root.add_node(&"press_anim", _animation_node(&"press"))
	root.connect_node(&"press", 0, &"grab")
	root.connect_node(&"press", 1, &"press_anim")
	root.connect_node(&"output", 0, &"press")
	return root


func _animation_node(anim_name: StringName) -> AnimationNodeAnimation:
	var node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	node.animation = anim_name
	return node
