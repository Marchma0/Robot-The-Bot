class_name FxBurst
extends Node3D
## Gerbe de petits cubes qui jaillissent puis retombent en s'effaçant : étincelles, confettis, fumée.
## Purement visuel et local : créée par un RPC `authority, call_local` de l'hôte, chez chaque joueur.

const LIFE: float = 1.1

var _bits: Array[MeshInstance3D] = []
var _velocities: Array[Vector3] = []
var _spins: Array[Vector3] = []
var _gravity: float = 9.0
var _grow: float = 0.0
var _age: float = 0.0


## `count` cubes de `bit_size` m, lancés depuis `local_pos` (repère de `parent`) à `speed` m/s.
## `colors` : une couleur au hasard par cube. `gravity` : 0 pour de la fumée qui flotte, `grow` : grossit (fumée).
static func spawn(parent: Node3D, local_pos: Vector3, colors: Array[Color], count: int = 18, speed: float = 3.0,
		bit_size: float = 0.06, gravity: float = 9.0, grow: float = 0.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var burst: FxBurst = FxBurst.new()
	burst.position = local_pos
	burst._gravity = gravity
	burst._grow = grow
	parent.add_child(burst)
	burst._build(colors, count, speed, bit_size)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	var fade: float = clampf((LIFE - _age) / 0.4, 0.0, 1.0)
	for i: int in _bits.size():
		_velocities[i].y -= _gravity * delta
		_velocities[i] *= 1.0 - 1.2 * delta
		_bits[i].position += _velocities[i] * delta
		_bits[i].rotation += _spins[i] * delta
		_bits[i].scale = Vector3.ONE * maxf(fade * (1.0 + _grow * _age), 0.01)


func _build(colors: Array[Color], count: int, speed: float, bit_size: float) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE * bit_size
	for i: int in count:
		var bit: MeshInstance3D = MeshInstance3D.new()
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = colors[randi() % colors.size()] if not colors.is_empty() else Color.WHITE
		bit.mesh = mesh
		bit.material_override = mat
		bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bit)
		_bits.append(bit)
		var dir: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(0.3, 1.0), randf_range(-1.0, 1.0)).normalized()
		_velocities.append(dir * speed * randf_range(0.6, 1.2))
		_spins.append(Vector3(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0), randf_range(-9.0, 9.0)))
