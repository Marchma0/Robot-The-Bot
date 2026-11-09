class_name DartsGame
extends Node3D
## Jeu de fléchettes du robot, sur la cible du salon (ventre). Trois fléchettes (DartHandle), plantées dans
## la cible au départ. On vise la cible (DartsTake) ou une fléchette plantée (E) pour prendre toutes les fléchettes
## libres d'un coup : elles vont ensemble dans une case de l'inventaire (Inventory). Case en main, on lance au
## regard (clic), de n'importe où dans le robot ; G en pose une couchée au sol, devant soi. Si des fléchettes
## traînent ailleurs, un clic sur la cible les y remet toutes (`request_reset`). La fléchette part en cloche
## et se plante là où elle tape : la cible (points selon l'anneau, « Dans le mille ! » au centre), un mur,
## un meuble… ou un autre nain : plantée au visage (de face, à hauteur de tête), il a la vue brouillée ; ailleurs
## (casque, corps), il a juste un flash rouge de douleur. Dans tous les cas, un autre nain doit venir la lui
## retirer : elle va dans l'inventaire de celui qui la retire (sur la cible s'il n'a plus de place).
## Une manche = les lancers d'un même joueur (3 au plus) ; elle se termine quand il n'a plus de fléchette en main,
## qu'il les repose, ou qu'un autre lance. Les scores s'écrivent à la craie sur l'ardoise d'à côté (`ChalkScoreboard`).
##
## Réseau : prendre, poser, lancer et retirer passent par des RPC vers l'hôte, qui vérifie, calcule le vol
## (rayons contre le monde et les nains) et le score, puis envoie le vol à tout le monde (`_show_throw`) :
## chaque peer anime la fléchette lui-même. L'hôte tient (synchronisé) le lanceur de la manche, ses scores,
## les dernières manches et la place de chaque fléchette (`dart_where`, `dart_pos`, `dart_dir`, `dart_peer`,
## `dart_slot` : la case de l'inventaire de celui qui l'a en main).
## Repère : celui de la cible (centre de la cible contre le mur, elle regarde vers -Z).

enum Where { PLANTED, IN_HAND, IN_DWARF }
## Où une fléchette est plantée dans un nain : casque (côté, arrière), visage (vue brouillée), corps.
enum Spot { HEAD, FACE, BODY }

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
## Rayon de la cible (m) : une fléchette plantée plus loin du centre « traîne » ailleurs (has_darts_away).
const BOARD_RADIUS: float = 0.3
## Fléchette posée au sol (G) : à cette distance devant le nain, et ce petit écart au-dessus du sol (m).
const DROP_DISTANCE: float = 0.5
const DROP_LIFT: float = 0.012
## Distance max pour prendre les fléchettes (depuis la cible ou une fléchette plantée) et pour en retirer une.
const TAKE_REACH: float = 3.0
const PULL_REACH: float = 2.5
const MAX_FLIGHT_TIME: float = 1.5
## Fléchette dans un nain : plantée dans sa tête, du côté d'où elle arrive (repère de l'os de la tête).
const HEAD_CENTER: Vector3 = Vector3(0.0, 0.03, -0.02)
const HEAD_RADIUS: float = 0.24
## Touché à partir de cette hauteur (m, depuis les pieds) : la tête, sinon le corps (repère de l'os du torse).
const HEAD_ZONE_HEIGHT: float = 0.78
const TORSO_CENTER: Vector3 = Vector3(0.0, 0.15, 0.0)
const TORSO_RADIUS: float = 0.3
## Au visage : la fléchette arrive de face, à moins de 60° de l'axe du regard du nain.
const FACE_CONE_COS: float = 0.5
## Manches gardées sur l'ardoise.
const HISTORY_SIZE: int = 4

