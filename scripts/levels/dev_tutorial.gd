class_name DevTutorial
extends Node3D
## Parcours tuto de dev (provisoire, sans décor) : un parcours linéaire, une étape par commande du robot.
## Chaque étape a sa consigne en haut de l'écran ; celles qui se valident en arrivant quelque part ont une
## dalle au sol (grise : plus tard, jaune : en cours, verte : faite) et un panneau. Les obstacles (murs, trou,
## poutre, rochers, portes, barrière, tour) sont sur le calque « obstacle du robot »
## (MechaWalker.OBSTACLE_LAYER) : on ne passe qu'en utilisant la bonne commande.
##
## Plan (vu de dessus, le robot part en (0, 0) tourné vers -Z) :
## - couloir A vers -Z, virage à droite, couloir B vers +X : trou à sauter, poutre basse ;
## - salle du demi-tour, puis couloir C vers -X : deux rochers à forer, porte 1 (2 caisses dans le sac) ;
## - salle des caisses mobiles (au sud du chemin, derrière une barrière) : les 4 rangées, la porte 2 s'ouvre ;
## - couloir F : bouton au sol (un nain sort), tour avec un bouton en haut (un nain monte sur un bras du
##   robot, le pilote du bras le lève), porte 3, arrivée.
## Murs, sol, trou et rails sont créés par le script (tables ci-dessous) : faciles à retoucher.
##
## Réseau : l'hôte tient `step`, `gates_open` et `crates_left` (synchronisés, On Change, spawn) ; chaque
## joueur dessine les dalles, les portes et la consigne d'après eux. Les caisses mobiles sont déplacées par
## l'hôte (leur `position` est déjà répliquée par CargoCrate) jusqu'à ce qu'une pince ou un nain les prenne ;
## elles sont dans le groupe `NetAudit.MOVING_GROUP` (F9 ne compare pas leur place : elle change sans arrêt).
## Les murs sont créés pareil chez tout le monde (rien de réseau). Rochers, caisses et boutons sont dans la
## scène (recettes de docs/reseau.md).

enum Step { WALK, TURN, JUMP, CROUCH, U_TURN, DRILL, GRAB, MOVING, BUTTON, LIFT, CLIMB, FINISH, DONE }
## Portes (bits de `gates_open`) : 2 caisses dans le sac, caisses mobiles toutes rangées, bouton de la tour.
enum Gate { CRATES, MOVING, LIFT }

## Dalle de chaque étape qui en a une : Rect2(x, z, largeur en x, profondeur en z), dans le repère du niveau.
const PADS: Dictionary[Step, Rect2] = {
	Step.WALK: Rect2(-6.0, -24.0, 12.0, 8.0),
	Step.TURN: Rect2(10.0, -42.0, 8.0, 12.0),
	Step.JUMP: Rect2(29.0, -42.0, 6.0, 12.0),
	Step.CROUCH: Rect2(44.0, -42.0, 6.0, 12.0),
	Step.U_TURN: Rect2(44.0, -58.0, 8.0, 12.0),
	Step.DRILL: Rect2(25.0, -58.0, 7.0, 12.0),
	Step.GRAB: Rect2(9.0, -58.0, 7.0, 12.0),
	Step.FINISH: Rect2(-62.0, -60.0, 8.0, 16.0),
}
## Portes : boîte au sol (x, z, largeur, profondeur). Elles s'enfoncent dans le sol en GATE_TIME s.
const GATES: Dictionary[Gate, Rect2] = {
	Gate.CRATES: Rect2(19.5, -58.0, 1.0, 12.0),
	Gate.MOVING: Rect2(-30.5, -58.0, 1.0, 12.0),
	Gate.LIFT: Rect2(-50.5, -60.0, 1.0, 16.0),
}
const GATE_HEIGHT: float = 6.0
const GATE_TIME: float = 1.5
## Caisses à mettre dans le sac pour ouvrir la porte 1.
const CRATES_NEEDED: int = 2
## Trou à sauter : 3 m de large (le saut en fait 5,5), 6 m de fond.
const PIT: Rect2 = Rect2(22.0, -42.0, 3.0, 12.0)
const PIT_DEPTH: float = 6.0
## Tour de l'étape « ascenseur » : le bouton est en haut, hors d'atteinte sans un bras du robot.
const TOWER: Rect2 = Rect2(-47.0, -60.0, 6.0, 3.0)
const TOWER_HEIGHT: float = 5.5
## Trajet de chaque caisse mobile (nom du nœud sous `MovingCrates`) : va-et-vient de `from` à `to` à
## `speed` m/s, ou cercle de rayon `radius` autour de `center` à `speed` rad/s.
const MOVERS: Dictionary[StringName, Dictionary] = {
	&"Mover1": {"from": Vector3(-26.0, 0.0, -64.0), "to": Vector3(4.0, 0.0, -64.0), "speed": 3.0},
	&"Mover2": {"from": Vector3(4.0, 0.0, -68.5), "to": Vector3(-26.0, 0.0, -68.5), "speed": 2.0},
	&"Mover3": {"center": Vector3(-11.0, 0.0, -76.0), "radius": 4.5, "speed": 0.6},
	&"Mover4": {"from": Vector3(-26.0, 0.3, -75.0), "to": Vector3(-26.0, 5.0, -75.0), "speed": 1.5},
}
const WALL_HEIGHT: float = 5.0
const FLOOR_DEPTH: float = 8.0
const OBSTACLE: int = MechaWalker.OBSTACLE_LAYER
const COLOR_FLOOR: Color = Color(0.42, 0.42, 0.44)
const COLOR_WALL: Color = Color(0.62, 0.6, 0.56)
const COLOR_HAZARD: Color = Color(0.85, 0.45, 0.15)
const COLOR_DARK: Color = Color(0.12, 0.12, 0.14)
const COLOR_PAD_LATER: Color = Color(0.3, 0.3, 0.32)
const COLOR_PAD_NOW: Color = Color(1.0, 0.8, 0.2)
const COLOR_PAD_DONE: Color = Color(0.3, 0.85, 0.4)
const FONT: FontVariation = preload("res://assets/fonts/fredoka.tres")

