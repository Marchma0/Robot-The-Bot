extends Node3D
## Flammes du feu de camp : quelques cônes lumineux qui dansent, et une lumière qui vacille.
## Purement visuel et local (rien sur le réseau).

const FLAME_COUNT: int = 5

@export var light_energy: float = 2.4

var _flames: Array[MeshInstance3D] = []
var _phases: Array[float] = []
var _time: float = 0.0

@onready var _light: OmniLight3D = $Light


func _ready() -> void:
	var colors: Array[Color] = [Color(1.0, 0.45, 0.1), Color(1.0, 0.7, 0.2), Color(1.0, 0.85, 0.45)]
	for i: int in FLAME_COUNT:
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = 0.16 - i * 0.02
		mesh.height = 0.7 - i * 0.08
		mesh.radial_segments = 5
		mesh.rings = 1
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = colors[i % colors.size()]
		mat.emission_enabled = true
		mat.emission = colors[i % colors.size()]
		mat.emission_energy_multiplier = 2.5
		mesh.material = mat
		var flame: MeshInstance3D = MeshInstance3D.new()
		flame.mesh = mesh
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a: float = i * TAU / FLAME_COUNT
		flame.position = Vector3(cos(a) * 0.12, mesh.height / 2.0 + 0.08, sin(a) * 0.12) * Vector3(1, 1, 1)
		add_child(flame)
		_flames.append(flame)
		_phases.append(randf() * TAU)


func _process(delta: float) -> void:
	_time += delta
	for i: int in _flames.size():
		var p: float = _phases[i]
		var s: float = 1.0 + 0.25 * sin(_time * (7.0 + i) + p) + 0.1 * sin(_time * 17.0 + p * 2.0)
		_flames[i].scale = Vector3(1.0 / sqrt(s), s, 1.0 / sqrt(s))
		_flames[i].rotation = Vector3(0.12 * sin(_time * 3.0 + p), _time * 0.8 + p, 0.12 * cos(_time * 2.6 + p))
	_light.light_energy = light_energy * (0.85 + 0.15 * sin(_time * 11.0) * sin(_time * 4.3))
