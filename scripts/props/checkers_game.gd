class_name CheckersGame
extends Node3D
## Jeu de dames de la table basse du salon (règles : CheckersRules). On vise un de ses pions (E / clic) :
## il est entouré et ses coups possibles s'allument ; on vise ensuite la case d'arrivée. Le premier joueur
## qui joue un côté le garde jusqu'à la fin de la partie (seul, on peut jouer les deux). En fin de partie,
## les pions du gagnant sautillent et la pendule d'échecs posée à côté sonne ; on appuie
## dessus pour une nouvelle partie (CheckersClock, qui montre aussi à qui de jouer).
##
## Réseau : chaque clic est une demande à l'hôte (`request_cell`), qui vérifie (portée, tour, coup permis)
## et tient l'état synchronisé : damier, tour, pion choisi, rafle en cours, gagnant, joueur de chaque côté.
## Chaque peer anime lui-même les pions d'après les changements du damier (glissade en cloche, pièce
## prise qui saute hors du plateau). Repère : celui de la table (origine au sol, au centre).

## Damier du modèle (blender/props/coffee_table.py) : 0,3 m de côté, centré sur la table en profondeur, un peu
## vers le canapé (la pendule est de l'autre côté).
const CELL: float = 0.0375
const BOARD_TOP: float = 0.349
const BOARD_CENTER_X: float = -0.03
const BOARD_CENTER_Z: float = 0.0
const REACH: float = 2.2
const PIECE_RADIUS: float = 0.015
const PIECE_HEIGHT: float = 0.008
## Animation d'un coup (s) et hauteur de la cloche (m).
const MOVE_TIME: float = 0.35
const HOP_HEIGHT: float = 0.035
const CAPTURE_TIME: float = 0.45
const SIDE_COLORS: Array[Color] = [Color(0.7, 0.1, 0.08), Color(0.86, 0.79, 0.63)]
const SELECT_COLOR: Color = Color(1.0, 0.85, 0.25)
const TARGET_COLOR: Color = Color(0.45, 1.0, 0.45)
## Plus de coups possibles d'une seule pièce (dame au centre).
const MAX_TARGETS: int = 13

## Damier (CheckersRules.Piece par case). Autorité : hôte.
var board: PackedByteArray = CheckersRules.start_board()
## Côté qui doit jouer (CheckersRules.Side). Autorité : hôte.
var turn: int = CheckersRules.Side.RED
## Case du pion choisi (-1 = aucun). Autorité : hôte.
var selected: int = -1
## Rafle en cours : le pion choisi doit continuer à prendre. Autorité : hôte.
var chain: bool = false
## Côté gagnant (-1 = partie en cours). Autorité : hôte.
var winner: int = -1
## Joueur de chaque côté (0 = libre). Autorité : hôte.
var side_peers: PackedInt32Array = PackedInt32Array([0, 0])

## Pions affichés, par case.
var _pieces: Dictionary[int, Node3D] = {}
var _drawn_board: PackedByteArray = PackedByteArray()
## Animations en cours : {"node", "from", "to", "t", "capture"}.
var _anims: Array[Dictionary] = []
var _select_ring: MeshInstance3D
var _target_dots: Array[MeshInstance3D] = []
var _drawn_hint_key: String = ""
var _time: float = 0.0
var _piece_mesh: CylinderMesh
var _piece_top_mesh: CylinderMesh
var _side_materials: Array[StandardMaterial3D] = []
var _side_top_materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	_make_piece_meshes()
	var marker: StandardMaterial3D = StandardMaterial3D.new()
	marker.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	marker.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for cell: int in CheckersRules.SIZE * CheckersRules.SIZE:
		if not CheckersRules.is_dark_cell(cell):
			continue
		var area: CheckersCell = CheckersCell.new()
		area.name = "Cell%d" % cell
		area.position = cell_position(cell)
		area.setup(self, cell, CELL, marker)
		add_child(area)
	_select_ring = _make_marker(_ring_mesh(), SELECT_COLOR)
	for i: int in MAX_TARGETS:
		_target_dots.append(_make_marker(_dot_mesh(), TARGET_COLOR))
	_rebuild_pieces()
	NetworkManager.session_ended.connect(_on_session_ended)


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	# Joueur parti : son côté se libère.
	for side: int in 2:
		if side_peers[side] != 0 and Dwarf.of_peer(side_peers[side]) == null:
			var peers: PackedInt32Array = side_peers
			peers[side] = 0
			side_peers = peers