## Joueur dont la manche est en cours (0 = personne). Autorité : hôte.
var thrower_peer_id: int = 0
var thrower_name: String = ""
## Points de chaque lancer de la manche en cours. Autorité : hôte.
var round_scores: PackedInt32Array = PackedInt32Array()
## La manche affichée est finie (toutes les fléchettes lancées, ou reposées). Autorité : hôte.
var round_done: bool = false
## Dernières manches finies, la plus récente en premier : lanceur et total. Autorité : hôte.
var history_names: PackedStringArray = PackedStringArray()
var history_totals: PackedInt32Array = PackedInt32Array()
## Place de chaque fléchette (Where). Autorité : hôte.
var dart_where: PackedInt32Array = PackedInt32Array()
## Pointe et direction de chaque fléchette : repère du jeu (PLANTED) ou de la tête du nain touché (IN_DWARF).
var dart_pos: PackedVector3Array = PackedVector3Array()
var dart_dir: PackedVector3Array = PackedVector3Array()
## Nain dans lequel la fléchette est plantée (IN_DWARF) ou qui l'a sur lui (IN_HAND), sinon 0.
var dart_peer: PackedInt32Array = PackedInt32Array()
## Case de l'inventaire de ce nain (IN_HAND). Les fléchettes d'un même nain sont toutes dans la même case.
var dart_slot: PackedInt32Array = PackedInt32Array()
## Où elle est plantée dans ce nain (Spot), si IN_DWARF.
var dart_spot: PackedInt32Array = PackedInt32Array()

var _darts: Array[DartHandle] = []
var _flights: Array[Dictionary] = []
## Fléchette montrée dans la main de chaque nain qui en a en main (une par nain au plus).
var _hand_darts: Array[Node3D] = []
## Hôte : fin de manche dans ce temps (s), -1 = pas de manche qui se termine.
var _round_end_timer: float = -1.0
var _blind_shown: bool = false
var _flash_timer: float = 0.0

@onready var _board_body: CollisionObject3D = %BoardBody
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
	for i: int in DART_COUNT:
		var hand_dart: Node3D = DART_MODEL.instantiate() as Node3D
		hand_dart.top_level = true
		hand_dart.visible = false
		add_child(hand_dart)
		_hand_darts.append(hand_dart)
	add_to_group(Inventory.GROUP)
	NetworkManager.session_ended.connect(_on_session_ended)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _round_end_timer >= 0.0:
		_round_end_timer -= delta
		if _round_end_timer < 0.0 and darts_held_by(thrower_peer_id) == 0:
			_end_round()
	# Joueur parti : sa manche se termine, ses fléchettes retournent sur la cible.
	if thrower_peer_id != 0 and Dwarf.of_peer(thrower_peer_id) == null:
		_end_round()
	for i: int in DART_COUNT:
		if dart_where[i] != Where.PLANTED and Dwarf.of_peer(dart_peer[i]) == null:
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
				# Le nain touché ne voit pas sa propre fléchette (elle lui rentrerait dans l'œil). Au visage, il a
				# l'écran brouillé ; ailleurs, il a seulement eu le flash de douleur en la recevant.
				dart.visible = dwarf != null and dart_peer[i] != me
				if dwarf != null:
					var attach: Node3D = _attach_of(dwarf, dart_spot[i])
					dart.global_transform = _dart_transform(attach.global_transform * dart_pos[i],
						(attach.global_basis * dart_dir[i]).normalized())
				blind = blind or (dart_peer[i] == me and dart_spot[i] == Spot.FACE)
		dart.set_pickable(dart_where[i] != Where.IN_HAND)
	if blind != _blind_shown:
		var local: Dwarf = Dwarf.of_peer(me)
		if local != null:
			_blind_shown = blind
			local.set_dart_blind(blind)
	# Une fléchette dans la main de chaque nain dont la case des fléchettes est en main.
	var shown: int = 0
	var holders: PackedInt32Array = PackedInt32Array()
	for i: int in DART_COUNT:
		if dart_where[i] != Where.IN_HAND or dart_peer[i] in holders:
			continue
		holders.append(dart_peer[i])
		var holder: Dwarf = Dwarf.of_peer(dart_peer[i])
		if holder != null and Inventory.is_in_hand(get_tree(), dart_peer[i], dart_slot[i]):
			_hand_darts[shown].visible = true
			_hand_darts[shown].global_transform = holder.get_hold_transform()
			shown += 1
	for k: int in range(shown, DART_COUNT):
		_hand_darts[k].visible = false
	_update_effects(delta)


## Nombre de fléchettes sur des nains (dans leur inventaire).
func darts_in_hand() -> int:
	return dart_where.count(Where.IN_HAND)


