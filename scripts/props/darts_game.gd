class_name DartsGame
extends Node3D
## Fléchettes du camp (M12.1). On prend les 3 fléchettes au seau posé près de la ligne (`DartsTake`),
## on vise au regard et on lance (clic) depuis derrière la ligne. La fléchette part en cloche ; plantée
## dans la cible, elle marque selon l'anneau (50 au centre … 1 au bord). Après 3 lancers, le total s'affiche
## au tableau à la craie (avec le record du camp) et les fléchettes sont libérées pour le joueur suivant.
##
## Réseau : prendre, lâcher et lancer passent par des RPC vers l'hôte, qui vérifie (portée, derrière la ligne),
## calcule le vol et le score, puis envoie le vol à tout le monde (`_show_throw`) : chaque peer anime la
## fléchette lui-même. L'hôte est autoritaire sur `thrower_peer_id`, les scores et le record (répliqués).
## Repère : celui du chevalet (darts_stand.glb), la cible regarde vers -Z, ligne de tir à z = -3.

const DARTS_PER_ROUND: int = 3
const THROW_SPEED: float = 9.0
const DART_GRAVITY: float = 7.0
const BOARD_CENTER: Vector3 = Vector3(0.0, 1.25, -0.005)
## Panneau de bois derrière la cible : une fléchette qui le touche s'y plante (0 point).
const PANEL_HALF_WIDTH: float = 0.48
const PANEL_Y: Vector2 = Vector2(0.72, 1.78)
## Anneaux : [rayon max (m), points], du centre vers le bord.
const RINGS: Array = [[0.04, 50], [0.1, 25], [0.17, 15], [0.24, 10], [0.3, 5], [0.36, 1]]
const LINE_Z: float = -3.0
const TAKE_REACH: float = 3.0
const ROUND_END_TIME: float = 2.5
const MAX_FLIGHT_TIME: float = 1.5

## Joueur qui a les fléchettes (0 = personne). Autorité : hôte.
var thrower_peer_id: int = 0
var thrower_name: String = ""
## Scores de la manche en cours (0 à 3 lancers). Autorité : hôte.
var round_scores: PackedInt32Array = PackedInt32Array()
## Meilleur total en 3 fléchettes depuis le lancement du camp. Autorité : hôte.
var record: int = 0
var record_name: String = ""

var _round_timer: float = -1.0
var _darts: Array[Node3D] = []
var _flights: Array[Dictionary] = []
var _hand_dart: Node3D

@onready var _score: Label3D = %Score


func _ready() -> void:
	for i: int in DARTS_PER_ROUND:
		var dart: Node3D = _make_dart()
		dart.visible = false
		add_child(dart)
		_darts.append(dart)
		_flights.append({})
	_hand_dart = _make_dart()
	_hand_dart.top_level = true
	_hand_dart.visible = false
	add_child(_hand_dart)
	add_to_group(Possession.GROUP)
	_score.font = preload("res://assets/fonts/fredoka.tres")
	NetworkManager.session_ended.connect(_on_session_ended)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or _round_timer < 0.0:
		return
	_round_timer -= delta
	if _round_timer <= 0.0:
		_round_timer = -1.0
		thrower_peer_id = 0   # manche finie : au suivant


func _process(delta: float) -> void:
	for i: int in _darts.size():
		_animate_dart(i, delta)
	# Fléchette dans la main de celui qui lance (s'il lui en reste).
	var holder: Dwarf = Dwarf.of_peer(thrower_peer_id)
	_hand_dart.visible = holder != null and round_scores.size() < DARTS_PER_ROUND and _round_timer < 0.0
	if _hand_dart.visible:
		_hand_dart.global_transform = holder.get_hold_transform()
	_score.text = _score_text()


## Vrai si le joueur local a les fléchettes en main.
func is_thrower_locally() -> bool:
	return thrower_peer_id != 0 and thrower_peer_id == multiplayer.get_unique_id()


@rpc("any_peer", "call_local", "reliable")
func request_take() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var dwarf: Dwarf = Dwarf.of_peer(sender)
	if dwarf == null or (thrower_peer_id != 0 and thrower_peer_id != sender) or _round_timer >= 0.0:
		return
	if dwarf.global_position.distance_to(to_global(Vector3(0.0, 0.0, LINE_Z))) > TAKE_REACH + 1.0:
		return
	if thrower_peer_id == sender or Possession.is_peer_busy(get_tree(), sender, self):
		return
	thrower_peer_id = sender
	thrower_name = dwarf.get_display_name()
	round_scores = PackedInt32Array()
	_clear_darts.rpc()


@rpc("any_peer", "call_local", "reliable")
func request_release() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == thrower_peer_id and _round_timer < 0.0:
		thrower_peer_id = 0