func _process(delta: float) -> void:
	_time += delta
	if board != _drawn_board:
		_show_board_change()
	_update_anims(delta)
	_update_markers()
	_celebrate()


## Centre d'une case, au ras du damier (repère de la table).
func cell_position(cell: int) -> Vector3:
	var col: int = cell % CheckersRules.SIZE
	@warning_ignore("integer_division")
	var row: int = cell / CheckersRules.SIZE
	return Vector3(BOARD_CENTER_X - 0.15 + (col + 0.5) * CELL, BOARD_TOP, BOARD_CENTER_Z + 0.15 - (row + 0.5) * CELL)


## Vrai si le joueur `peer_id` peut jouer le côté `side`.
func can_play(peer_id: int, side: int) -> bool:
	return side_peers[side] == 0 or side_peers[side] == peer_id


## Indices quand le joueur local vise la case `cell`.
func hints_for(cell: int) -> Array[InputHint]:
	if winner >= 0:
		return []
	var me: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if not can_play(me, turn):
		return [InputHint.state(&"locked")]
	if selected >= 0 and not CheckersRules.find_move(board, selected, cell, chain).is_empty():
		return [InputHint.make(&"grab", &"move")]
	if chain:
		return []
	if cell == selected:
		return [InputHint.make(&"grab", &"hand_open")]
	if CheckersRules.side_of(board[cell]) == turn and not CheckersRules.legal_moves(board, cell).is_empty():
		return [InputHint.make(&"grab", &"hand_grab")]
	return []


## Les meshes du pion posé sur `cell` (pour le surligner quand on vise sa case).
func piece_meshes_at(cell: int) -> Array[GeometryInstance3D]:
	var meshes: Array[GeometryInstance3D] = []
	if _pieces.has(cell):
		for child: Node in _pieces[cell].get_children():
			if child is GeometryInstance3D:
				meshes.append(child as GeometryInstance3D)
	return meshes


## Un joueur clique sur la case `cell` : choisir un pion, le reposer, ou jouer le pion choisi.
@rpc("any_peer", "call_local", "reliable")
func request_cell(cell: int) -> void:
	if not multiplayer.is_server() or cell < 0 or cell >= board.size() or winner >= 0:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not Dwarf.is_peer_near(sender, to_global(cell_position(cell)), REACH) or not can_play(sender, turn):
		return
	if selected >= 0:
		var move: Dictionary = CheckersRules.find_move(board, selected, cell, chain)
		if not move.is_empty():
			_take_side(sender, turn)
			_play(move)
			return
		if chain:
			return   # en pleine rafle, le pion doit continuer à prendre
		if cell == selected:
			selected = -1
			return
	if CheckersRules.side_of(board[cell]) == turn and not CheckersRules.legal_moves(board, cell).is_empty():
		selected = cell


## Hôte : nouvelle partie.
func reset_game() -> void:
	board = CheckersRules.start_board()
	turn = CheckersRules.Side.RED
	selected = -1
	chain = false
	winner = -1
	side_peers = PackedInt32Array([0, 0])


func _take_side(peer_id: int, side: int) -> void:
	if side_peers[side] == 0:
		var peers: PackedInt32Array = side_peers
		peers[side] = peer_id
		side_peers = peers


## Hôte : joue le coup du pion choisi ; rafle s'il peut encore prendre, sinon au tour de l'autre.
func _play(move: Dictionary) -> void:
	var to: int = move["to"]
	var after: PackedByteArray = CheckersRules.apply_move(board, selected, move, false)
	if move["captured"] >= 0 and not CheckersRules.legal_moves(after, to, true).is_empty():
		board = after
		selected = to
		chain = true
		return
	board = CheckersRules.apply_move(board, selected, move, true)
	selected = -1
	chain = false
	turn = 1 - turn
	if not CheckersRules.side_can_move(board, turn):
		winner = 1 - turn


