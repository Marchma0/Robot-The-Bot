class_name DartsGame
extends Node3D
## Jeu de fléchettes du robot, sur la cible du salon (ventre). Trois fléchettes (DartHandle), plantées dans
## la cible au départ. On vise la cible (DartsTake) ou une fléchette plantée pour prendre toutes les fléchettes
## libres d'un coup, puis on lance au regard (clic), de n'importe où dans le robot. La fléchette part en cloche
## et se plante là où elle tape : la cible (points selon l'anneau, « Dans le mille ! » au centre), un mur,
## un meuble… ou un autre nain : il a la vue brouillée tant qu'elle est plantée, et un autre nain doit venir
## la lui retirer (elle retourne sur la cible). Après le dernier lancer, le total s'affiche quelques secondes.
##
## Réseau : prendre, poser, lancer et retirer passent par des RPC vers l'hôte, qui vérifie, calcule le vol
## (rayons contre le monde et les nains) et le score, puis envoie le vol à tout le monde (`_show_throw`) :
## chaque peer anime la fléchette lui-même. L'hôte tient (synchronisé) qui lance, les scores de la manche
## et la place de chaque fléchette (`dart_where`, `dart_pos`, `dart_dir`, `dart_peer`).
## Repère : celui de la cible (centre de la cible contre le mur, elle regarde vers -Z).

enum Where { PLANTED, IN_HAND, IN_DWARF }

const DART_SCENE: PackedScene = preload("res://scenes/mecha/props/dart.tscn")
const DART_MODEL: PackedScene = preload("res://assets/models/props/dart.glb")
const DART_COUNT: int = 3
const THROW_SPEED: float = 9.0
const DART_GRAVITY: float = 7.0
## La pointe s'enfonce de ça (m) là où elle touche.
const EMBED: float = 0.02
## Anneaux de la cible : [rayon max (m), points], du centre vers le bord (même tracé que dartboard_wall.py).
const RINGS: Array = [[0.04, 50], [0.12, 20], [0.19, 10], [0.25, 5]]
const BULLSEYE_POINTS: int = 50
## Fléchettes au repos, plantées dans la cible (x, y sur la cible, un peu de biais).
const REST_SPOTS: Array[Vector3] = [Vector3(0.09, 0.1, 0.0), Vector3(-0.11, 0.02, 0.0), Vector3(0.03, -0.13, 0.0)]
const BOARD_FRONT_Z: float = -0.04
## Distance max pour prendre les fléchettes (depuis la cible ou une fléchette plantée) et pour en retirer une.
const TAKE_REACH: float = 3.0
const PULL_REACH: float = 2.5
const MAX_FLIGHT_TIME: float = 1.5
## Fléchette dans un nain : plantée dans sa tête, du côté d'où elle arrive (repère de l'os de la tête).
const HEAD_CENTER: Vector3 = Vector3(0.0, 0.03, -0.02)
const HEAD_RADIUS: float = 0.24
const SCORE_SHOW_TIME: float = 4.0

## Joueur qui a les fléchettes en main (0 = personne). Autorité : hôte.
var thrower_peer_id: int = 0
var thrower_name: String = ""
## Points de chaque lancer de la manche en cours. Autorité : hôte.
var round_scores: PackedInt32Array = PackedInt32Array()
## Place de chaque fléchette (Where). Autorité : hôte.
var dart_where: PackedInt32Array = PackedInt32Array()
## Pointe et direction de chaque fléchette : repère du jeu (PLANTED) ou de la tête du nain touché (IN_DWARF).
var dart_pos: PackedVector3Array = PackedVector3Array()
var dart_dir: PackedVector3Array = PackedVector3Array()
## Nain dans lequel la fléchette est plantée (IN_DWARF), sinon 0.
var dart_peer: PackedInt32Array = PackedInt32Array()