## Le robot (trouvé par le MissionDirector si vide ; à donner dans une scène de test).
@export var mecha: Node3D

## Étape en cours (Step). Autorité : hôte (synchronisé).
var step: int = Step.WALK
## Portes ouvertes (un bit par Gate). Autorité : hôte (synchronisé).
var gates_open: int = 0
## Caisses mobiles pas encore rangées dans le sac. Autorité : hôte (synchronisé).
var crates_left: int = MOVERS.size()

var _pads: Dictionary[Step, StandardMaterial3D] = {}
var _gates: Dictionary[Gate, AnimatableBody3D] = {}
var _gate_amounts: Dictionary[Gate, float] = {}
var _hud: Label
## Hôte : le sac a été vidé au départ, les pinces sont écoutées.
var _host_ready: bool = false
## Hôte : temps du parcours (place des caisses mobiles), et caisses qu'on ne déplace plus (prises).
var _time: float = 0.0
var _released: Dictionary[StringName, bool] = {}

@onready var _ground_button: PushButton = %OutsideButton
@onready var _tower_button: PushButton = %TowerButton
@onready var _moving_crates: Node3D = %MovingCrates


func _ready() -> void:
	_build_floor()
	for wall: AABB in _walls():
		_add_box(wall, COLOR_WALL, 1 | OBSTACLE)
	_build_pit()
	_build_beam()
	_build_arena()
	_build_tower()
	for gate: Gate in GATES:
		_build_gate(gate)
	_build_pads()
	_build_hud()
	_add_pedestal(_ground_button, 0.0)
	_add_pedestal(_tower_button, TOWER_HEIGHT)
	_ground_button.pressed.connect(_on_ground_button)
	_tower_button.pressed.connect(_on_tower_button)
	# Caisses mobiles (celles de la scène, puis celles que l'hôte envoie) : leur place change sans arrêt.
	for crate: Node in _moving_crates.get_children():
		crate.add_to_group(NetAudit.MOVING_GROUP)
	_moving_crates.child_entered_tree.connect(func(crate: Node) -> void: crate.add_to_group(NetAudit.MOVING_GROUP))


func _physics_process(delta: float) -> void:
	for gate: Gate in _gates:
		var amount: float = move_toward(_gate_amounts[gate], 1.0 if is_gate_open(gate) else 0.0, delta / GATE_TIME)
		_gate_amounts[gate] = amount
		_gates[gate].position.y = -GATE_HEIGHT * amount * amount * (3.0 - 2.0 * amount)
	_refresh_visuals()
	if multiplayer.is_server():
		_host_update(delta)


func is_gate_open(gate: Gate) -> bool:
	return gates_open & (1 << gate) != 0