## Nouvelle partie demandée par un joueur (il appuie sur la pendule).
@rpc("any_peer", "call_local", "reliable")
func request_new_game() -> void:
	if not multiplayer.is_server():
		return
	if Dwarf.is_peer_near(multiplayer.get_remote_sender_id(), to_global(cell_position(27)), REACH):
		reset_game()


func _on_session_ended(_reason: String) -> void:
	reset_game()


# --- Affichage (chaque peer) ---

## Le damier a changé : un seul pion arrivé quelque part = un coup (il glisse, les pièces prises sautent
## hors du plateau). Sinon (nouvelle partie, arrivée en cours de partie) : tout est remis en place.
func _show_board_change() -> void:
	var arrived: Array[int] = []
	var left: Array[int] = []
	for cell: int in board.size():
		var was: int = _drawn_board[cell] if cell < _drawn_board.size() else 0
		if was == board[cell]:
			continue
		if was == 0:
			arrived.append(cell)
		elif board[cell] == 0:
			left.append(cell)
		elif CheckersRules.side_of(was) == CheckersRules.side_of(board[cell]) and _pieces.has(cell):
			_set_king(_pieces[cell], CheckersRules.is_king(board[cell]))   # pion devenu dame sur place
	var mover: int = -1
	if arrived.size() == 1:
		for cell: int in left:
			if _pieces.has(cell) and CheckersRules.side_of(_drawn_board[cell]) == CheckersRules.side_of(board[arrived[0]]):
				mover = cell
	if mover < 0:
		_rebuild_pieces()
		return
	var to: int = arrived[0]
	var node: Node3D = _pieces[mover]
	_pieces.erase(mover)
	_pieces[to] = node
	for mesh: GeometryInstance3D in piece_meshes_at(to):
		mesh.material_overlay = null
	_set_king(node, CheckersRules.is_king(board[to]))
	_anims.append({"node": node, "from": node.position, "to": cell_position(to), "t": 0.0, "capture": false})
	for cell: int in left:
		if cell != mover and _pieces.has(cell):
			var taken: Node3D = _pieces[cell]
			_pieces.erase(cell)
			var out: Vector3 = taken.position + (taken.position - cell_position(to)).normalized() * 0.08
			_anims.append({"node": taken, "from": taken.position, "to": out, "t": -MOVE_TIME * 0.6, "capture": true})
	_drawn_board = board.duplicate()


func _rebuild_pieces() -> void:
	for anim: Dictionary in _anims:
		if (anim["capture"] as bool) and is_instance_valid(anim["node"]):
			(anim["node"] as Node3D).queue_free()
	_anims.clear()
	for node: Node3D in _pieces.values():
		node.queue_free()
	_pieces.clear()
	for cell: int in board.size():
		var side: int = CheckersRules.side_of(board[cell])
		if side < 0:
			continue
		var node: Node3D = _make_piece(side)
		node.position = cell_position(cell)
		_set_king(node, CheckersRules.is_king(board[cell]))
		_pieces[cell] = node
	_drawn_board = board.duplicate()


func _update_anims(delta: float) -> void:
	for i: int in range(_anims.size() - 1, -1, -1):
		var anim: Dictionary = _anims[i]
		var node: Node3D = anim["node"]
		if not is_instance_valid(node):
			_anims.remove_at(i)
			continue
		var duration: float = CAPTURE_TIME if anim["capture"] else MOVE_TIME
		anim["t"] = anim["t"] + delta
		var k: float = clampf(anim["t"] / duration, 0.0, 1.0)
		var pos: Vector3 = (anim["from"] as Vector3).lerp(anim["to"], smoothstep(0.0, 1.0, k))
		pos.y += sin(k * PI) * HOP_HEIGHT * (1.6 if anim["capture"] else 1.0)
		node.position = pos
		if anim["capture"]:
			node.scale = Vector3.ONE * maxf(1.0 - k * k, 0.01)
		if k >= 1.0:
			if anim["capture"]:
				node.queue_free()
			_anims.remove_at(i)


