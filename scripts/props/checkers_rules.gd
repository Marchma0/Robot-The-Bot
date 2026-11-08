class_name CheckersRules
extends RefCounted
## Règles du jeu de dames sur le damier 8 x 8 de la table basse (fonctions pures, mêmes résultats partout).
##
## - Les pions avancent d'une case en diagonale ; ils prennent en sautant une pièce adverse, en avant
##   comme en arrière.
## - La prise est obligatoire ; après une prise, la même pièce continue tant qu'elle peut prendre (rafle).
## - Un pion qui finit son coup sur la dernière rangée devient une dame. La dame est « volante » : elle va
##   aussi loin qu'elle veut en diagonale, et prend une pièce à distance.
## - On perd quand on n'a plus de pièce, ou plus de coup possible.
## Simplification : une pièce prise disparaît tout de suite (pas à la fin de la rafle), et on n'est pas obligé
## de choisir la rafle qui prend le plus.
##
## Damier : tableau de 64 cases, index = rangée * 8 + colonne. Les rouges partent des rangées 0 à 2 et montent,
## les crèmes partent des rangées 5 à 7 et descendent. On ne joue que sur les cases sombres ((col + rangée) impair).

enum Piece { EMPTY = 0, RED = 1, RED_KING = 2, CREAM = 3, CREAM_KING = 4 }
enum Side { RED = 0, CREAM = 1 }

const SIZE: int = 8
const DIAGONALS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]


## Damier du début de partie : 12 pions de chaque côté.
static func start_board() -> PackedByteArray:
	var board: PackedByteArray = PackedByteArray()
	board.resize(SIZE * SIZE)
	for row: int in SIZE:
		for col: int in SIZE:
			if not is_dark(col, row):
				continue
			if row <= 2:
				board[row * SIZE + col] = Piece.RED
			elif row >= 5:
				board[row * SIZE + col] = Piece.CREAM
	return board


static func is_dark(col: int, row: int) -> bool:
	return (col + row) % 2 == 1


static func is_dark_cell(cell: int) -> bool:
	var pos: Vector2i = _pos(cell)
	return is_dark(pos.x, pos.y)


## Côté d'une pièce (-1 si la case est vide).
static func side_of(piece: int) -> int:
	if piece == Piece.RED or piece == Piece.RED_KING:
		return Side.RED
	if piece == Piece.CREAM or piece == Piece.CREAM_KING:
		return Side.CREAM
	return -1


static func is_king(piece: int) -> bool:
	return piece == Piece.RED_KING or piece == Piece.CREAM_KING


## Coups possibles de la pièce en `cell` : liste de {"to": case, "captured": case prise ou -1}.
## S'il existe une prise pour ce côté (ou pendant une rafle, `chain`), seules les prises comptent.
static func legal_moves(board: PackedByteArray, cell: int, chain: bool = false) -> Array[Dictionary]:
	var side: int = side_of(board[cell])
	if side < 0:
		return []
	var captures: Array[Dictionary] = _captures_from(board, cell)
	if chain or not captures.is_empty() or side_has_capture(board, side):
		return captures
	return _steps_from(board, cell)


## Le coup de `from` vers `to`, ou un dictionnaire vide s'il n'est pas permis.
static func find_move(board: PackedByteArray, from: int, to: int, chain: bool) -> Dictionary:
	for move: Dictionary in legal_moves(board, from, chain):
		if move["to"] == to:
			return move
	return {}


static func side_has_capture(board: PackedByteArray, side: int) -> bool:
	for cell: int in board.size():
		if side_of(board[cell]) == side and not _captures_from(board, cell).is_empty():
			return true
	return false


static func side_can_move(board: PackedByteArray, side: int) -> bool:
	for cell: int in board.size():
		if side_of(board[cell]) == side and not legal_moves(board, cell).is_empty():
			return true
	return false


## Joue le coup (déjà vérifié) sur une copie du damier et la renvoie. `promote` : le coup se termine
## (pas de rafle à suivre), le pion arrivé au bout devient une dame.
static func apply_move(board: PackedByteArray, from: int, move: Dictionary, promote: bool) -> PackedByteArray:
	var result: PackedByteArray = board.duplicate()
	var to: int = move["to"]
	result[to] = result[from]
	result[from] = Piece.EMPTY
	if move["captured"] >= 0:
		result[move["captured"]] = Piece.EMPTY
	if promote:
		var row: int = _pos(to).y
		if result[to] == Piece.RED and row == SIZE - 1:
			result[to] = Piece.RED_KING
		elif result[to] == Piece.CREAM and row == 0:
			result[to] = Piece.CREAM_KING
	return result


## Pions : un pas en avant ; dames : glissent dans les 4 diagonales.
static func _steps_from(board: PackedByteArray, cell: int) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	var piece: int = board[cell]
	var forward: int = 1 if side_of(piece) == Side.RED else -1
	for dir: Vector2i in DIAGONALS:
		if not is_king(piece) and dir.y != forward:
			continue
		var pos: Vector2i = _pos(cell) + dir
		while _inside(pos) and board[_index(pos)] == Piece.EMPTY:
			moves.append({"to": _index(pos), "captured": -1})
			if not is_king(piece):
				break
			pos += dir
	return moves


## Prises : un pion saute une pièce adverse voisine ; une dame la prend à distance et se pose
## sur n'importe quelle case libre derrière elle.
static func _captures_from(board: PackedByteArray, cell: int) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	var piece: int = board[cell]
	var side: int = side_of(piece)
	for dir: Vector2i in DIAGONALS:
		var pos: Vector2i = _pos(cell) + dir
		if is_king(piece):
			while _inside(pos) and board[_index(pos)] == Piece.EMPTY:
				pos += dir
		if not _inside(pos) or side_of(board[_index(pos)]) != 1 - side:
			continue
		var captured: int = _index(pos)
		var land: Vector2i = pos + dir
		while _inside(land) and board[_index(land)] == Piece.EMPTY:
			moves.append({"to": _index(land), "captured": captured})
			if not is_king(piece):
				break
			land += dir
	return moves


@warning_ignore("integer_division")
static func _pos(cell: int) -> Vector2i:
	return Vector2i(cell % SIZE, cell / SIZE)


static func _index(pos: Vector2i) -> int:
	return pos.y * SIZE + pos.x


static func _inside(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < SIZE and pos.y >= 0 and pos.y < SIZE