## Consigne de l'étape `index` (affichée en haut de l'écran).
func step_text(index: int) -> String:
	match index:
		Step.WALK:
			return tr("Avancer : poussez vos joysticks vers l'avant, chacun son tour")
		Step.TURN:
			return tr("Virage : poussez en diagonale vers la droite pour tourner en marchant")
		Step.JUMP:
			return tr("Saut : au bord du trou, flèche du haut tous les deux, joysticks vers l'avant, puis les flèches")
		Step.CROUCH:
			return tr("Accroupi : flèche du bas tous les deux, puis les flèches ; passez sous la poutre")
		Step.U_TURN:
			return tr("Demi-tour : poussez sur le côté pour pivoter sur place")
		Step.DRILL:
			return tr("Foreuse : en haut, poste de droite, cassez les deux rochers")
		Step.GRAB:
			return tr("Grappin : en haut, poste de gauche, mettez 2 caisses dans le sac")
		Step.MOVING:
			return tr("Caisses mobiles : lancez la pince pour les attraper toutes (reste %d)") % crates_left
		Step.BUTTON:
			return tr("Dehors : sortez par la trappe et appuyez sur le bouton au sol")
		Step.LIFT:
			return tr("Ascenseur : un nain monte sur un bras baissé, son pilote le lève jusqu'en haut de la tour, il appuie sur le bouton")
		Step.CLIMB:
			return tr("Remontez tous dans le robot par la corde")
		Step.FINISH:
			return tr("Arrivée : avancez jusqu'à la dernière dalle")
	return tr("Tuto terminé ! Bouton « retour au camp » dans le robot")


func _host_update(delta: float) -> void:
	var body: Node3D = _get_mecha()
	var backpack: Backpack = get_tree().get_first_node_in_group(&"backpacks") as Backpack
	if body == null or backpack == null:
		return
	if not _host_ready:
		_host_ready = true
		# Sac vidé au départ : il faut de la place pour les caisses du parcours, et on les compte depuis zéro.
		backpack.clear_inventory()
		for arm: Node in get_tree().get_nodes_in_group(GrabberArm.GROUP):
			(arm as GrabberArm).item_grabbed.connect(_on_item_grabbed)
	_time += delta
	_move_crates()
	if backpack.get_item_count() >= CRATES_NEEDED:
		_open(Gate.CRATES)
	var at: Vector2 = Vector2(body.global_position.x, body.global_position.z) - Vector2(global_position.x, global_position.z)
	match step:
		Step.MOVING:
			if crates_left == 0:
				_open(Gate.MOVING)
				step += 1
		Step.BUTTON, Step.LIFT, Step.DONE:
			pass   # les boutons font avancer l'étape
		Step.CLIMB:
			if _everyone_aboard():
				step += 1
		_:
			if PADS.has(step) and PADS[step].has_point(at):
				step += 1


## Hôte : place chaque caisse mobile sur son trajet, tant que personne ne l'a prise ; compte celles qui restent.
func _move_crates() -> void:
	var left: int = 0
	for node: Node in _moving_crates.get_children():
		var crate: CargoCrate = node as CargoCrate
		if crate == null or crate.is_queued_for_deletion():
			continue
		left += 1
		if crate.holder_peer_id != 0:
			_released[crate.name] = true   # un nain l'a prise : elle reste où il la pose
		if _released.has(crate.name) or not MOVERS.has(crate.name):
			continue
		crate.position = _mover_place(MOVERS[crate.name])
	crates_left = left


func _mover_place(path: Dictionary) -> Vector3:
	if path.has("center"):
		var angle: float = _time * (path["speed"] as float)
		return (path["center"] as Vector3) + Vector3(cos(angle), 0.0, sin(angle)) * (path["radius"] as float)
	var from: Vector3 = path["from"]
	var to: Vector3 = path["to"]
	return from.lerp(to, pingpong(_time * (path["speed"] as float) / from.distance_to(to), 1.0))


func _on_item_grabbed(item: Node3D, _item_kind: String) -> void:
	if item.get_parent() == _moving_crates:
		_released[item.name] = true   # dans la pince : c'est elle qui la porte


func _open(gate: Gate) -> void:
	gates_open |= 1 << gate


func _on_ground_button(_peer_id: int) -> void:
	# Émis chez l'hôte seulement (appui déjà validé par le PushButton).
	if step == Step.BUTTON:
		step += 1


func _on_tower_button(_peer_id: int) -> void:
	if step == Step.LIFT:
		_open(Gate.LIFT)
		step += 1


