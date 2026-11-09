extends Node3D
## Bac à sable des fléchettes du robot (3.9) : un vrai nain (hors réseau, on est l'hôte) prend les fléchettes
## plantées dans la cible du salon, lance dans le mille, puis à côté, puis sur un allié (nain du joueur 2) ;
## le total s'affiche ; il retire la fléchette de la tête de l'allié. Puis une fléchette plantée dans son
## propre nain lui brouille la vue, et il ne peut pas se l'enlever lui-même. Enfin, l'inventaire (5 cacas).
## Captures dans build/views/darts_*.png.

const DWARF_SCENE: PackedScene = preload("res://scenes/player/dwarf.tscn")
const POOP_SCENE: PackedScene = preload("res://scenes/props/poop.tscn")
const CRATE_SCENE: PackedScene = preload("res://scenes/props/cargo_crate.tscn")

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
	TestCheck.expect(_darts.darts_held_by(1) == 3, "on prend les 3 fléchettes d'un coup")
	var first: Dictionary = Inventory.slots_of(get_tree(), 1)[0]
	TestCheck.expect(not first.is_empty() and first["icon"] == &"dart" and first["count"] == 3, "les 3 fléchettes prennent une seule case de l'inventaire")
	(_dwarf.get_node("%Camera") as Camera3D).current = true
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/darts_0b_en_main.png")

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
	TestCheck.expect(in_ally >= 0 and _darts.dart_where[in_ally] == DartsGame.Where.IN_HAND and _darts.darts_held_by(1) == 1,
		"on retire la fléchette de l'allié : elle va dans notre inventaire")
	_darts.request_drop_one.rpc_id(1)
	await _wait(0.2)
	TestCheck.expect(_darts.darts_held_by(1) == 0 and _darts.dart_where[in_ally] == DartsGame.Where.PLANTED,
		"G : la fléchette est posée (plus dans l'inventaire)")
	TestCheck.expect(_darts.has_darts_away(), "G : posée au sol, pas sur la cible")
	var dropped: Vector3 = _dwarf.global_transform.affine_inverse() * _darts.to_global(_darts.dart_pos[in_ally])
	TestCheck.expect(absf(dropped.y) < 0.1 and dropped.z < -0.2,
		"G : couchée au sol, devant les pieds du nain (%s)" % dropped)
	await _shot("2b_posee_au_sol", Vector3(0.1, 3.8, 0.6),
		_mecha.to_local(_darts.to_global(_darts.dart_pos[in_ally])), 0.1)
	var handles: Array[Node] = _darts.find_children("*", "DartHandle", true, false)
	var floor_handle: DartHandle = handles.filter(func(h: Node) -> bool: return (h as DartHandle).index == in_ally)[0]
	TestCheck.expect(floor_handle.picks_up_with_item(), "objet en main : le clic sur la fléchette au sol la ramasse (au lieu de lancer)")
	for h: Node in handles:
		var handle: DartHandle = h as DartHandle
		if _darts.dart_where[handle.index] == DartsGame.Where.PLANTED and _darts.is_on_board(handle.index):
			TestCheck.expect(not handle.picks_up_with_item(), "objet en main : le clic vers la cible lance toujours")
	var planted_before: int = _darts.dart_where.count(DartsGame.Where.PLANTED)
	_darts.request_take_one.rpc_id(1, in_ally)
	await _wait(0.2)
	TestCheck.expect(_darts.darts_held_by(1) == 1 and _darts.dart_where.count(DartsGame.Where.PLANTED) == planted_before - 1,
		"fléchette au sol ramassée : celle-là seulement")
	_darts.request_drop_one.rpc_id(1)
	await _wait(0.2)
	_darts.request_reset.rpc_id(1)
	await _wait(0.2)
	TestCheck.expect(not _darts.has_darts_away() and _darts.has_free_darts(),
		"clic sur la cible : toutes les fléchettes y retournent")

	# Une fléchette en plein visage (elle arrive de face) : vue brouillée, et on ne peut pas se l'enlever soi-même.
	var facing: Vector3 = -_dwarf.view_transform().basis.z
	var head_point: Vector3 = _dwarf.global_position + _mecha.global_basis.y * 1.0
	_darts._land(0, {"point": head_point, "dir": -facing, "dwarf": _dwarf, "time": 0.05})
	await _wait(0.6)
	TestCheck.expect(_darts.dart_spot[0] == DartsGame.Spot.FACE, "de face, à hauteur de tête : plantée au visage")
	TestCheck.expect(_dwarf._hud.dart_blind._active, "fléchette au visage : vue brouillée")
	(_dwarf.get_node("%Camera") as Camera3D).current = true   # la vue du joueur
	await _wait(0.4)
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/darts_4_vue_brouillee.png")
	_darts.request_pull.rpc_id(1, 0)
	await _wait(0.2)
	TestCheck.expect(_darts.dart_where[0] == DartsGame.Where.IN_DWARF, "on ne peut pas s'enlever sa propre fléchette")
	_darts._put_on_board(0)
	await _wait(0.4)
	TestCheck.expect(not _dwarf._hud.dart_blind._active, "fléchette retirée : la vue redevient nette")

	# Dans le dos (casque) puis dans le corps : pas de vue brouillée, seulement le flash rouge de douleur.
	_darts._land(1, {"point": head_point, "dir": facing, "dwarf": _dwarf, "time": 0.05})
	await _wait(0.2)
	TestCheck.expect(_darts.dart_spot[1] == DartsGame.Spot.HEAD, "de dos, à hauteur de tête : plantée dans le casque")
	TestCheck.expect(_dwarf._hud.hurt_overlay.is_flashing(), "fléchette dans le casque : flash rouge de douleur")
	(_dwarf.get_node("%Camera") as Camera3D).current = true
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/darts_5_douleur.png")
	await _wait(0.5)
	TestCheck.expect(not _dwarf._hud.dart_blind._active, "fléchette dans le casque : la vue reste nette")
	_darts._land(2, {"point": _dwarf.global_position + _mecha.global_basis.y * 0.5, "dir": -facing, "dwarf": _dwarf, "time": 0.05})
	await _wait(0.6)
	TestCheck.expect(_darts.dart_spot[2] == DartsGame.Spot.BODY and not _dwarf._hud.dart_blind._active, "fléchette dans le ventre : plantée dans le corps, vue nette")
	TestCheck.expect(_darts.dart_where[1] == DartsGame.Where.IN_DWARF and _darts.dart_where[2] == DartsGame.Where.IN_DWARF, "elles restent plantées (un allié doit les retirer)")
	await _shot("6_plantees_allie_vue", Vector3(0.6, 3.6, -1.6), _mecha.to_local(_dwarf.global_position) + Vector3(0.0, 0.7, 0.0))
	_darts._put_on_board(1)
	_darts._put_on_board(2)
	await _inventory_checks()
	if quit_when_done or TestCheck.is_auto():
		TestCheck.finish(get_tree())