## Nombre de fléchettes dans l'inventaire du joueur `peer_id`.
func darts_held_by(peer_id: int) -> int:
	var count: int = 0
	for i: int in DART_COUNT:
		if dart_where[i] == Where.IN_HAND and dart_peer[i] == peer_id:
			count += 1
	return count


## Vrai s'il reste des fléchettes à prendre (plantées ailleurs que dans un nain).
func has_free_darts() -> bool:
	return dart_where.has(Where.PLANTED)


## Inventaire (voir Inventory) : une case pour toutes les fléchettes de ce joueur.
func inventory_entries(peer_id: int) -> Array[Dictionary]:
	var count: int = darts_held_by(peer_id)
	if count == 0:
		return []
	return [{"slot": _slot_of(peer_id), "icon": &"dart", "count": count}]


## Joueur local, fléchettes en main : en lancer une (`origin` = les yeux, `direction` = le regard).
func throw_from_hand(origin: Vector3, direction: Vector3) -> void:
	request_throw.rpc_id(1, origin, direction)


## Joueur local, fléchettes en main (G) : en poser une par terre devant soi.
func drop_from_hand() -> void:
	request_drop_one.rpc_id(1)


## Vrai si une fléchette traîne ailleurs que sur la cible (plantée dans un mur, posée au sol, dans un nain) :
## viser la cible propose alors de toutes les y remettre (DartsTake).
func has_darts_away() -> bool:
	for i: int in DART_COUNT:
		if dart_where[i] == Where.IN_DWARF or (dart_where[i] == Where.PLANTED and not _is_on_board(i)):
			return true
	return false


## Prendre toutes les fléchettes libres (plantées ailleurs que dans un nain) : elles vont dans la case des
## fléchettes du joueur s'il en a déjà, sinon dans une case libre.
@rpc("any_peer", "call_local", "reliable")
func request_take() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var dwarf: Dwarf = Dwarf.of_peer(sender)
	if dwarf == null or not has_free_darts() or not _near_a_dart(dwarf):
		return
	if Possession.holds_control(get_tree(), sender):
		return   # assis, sur la corde ou un levier en main
	var slot: int = _slot_for(sender)
	if slot < 0:
		return   # inventaire plein
	for i: int in DART_COUNT:
		if dart_where[i] == Where.PLANTED:
			_give(i, sender, slot)