## Anneau sous le pion choisi, pastilles sur les cases où il peut aller.
func _update_markers() -> void:
	var key: String = "%d|%s|%s" % [selected, chain, board.hex_encode()]
	if key == _drawn_hint_key:
		return
	_drawn_hint_key = key
	_select_ring.visible = selected >= 0
	var moves: Array[Dictionary] = []
	if selected >= 0:
		_select_ring.position = cell_position(selected) + Vector3.UP * 0.0015
		moves = CheckersRules.legal_moves(board, selected, chain)
	for i: int in _target_dots.size():
		_target_dots[i].visible = i < moves.size()
		if i < moves.size():
			_target_dots[i].position = cell_position(moves[i]["to"]) + Vector3.UP * 0.0015


## Fin de partie : les pions du gagnant sautillent.
func _celebrate() -> void:
	if winner < 0 or not _anims.is_empty():
		return
	for cell: int in _pieces:
		if CheckersRules.side_of(board[cell]) == winner:
			var phase: float = float(cell) * 0.7
			_pieces[cell].position = cell_position(cell) + Vector3.UP * absf(sin(_time * 5.0 + phase)) * 0.02


func _make_piece(side: int) -> Node3D:
	var node: Node3D = Node3D.new()
	for level: int in 2:   # 2e étage = couronne de la dame
		var base: MeshInstance3D = MeshInstance3D.new()
		base.mesh = _piece_mesh
		base.material_override = _side_materials[side]
		base.position.y = PIECE_HEIGHT * 0.5 + level * (PIECE_HEIGHT + 0.003)
		var top: MeshInstance3D = MeshInstance3D.new()
		top.mesh = _piece_top_mesh
		top.material_override = _side_top_materials[side]
		top.position.y = PIECE_HEIGHT + 0.0015 + level * (PIECE_HEIGHT + 0.003)
		base.visible = level == 0
		top.visible = level == 0
		node.add_child(base)
		node.add_child(top)
	add_child(node)
	return node


func _set_king(node: Node3D, king: bool) -> void:
	for i: int in range(2, node.get_child_count()):
		(node.get_child(i) as Node3D).visible = king


func _make_piece_meshes() -> void:
	_piece_mesh = CylinderMesh.new()
	_piece_mesh.top_radius = PIECE_RADIUS
	_piece_mesh.bottom_radius = PIECE_RADIUS
	_piece_mesh.height = PIECE_HEIGHT
	_piece_mesh.radial_segments = 16
	_piece_mesh.rings = 1
	# Petit bourrelet sur le dessus du pion (3 mm), plus foncé.
	_piece_top_mesh = CylinderMesh.new()
	_piece_top_mesh.top_radius = PIECE_RADIUS * 0.6
	_piece_top_mesh.bottom_radius = PIECE_RADIUS * 0.75
	_piece_top_mesh.height = 0.003
	_piece_top_mesh.radial_segments = 16
	_piece_top_mesh.rings = 1
	for color: Color in SIDE_COLORS:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.45
		_side_materials.append(material)
		var top: StandardMaterial3D = material.duplicate() as StandardMaterial3D
		top.albedo_color = color.darkened(0.2)
		_side_top_materials.append(top)


func _make_marker(mesh: Mesh, color: Color) -> MeshInstance3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.mesh = mesh
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.visible = false
	add_child(marker)
	return marker


func _ring_mesh() -> TorusMesh:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = PIECE_RADIUS + 0.001
	torus.outer_radius = PIECE_RADIUS + 0.004
	torus.rings = 20
	torus.ring_segments = 4
	return torus


func _dot_mesh() -> CylinderMesh:
	var dot: CylinderMesh = CylinderMesh.new()
	dot.top_radius = 0.006
	dot.bottom_radius = 0.006
	dot.height = 0.001
	dot.radial_segments = 10
	dot.rings = 1
	return dot