## Inventaire : 5 cacas remplissent les 5 cases, un 6e est refusé ; seul celui de la case choisie est en main
## (visible, seul à pouvoir être lancé) ; un levier tenu le range tout seul. Puis une caisse portée à deux mains :
## elle passe en main, on ne change plus de case, on ne ramasse rien d'autre, ni levier ni siège.
func _inventory_checks() -> void:
	var poops: Array[Poop] = []
	for i: int in Inventory.SIZE + 1:
		var poop: Poop = POOP_SCENE.instantiate() as Poop
		_mecha.get_node("Props").add_child(poop, true)
		poop.global_position = _dwarf.global_position + _mecha.global_basis.x * 0.3
		poops.append(poop)
	await _wait(0.1)
	for poop: Poop in poops:
		poop.request_pick.rpc_id(1)
		await _wait(0.05)
	var slots: Array[Dictionary] = Inventory.slots_of(get_tree(), 1)
	var full: bool = true
	for slot: Dictionary in slots:
		full = full and not slot.is_empty() and slot["icon"] == &"poop"
	TestCheck.expect(full and poops[0].holder_slot == 0 and poops[4].holder_slot == 4, "5 cacas : un par case, dans l'ordre")
	TestCheck.expect(poops[5].holder_peer_id == 0, "inventaire plein : le 6e caca reste par terre")
	_darts.request_take.rpc_id(1)
	await _wait(0.1)
	TestCheck.expect(_darts.darts_held_by(1) == 0, "inventaire plein : on ne peut pas prendre les fléchettes")
	_dwarf.hand_slot = 2
	await _wait(0.1)
	TestCheck.expect(poops[2].visible and not poops[0].visible, "seul le caca de la case choisie est en main")
	(_dwarf.get_node("%Camera") as Camera3D).current = true   # la vue du joueur, barre d'inventaire en bas
	await TestCheck.frame_drawn(get_tree())
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/darts_7_inventaire.png")
	poops[0].request_throw.rpc_id(1, Vector3.FORWARD)
	await _wait(0.1)
	TestCheck.expect(poops[0].holder_peer_id == 1, "un caca rangé (pas en main) ne se lance pas")
	TestCheck.expect(not Possession.is_peer_busy(get_tree(), 1), "caca en main : levier, siège et corde restent possibles")
	var lever: Lever = _mecha.get_node("Controls/LegL_Stick") as Lever
	lever.holder_peer_id = 1   # comme si l'hôte venait d'accepter l'attrape
	await _wait(0.1)
	TestCheck.expect(not poops[2].visible and not Inventory.has_item_in_hand(get_tree(), 1), "levier en main : le caca est rangé tout seul")
	lever.holder_peer_id = 0
	await _wait(0.1)
	TestCheck.expect(poops[2].visible, "levier lâché : le caca revient en main")
	poops[2].request_throw.rpc_id(1, Vector3.ZERO)
	await _wait(0.1)
	TestCheck.expect(poops[2].holder_peer_id == 0, "G : on pose le caca")

	# Caisse : la case en main (3) est vide, mais on choisit une case pleine pour vérifier qu'elle y passe.
	_dwarf.hand_slot = 0
	var crate: CargoCrate = CRATE_SCENE.instantiate() as CargoCrate
	_mecha.get_node("Props").add_child(crate, true)
	crate.global_position = _dwarf.global_position + _mecha.global_basis.x * 0.6
	await _wait(0.1)
	crate.request_pick.rpc_id(1)
	await _wait(0.1)
	TestCheck.expect(crate.holder_peer_id == 1 and crate.holder_slot == 2 and _dwarf.hand_slot == 2,
		"caisse prise : elle va dans la case libre, qui passe en main")
	_dwarf.hand_slot = 0
	_dwarf._choose_slot(_key_event(&"slot_1"))
	await _wait(0.1)
	TestCheck.expect(_dwarf.hand_slot == 2, "caisse en main : on ne change pas de case")
	TestCheck.expect(Possession.is_peer_busy(get_tree(), 1), "caisse en main : levier, siège et corde refusés")
	poops[2].request_pick.rpc_id(1)
	await _wait(0.1)
	TestCheck.expect(poops[2].holder_peer_id == 0, "caisse en main : on ne ramasse rien d'autre")
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/darts_8_caisse.png")
	var side: Vector3 = _mecha.to_local(_dwarf.global_position)
	await _shot("9_caisse_portee", side + Vector3(1.6, 1.0, 0.9), side + Vector3(0.0, 0.5, 0.0))
	crate.request_put_down.rpc_id(1)
	await _wait(0.1)
	var on_floor: float = (_mecha.global_transform.affine_inverse() * crate.global_position).y
	TestCheck.expect(crate.holder_peer_id == 0 and crate.collision_layer != 0, "clic ou G : la caisse est posée")
	print("Caisse posée à %.2f m (repère du mécha), nain à %.2f m" % [on_floor, _dwarf.position.y])
	TestCheck.expect(absf(on_floor - _dwarf.position.y) < 0.3, "elle est posée au sol, devant le nain")
	crate.queue_free()
	for poop: Poop in poops:
		if is_instance_valid(poop):
			poop.queue_free()


func _key_event(action: StringName) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


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