func _everyone_aboard() -> bool:
	var director: MissionDirector = get_tree().get_first_node_in_group(&"mission_director") as MissionDirector
	return director == null or director.everyone_aboard()


func _get_mecha() -> Node3D:
	if mecha == null:
		var director: MissionDirector = get_tree().get_first_node_in_group(&"mission_director") as MissionDirector
		if director != null:
			mecha = director.mecha
	return mecha


func _refresh_visuals() -> void:
	for pad_step: Step in _pads:
		var color: Color = COLOR_PAD_LATER
		if step > pad_step:
			color = COLOR_PAD_DONE
		elif step == pad_step:
			color = COLOR_PAD_NOW
		_pads[pad_step].albedo_color = color
	var text: String = step_text(step)
	if step < Step.DONE:
		text = tr("Étape %d / %d") % [step + 1, Step.DONE] + "   " + text
	_hud.text = text


## Murs (boîtes), en (x, y, z) et tailles. Voir le plan en tête du fichier.
func _walls() -> Array[AABB]:
	var h: float = WALL_HEIGHT
	return [
		# Couloir A (vers -Z) : gauche, droite, derrière le départ.
		_xz(-7.0, -6.0, -46.0, 6.0, h),
		_xz(6.0, 7.0, -30.0, 6.0, h),
		_xz(-7.0, 7.0, 6.0, 7.0, h),
		# Couloir B (vers +X) : son mur côté +Z (z = -30), jusqu'au fond de la salle du demi-tour.
		_xz(6.0, 73.0, -30.0, -29.0, h),
		# Entre B et C (épais), puis le mur nord de la salle des caisses mobiles.
		_xz(-7.0, 56.0, -46.0, -42.0, h),
		_xz(-31.0, -7.0, -46.0, -45.0, h),
		# Salle du demi-tour (fond) et mur sud de C jusqu'à la salle des caisses mobiles.
		_xz(72.0, 73.0, -59.0, -30.0, h),
		_xz(8.0, 73.0, -59.0, -58.0, h),
		# Rétrécissement des rochers (il reste 8 m, bouchés par les deux rochers).
		_xz(35.0, 37.0, -48.0, -46.0, h),
		_xz(35.0, 37.0, -58.0, -56.0, h),
		# Piliers de la poutre basse.
		_xz(37.5, 39.5, -44.0, -42.0, 9.8),
		_xz(37.5, 39.5, -30.0, -28.0, 9.8),
		# Salle des caisses mobiles (x de -30 à 8, z de -82 à -46) : est, sud, ouest (sous la porte 2).
		_xz(8.0, 9.0, -83.0, -59.0, h),
		_xz(-31.0, 9.0, -83.0, -82.0, h),
		_xz(-31.0, -30.0, -83.0, -58.0, h),
		# Couloir F (x de -64 à -30, 16 m de large) : raccord avec la salle, nord, sud, fond.
		_xz(-31.0, -30.0, -46.0, -43.0, h),
		_xz(-65.0, -31.0, -44.0, -43.0, h),
		_xz(-65.0, -31.0, -61.0, -60.0, h),
		_xz(-65.0, -64.0, -60.0, -44.0, h),
		# Mur plus haut derrière la tour : d'en haut, un nain ne sort pas du parcours.
		_xz(TOWER.position.x, TOWER.end.x, -61.0, -60.0, TOWER_HEIGHT + 2.5),
	]


func _xz(x0: float, x1: float, z0: float, z1: float, height: float, y0: float = 0.0) -> AABB:
	return AABB(Vector3(x0, y0, z0), Vector3(x1 - x0, height, z1 - z0))


## Sol épais (les parois du trou), avec le trou du saut découpé dedans.
func _build_floor() -> void:
	var x0: float = PIT.position.x
	var x1: float = PIT.end.x
	var z0: float = PIT.position.y
	var z1: float = PIT.end.y
	var floors: Array[AABB] = [
		_xz(-72.0, x0, -92.0, 15.0, FLOOR_DEPTH, -FLOOR_DEPTH),
		_xz(x1, 80.0, -92.0, 15.0, FLOOR_DEPTH, -FLOOR_DEPTH),
		_xz(x0, x1, -92.0, z0, FLOOR_DEPTH, -FLOOR_DEPTH),
		_xz(x0, x1, z1, 15.0, FLOOR_DEPTH, -FLOOR_DEPTH),
	]
	for box: AABB in floors:
		_add_box(box, COLOR_FLOOR, 1)


