class_name Backpack
extends Node3D
## Gros sac à dos du mécha (M10 — Inventaire), fixé dans le dos du ventre.
## Reçoit automatiquement les objets attrapés (grappin M9, caisses de ravitaillement,
## ou objets lancés dans son ouverture) avec une animation de rangement :
## le couvercle s'ouvre, l'objet décrit un arc par-dessus l'épaule jusque dans le sac,
## le tas intérieur et la jauge arrière montent, puis le couvercle se referme.
##
## Réseau : l'hôte est seul autoritaire sur `stored_items` (répliqué par MultiplayerSynchronizer)
## et déclenche l'animation chez tous les peers via `play_store_animation` (aucune position
## d'animation envoyée en continu).

signal item_stored(item_kind: String, total_count: int)

const CRATE_MODEL: PackedScene = preload("res://assets/models/props/cargo_crate.glb")
const LID_OPEN_ANGLE: float = -deg_to_rad(72.0)
const PHASE_RISE_END: float = 0.52
const PHASE_DROP_END: float = 0.92
const SHOULDER_LOCAL_POS: Vector3 = Vector3(-0.95, 3.15, 0.45)
const HOVER_LOCAL_POS: Vector3 = Vector3(0.0, 3.35, 0.88)
const WELL_BASE_POS: Vector3 = Vector3(0.0, 1.72, 0.88)
const WELL_TOP_POS: Vector3 = Vector3(0.0, 2.32, 0.88)
const GAUGE_HEIGHT: float = 0.64

## Capacité maximale du sac à dos (nombre d'objets).
@export var max_capacity: int = 10
## Vitesse d'ouverture / fermeture du couvercle (rad/s).
@export var lid_speed: float = 7.5

## Liste des types d'objets rangés ("crate", "ore", "poop", "poop_gold"…). Autorité : hôte.
var stored_items: PackedStringArray = PackedStringArray():
	set(value):
		stored_items = value
		if is_node_ready():
			_refresh_inventory_visuals()

var _lid_open_timer: float = 0.0
var _lid_angle: float = 0.0
var _pile_bounce: float = 0.0
var _flights: Array[Dictionary] = []
var _gauge_mat: StandardMaterial3D

@onready var _lid_pivot: Node3D = %LidPivot
@onready var _cargo_pile: Node3D = %CargoPile
@onready var _flying_items: Node3D = %FlyingItems
@onready var _gauge_bar: MeshInstance3D = %GaugeBar
@onready var _catch_zone: Area3D = %CatchZone


func _ready() -> void:
	add_to_group(&"backpacks")
	_setup_gauge_material()
	_catch_zone.body_entered.connect(_on_catch_zone_body_entered)
	NetworkManager.session_ended.connect(_on_session_ended)
	_refresh_inventory_visuals()


func _physics_process(delta: float) -> void:
	if _lid_open_timer > 0.0:
		_lid_open_timer = maxf(0.0, _lid_open_timer - delta)
	var target_angle: float = LID_OPEN_ANGLE if (_lid_open_timer > 0.0 or not _flights.is_empty()) else 0.0
	_lid_angle = move_toward(_lid_angle, target_angle, lid_speed * delta)
	_lid_pivot.rotation.x = _lid_angle

	if _pile_bounce > 0.0:
		_pile_bounce = maxf(0.0, _pile_bounce - delta * 3.5)
		var pulse: float = 1.0 + 0.14 * sin(_pile_bounce * PI)
		_cargo_pile.scale = Vector3(1.0, pulse, 1.0)
	else:
		_cargo_pile.scale = Vector3.ONE

	_update_flights(delta)


## Vrai si le sac à dos est plein.
func is_full() -> bool:
	return stored_items.size() >= max_capacity


## Nombre d'objets actuellement stockés dans le sac.
func get_item_count() -> int:
	return stored_items.size()


