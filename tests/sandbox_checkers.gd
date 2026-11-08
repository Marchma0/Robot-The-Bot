extends Node3D
## Bac à sable du jeu de dames de la table basse (3.10) : un nain (hors réseau, on est l'hôte) joue les deux
## côtés : choix d'un pion, coup simple, prise obligatoire, prise, fin de partie avec promotion en dame,
## nouvelle partie. Captures dans build/views/checkers_*.png.

const DWARF_SCENE: PackedScene = preload("res://scenes/player/dwarf.tscn")
const P = CheckersRules.Piece

@export var quit_when_done: bool = true

var _cam: Camera3D
var _dwarf: Dwarf

@onready var _mecha: Node3D = $Mecha
@onready var _game: CheckersGame = $Mecha/InteriorBelly/CoffeeTable/Checkers


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	_dwarf = DWARF_SCENE.instantiate() as Dwarf
	_dwarf.setup(1, 0)
	_mecha.get_node("Players").add_child(_dwarf)
	_dwarf.position = Vector3(-0.3, 2.65, 0.4)
	_cam = Camera3D.new()
	add_child(_cam)
	await _wait(1.0)
	TestCheck.expect(_game.board.count(P.RED) == 12 and _game.board.count(P.CREAM) == 12, "au départ, 12 pions de chaque côté")
	TestCheck.expect(_game.find_children("Cell*", "CheckersCell", false, false).size() == 32, "32 cases jouables à viser")
	await _shot("0_depart")

	_click(_cell(1, 2))
	TestCheck.expect(_game.selected == _cell(1, 2), "on choisit un pion rouge")
	await _shot("1_pion_choisi")
	_click(_cell(2, 3))
	TestCheck.expect(_game.board[_cell(2, 3)] == P.RED and _game.board[_cell(1, 2)] == P.EMPTY, "le pion avance en diagonale")
	TestCheck.expect(_game.turn == CheckersRules.Side.CREAM, "au tour des crèmes")
	_click(_cell(2, 5))
	_click(_cell(3, 4))
	_click(_cell(5, 2))
	_click(_cell(4, 3))
	await _wait(0.5)
	# Les crèmes doivent prendre : un pion qui ne peut pas prendre ne se choisit pas.
	_click(_cell(6, 5))
	TestCheck.expect(_game.selected == -1, "prise obligatoire : un pion qui ne prend pas ne se choisit pas")
	_click(_cell(3, 4))
	_click(_cell(1, 2))
	TestCheck.expect(_game.board[_cell(2, 3)] == P.EMPTY and _game.board.count(P.RED) == 11, "le pion crème prend le rouge en sautant")
	await _shot("2_prise", 0.15)

	# Fin de partie : le dernier pion crème est pris, le pion rouge arrive au bout et devient dame.
	var board: PackedByteArray = PackedByteArray()
	board.resize(64)
	board[_cell(2, 5)] = P.RED
	board[_cell(3, 6)] = P.CREAM
	_game.board = board
	_game.turn = CheckersRules.Side.RED
	_game.selected = -1
	await _wait(0.2)
	_click(_cell(2, 5))
	_click(_cell(4, 7))
	TestCheck.expect(_game.board[_cell(4, 7)] == P.RED_KING, "arrivé au bout, le pion devient dame")
	TestCheck.expect(_game.winner == CheckersRules.Side.RED, "plus de pion crème : les rouges gagnent")
	_click(_cell(4, 7))
	TestCheck.expect(_game.selected == -1, "partie finie : plus rien ne se joue")
	await _shot("3_victoire", 0.6)
	await _shot_at("4_pendule_sonne", Vector3(-1.45, 3.12, -0.27), Vector3(-1.105, 2.99, -0.265))

	_game.request_new_game.rpc_id(1)   # comme un appui sur la pendule
	await _wait(0.6)
	TestCheck.expect(_game.winner == -1 and _game.board.count(P.RED) == 12 and _game.turn == CheckersRules.Side.RED, "nouvelle partie : tout est remis en place")
	TestCheck.expect(_game.find_children("", "Node3D", false, false).size() > 0, "pions affichés")
	await _play_from_sofa()
	if quit_when_done or TestCheck.is_auto():
		TestCheck.finish(get_tree())


## Assis sur le canapé, on baisse les yeux vers le damier : on vise une case et on joue (clic).
func _play_from_sofa() -> void:
	_dwarf.position = Vector3(-1.5, 2.65, 0.2)
	await _wait(0.4)
	var seat: Seat = _mecha.get_node("Controls/Sofa_Left") as Seat
	var interactor: Interactor = _dwarf.get_node("%Interactor") as Interactor
	seat.request_sit.rpc_id(1)
	interactor.begin_claim(seat)
	await _wait(1.2)
	TestCheck.expect(seat.occupant_peer_id == 1, "assis sur le canapé")
	var head: Node3D = _dwarf.get_node("%Head")
	var aimed: CheckersCell = null
	for k: int in 18:
		head.rotation.x = deg_to_rad(-10.0 - k * 3.0)
		for yaw_step: int in 13:
			_dwarf._seat_yaw = -0.6 + yaw_step * 0.1
			await get_tree().physics_frame
			await get_tree().physics_frame
			aimed = interactor._target as CheckersCell
			if aimed != null:
				break
		if aimed != null:
			break
	TestCheck.expect(aimed != null, "assis : on vise une case du damier")
	_click(_cell(1, 2))
	TestCheck.expect(_game.selected == _cell(1, 2), "assis : l'hôte accepte le coup (à portée depuis le canapé)")
	_cam.current = false
	(_dwarf.get_node("%Camera") as Camera3D).current = true
	await _wait(0.4)
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/checkers_5_depuis_canape.png")


func _cell(col: int, row: int) -> int:
	return row * CheckersRules.SIZE + col


func _click(cell: int) -> void:
	_game.request_cell.rpc_id(1, cell)


func _shot(shot_name: String, delay: float = 0.45) -> void:
	await _wait(delay)
	_cam.global_position = _mecha.global_transform * Vector3(-1.025, 3.45, 0.42)
	_cam.look_at(_mecha.global_transform * Vector3(-1.025, 2.94, 0.06), _mecha.global_basis.y)
	_cam.current = true
	await TestCheck.frame_drawn(get_tree())
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/checkers_%s.png" % shot_name)


func _shot_at(shot_name: String, from: Vector3, to: Vector3) -> void:
	_cam.global_position = _mecha.global_transform * from
	_cam.look_at(_mecha.global_transform * to, _mecha.global_basis.y)
	await TestCheck.frame_drawn(get_tree())
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/checkers_%s.png" % shot_name)


func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