## Lancer (hôte) : `origin` = les yeux du lanceur, `direction` = où il regarde (global).
@rpc("any_peer", "call_local", "reliable")
func request_throw(origin: Vector3, direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var dwarf: Dwarf = Dwarf.of_peer(sender)
	if sender != thrower_peer_id or dwarf == null or round_scores.size() >= DARTS_PER_ROUND or _round_timer >= 0.0:
		return
	if dwarf.global_position.distance_to(origin) > 2.0 or to_local(dwarf.global_position).z > LINE_Z + 0.3:
		return   # yeux trop loin du nain, ou devant la ligne de tir
	var o: Vector3 = to_local(origin)
	var v: Vector3 = (global_basis.inverse() * direction.normalized()) * THROW_SPEED
	var result: Dictionary = _simulate(o, v)
	var index: int = round_scores.size()
	var scores: PackedInt32Array = round_scores
	scores.append(result["score"])
	round_scores = scores
	_show_throw.rpc(index, o, v, result["time"], result["stuck"])
	if round_scores.size() >= DARTS_PER_ROUND:
		var total: int = _total()
		if total > record:
			record = total
			record_name = thrower_name
		_round_timer = ROUND_END_TIME


## Chez tout le monde : la fléchette `index` vole de `origin` (vitesse `velocity`, repère du jeu) pendant `time`.
@rpc("authority", "call_local", "reliable")
func _show_throw(index: int, origin: Vector3, velocity: Vector3, time: float, stuck: bool) -> void:
	if index < 0 or index >= _darts.size():
		return
	_flights[index] = {"origin": origin, "velocity": velocity, "time": time, "t": 0.0, "stuck": stuck}
	_darts[index].visible = true


@rpc("authority", "call_local", "reliable")
func _clear_darts() -> void:
	for i: int in _darts.size():
		_darts[i].visible = false
		_flights[i] = {}


## Vol en cloche, pas à pas, jusqu'à la cible, le panneau ou le sol. Renvoie score, temps et « plantée ».
func _simulate(o: Vector3, v: Vector3) -> Dictionary:
	var dt: float = 1.0 / 120.0
	var p: Vector3 = o
	var t: float = 0.0
	while t < MAX_FLIGHT_TIME:
		var next: Vector3 = p + v * dt
		v.y -= DART_GRAVITY * dt
		if p.z < BOARD_CENTER.z and next.z >= BOARD_CENTER.z:
			var f: float = (BOARD_CENTER.z - p.z) / (next.z - p.z)
			var hit: Vector3 = p.lerp(next, f)
			if absf(hit.x) <= PANEL_HALF_WIDTH and hit.y >= PANEL_Y.x and hit.y <= PANEL_Y.y:
				var r: float = Vector2(hit.x, hit.y - BOARD_CENTER.y).length()
				return {"score": _ring_score(r), "time": t + f * dt, "stuck": true}
		if next.y <= 0.02:
			return {"score": 0, "time": t + dt, "stuck": false}
		p = next
		t += dt
	return {"score": 0, "time": MAX_FLIGHT_TIME, "stuck": false}


func _ring_score(r: float) -> int:
	for ring: Array in RINGS:
		if r <= ring[0]:
			return ring[1]
	return 0


## Place la fléchette volante `i` sur sa trajectoire (même calcul que l'hôte, en continu).
func _animate_dart(i: int, delta: float) -> void:
	var flight: Dictionary = _flights[i]
	if flight.is_empty():
		return
	flight["t"] = minf(flight["t"] + delta, flight["time"])
	var t: float = flight["t"]
	var o: Vector3 = flight["origin"]
	var v0: Vector3 = flight["velocity"]
	var pos: Vector3 = o + v0 * t + Vector3(0.0, -0.5 * DART_GRAVITY * t * t, 0.0)
	var vel: Vector3 = v0 + Vector3(0.0, -DART_GRAVITY * t, 0.0)
	if t >= flight["time"] and not flight["stuck"]:
		vel = Vector3(vel.x, 0.0, vel.z)   # tombée par terre : couchée sur le sable
	_darts[i].position = pos
	if vel.length() > 0.01:
		_darts[i].basis = Basis.looking_at(vel.normalized(), Vector3.UP if absf(vel.normalized().y) < 0.95 else Vector3.FORWARD)


func _score_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("FLÉCHETTES")
	if thrower_name != "":
		lines.append(thrower_name)
		var marks: PackedStringArray = PackedStringArray()
		for i: int in DARTS_PER_ROUND:
			marks.append(str(round_scores[i]) if i < round_scores.size() else "–")
		lines.append("  ".join(marks))
		lines.append("total %d" % _total())
	if record > 0:
		lines.append("record %d (%s)" % [record, record_name])
	return "\n".join(lines)


func _total() -> int:
	var total: int = 0
	for s: int in round_scores:
		total += s
	return total


## Une fléchette : pointe vers -Z (fût en cuivre, empennage rouge).
func _make_dart() -> Node3D:
	var dart: Node3D = Node3D.new()
	var shaft: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.0
	cyl.bottom_radius = 0.008
	cyl.height = 0.17
	cyl.radial_segments = 6
	cyl.rings = 1
	var copper: StandardMaterial3D = StandardMaterial3D.new()
	copper.albedo_color = Color(0.78, 0.45, 0.22)
	copper.metallic = 0.9
	copper.roughness = 0.35
	cyl.material = copper
	shaft.mesh = cyl
	shaft.rotation.x = -PI / 2.0   # le haut du cône (la pointe) vers -Z
	dart.add_child(shaft)
	var flight: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.07, 0.003, 0.05)
	var red: StandardMaterial3D = StandardMaterial3D.new()
	red.albedo_color = Color(0.7, 0.1, 0.08)
	box.material = red
	flight.mesh = box
	flight.position = Vector3(0.0, 0.0, 0.08)
	dart.add_child(flight)
	var flight2: MeshInstance3D = flight.duplicate() as MeshInstance3D
	flight2.rotation.z = PI / 2.0
	dart.add_child(flight2)
	return dart


func _on_session_ended(_reason: String) -> void:
	thrower_peer_id = 0
	thrower_name = ""
	round_scores = PackedInt32Array()
	_round_timer = -1.0
	_clear_darts()
