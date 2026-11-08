extends Node3D
## Bac à sable des fléchettes du robot (3.9) : un vrai nain (hors réseau, on est l'hôte) prend les fléchettes
## plantées dans la cible du salon, lance dans le mille, puis à côté, puis sur un allié (nain du joueur 2) ;
## le total s'affiche ; il retire la fléchette de la tête de l'allié. Puis une fléchette plantée dans son
## propre nain lui brouille la vue, et il ne peut pas se l'enlever lui-même.
## Captures dans build/views/darts_*.png.

const DWARF_SCENE: PackedScene = preload("res://scenes/player/dwarf.tscn")

@export var quit_when_done: bool = true

var _dwarf: Dwarf
var _ally: Dwarf
var _cam: Camera3D

@onready var _mecha: Node3D = $Mecha
@onready var _darts: DartsGame = $Mecha/Controls/Darts


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	_dwarf = _spawn(1, 0, Vector3(-0.3, 2.65, -0.6))
	_ally = _spawn(2, 1, Vector3(0.9, 2.6, 0.7))
	_cam = Camera3D.new()
	add_child(_cam)
	await _wait(1.2)
	TestCheck.expect(_darts.dart_where.count(DartsGame.Where.PLANTED) == 3, "au départ, les 3 fléchettes sont plantées dans la cible")
	await _shot("0_repos", Vector3(-0.6, 3.7, 0.4), Vector3(0.0, 3.85, 1.9))

	_darts.request_take.rpc_id(1)
	await _wait(0.2)
	TestCheck.expect(_darts.thrower_peer_id == 1 and _darts.darts_in_hand() == 3, "on prend les 3 fléchettes d'un coup")

	await _throw_at(_darts.to_global(Vector3(0.0, 0.0, DartsGame.BOARD_FRONT_Z)))
	await _shot("1_dans_le_mille", Vector3(-0.5, 3.75, 0.8), Vector3(0.0, 3.85, 1.9), 0.25)
	print("Fléchettes : 1er lancer %s" % _darts.round_scores)
	TestCheck.expect(_darts.round_scores[0] == DartsGame.BULLSEYE_POINTS, "1er lancer : dans le mille (%d points)" % DartsGame.BULLSEYE_POINTS)

	await _throw_at(_darts.to_global(Vector3(0.16, -0.05, DartsGame.BOARD_FRONT_Z)))
	await _wait(0.5)
	var ally_head: Vector3 = _ally.global_position + _mecha.global_basis.y * 1.0
	await _throw_at(ally_head)
	var in_ally: int = _darts.dart_peer.find(2)
	print("Fléchettes : scores %s, fléchette dans l'allié : %d" % [_darts.round_scores, in_ally])
	TestCheck.expect(_darts.round_scores.size() == 3, "3 lancers comptés")
	TestCheck.expect(in_ally >= 0 and _darts.dart_where[in_ally] == DartsGame.Where.IN_DWARF, "3e lancer : la fléchette est plantée dans l'allié")
	await _wait(0.5)
	TestCheck.expect(_darts.thrower_peer_id == 0, "après 3 lancers, la manche est finie")
	TestCheck.expect(_darts.round_done and _darts.history_totals.size() == 1 and _darts.history_totals[0] == _darts.round_total(),
		"le total de la manche est écrit sur l'ardoise")
	var board_total: Label = null
	for label: Node in _darts.find_children("*", "Label", true, false):
		if (label as Label).text == "= %d" % _darts.round_total():
			board_total = label
	TestCheck.expect(board_total != null, "l'ardoise affiche « = total »")
	await _shot("2_score", Vector3(0.1, 3.8, 0.6), Vector3(0.3, 3.85, 1.9))
	await _shot("3_allie_touche", Vector3(1.75, 3.75, 0.2), _mecha.to_local(ally_head), 0.1)

	_darts.request_pull.rpc_id(1, in_ally)
	await _wait(0.3)
	TestCheck.expect(in_ally >= 0 and _darts.dart_where[in_ally] == DartsGame.Where.PLANTED, "on retire la fléchette de l'allié : elle retourne sur la cible")

	# Une fléchette plantée dans son propre nain : vue brouillée, et on ne peut pas se l'enlever soi-même.
	_darts._land(0, {"point": _dwarf.global_position + _mecha.global_basis.y * 1.0, "dir": _mecha.global_basis.z, "dwarf": _dwarf, "time": 0.05})
	await _wait(0.6)
	TestCheck.expect(_dwarf._hud.dart_blind._active, "fléchette dans son nain : vue brouillée")
	_cam.current = false
	await _wait(0.4)
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/darts_4_vue_brouillee.png")
	_darts.request_pull.rpc_id(1, 0)
	await _wait(0.2)
	TestCheck.expect(_darts.dart_where[0] == DartsGame.Where.IN_DWARF, "on ne peut pas s'enlever sa propre fléchette")
	_darts._put_on_board(0)
	await _wait(0.4)
	TestCheck.expect(not _dwarf._hud.dart_blind._active, "fléchette retirée : la vue redevient nette")
	if quit_when_done or TestCheck.is_auto():
		TestCheck.finish(get_tree())


func _spawn(peer: int, slot: int, at: Vector3) -> Dwarf:
	var dwarf: Dwarf = DWARF_SCENE.instantiate() as Dwarf
	dwarf.setup(peer, slot)
	_mecha.get_node("Players").add_child(dwarf)
	dwarf.position = at
	return dwarf


## Lance une fléchette vers `target` (global) : visée corrigée pour la chute, avec le calcul de vol de l'hôte.
func _throw_at(target: Vector3) -> void:
	var eye: Vector3 = _dwarf.global_position + _mecha.global_basis.y * 0.95
	var aim: Vector3 = target
	for k: int in 6:
		var result: Dictionary = _darts._simulate(eye, (aim - eye).normalized() * DartsGame.THROW_SPEED, _dwarf)
		if not result.has("point"):
			break
		aim += target - (result["point"] as Vector3)
	_darts.request_throw.rpc_id(1, eye, (aim - eye).normalized())
	await _wait(0.45)


## Capture depuis `from` vers `to` (repère du mécha).
func _shot(shot_name: String, from: Vector3, to: Vector3, delay: float = 0.0) -> void:
	await _wait(delay)
	_cam.global_position = _mecha.global_transform * from
	_cam.look_at(_mecha.global_transform * to, _mecha.global_basis.y)
	_cam.current = true
	await TestCheck.frame_drawn(get_tree())
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/darts_%s.png" % shot_name)


func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