## Range un nœud du monde dans le sac (appelé sur l'hôte par le grappin M9, une caisse, ou la zone de capture).
## Renvoie vrai si l'objet a été accepté et rangé.
func store_node(item: Node3D, item_kind: String = "crate") -> bool:
	if not multiplayer.is_server():
		return false
	if item == null or not is_instance_valid(item) or is_full():
		return false
	var start_local_pos: Vector3 = to_local(item.global_position)
	var start_local_rot: Vector3 = item.rotation
	var next_items: PackedStringArray = stored_items.duplicate()
	next_items.append(item_kind)
	stored_items = next_items
	if item is Poop:
		(item as Poop).disarm()
	item.queue_free()
	play_store_animation.rpc(item_kind, start_local_pos, start_local_rot)
	item_stored.emit(item_kind, stored_items.size())
	return true


## Vide le sac à dos (autoritaire sur l'hôte).
func clear_inventory() -> void:
	if not multiplayer.is_server():
		return
	stored_items = PackedStringArray()


## Joué chez tous les peers quand l'hôte valide le rangement d'un objet.
@rpc("authority", "call_local", "reliable")
func play_store_animation(item_kind: String, start_local_pos: Vector3, start_local_rot: Vector3) -> void:
	_lid_open_timer = maxf(_lid_open_timer, PHASE_DROP_END + 0.38)
	var proxy: Node3D = _build_item_visual(item_kind)
	_flying_items.add_child(proxy)
	proxy.position = start_local_pos
	proxy.rotation = start_local_rot
	# Si l'objet part de la gauche ou de l'avant du mécha (cas du grappin M9), il passe par l'épaule gauche.
	var shoulder: Vector3 = SHOULDER_LOCAL_POS
	if start_local_pos.x > 0.3:
		shoulder.x = -SHOULDER_LOCAL_POS.x
	_flights.append({
		"node": proxy,
		"start_pos": start_local_pos,
		"shoulder_pos": shoulder,
		"start_rot": start_local_rot,
		"time": 0.0,
	})


func _update_flights(delta: float) -> void:
	var i: int = _flights.size() - 1
	while i >= 0:
		var flight: Dictionary = _flights[i]
		var node: Node3D = flight["node"] as Node3D
		if not is_instance_valid(node):
			_flights.remove_at(i)
			i -= 1
			continue
		var t: float = (flight["time"] as float) + delta
		flight["time"] = t
		var start_pos: Vector3 = flight["start_pos"] as Vector3
		var shoulder_pos: Vector3 = flight["shoulder_pos"] as Vector3
		var start_rot: Vector3 = flight["start_rot"] as Vector3

		if t < PHASE_RISE_END:
			var u: float = clampf(t / PHASE_RISE_END, 0.0, 1.0)
			var s: float = u * u * (3.0 - 2.0 * u)
			# Courbe de Bézier quadratique : départ -> épaule -> juste au-dessus du puits ouvert.
			var p0: Vector3 = start_pos.lerp(shoulder_pos, s)
			var p1: Vector3 = shoulder_pos.lerp(HOVER_LOCAL_POS, s)
			node.position = p0.lerp(p1, s)
			node.rotation = start_rot + Vector3(0.8 * s, 1.4 * s, 0.4 * s)
			node.scale = Vector3.ONE
		elif t < PHASE_DROP_END:
			var u: float = clampf((t - PHASE_RISE_END) / (PHASE_DROP_END - PHASE_RISE_END), 0.0, 1.0)
			var ease_in: float = u * u
			var fill_ratio: float = clampf(float(stored_items.size()) / float(maxf(1, max_capacity)), 0.0, 1.0)
			var target_well: Vector3 = WELL_BASE_POS.lerp(WELL_TOP_POS, fill_ratio * 0.75)
			node.position = HOVER_LOCAL_POS.lerp(target_well, ease_in)
			node.rotation = start_rot + Vector3(0.8 + 1.2 * u, 1.4 + 1.0 * u, 0.4)
			node.scale = Vector3.ONE * lerpf(1.0, 0.72, u)
		else:
			node.queue_free()
			_flights.remove_at(i)
			_pile_bounce = 1.0
			_refresh_inventory_visuals()
		i -= 1