var _darts: Array[DartHandle] = []
var _flights: Array[Dictionary] = []
var _hand_dart: Node3D
## Hôte : fin de manche dans ce temps (s), -1 = pas de manche qui se termine.
var _round_end_timer: float = -1.0
var _blind_shown: bool = false
var _score_timer: float = 0.0
var _cheer_timer: float = 0.0

@onready var _board_body: CollisionObject3D = %BoardBody
@onready var _score_pop: Label3D = %ScorePop
@onready var _cheer: Label3D = %Cheer
@onready var _confetti: CPUParticles3D = %Confetti
@onready var _flash: OmniLight3D = %Flash


func _ready() -> void:
	for i: int in DART_COUNT:
		var dart: DartHandle = DART_SCENE.instantiate() as DartHandle
		dart.game = self
		dart.index = i
		add_child(dart)
		_darts.append(dart)
		_flights.append({})
	_put_all_on_board()
	_hand_dart = DART_MODEL.instantiate() as Node3D
	_hand_dart.top_level = true
	_hand_dart.visible = false
	add_child(_hand_dart)
	add_to_group(Possession.GROUP)
	var font: Font = preload("res://assets/fonts/fredoka.tres")
	_score_pop.font = font
	_cheer.font = font
	_score_pop.visible = false
	_cheer.visible = false
	NetworkManager.session_ended.connect(_on_session_ended)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _round_end_timer >= 0.0:
		_round_end_timer -= delta
		if _round_end_timer < 0.0:
			_show_score.rpc(thrower_name, _total())
			thrower_peer_id = 0
	# Joueur parti : ses fléchettes retournent sur la cible.
	if thrower_peer_id != 0 and Dwarf.of_peer(thrower_peer_id) == null:
		_return_held_darts()
		thrower_peer_id = 0
	for i: int in DART_COUNT:
		if dart_where[i] == Where.IN_DWARF and Dwarf.of_peer(dart_peer[i]) == null:
			_put_on_board(i)


func _process(delta: float) -> void:
	var me: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var blind: bool = false
	for i: int in DART_COUNT:
		if _animate_flight(i, delta):
			continue
		var dart: DartHandle = _darts[i]
		match dart_where[i]:
			Where.PLANTED:
				dart.visible = true
				dart.transform = _dart_transform(dart_pos[i], dart_dir[i])
			Where.IN_HAND:
				dart.visible = false
			Where.IN_DWARF:
				var dwarf: Dwarf = Dwarf.of_peer(dart_peer[i])
				# Le nain touché ne voit pas sa propre fléchette (elle lui rentrerait dans l'œil) : il a l'écran brouillé.
				dart.visible = dwarf != null and dart_peer[i] != me
				if dwarf != null:
					var head: Node3D = dwarf.get_head_attach()
					dart.global_transform = _dart_transform(head.global_transform * dart_pos[i],
						(head.global_basis * dart_dir[i]).normalized())
				blind = blind or dart_peer[i] == me
		dart.set_pickable(dart_where[i] != Where.IN_HAND)
	if blind != _blind_shown:
		var local: Dwarf = Dwarf.of_peer(me)
		if local != null:
			_blind_shown = blind
			local.set_dart_blind(blind)
	# Fléchette dans la main de celui qui lance (s'il lui en reste).
	var holder: Dwarf = Dwarf.of_peer(thrower_peer_id)
	_hand_dart.visible = holder != null and darts_in_hand() > 0
	if _hand_dart.visible:
		_hand_dart.global_transform = holder.get_hold_transform()
	_update_effects(delta)


## Vrai si le joueur local a les fléchettes en main.
func is_thrower_locally() -> bool:
	return thrower_peer_id != 0 and thrower_peer_id == multiplayer.get_unique_id()


func darts_in_hand() -> int:
	return dart_where.count(Where.IN_HAND)


