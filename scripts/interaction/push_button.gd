class_name PushButton
extends Interactable
## Bouton : action instantanée (E / clic), utilisable en marchant.
## En mode `toggle`, chaque appui allume / éteint (le bouton reste enfoncé et brille quand il est allumé).
## L'hôte valide l'appui, émet `pressed`, met à jour l'état (répliqué par le
## MultiplayerSynchronizer) puis déclenche l'animation chez tout le monde.

## Émis sur l'hôte uniquement, après validation.
signal pressed(peer_id: int)

const PRESS_DEPTH: float = 0.025
const PRESS_DURATION: float = 0.15
## Flèche de croix directionnelle (`arrow`) : contour d'une branche de la croix qui pointe vers -Z (haut),
## et petit triangle clair gravé dessus. Repère du bouton (avant son échelle).
const ARROW_ARM: PackedVector2Array = [Vector2(-0.05, -0.07), Vector2(0.05, -0.07), Vector2(0.05, 0.05),
	Vector2(0.0, 0.09), Vector2(-0.05, 0.05)]
const ARROW_MARK: PackedVector2Array = [Vector2(0.0, -0.055), Vector2(0.032, -0.012), Vector2(-0.032, -0.012)]
const ARROW_MARK_COLOR: Color = Color(0.93, 0.9, 0.82)

@export var cap_color: Color = Color(0.8, 0.15, 0.1)
## Interrupteur : un appui allume, l'appui suivant éteint.
@export var toggle: bool = false
## Bouton en forme de flèche de manette (croix directionnelle) : -1 = bouton rond, sinon
## 0 haut, 1 bas, 2 gauche, 3 droite (même ordre que QteSequence.Arrow). Le socle rond est alors caché.
@export_range(-1, 3) var arrow: int = -1
## Interrupteur allumé au début de la partie (et après une partie terminée).
@export var start_on: bool = false

## Nombre d'appuis validés. Autorité : hôte.
var press_count: int = 0
## État allumé (mode toggle). Autorité : hôte.
var is_on: bool = false
## Allumé pour signaler « appuie ici » (QTE). Purement visuel, réglé localement par chaque peer.
var lit: bool = false

var _press_timer: float = 0.0
var _cap_rest_y: float = 0.0
var _cap_material: StandardMaterial3D

@onready var _cap: MeshInstance3D = %Cap
@onready var _debug_label: Label3D = %DebugLabel


func _ready() -> void:
	super()
	is_on = start_on
	_cap_material = StandardMaterial3D.new()
	_cap_material.albedo_color = cap_color
	_cap_material.roughness = 0.5
	_cap_material.emission = cap_color
	if arrow >= 0:
		_make_arrow_cap()
	_cap.set_surface_override_material(0, _cap_material)
	_cap_rest_y = _cap.position.y
	_debug_label.visible = show_debug
	NetworkManager.session_ended.connect(_on_session_ended)


func _process(delta: float) -> void:
	# Animation purement visuelle (pas de gameplay ici).
	_press_timer = maxf(_press_timer - delta, 0.0)
	var down: bool = _press_timer > 0.0 or (toggle and is_on)
	_cap.position.y = _cap_rest_y - (PRESS_DEPTH if down else 0.0)
	_cap_material.emission_enabled = (toggle and is_on) or lit
	_cap_material.emission = Color(1.0, 0.55, 0.1) if lit else cap_color
	_cap_material.emission_energy_multiplier = 4.0 if lit else 1.0
	if show_debug:
		var state: String = ("allumé" if is_on else "éteint") if toggle else "appuis : %d" % press_count
		_debug_label.text = "%s\n%s" % [display_name, state]


func get_hints() -> Array[InputHint]:
	if toggle:
		return [InputHint.make(&"grab", &"power_off" if is_on else &"power_on")]
	return [InputHint.make(&"grab", &"press")]


func interact(press: bool, grab: bool, _hands_free: bool) -> Use:
	if not (press or grab):
		return Use.NONE
	request_press.rpc_id(1)
	return Use.DONE


@rpc("any_peer", "call_local", "reliable")
func request_press() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not is_peer_in_reach(sender, reach):
		return
	press_count += 1
	if toggle:
		is_on = not is_on
	pressed.emit(sender)
	_play_press.rpc()


@rpc("authority", "call_local", "reliable")
func _play_press() -> void:
	_press_timer = PRESS_DURATION


func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	return [_cap]


## Remplace le chapeau rond par une branche de croix directionnelle tournée vers `arrow`.
func _make_arrow_cap() -> void:
	_cap_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh: ArrayMesh = ArrayMesh.new()
	_add_prism(mesh, ARROW_ARM, -0.025, 0.025)
	_add_prism(mesh, ARROW_MARK, 0.0245, 0.03)
	var mark: StandardMaterial3D = StandardMaterial3D.new()
	mark.albedo_color = ARROW_MARK_COLOR
	mark.roughness = 0.6
	mark.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(1, mark)
	_cap.mesh = mesh
	_cap.rotation.y = [0.0, PI, PI / 2.0, -PI / 2.0][arrow]
	(get_node("Base") as Node3D).visible = false


## Ajoute à `mesh` une surface : le contour convexe `outline` (x, z) extrudé de y0 à y1 (dessus + côtés).
static func _add_prism(mesh: ArrayMesh, outline: PackedVector2Array, y0: float, y1: float) -> void:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(1, outline.size() - 1):
		for p: Vector2 in [outline[0], outline[i + 1], outline[i]]:
			tool.set_normal(Vector3.UP)
			tool.add_vertex(Vector3(p.x, y1, p.y))
	for i: int in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		var normal: Vector3 = Vector3(b.y - a.y, 0.0, a.x - b.x).normalized()
		for p: Vector3 in [Vector3(a.x, y0, a.y), Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y),
				Vector3(a.x, y0, a.y), Vector3(b.x, y1, b.y), Vector3(b.x, y0, b.y)]:
			tool.set_normal(normal)
			tool.add_vertex(p)
	tool.commit(mesh)


func _on_session_ended(_reason: String) -> void:
	press_count = 0
	is_on = start_on