## Poser (G) : une fléchette du joueur (case en main) est posée couchée au sol, devant lui ; on la ramasse
## ensuite comme une fléchette plantée. Hors du robot (ou sans sol sous la main), elle retourne sur la cible.
@rpc("any_peer", "call_local", "reliable")
func request_drop_one() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var dwarf: Dwarf = Dwarf.of_peer(sender)
	var index: int = _first_held_by(sender)
	if dwarf == null or index < 0 or not Inventory.is_in_hand(get_tree(), sender, dart_slot[index]):
		return
	var forward: Vector3 = -dwarf.global_basis.z
	var above: Vector3 = dwarf.global_position + forward * DROP_DISTANCE + dwarf.global_basis.y * 0.8
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		above, above - dwarf.global_basis.y * 2.0, 1, [dwarf.get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not (owner != null and owner.is_ancestor_of(hit["collider"] as Node)):
		_put_on_board(index)
	else:
		# Couchée sur le sol, la pointe vers l'avant du nain, un peu au-dessus pour ne pas s'y enfoncer.
		var where: PackedInt32Array = dart_where
		var pos: PackedVector3Array = dart_pos
		var dir: PackedVector3Array = dart_dir
		var peer: PackedInt32Array = dart_peer
		where[index] = Where.PLANTED
		pos[index] = to_local((hit["position"] as Vector3) + dwarf.global_basis.y * DROP_LIFT)
		dir[index] = (global_basis.inverse() * forward).normalized()
		peer[index] = 0
		dart_where = where
		dart_pos = pos
		dart_dir = dir
		dart_peer = peer
	if sender == thrower_peer_id and darts_held_by(sender) == 0:
		_end_round()


## Cible (clic) : toutes les fléchettes qui traînent ailleurs (murs, sol, nains) retournent sur la cible.
## Celles qu'un joueur a dans son inventaire ne bougent pas.
@rpc("any_peer", "call_local", "reliable")
func request_reset() -> void:
	if not multiplayer.is_server():
		return
	var dwarf: Dwarf = Dwarf.of_peer(multiplayer.get_remote_sender_id())
	if dwarf == null or dwarf.global_position.distance_to(global_position) > TAKE_REACH:
		return
	for i: int in DART_COUNT:
		if dart_where[i] != Where.IN_HAND:
			_put_on_board(i)


## Lancer (hôte) : `origin` = les yeux du lanceur, `direction` = où il regarde (global).
@rpc("any_peer", "call_local", "reliable")
func request_throw(origin: Vector3, direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var dwarf: Dwarf = Dwarf.of_peer(sender)
	var index: int = _first_held_by(sender)
	if dwarf == null or index < 0 or direction.length() < 0.1:
		return
	if not Inventory.is_in_hand(get_tree(), sender, dart_slot[index]):
		return   # les fléchettes sont rangées (autre case, ou il tient une commande)
	if dwarf.global_position.distance_to(origin) > 2.0:
		return   # yeux trop loin du nain
	if sender != thrower_peer_id or round_done or round_scores.size() >= DART_COUNT:
		_start_round(sender, dwarf)
	var velocity: Vector3 = direction.normalized() * THROW_SPEED
	var result: Dictionary = _simulate(origin, velocity, dwarf)
	var scores: PackedInt32Array = round_scores
	scores.append(result["score"])
	round_scores = scores
	_land(index, result)
	_show_throw.rpc(index, to_local(origin), global_basis.inverse() * velocity, result["time"],
		result["score"] == BULLSEYE_POINTS)
	if darts_held_by(sender) == 0:
		_round_end_timer = result["time"] + 0.4


## Retirer la fléchette `index` plantée dans un autre nain : elle va dans l'inventaire de celui qui la retire
## (avec ses autres fléchettes, sinon dans une case libre), ou sur la cible s'il n'a plus de place.
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
	var slot: int = -1 if Possession.holds_control(get_tree(), sender) else _slot_for(sender)
	if slot < 0:
		_put_on_board(index)
	else:
		_give(index, sender, slot)


## Chez tout le monde : la fléchette `index` vole de `origin` (vitesse `velocity`, repère du jeu) pendant `time`.
@rpc("authority", "call_local", "reliable")
func _show_throw(index: int, origin: Vector3, velocity: Vector3, time: float, bullseye: bool) -> void:
	if index < 0 or index >= DART_COUNT:
		return
	_flights[index] = {"origin": origin, "velocity": velocity, "time": time, "t": 0.0, "bullseye": bullseye}
	_darts[index].visible = true


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
	var spots: PackedInt32Array = dart_spot
	if result.has("dwarf"):
		var dwarf: Dwarf = result["dwarf"]
		var spot: int = _spot_of(dwarf, result["point"], result["dir"])
		var attach: Node3D = _attach_of(dwarf, spot)
		var local_dir: Vector3 = (attach.global_basis.inverse() * (result["dir"] as Vector3)).normalized()
		var center: Vector3 = TORSO_CENTER if spot == Spot.BODY else HEAD_CENTER
		var radius: float = TORSO_RADIUS if spot == Spot.BODY else HEAD_RADIUS
		where[index] = Where.IN_DWARF
		pos[index] = center - local_dir * (radius - EMBED)
		spots[index] = spot
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
	dart_spot = spots


func _hit_dwarf(peer_id: int) -> void:
	var dwarf: Dwarf = Dwarf.of_peer(peer_id)
	if dwarf != null:
		dwarf.receive_dart.rpc()


## Où se plante une fléchette qui touche `dwarf` en `point`, en allant vers `dir` (global).
func _spot_of(dwarf: Dwarf, point: Vector3, dir: Vector3) -> int:
	var height: float = (dwarf.global_transform.affine_inverse() * point).y
	if height < HEAD_ZONE_HEIGHT:
		return Spot.BODY
	var facing: Vector3 = -dwarf.view_transform().basis.z   # là où le nain regarde
	return Spot.FACE if dir.normalized().dot(facing) < -FACE_CONE_COS else Spot.HEAD


## Os qui porte une fléchette plantée à cet endroit (tête ou torse).
static func _attach_of(dwarf: Dwarf, spot: int) -> Node3D:
	return dwarf.get_torso_attach() if spot == Spot.BODY else dwarf.get_head_attach()


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
	dart_spot = PackedInt32Array()
	dart_slot = PackedInt32Array()
	for i: int in DART_COUNT:
		dart_where.append(Where.PLANTED)
		dart_pos.append(Vector3.ZERO)
		dart_dir.append(Vector3.FORWARD)
		dart_peer.append(0)
		dart_spot.append(Spot.HEAD)
		dart_slot.append(0)
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
	var spots: PackedInt32Array = dart_spot
	spots[index] = Spot.HEAD
	dart_spot = spots


## Hôte : la fléchette `index` va dans la case `slot` de l'inventaire du joueur `peer_id`.
func _give(index: int, peer_id: int, slot: int) -> void:
	var where: PackedInt32Array = dart_where
	var peer: PackedInt32Array = dart_peer
	var slots: PackedInt32Array = dart_slot
	where[index] = Where.IN_HAND
	peer[index] = peer_id
	slots[index] = slot
	dart_where = where
	dart_peer = peer
	dart_slot = slots


## Case des fléchettes du joueur `peer_id` (-1 s'il n'en a pas).
func _slot_of(peer_id: int) -> int:
	var index: int = _first_held_by(peer_id)
	return dart_slot[index] if index >= 0 else -1


## Hôte : où ranger des fléchettes du joueur `peer_id` : avec les siennes, sinon une case libre (-1 = plein).
func _slot_for(peer_id: int) -> int:
	var slot: int = _slot_of(peer_id)
	return slot if slot >= 0 else Inventory.free_slot(get_tree(), peer_id)


func _first_held_by(peer_id: int) -> int:
	for i: int in DART_COUNT:
		if dart_where[i] == Where.IN_HAND and dart_peer[i] == peer_id:
			return i
	return -1


## Hôte : le joueur lance la première fléchette d'une nouvelle manche ; la manche en cours (d'un autre) se termine.
func _start_round(peer_id: int, dwarf: Dwarf) -> void:
	_end_round()
	_round_end_timer = -1.0
	thrower_peer_id = peer_id
	thrower_name = dwarf.get_display_name()
	round_scores = PackedInt32Array()
	round_done = false


## Vrai si la fléchette `index`, plantée, est dans la cible (à sa place de repos ou lancée dedans).
func _is_on_board(index: int) -> bool:
	var pos: Vector3 = dart_pos[index]
	return Vector2(pos.x, pos.y).length() <= BOARD_RADIUS and absf(pos.z) < 0.15


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


## « Dans le mille ! » : confettis et éclair de lumière sur la cible (chez chacun) ; l'ardoise l'entoure.
func _celebrate() -> void:
	_confetti.restart()
	_confetti.emitting = true
	_flash_timer = 0.6


func _update_effects(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer = maxf(_flash_timer - delta, 0.0)
		_flash.light_energy = 3.0 * _flash_timer / 0.6


## Nombre de fléchettes en vol (leur lancer n'est pas encore écrit sur l'ardoise).
func flying_count() -> int:
	var count: int = 0
	for flight: Dictionary in _flights:
		if not flight.is_empty():
			count += 1
	return count


## Total de la manche affichée.
func round_total() -> int:
	var total: int = 0
	for s: int in round_scores:
		total += s
	return total


## Hôte : la manche se termine (toutes lancées, ou fléchettes reposées) ; elle passe dans l'historique.
func _end_round() -> void:
	thrower_peer_id = 0
	if round_scores.is_empty() or round_done:
		return
	round_done = true
	var names: PackedStringArray = history_names
	var totals: PackedInt32Array = history_totals
	names.insert(0, thrower_name)
	totals.insert(0, round_total())
	if names.size() > HISTORY_SIZE:
		names.resize(HISTORY_SIZE)
		totals.resize(HISTORY_SIZE)
	history_names = names
	history_totals = totals


func _on_session_ended(_reason: String) -> void:
	thrower_peer_id = 0
	thrower_name = ""
	round_scores = PackedInt32Array()
	round_done = false
	history_names = PackedStringArray()
	history_totals = PackedInt32Array()
	_round_end_timer = -1.0
	for i: int in DART_COUNT:
		_flights[i] = {}
	_put_all_on_board()