## Prendre toutes les fléchettes libres (plantées ailleurs que dans un nain).
@rpc("any_peer", "call_local", "reliable")
func request_take() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var dwarf: Dwarf = Dwarf.of_peer(sender)
	if dwarf == null or thrower_peer_id != 0 or _round_end_timer >= 0.0 or not _near_a_dart(dwarf):
		return
	if dart_where.count(Where.PLANTED) == 0 or Possession.is_peer_busy(get_tree(), sender, self):
		return
	var where: PackedInt32Array = dart_where
	for i: int in DART_COUNT:
		if where[i] == Where.PLANTED:
			where[i] = Where.IN_HAND
	dart_where = where
	thrower_peer_id = sender
	thrower_name = dwarf.get_display_name()
	round_scores = PackedInt32Array()


## Poser : les fléchettes encore en main retournent sur la cible.
@rpc("any_peer", "call_local", "reliable")
func request_release() -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != thrower_peer_id:
		return
	if _round_end_timer >= 0.0:
		return   # la manche se termine déjà
	_return_held_darts()
	thrower_peer_id = 0


## Lancer (hôte) : `origin` = les yeux du lanceur, `direction` = où il regarde (global).
@rpc("any_peer", "call_local", "reliable")
func request_throw(origin: Vector3, direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var dwarf: Dwarf = Dwarf.of_peer(sender)
	var index: int = dart_where.find(Where.IN_HAND)
	if sender != thrower_peer_id or dwarf == null or index < 0 or direction.length() < 0.1:
		return
	if dwarf.global_position.distance_to(origin) > 2.0:
		return   # yeux trop loin du nain
	var velocity: Vector3 = direction.normalized() * THROW_SPEED
	var result: Dictionary = _simulate(origin, velocity, dwarf)
	var scores: PackedInt32Array = round_scores
	scores.append(result["score"])
	round_scores = scores
	_land(index, result)
	_show_throw.rpc(index, to_local(origin), global_basis.inverse() * velocity, result["time"],
		result["score"] == BULLSEYE_POINTS)
	if darts_in_hand() == 0:
		_round_end_timer = result["time"] + 0.4


## Retirer la fléchette `index` plantée dans un autre nain : elle retourne sur la cible.
@rpc("any_peer", "call_local", "reliable")
func request_pull(index: int) -> void:
	if not multiplayer.is_server() or index < 0 or index >= DART_COUNT or dart_where[index] != Where.IN_DWARF:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var puller: Dwarf = Dwarf.of_peer(sender)
	var victim: Dwarf = Dwarf.of_peer(dart_peer[index])
	if puller == null or sender == dart_peer[index]:
		return   # on ne peut pas se l'enlever soi-même
	if victim != null and puller.global_position.distance_to(victim.global_position) > PULL_REACH:
		return
	_put_on_board(index)


## Chez tout le monde : la fléchette `index` vole de `origin` (vitesse `velocity`, repère du jeu) pendant `time`.
@rpc("authority", "call_local", "reliable")
func _show_throw(index: int, origin: Vector3, velocity: Vector3, time: float, bullseye: bool) -> void:
	if index < 0 or index >= DART_COUNT:
		return
	_flights[index] = {"origin": origin, "velocity": velocity, "time": time, "t": 0.0, "bullseye": bullseye}
	_darts[index].visible = true


## Chez tout le monde : le total de la manche s'affiche quelques secondes au-dessus de la cible.
@rpc("authority", "call_local", "reliable")
func _show_score(player_name: String, total: int) -> void:
	_score_pop.text = tr("%s : %d points") % [player_name, total]
	_score_pop.visible = true
	_score_timer = SCORE_SHOW_TIME


## Vol en cloche (hôte), pas à pas, avec un rayon à chaque pas contre le monde et les nains (sauf le lanceur).
## Renvoie : temps de vol, points, et où la fléchette se plante (« dwarf », « point », « dir »), ou rien (perdue).
func _simulate(origin: Vector3, velocity: Vector3, thrower: Dwarf) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var gravity: Vector3 = -global_basis.y * DART_GRAVITY
	var dt: float = 1.0 / 120.0
	var p: Vector3 = origin
	var t: float = 0.0
	while t < MAX_FLIGHT_TIME:
		var next: Vector3 = p + velocity * dt
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p, next, 1, [thrower.get_rid()])
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			var point: Vector3 = hit["position"]
			var f: float = p.distance_to(point) / maxf(p.distance_to(next), 0.0001)
			var result: Dictionary = {"time": t + f * dt, "score": 0, "point": point, "dir": velocity.normalized()}
			var collider: Object = hit["collider"]
			if collider is Dwarf:
				result["dwarf"] = collider
			elif collider == _board_body:
				var on_board: Vector3 = to_local(point)
				result["score"] = _ring_score(Vector2(on_board.x, on_board.y).length())
			return result
		velocity += gravity * dt
		p = next
		t += dt
	return {"time": MAX_FLIGHT_TIME, "score": 0}