## Trou (étape du saut) : un vrai trou de 6 m. Le robot n'y descend pas (obstacle invisible qui le remplit
## jusqu'à 50 cm au-dessus du sol) ; un nain qui y tombe ressort par la rampe le long du bord.
func _build_pit() -> void:
	var x0: float = PIT.position.x
	var z0: float = PIT.position.y
	_add_box(AABB(Vector3(x0, -FLOOR_DEPTH, z0), Vector3(PIT.size.x, FLOOR_DEPTH - PIT_DEPTH, PIT.size.y)), COLOR_DARK, 1)
	# Parois sombres (10 cm), pour que le trou se voie.
	_add_box(AABB(Vector3(x0, -PIT_DEPTH, z0), Vector3(0.1, PIT_DEPTH, PIT.size.y)), COLOR_DARK, 1)
	_add_box(AABB(Vector3(PIT.end.x - 0.1, -PIT_DEPTH, z0), Vector3(0.1, PIT_DEPTH, PIT.size.y)), COLOR_DARK, 1)
	_add_box(AABB(Vector3(x0, -PIT_DEPTH, z0), Vector3(PIT.size.x, PIT_DEPTH, 0.1)), COLOR_DARK, 1)
	_add_box(AABB(Vector3(x0, -PIT_DEPTH, PIT.end.y - 0.1), Vector3(PIT.size.x, PIT_DEPTH, 0.1)), COLOR_DARK, 1)
	x0 += 0.1
	# Rampe des nains : 1,2 m de large contre le bord, du fond (côté +Z) jusqu'au sol (côté -Z).
	var run: float = PIT.size.y - 1.0
	var length: float = sqrt(run * run + PIT_DEPTH * PIT_DEPTH)
	var slope: float = atan2(PIT_DEPTH, run)
	var ramp: StaticBody3D = _add_box(AABB(Vector3(-0.6, -0.2, -length / 2.0), Vector3(1.2, 0.4, length)), COLOR_HAZARD, 1)
	ramp.rotation.x = slope
	# Le dessus de la rampe passe par le milieu de la pente : on recule le centre de sa demi-épaisseur.
	ramp.position = Vector3(x0 + 0.6, -PIT_DEPTH / 2.0, z0 + 0.5 + run / 2.0) - Vector3(0.0, cos(slope), sin(slope)) * 0.2
	var blocker: StaticBody3D = StaticBody3D.new()
	blocker.collision_layer = OBSTACLE
	blocker.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(PIT.size.x, PIT_DEPTH + 0.5, PIT.size.y)
	shape.shape = box
	blocker.add_child(shape)
	blocker.position = Vector3(PIT.get_center().x, (0.5 - PIT_DEPTH) / 2.0, PIT.get_center().y)
	add_child(blocker)
	# Bandes de bord, pour voir le trou de loin.
	_add_strip(Rect2(PIT.position.x - 0.5, z0, 0.5, PIT.size.y), COLOR_HAZARD)
	_add_strip(Rect2(PIT.end.x, z0, 0.5, PIT.size.y), COLOR_HAZARD)


## Poutre basse (étape de l'accroupi) : le bas à 8,8 m, entre la tête du robot accroupi et debout.
func _build_beam() -> void:
	_add_box(_xz(37.5, 39.5, -44.0, -28.0, 1.0, 8.8), COLOR_HAZARD, 1 | OBSTACLE)


## Salle des caisses mobiles : une barrière basse garde le robot sur le chemin (il faut lancer la pince),
## et des rails au sol montrent le trajet des caisses.
func _build_arena() -> void:
	_add_box(_xz(-30.0, 8.0, -60.5, -59.5, 1.0), COLOR_HAZARD, 1 | OBSTACLE)
	for mover: StringName in MOVERS:
		var path: Dictionary = MOVERS[mover]
		if path.has("center"):
			var center: Vector3 = path["center"]
			var radius: float = path["radius"]
			for i: int in 16:
				var angle: float = TAU * float(i) / 16.0
				var point: Vector3 = center + Vector3(cos(angle), 0.0, sin(angle)) * radius
				_add_strip(Rect2(point.x - 0.25, point.z - 0.25, 0.5, 0.5), COLOR_DARK)
			continue
		var from: Vector3 = path["from"]
		var to: Vector3 = path["to"]
		if is_equal_approx(from.x, to.x) and is_equal_approx(from.z, to.z):
			# Caisse qui monte et descend : un mât, derrière elle.
			_add_box(AABB(Vector3(from.x - 0.75, 0.0, from.z - 0.1), Vector3(0.2, to.y + 1.0, 0.2)), COLOR_DARK, 1)
		else:
			_add_strip(Rect2(minf(from.x, to.x), minf(from.z, to.z) - 0.2,
				maxf(absf(to.x - from.x), 0.4), maxf(absf(to.z - from.z), 0.4)), COLOR_DARK)


