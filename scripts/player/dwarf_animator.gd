class_name DwarfAnimator
extends Node
## Anime le corps du nain à partir de son ÉTAT (vitesse, en l'air, tient un levier,
## assis, flotte dans le rayon, grimpe, compteur d'appuis). Cet état est synchronisé
## par le nain ; chaque peer joue l'animation localement (on ne synchronise jamais
## l'animation elle-même).
##
## AnimationTree construit en code :
##   base  = machine à états idle / walk / air / sit / float / climb (fondus)
##   grab  = Blend2 filtré sur le bras droit (tenir un levier, même en marchant)
##   press = OneShot filtré sur le bras droit (appuyer sur un bouton)
##   gesture = OneShot filtré sur le haut du corps (emotes « geste », jouables en marchant) ;
##             les emotes en boucle (danse) sont des états de la machine
##   throw / hit = OneShot filtrés sur le haut du corps (lancer un objet / recevoir un caca)

const LOOPING: Array[StringName] = [&"idle", &"walk", &"float", &"climb", &"emote_dance", &"crouch", &"crouch_walk", &"poop"]
const STATE_ANIMATIONS: Dictionary[StringName, StringName] = {
	&"idle": &"idle", &"walk": &"walk", &"air": &"jump", &"sit": &"sit",
	&"float": &"float", &"climb": &"climb", &"dance": &"emote_dance",
	&"crouch": &"crouch", &"crouch_walk": &"crouch_walk", &"poop": &"poop",
}
## Texte affiché dans la bulle d'état pour chaque état de base.
const STATE_LABELS: Dictionary[StringName, String] = {
	&"idle": "Au repos", &"walk": "Marche", &"air": "Saute", &"sit": "Assis",
	&"float": "Flotte", &"climb": "Grimpe", &"dance": "Danse",
	&"crouch": "Accroupi", &"crouch_walk": "Se dandine", &"poop": "Fait caca",
}
## États dont la vitesse de lecture suit la vitesse du nain (marche, grimpe).
const SCALED_STATES: Array[StringName] = [&"walk", &"climb", &"crouch_walk"]
## Os animés par la couche haut du corps (tenir / appuyer).
const ARM_TRACK: NodePath = ^"DwarfRig/Skeleton3D:arm_R"
## Os animés par les gestes (emotes) : tout le haut du corps, doigts compris.
const UPPER_BODY_TRACKS: Array[NodePath] = [
	^"DwarfRig/Skeleton3D:torso", ^"DwarfRig/Skeleton3D:head",
	^"DwarfRig/Skeleton3D:arm_L", ^"DwarfRig/Skeleton3D:arm_R",
	^"DwarfRig/Skeleton3D:finger_L", ^"DwarfRig/Skeleton3D:finger_R",
	^"DwarfRig/Skeleton3D:thumb_L", ^"DwarfRig/Skeleton3D:thumb_R",
]
const CROSSFADE: float = 0.15
## En dessous de cette vitesse (m/s), le nain est considéré à l'arrêt.
const WALK_THRESHOLD: float = 0.3

@export var dwarf: Dwarf
@export var body_model: Node3D
## Vitesse (m/s) à laquelle l'animation de marche joue à vitesse normale.
@export var walk_reference_speed: float = 2.0
## Vitesse de grimpe (m/s) à laquelle l'animation "climb" joue à vitesse normale.
@export var climb_reference_speed: float = 1.4
## Bac à sable : force un état ("idle", "walk", "air", "sit", "float", "climb", "crouch", "crouch_walk",
## "grab", "press"), sinon vide.
@export var preview_state: String = ""
## Bac à sable : rejoue cette emote (index dans Emotes.LIST) toutes les 2,5 s, -1 = non.
@export var preview_emote: int = Emotes.NONE

var _tree: AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var _grab_amount: float = 0.0
var _last_press_count: int = 0
var _preview_timer: float = 0.0
var _last_emote_count: int = 0
var _gesture_playing: bool = false
var _gesture_label: String = ""
var _gesture_time: float = 0.0
var _last_throw_count: int = 0
var _last_hit_count: int = 0
var _event_label: String = ""
var _event_time: float = 0.0