## Hôte : la fléchette `index` se plante là où le vol s'arrête (ou retourne sur la cible si elle est perdue).
func _land(index: int, result: Dictionary) -> void:
	if not result.has("point"):
		_put_on_board(index)
		return
	var tip: Vector3 = result["point"] + (result["dir"] as Vector3) * EMBED
	var where: PackedInt32Array = dart_where
	var pos: PackedVector3Array = dart_pos
	var dir: PackedVector3Array = dart_dir
	var peer: PackedInt32Array = dart_peer
	if result.has("dwarf"):
		var dwarf: Dwarf = result["dwarf"]
		var head: Node3D = dwarf.get_head_attach()
		var local_dir: Vector3 = (head.global_basis.inverse() * (result["dir"] as Vector3)).normalized()
		where[index] = Where.IN_DWARF
		pos[index] = HEAD_CENTER - local_dir * (HEAD_RADIUS - EMBED)
		dir[index] = local_dir
		peer[index] = dwarf.peer_id
		get_tree().create_timer(result["time"]).timeout.connect(_hit_dwarf.bind(dwarf.peer_id))
	else:
		where[index] = Where.PLANTED
		pos[index] = to_local(tip)
		dir[index] = global_basis.inverse() * result["dir"]
		peer[index] = 0
	dart_where = where
	dart_pos = pos
	dart_dir = dir
	dart_peer = peer


func _hit_dwarf(peer_id: int) -> void:
	var dwarf: Dwarf = Dwarf.of_peer(peer_id)
	if dwarf != null:
		dwarf.receive_dart.rpc()


func _ring_score(r: float) -> int:
	for ring: Array in RINGS:
		if r <= ring[0]:
			return ring[1]
	return 0


func _put_all_on_board() -> void:
	dart_where = PackedInt32Array()
	dart_pos = PackedVector3Array()
	dart_dir = PackedVector3Array()
	dart_peer = PackedInt32Array()
	for i: int in DART_COUNT:
		dart_where.append(Where.PLANTED)
		dart_pos.append(Vector3.ZERO)
		dart_dir.append(Vector3.FORWARD)
		dart_peer.append(0)
		_put_on_board(i)


## Hôte (et au départ) : la fléchette `index` retourne à sa place de repos, plantée dans la cible.
func _put_on_board(index: int) -> void:
	var spot: Vector3 = REST_SPOTS[index]
	var tilt: Vector3 = Vector3(spot.x * 0.6, spot.y * 0.6, 1.0).normalized()   # un peu de biais, vers le mur
	var where: PackedInt32Array = dart_where
	var pos: PackedVector3Array = dart_pos
	var dir: PackedVector3Array = dart_dir
	var peer: PackedInt32Array = dart_peer
	where[index] = Where.PLANTED
	pos[index] = Vector3(spot.x, spot.y, BOARD_FRONT_Z) + tilt * EMBED
	dir[index] = tilt
	peer[index] = 0
	dart_where = where
	dart_pos = pos
	dart_dir = dir
	dart_peer = peer


