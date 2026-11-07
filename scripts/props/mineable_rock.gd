class_name MineableRock
extends StaticBody3D
## Bloc rocheux minable par la foreuse du mécha (M8 — Foreuse).
## Quand la mèche en rotation de la foreuse s'enfonce dedans, l'hôte réduit ses points de vie (`hp_ratio`).
## Pendant le forage, le rocher vibre et se tasse ; une fois détruit (`broken = true`), il éclate
## en morceaux animés et libère une caisse de minerai (`CargoCrate`) récupérable au grappin (M9).
##
## Réseau : l'hôte est seul autoritaire sur `hp_ratio`, `being_drilled` et `broken`
## (répliqués par MultiplayerSynchronizer) et déclenche l'explosion via `play_break_animation`.

signal rock_broken(rock: MineableRock, spawned_crate: Node3D)

const CRATE_SCENE: PackedScene = preload("res://scenes/props/cargo_crate.tscn")
const BREAK_DURATION: float = 0.78
const CHUNK_COUNT: int = 12

## Points de vie totaux du rocher (secondes de forage × dégâts/s).
@export var max_hp: float = 100.0
## Type d'objet produit dans la caisse de minerai extraite.
@export var drop_item_kind: String = "ore"
## Conteneur où faire apparaître la caisse extraite (si vide, utilise le parent du rocher).
@export var drops_container: Node3D

## Ratio de vie restant (0.0 .. 1.0). Autorité : hôte.
var hp_ratio: float = 1.0
## Vrai tant que la foreuse est en train de forer ce rocher. Autorité : hôte.
var being_drilled: bool = false
## Vrai quand le rocher a été détruit. Autorité : hôte.
var broken: bool = false:
	set(value):
		broken = value
		if is_node_ready():
			_apply_broken_state()

var _shake_time: float = 0.0
var _break_timer: float = -1.0
var _chunks: Array[Dictionary] = []

@onready var _model: Node3D = %Model
@onready var _collision: CollisionShape3D = %CollisionShape3D
@onready var _fragments_root: Node3D = %Fragments


func _ready() -> void:
	add_to_group(&"mineable_rocks")
	_apply_broken_state()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server() and being_drilled:
		# Remis à vrai à chaque étape physique par DrillArm tant que le forage continue.
		being_drilled = false
	if _break_timer >= 0.0:
		_update_break_fragments(delta)


func _process(delta: float) -> void:
	if broken:
		return
	var damage_scale: float = lerpf(0.84, 1.0, clampf(hp_ratio, 0.0, 1.0))
	if being_drilled:
		_shake_time += delta * 52.0
		var amp: float = 0.035 * (1.3 - 0.5 * hp_ratio)
		_model.position = Vector3(
			sin(_shake_time * 1.7) * amp,
			absf(cos(_shake_time * 2.3)) * amp * 0.5,
			cos(_shake_time * 1.3) * amp
		)
		_model.rotation = Vector3(
			sin(_shake_time * 1.1) * 0.03,
			0.0,
			cos(_shake_time * 1.5) * 0.03
		)
	else:
		_model.position = _model.position.move_toward(Vector3.ZERO, delta * 0.4)
		_model.rotation = _model.rotation.move_toward(Vector3.ZERO, delta * 0.5)
	_model.scale = Vector3(damage_scale, lerpf(0.76, 1.0, hp_ratio), damage_scale)


## Distance (m) le long d'un rayon global (`from`, `dir` normé) jusqu'à l'entrée dans la boîte
## de collision du rocher ; -1.0 si le rayon la manque. Sert à la foreuse pour buter dans le rocher.
func ray_entry(from: Vector3, dir: Vector3) -> float:
	var box: BoxShape3D = _collision.shape as BoxShape3D
	if box == null:
		return -1.0
	var inv: Transform3D = _collision.global_transform.affine_inverse()
	var o: Vector3 = inv * from
	var d: Vector3 = inv.basis * dir
	var half: Vector3 = box.size * 0.5
	var t_min: float = -INF
	var t_max: float = INF
	for i: int in range(3):
		if absf(d[i]) < 0.00001:
			if absf(o[i]) > half[i]:
				return -1.0
			continue
		var t0: float = (-half[i] - o[i]) / d[i]
		var t1: float = (half[i] - o[i]) / d[i]
		t_min = maxf(t_min, minf(t0, t1))
		t_max = minf(t_max, maxf(t0, t1))
	if t_max < maxf(t_min, 0.0):
		return -1.0
	return maxf(t_min, 0.0)


