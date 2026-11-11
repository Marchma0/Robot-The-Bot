class_name DevTutorial
extends Node3D
## Parcours tuto de dev (provisoire, sans décor) : un couloir linéaire, une étape par commande du robot.
## Chaque étape a sa dalle au sol (grise : plus tard, jaune : en cours, verte : faite), un panneau, et la
## consigne en haut de l'écran. Les obstacles (murs, fossé, poutre, rochers, porte) sont sur le calque
## « obstacle du robot » (MechaWalker.OBSTACLE_LAYER) : on ne passe qu'en utilisant la bonne commande.
##
## Plan (vu de dessus, le robot part en (0, 0) tourné vers -Z) : couloir A tout droit vers -Z, virage à droite,
## couloir B vers +X (fossé, poutre basse), salle du demi-tour, couloir C vers -X (deux rochers, porte du
## grappin, bouton dehors, arrivée). Les murs sont créés par le script (tables `_walls`) : facile à retoucher.
##
## Réseau : l'hôte fait avancer `step` (et ouvre la porte, `gate_open`), tous deux synchronisés (On Change,
## spawn) ; chaque joueur dessine les dalles, la porte et la consigne d'après ces deux variables. Les murs
## sont créés pareil chez tout le monde (rien de réseau). Rochers, caisses et bouton sont dans la scène
## (recettes de docs/reseau.md).

enum Step { WALK, TURN, JUMP, CROUCH, U_TURN, DRILL, GRAB, BUTTON, CLIMB, FINISH, DONE }

## Dalle de chaque étape qui en a une : Rect2(x, z, largeur en x, profondeur en z), dans le repère du niveau.
const PADS: Dictionary[Step, Rect2] = {
	Step.WALK: Rect2(-6.0, -24.0, 12.0, 8.0),
	Step.TURN: Rect2(10.0, -42.0, 8.0, 12.0),
	Step.JUMP: Rect2(28.0, -42.0, 6.0, 12.0),
	Step.CROUCH: Rect2(44.0, -42.0, 6.0, 12.0),
	Step.U_TURN: Rect2(44.0, -58.0, 8.0, 12.0),
	Step.DRILL: Rect2(25.0, -58.0, 7.0, 12.0),
	Step.GRAB: Rect2(8.0, -58.0, 8.0, 12.0),
	Step.FINISH: Rect2(-24.0, -58.0, 8.0, 12.0),
}
## Caisses à mettre dans le sac pour ouvrir la porte.
const CRATES_NEEDED: int = 2
const WALL_HEIGHT: float = 5.0
## Porte du grappin : boîte (x, z) et hauteur ; elle s'enfonce dans le sol en GATE_TIME s.
const GATE_RECT: Rect2 = Rect2(19.5, -58.0, 1.0, 12.0)
const GATE_HEIGHT: float = 6.0
const GATE_TIME: float = 1.5
const OBSTACLE: int = MechaWalker.OBSTACLE_LAYER
const COLOR_FLOOR: Color = Color(0.42, 0.42, 0.44)
const COLOR_WALL: Color = Color(0.62, 0.6, 0.56)
const COLOR_HAZARD: Color = Color(0.85, 0.45, 0.15)
const COLOR_PAD_LATER: Color = Color(0.3, 0.3, 0.32)
const COLOR_PAD_NOW: Color = Color(1.0, 0.8, 0.2)
const COLOR_PAD_DONE: Color = Color(0.3, 0.85, 0.4)
const FONT: FontVariation = preload("res://assets/fonts/fredoka.tres")

## Le robot (trouvé par le MissionDirector si vide ; à donner dans une scène de test).
@export var mecha: Node3D

## Étape en cours (Step). Autorité : hôte (synchronisé).
var step: int = Step.WALK
## Porte du grappin ouverte. Autorité : hôte (synchronisé).
var gate_open: bool = false

var _pads: Dictionary[Step, StandardMaterial3D] = {}
var _gate: AnimatableBody3D
var _gate_amount: float = 0.0
var _hud: Label
var _backpack_base: int = -1