## Ce que fait le nain, en mots (lu par la bulle d'état).
var state_label: String = "Au repos"


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
	if dwarf == null:
		return
	var speed: float = dwarf.anim_speed
	var airborne: bool = dwarf.anim_airborne
	var seated: bool = dwarf.anim_seated
	var holding: bool = dwarf.anim_holding
	var press_count: int = dwarf.anim_press_count
	var floating: bool = dwarf.anim_floating
	var climbing: bool = dwarf.anim_climbing
	var emote: int = dwarf.anim_emote
	var emote_count: int = dwarf.anim_emote_count
	var crouching: bool = dwarf.anim_crouching
	var pooping: bool = dwarf.anim_pooping
	if preview_state != "":
		_preview_timer += delta
		speed = walk_reference_speed if preview_state == "walk" else 0.0
		if preview_state == "climb":
			speed = climb_reference_speed
		airborne = preview_state == "air"
		seated = preview_state == "sit"
		holding = preview_state == "grab"
		floating = preview_state == "float"
		climbing = preview_state == "climb"
		crouching = preview_state in ["crouch", "crouch_walk"]
		if preview_state == "crouch_walk":
			speed = 1.2
		press_count = int(_preview_timer / 1.2) if preview_state == "press" else 0
	if preview_emote != Emotes.NONE:
		_preview_timer += delta
		emote = preview_emote
		emote_count = int(_preview_timer / 2.5) + 1

	var target: StringName = &"idle"
	if seated:
		target = &"poop" if pooping else &"sit"
	elif Emotes.is_loop(emote):
		target = &"dance"
	elif climbing:
		target = &"climb"
	elif floating:
		target = &"float"
	elif crouching:
		target = &"crouch_walk" if speed > WALK_THRESHOLD else &"crouch"
	elif airborne:
		target = &"air"
	elif speed > WALK_THRESHOLD:
		target = &"walk"
	if _playback.get_current_node() != target:
		_playback.travel(target)
	_tree.set("parameters/base/walk/scale/scale", clampf(speed / walk_reference_speed, 0.6, 2.0))
	# À l'arrêt sur la corde, l'animation de grimpe se fige.
	_tree.set("parameters/base/climb/scale/scale", clampf(speed / climb_reference_speed, 0.0, 2.0))
	_tree.set("parameters/base/crouch_walk/scale/scale", clampf(speed / 1.2, 0.6, 2.0))

	_grab_amount = move_toward(_grab_amount, 1.0 if holding else 0.0, delta * 6.0)
	_tree.set("parameters/grab/blend_amount", _grab_amount)

	if press_count != _last_press_count:
		_last_press_count = press_count
		_tree.set("parameters/press/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	# Gestes : une nouvelle emote (compteur) lance le geste ; s'il est annulé, il s'efface.
	if emote_count != _last_emote_count:
		_last_emote_count = emote_count
		if Emotes.is_valid(emote) and not Emotes.is_loop(emote):
			_tree.set("parameters/gesture_pick/transition_request", String(Emotes.LIST[emote]["animation"]))
			_tree.set("parameters/gesture/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			_gesture_playing = true
			_gesture_label = Emotes.LIST[emote]["label"]
			_gesture_time = float(Emotes.LIST[emote]["duration"])
	elif _gesture_playing and not Emotes.is_valid(emote):
		_tree.set("parameters/gesture/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
		_gesture_playing = false
		_gesture_time = 0.0

	# Lancer / recevoir un caca : couches du haut du corps, déclenchées par des compteurs.
	if dwarf.anim_throw_count != _last_throw_count:
		_last_throw_count = dwarf.anim_throw_count
		_tree.set("parameters/throw/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		_event_label = "Lance !"
		_event_time = 0.8
	if dwarf.anim_hit_count != _last_hit_count:
		_last_hit_count = dwarf.anim_hit_count
		_tree.set("parameters/hit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		_event_label = "Touché !"
		_event_time = 1.2

	# Texte de la bulle : un événement (lancer, touché), puis un geste, puis l'état de base.
	_gesture_time -= delta
	_event_time -= delta
	if _event_time > 0.0:
		state_label = _event_label
	elif _gesture_time > 0.0:
		state_label = _gesture_label
	else:
		state_label = STATE_LABELS.get(target, "")


func _build_tree() -> AnimationNodeBlendTree:
	var machine: AnimationNodeStateMachine = AnimationNodeStateMachine.new()
	var x: float = 0.0
	for state: StringName in STATE_ANIMATIONS:
		var node: AnimationRootNode = _animation_node(STATE_ANIMATIONS[state])
		if state in SCALED_STATES:
			# Marche et grimpe passent par un TimeScale pour suivre la vitesse du nain.
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

	var gesture: AnimationNodeOneShot = AnimationNodeOneShot.new()
	gesture.filter_enabled = true
	for track: NodePath in UPPER_BODY_TRACKS:
		gesture.set_filter_path(track, true)
	gesture.fadein_time = 0.12
	gesture.fadeout_time = 0.2
	root.add_node(&"gesture", gesture)
	var pick: AnimationNodeTransition = AnimationNodeTransition.new()
	root.add_node(&"gesture_pick", pick)
	var index: int = 0
	for entry: Dictionary in Emotes.LIST:
		if entry["loop"]:
			continue
		var anim_name: StringName = entry["animation"]
		pick.add_input(String(anim_name))
		root.add_node(anim_name, _animation_node(anim_name))
		root.connect_node(&"gesture_pick", index, anim_name)
		index += 1
	root.connect_node(&"gesture", 0, &"press")
	root.connect_node(&"gesture", 1, &"gesture_pick")
	var last: StringName = &"gesture"
	for layer: StringName in [&"throw", &"hit"]:
		var shot: AnimationNodeOneShot = AnimationNodeOneShot.new()
		shot.filter_enabled = true
		for track: NodePath in UPPER_BODY_TRACKS:
			shot.set_filter_path(track, true)
		shot.fadein_time = 0.05
		shot.fadeout_time = 0.15
		root.add_node(layer, shot)
		var anim_name: StringName = StringName(String(layer) + "_anim")
		root.add_node(anim_name, _animation_node(layer))
		root.connect_node(layer, 0, last)
		root.connect_node(layer, 1, anim_name)
		last = layer
	root.connect_node(&"output", 0, last)
	return root


func _animation_node(anim_name: StringName) -> AnimationNodeAnimation:
	var node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	node.animation = anim_name
	return node