## Tour de l'étape « ascenseur » : un bloc plein, le bouton est posé dessus (dans la scène).
func _build_tower() -> void:
	_add_box(_xz(TOWER.position.x, TOWER.end.x, TOWER.position.y, TOWER.end.y, TOWER_HEIGHT), COLOR_WALL, 1 | OBSTACLE)
	_add_strip(TOWER, COLOR_PAD_NOW, TOWER_HEIGHT)


func _build_gate(gate: Gate) -> void:
	var rect: Rect2 = GATES[gate]
	var body: AnimatableBody3D = AnimatableBody3D.new()
	body.sync_to_physics = false
	body.collision_layer = 1 | OBSTACLE
	body.collision_mask = 0
	var holder: Node3D = Node3D.new()
	add_child(holder)
	holder.add_child(body)
	var size: Vector3 = Vector3(rect.size.x, GATE_HEIGHT, rect.size.y)
	_fill_box(body, AABB(-size / 2.0, size), COLOR_HAZARD)
	holder.position = Vector3(rect.get_center().x, GATE_HEIGHT / 2.0, rect.get_center().y)
	_gates[gate] = body
	_gate_amounts[gate] = 0.0


func _build_pads() -> void:
	for pad_step: Step in PADS:
		var rect: Rect2 = PADS[pad_step]
		_pads[pad_step] = _add_strip(rect, COLOR_PAD_LATER)
		var center: Vector2 = rect.get_center()
		var sign_label: Label3D = Label3D.new()
		sign_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		sign_label.text = tr("Étape %d") % [int(pad_step) + 1]
		sign_label.font = FONT
		sign_label.font_size = 160
		sign_label.outline_size = 32
		sign_label.pixel_size = 0.01
		sign_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sign_label.position = Vector3(center.x, 6.5, center.y)
		add_child(sign_label)


func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_hud = Label.new()
	_hud.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hud.offset_left = 60.0
	_hud.offset_right = -60.0
	_hud.offset_top = 14.0
	_hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_theme_font_override(&"font", FONT)
	_hud.add_theme_font_size_override(&"font_size", 26)
	_hud.add_theme_color_override(&"font_outline_color", Color(0.1, 0.08, 0.06))
	_hud.add_theme_constant_override(&"outline_size", 8)
	layer.add_child(_hud)


## Socle sous un bouton de la scène, posé à la hauteur `base`.
func _add_pedestal(button: PushButton, base: float) -> void:
	var at: Vector3 = button.position
	_add_box(AABB(Vector3(at.x - 0.5, base, at.z - 0.5), Vector3(1.0, at.y - base, 1.0)), COLOR_WALL, 1)


## Boîte statique visible et solide, `box` dans le repère du niveau.
func _add_box(box: AABB, color: Color, layers: int) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = layers
	body.collision_mask = 0
	body.position = box.get_center()
	add_child(body)
	_fill_box(body, AABB(-box.size / 2.0, box.size), color)
	return body


func _fill_box(body: CollisionObject3D, local_box: AABB, color: Color) -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	var mesh_box: BoxMesh = BoxMesh.new()
	mesh_box.size = local_box.size
	mesh_box.material = material
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = mesh_box
	mesh.position = local_box.get_center()
	body.add_child(mesh)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = local_box.size
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = shape
	collider.position = local_box.get_center()
	body.add_child(collider)


## Bande peinte (sans collision) posée à la hauteur `y` : dalle, rail, bord. Renvoie sa matière.
func _add_strip(rect: Rect2, color: Color, y: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	var mesh_box: BoxMesh = BoxMesh.new()
	mesh_box.size = Vector3(rect.size.x, 0.06, rect.size.y)
	mesh_box.material = material
	var strip: MeshInstance3D = MeshInstance3D.new()
	strip.mesh = mesh_box
	strip.position = Vector3(rect.get_center().x, y + 0.03, rect.get_center().y)
	add_child(strip)
	return material