@onready var _button: PushButton = %OutsideButton


func _ready() -> void:
	_build_floor()
	for wall: AABB in _walls():
		_add_box(wall, COLOR_WALL, 1 | OBSTACLE)
	_build_ditch()
	_build_beam()
	_build_gate()
	_build_pads()
	_build_hud()
	# Socle du bouton du dehors.
	var at: Vector3 = _button.position
	_add_box(AABB(Vector3(at.x - 0.5, 0.0, at.z - 0.5), Vector3(1.0, at.y, 1.0)), COLOR_WALL, 1)
	_button.pressed.connect(_on_button_pressed)


func _physics_process(delta: float) -> void:
	_gate_amount = move_toward(_gate_amount, 1.0 if gate_open else 0.0, delta / GATE_TIME)
	_gate.position.y = -GATE_HEIGHT * _gate_amount * _gate_amount * (3.0 - 2.0 * _gate_amount)
	_refresh_visuals()
	if multiplayer.is_server():
		_host_update()


## Consigne de l'étape `index` (affichée en haut de l'écran).
func step_text(index: int) -> String:
	match index:
		Step.WALK:
			return tr("Avancer : poussez vos joysticks vers l'avant, chacun son tour")
		Step.TURN:
			return tr("Virage : poussez en diagonale vers la droite pour tourner en marchant")
		Step.JUMP:
			return tr("Saut : flèche du haut tous les deux, joysticks vers l'avant, puis les flèches")
		Step.CROUCH:
			return tr("Accroupi : flèche du bas tous les deux, puis les flèches ; passez sous la poutre")
		Step.U_TURN:
			return tr("Demi-tour : poussez sur le côté pour pivoter sur place")
		Step.DRILL:
			return tr("Foreuse : en haut, poste de droite, cassez les deux rochers")
		Step.GRAB:
			return tr("Grappin : en haut, poste de gauche, mettez 2 caisses dans le sac")
		Step.BUTTON:
			return tr("Dehors : sortez par la trappe et appuyez sur le bouton")
		Step.CLIMB:
			return tr("Remontez tous dans le robot par la corde")
		Step.FINISH:
			return tr("Arrivée : avancez jusqu'à la dernière dalle")
	return tr("Tuto terminé ! Bouton « retour au camp » dans le robot")


func _host_update() -> void:
	var body: Node3D = _get_mecha()
	if body == null:
		return
	var backpack: Backpack = get_tree().get_first_node_in_group(&"backpacks") as Backpack
	if backpack != null and _backpack_base < 0:
		_backpack_base = backpack.get_item_count()
	if not gate_open and backpack != null and backpack.get_item_count() - _backpack_base >= CRATES_NEEDED:
		gate_open = true
	var at: Vector2 = Vector2(body.global_position.x, body.global_position.z) - Vector2(global_position.x, global_position.z)
	match step:
		Step.BUTTON:
			pass   # le bouton fait avancer l'étape (_on_button_pressed)
		Step.CLIMB:
			if _everyone_aboard():
				step += 1
		Step.DONE:
			pass
		_:
			if PADS.has(step) and PADS[step].has_point(at):
				step += 1


func _on_button_pressed(_peer_id: int) -> void:
	# Émis chez l'hôte seulement (appui déjà validé par le PushButton).
	if step == Step.BUTTON:
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
		# Entre B et C (épais), et le mur nord de la fin de C.
		_xz(-7.0, 56.0, -46.0, -42.0, h),
		_xz(-31.0, -7.0, -46.0, -45.0, h),
		# Salle du demi-tour (fond), mur sud de C, bout de C.
		_xz(72.0, 73.0, -59.0, -30.0, h),
		_xz(-31.0, 73.0, -59.0, -58.0, h),
		_xz(-31.0, -30.0, -58.0, -46.0, h),
		# Rétrécissement des rochers (il reste 8 m, bouchés par les deux rochers).
		_xz(35.0, 37.0, -48.0, -46.0, h),
		_xz(35.0, 37.0, -58.0, -56.0, h),
		# Piliers de la poutre basse.
		_xz(37.5, 39.5, -44.0, -42.0, 9.8),
		_xz(37.5, 39.5, -30.0, -28.0, 9.8),
	]