func _refresh_inventory_visuals() -> void:
	var count: int = stored_items.size()
	var ratio: float = clampf(float(count) / float(maxf(1, max_capacity)), 0.0, 1.0)

	# 1. Jauge lumineuse à l'arrière du sac
	if _gauge_bar != null:
		_gauge_bar.visible = count > 0
		var h: float = maxf(0.02, GAUGE_HEIGHT * ratio)
		_gauge_bar.scale = Vector3(1.0, maxf(0.03, ratio), 1.0)
		_gauge_bar.position.y = 1.60 + h * 0.5
		if _gauge_mat != null:
			var col: Color = Color(0.25, 0.82, 0.35).lerp(Color(0.95, 0.62, 0.18), ratio)
			_gauge_mat.albedo_color = col
			_gauge_mat.emission = col

	# 2. Tas d'objets visible à l'intérieur du puits quand le couvercle s'ouvre
	if _cargo_pile != null:
		for child: Node in _cargo_pile.get_children():
			child.queue_free()
		var slots: Array[Vector3] = [
			Vector3(-0.72, 0.0, -0.18),
			Vector3(0.0, 0.0, 0.08),
			Vector3(0.72, 0.0, -0.14),
			Vector3(-0.42, 0.22, 0.14),
			Vector3(0.42, 0.22, 0.10),
			Vector3(-0.75, 0.38, -0.05),
			Vector3(0.0, 0.42, -0.12),
			Vector3(0.70, 0.40, 0.06),
			Vector3(-0.36, 0.56, 0.05),
			Vector3(0.36, 0.58, -0.04),
		]
		var shown: int = mini(count, slots.size())
		for idx: int in range(shown):
			var kind: String = stored_items[idx]
			var item_vis: Node3D = _build_item_visual(kind)
			item_vis.scale = Vector3.ONE * 0.68
			item_vis.position = slots[idx]
			item_vis.rotation = Vector3(0.08 * float((idx % 3) - 1), 0.55 * float(idx), 0.06 * float(idx % 2))
			_cargo_pile.add_child(item_vis)


func _build_item_visual(item_kind: String) -> Node3D:
	if item_kind == "poop" or item_kind == "poop_gold":
		var holder: Node3D = Node3D.new()
		var mesh_inst: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.22
		sphere.height = 0.38
		mesh_inst.mesh = sphere
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		if item_kind == "poop_gold":
			mat.albedo_color = Color(1.0, 0.78, 0.2)
			mat.metallic = 1.0
			mat.roughness = 0.2
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.7, 0.2)
		else:
			mat.albedo_color = Color(0.36, 0.22, 0.11)
			mat.roughness = 0.85
		mesh_inst.material_override = mat
		holder.add_child(mesh_inst)
		return holder
	return CRATE_MODEL.instantiate() as Node3D


func _setup_gauge_material() -> void:
	_gauge_mat = StandardMaterial3D.new()
	_gauge_mat.albedo_color = Color(0.25, 0.82, 0.35)
	_gauge_mat.roughness = 0.35
	_gauge_mat.emission_enabled = true
	_gauge_mat.emission = Color(0.25, 0.82, 0.35)
	_gauge_mat.emission_energy_multiplier = 0.65
	if _gauge_bar != null:
		_gauge_bar.material_override = _gauge_mat


func _on_catch_zone_body_entered(body: Node) -> void:
	if not multiplayer.is_server() or is_full():
		return
	if body is Poop:
		var poop: Poop = body as Poop
		if poop.holder_peer_id == 0:
			store_node(poop, "poop_gold" if poop.golden else "poop")
	elif body is CargoCrate:
		var crate: CargoCrate = body as CargoCrate
		if crate.holder_peer_id == 0:
			store_node(crate, crate.item_kind)


func _on_session_ended(_reason: String) -> void:
	stored_items = PackedStringArray()
	_lid_open_timer = 0.0
	for flight: Dictionary in _flights:
		var node: Node3D = flight["node"] as Node3D
		if is_instance_valid(node):
			node.queue_free()
	_flights.clear()