func _return_held_darts() -> void:
	for i: int in DART_COUNT:
		if dart_where[i] == Where.IN_HAND:
			_put_on_board(i)


func _near_a_dart(dwarf: Dwarf) -> bool:
	if dwarf.global_position.distance_to(global_position) <= TAKE_REACH:
		return true
	for i: int in DART_COUNT:
		if dart_where[i] == Where.PLANTED and dwarf.global_position.distance_to(to_global(dart_pos[i])) <= TAKE_REACH:
			return true
	return false


## Fléchette dont la pointe est en `tip` et qui pointe vers `dir` (repère du parent).
func _dart_transform(tip: Vector3, dir: Vector3) -> Transform3D:
	var up: Vector3 = Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.FORWARD
	return Transform3D(Basis.looking_at(dir, up), tip)


## Fléchette `i` en vol : la place sur sa trajectoire (même calcul que l'hôte). Faux si elle ne vole pas.
func _animate_flight(i: int, delta: float) -> bool:
	var flight: Dictionary = _flights[i]
	if flight.is_empty():
		return false
	flight["t"] = minf(flight["t"] + delta, flight["time"])
	var t: float = flight["t"]
	var v0: Vector3 = flight["velocity"]
	var pos: Vector3 = (flight["origin"] as Vector3) + v0 * t + Vector3(0.0, -0.5 * DART_GRAVITY * t * t, 0.0)
	var vel: Vector3 = v0 + Vector3(0.0, -DART_GRAVITY * t, 0.0)
	_darts[i].visible = true
	_darts[i].set_pickable(false)
	_darts[i].transform = _dart_transform(pos, vel)
	if t >= flight["time"]:
		_flights[i] = {}
		if flight["bullseye"]:
			_celebrate()
	return true


## « Dans le mille ! » : confettis, éclair de lumière et texte qui saute au-dessus de la cible (chez chacun).
func _celebrate() -> void:
	_confetti.restart()
	_confetti.emitting = true
	_cheer_timer = 1.8
	_cheer.visible = true


func _update_effects(delta: float) -> void:
	if _cheer_timer > 0.0:
		_cheer_timer -= delta
		var age: float = 1.8 - _cheer_timer
		var pop: float = minf(age / 0.15, 1.0)
		_cheer.scale = Vector3.ONE * (0.4 + 0.8 * pop - 0.2 * clampf((age - 0.15) / 0.2, 0.0, 1.0))
		_cheer.position.y = 0.38 + age * 0.12
		_cheer.modulate.a = clampf(_cheer_timer / 0.5, 0.0, 1.0)
		_cheer.outline_modulate.a = _cheer.modulate.a
		_flash.light_energy = maxf(0.0, 3.0 * (1.0 - age / 0.6))
		if _cheer_timer <= 0.0:
			_cheer.visible = false
			_flash.light_energy = 0.0
	if _score_timer > 0.0:
		_score_timer -= delta
		var age_s: float = SCORE_SHOW_TIME - _score_timer
		_score_pop.scale = Vector3.ONE * (0.5 + 0.5 * minf(age_s / 0.2, 1.0))
		_score_pop.modulate.a = clampf(_score_timer / 0.6, 0.0, 1.0)
		_score_pop.outline_modulate.a = _score_pop.modulate.a
		if _score_timer <= 0.0:
			_score_pop.visible = false


func _total() -> int:
	var total: int = 0
	for s: int in round_scores:
		total += s
	return total


func _on_session_ended(_reason: String) -> void:
	thrower_peer_id = 0
	thrower_name = ""
	round_scores = PackedInt32Array()
	_round_end_timer = -1.0
	for i: int in DART_COUNT:
		_flights[i] = {}
	_put_all_on_board()