## Appelé sur l'hôte par la foreuse (`DrillArm`) à chaque étape physique de contact.
## Renvoie vrai si le rocher vient d'être détruit.
func apply_drill_damage(amount: float) -> bool:
	if not multiplayer.is_server() or broken:
		return false
	being_drilled = true
	hp_ratio = maxf(0.0, hp_ratio - amount / maxf(1.0, max_hp))
	if hp_ratio <= 0.0:
		_break_on_host()
		return true
	return false


## Réinitialise le rocher (utile pour les bacs à sable en boucle).
func reset_rock() -> void:
	if not multiplayer.is_server():
		return
	hp_ratio = 1.0
	being_drilled = false
	broken = false


@rpc("authority", "call_local", "reliable")
func play_break_animation() -> void:
	_clear_fragments()
	_break_timer = 0.0
	var colors: Array[Color] = [
		Color(0.22, 0.22, 0.25),
		Color(0.32, 0.33, 0.36),
		Color(0.78, 0.45, 0.22),
		Color(0.92, 0.72, 0.18),
	]
	for i: int in range(CHUNK_COUNT):
		var mesh_inst: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		var s: float = 0.22 + 0.10 * float(i % 3)
		box.size = Vector3(s, s * 0.85, s * 0.9)
		mesh_inst.mesh = box
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		var col: Color = colors[i % colors.size()]
		mat.albedo_color = col
		mat.roughness = 0.45 if i % 4 >= 2 else 0.85
		mat.metallic = 0.7 if i % 4 >= 2 else 0.1
		if i % 4 == 3:
			mat.emission_enabled = true
			mat.emission = col
			mat.emission_energy_multiplier = 0.8
		mesh_inst.material_override = mat
		_fragments_root.add_child(mesh_inst)
		var angle: float = TAU * float(i) / float(CHUNK_COUNT) + 0.25 * float(i % 2)
		var radial: float = 2.4 + 1.2 * float(i % 3)
		var start_pos: Vector3 = Vector3(cos(angle) * 0.42, 0.55 + 0.30 * float(i), sin(angle) * 0.42)
		var vel: Vector3 = Vector3(cos(angle) * radial, 3.0 + 0.9 * float(i % 4), sin(angle) * radial)
		var spin: Vector3 = Vector3(2.5 - float(i % 5), 3.1, -2.2 + float(i % 3))
		mesh_inst.position = start_pos
		_chunks.append({
			"node": mesh_inst,
			"vel": vel,
			"spin": spin,
		})


func _break_on_host() -> void:
	broken = true
	being_drilled = false
	play_break_animation.rpc()
	var crate: CargoCrate = CRATE_SCENE.instantiate() as CargoCrate
	crate.item_kind = drop_item_kind
	var parent_node: Node = drops_container if drops_container != null else get_parent()
	if parent_node != null:
		parent_node.add_child(crate, true)
		crate.global_position = global_position + Vector3(0.0, 0.05, 0.0)
		crate.rotation.y = rotation.y + 0.35
	rock_broken.emit(self, crate)


func _apply_broken_state() -> void:
	if _model != null:
		_model.visible = not broken
		if not broken:
			_model.position = Vector3.ZERO
			_model.rotation = Vector3.ZERO
			_model.scale = Vector3.ONE
	if _collision != null:
		_collision.set_deferred("disabled", broken)


func _update_break_fragments(delta: float) -> void:
	_break_timer += delta
	var t: float = clampf(_break_timer / BREAK_DURATION, 0.0, 1.0)
	for chunk: Dictionary in _chunks:
		var node: Node3D = chunk["node"] as Node3D
		if not is_instance_valid(node):
			continue
		var vel: Vector3 = chunk["vel"] as Vector3
		var spin: Vector3 = chunk["spin"] as Vector3
		vel.y -= 9.8 * delta
		chunk["vel"] = vel
		node.position += vel * delta
		if node.position.y < 0.08:
			node.position.y = 0.08
		node.rotation += spin * delta
		node.scale = Vector3.ONE * (1.0 - t * 0.85)
	if _break_timer >= BREAK_DURATION:
		_clear_fragments()
		_break_timer = -1.0


func _clear_fragments() -> void:
	for chunk: Dictionary in _chunks:
		var node: Node3D = chunk["node"] as Node3D
		if is_instance_valid(node):
			node.queue_free()
	_chunks.clear()