func _xz(x0: float, x1: float, z0: float, z1: float, height: float, y0: float = 0.0) -> AABB:
	return AABB(Vector3(x0, y0, z0), Vector3(x1 - x0, height, z1 - z0))


## Sol, avec un trou pour le fossé (x de 22 à 24 dans le couloir B).
func _build_floor() -> void:
	var floors: Array[AABB] = [
		_xz(-40.0, 22.0, -70.0, 15.0, 1.0, -1.0),
		_xz(24.0, 80.0, -70.0, 15.0, 1.0, -1.0),
		_xz(22.0, 24.0, -70.0, -42.0, 1.0, -1.0),
		_xz(22.0, 24.0, -30.0, 15.0, 1.0, -1.0),
	]
	for box: AABB in floors:
		_add_box(box, COLOR_FLOOR, 1)


## Fossé (étape du saut), 2 m de large : un creux en V de 0,6 m (les nains en ressortent à pied), rempli d'un obstacle
## invisible pour le robot jusqu'à 50 cm au-dessus du sol.
func _build_ditch() -> void:
	for side: int in 2:
		var ramp: StaticBody3D = _add_box(AABB(Vector3(-0.585, -0.25, -6.0), Vector3(1.17, 0.5, 12.0)), COLOR_HAZARD, 1)
		ramp.position = Vector3(22.37 if side == 0 else 23.63, -0.51, -36.0)
		ramp.rotation.z = deg_to_rad(-31.0 if side == 0 else 31.0)
	var blocker: StaticBody3D = StaticBody3D.new()
	blocker.collision_layer = OBSTACLE
	blocker.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2.0, 1.3, 12.0)
	shape.shape = box
	blocker.add_child(shape)
	blocker.position = Vector3(23.0, -0.15, -36.0)
	add_child(blocker)


## Poutre basse (étape de l'accroupi) : le bas à 8,8 m, entre la tête du robot accroupi et debout.
func _build_beam() -> void:
	_add_box(_xz(37.5, 39.5, -44.0, -28.0, 1.0, 8.8), COLOR_HAZARD, 1 | OBSTACLE)


func _build_gate() -> void:
	_gate = AnimatableBody3D.new()
	_gate.sync_to_physics = false
	_gate.collision_layer = 1 | OBSTACLE
	_gate.collision_mask = 0
	var holder: Node3D = Node3D.new()
	add_child(holder)
	holder.add_child(_gate)
	var box: AABB = AABB(Vector3(GATE_RECT.position.x, 0.0, GATE_RECT.position.y),
		Vector3(GATE_RECT.size.x, GATE_HEIGHT, GATE_RECT.size.y))
	_fill_box(_gate, AABB(box.position - box.get_center(), box.size), COLOR_HAZARD)
	holder.position = box.get_center()


func _build_pads() -> void:
	for pad_step: Step in PADS:
		var rect: Rect2 = PADS[pad_step]
		var material: StandardMaterial3D = StandardMaterial3D.new()
		var mesh_box: BoxMesh = BoxMesh.new()
		mesh_box.size = Vector3(rect.size.x, 0.06, rect.size.y)
		mesh_box.material = material
		var pad: MeshInstance3D = MeshInstance3D.new()
		pad.mesh = mesh_box
		var center: Vector2 = rect.get_center()
		pad.position = Vector3(center.x, 0.03, center.y)
		add_child(pad)
		_pads[pad_step] = material
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
	_hud.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hud.offset_top = 14.0
	_hud.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_theme_font_override(&"font", FONT)
	_hud.add_theme_font_size_override(&"font_size", 26)
	_hud.add_theme_color_override(&"font_outline_color", Color(0.1, 0.08, 0.06))
	_hud.add_theme_constant_override(&"outline_size", 8)
	layer.add_child(_hud)


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
