extends Node
## Test réseau automatique : un hôte et un client (ENet local, sans fenêtre) jouent un scénario,
## et après chaque étape on vérifie que le client voit EXACTEMENT la même chose que l'hôte.
##
## Lancer (deux terminaux, ou `tests/tools/net_test.sh` qui fait tout) :
##   Godot --headless --path . res://tests/tools/net_test.tscn -- --role=host
##   Godot --headless --path . res://tests/tools/net_test.tscn -- --role=client
##
## Ce qui est comparé (voir `NetAudit.snapshot`) : toutes les propriétés « à chaque changement »
## des MultiplayerSynchronizer de l'hôte, plus la présence et la place de chaque objet physique
## du niveau et du robot. Un écart = un bug de synchro. Sortie : « NET TEST OK » ou la liste des écarts.

const PORT: int = 7791
const STEP_WAIT: float = 1.5
const TIMEOUT: float = 300.0

var _role: String = ""
var _failures: int = 0
var _client_id: int = 0
var _pending_check: String = ""

@onready var _main: Node = $Main
@onready var _world: Node3D = $Main/World
@onready var _director: MissionDirector = $Main/World/MissionDirector


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			_role = arg.trim_prefix("--role=")
	if _role.is_empty():
		push_error("net_test : il faut --role=host ou --role=client")
		get_tree().quit(2)
		return
	get_tree().create_timer(TIMEOUT).timeout.connect(_on_timeout)
	await get_tree().create_timer(0.5).timeout
	if _role == "host":
		_run_host()
	else:
		_run_client()


# --- Hôte : joue le scénario ---

func _run_host() -> void:
	var err: Error = NetworkManager.host_game(PORT)
	if err != OK:
		_log("hôte impossible : %s" % error_string(err))
		get_tree().quit(2)
		return
	_log("hôte prêt, on prépare une partie avant que le client arrive")
	# Avant l'arrivée du client : on part en mission et on casse un rocher (test « arrivée en cours »).
	_director._travel(&"test_ground")
	await get_tree().create_timer(STEP_WAIT).timeout
	_level().get_node("MineableRocks/Rock2").apply_drill_damage(1.0e6)
	await get_tree().create_timer(0.5).timeout
	_backpack().store_node(_level().get_node("CargoCrates/Crate2"), "crate")
	await get_tree().create_timer(STEP_WAIT).timeout

	_log("en attente du client…")
	while multiplayer.get_peers().is_empty():
		await get_tree().process_frame
	_client_id = multiplayer.get_peers()[0]
	await get_tree().create_timer(STEP_WAIT * 2.0).timeout
	await _check("arrivée en cours de mission")

	_level().get_node("MineableRocks/Rock1").apply_drill_damage(1.0e6)
	await get_tree().create_timer(STEP_WAIT).timeout
	await _check("rocher cassé par l'hôte + caisse de minerai")

	_backpack().store_node(_level().get_node("CargoCrates/Crate1"), "crate")
	await get_tree().create_timer(STEP_WAIT).timeout
	await _check("caisse posée dans le niveau rangée dans le sac")

	_toilet()._drop_poop(false)
	await get_tree().create_timer(STEP_WAIT).timeout
	await _check("caca qui apparaît")

	# Le client agit lui-même (il se place à portée, puis envoie la même demande que le jeu).
	await _client_step("interrupteur du rayon (client)", "Mecha/Controls/BeamSwitch_Belly", "request_press")
	await _client_step("porte des toilettes (client)", "Mecha/ToiletDoor/Handle", "request_toggle")
	await _robo_jet_steps()
	await _client_step("télé éteinte (client)", "Mecha/InteriorBelly/TvSet/Power", "request_press")
	await _client_step("dames : pion choisi (client)", "Mecha/InteriorBelly/CoffeeTable/Checkers", "request_cell", [17])
	await _client_step("dames : pion joué (client)", "Mecha/InteriorBelly/CoffeeTable/Checkers", "request_cell", [26])
	await _client_step("dames : nouvelle partie à la pendule (client)", "Mecha/InteriorBelly/CoffeeTable/Checkers", "request_new_game")
	await _client_step("bouton du pad (client)", "Mecha/Controls/LegL_PadUp", "request_press")
	await get_tree().create_timer(STEP_WAIT).timeout   # la flèche ↑ en attente de l'autre pilote expire
	var qte: QteSequence = _world.get_node("Mecha/RecoveryQte") as QteSequence
	await _maneuver_steps(qte)
	# QTE : la séquence entière et les erreurs sont synchronisées (écran « Just Dance » des consoles).
	qte.start([Vector2i(0, QteSequence.Arrow.UP), Vector2i(1, QteSequence.Arrow.LEFT), Vector2i(0, QteSequence.Arrow.RIGHT)])
	await get_tree().create_timer(STEP_WAIT).timeout
	await _check("QTE lancé par l'hôte (séquence)")
	await _client_step("QTE : mauvaise flèche (client)", "Mecha/Controls/LegL_PadDown", "request_press")
	await _client_step("QTE : bonne flèche (client)", "Mecha/Controls/LegL_PadUp", "request_press")
	qte.cancel()
	await get_tree().create_timer(STEP_WAIT).timeout
	await _check("QTE annulé")
	await _client_step("levier attrapé (client)", "Mecha/Controls/LegL_Stick", "request_grab")
	await _client_step("levier lâché (client)", "Mecha/Controls/LegL_Stick", "request_release")
	await _client_step("assis au grappin (client)", "Mecha/Controls/Grabber_Seat", "request_sit")
	await _client_refused("déjà assis : la foreuse voisine est refusée (client)", "Mecha/Controls/Drill_Seat", "request_sit")
	await _client_step("grappin piloté (client)", "Mecha/Controls/Grabber_Seat", "drive", [Vector2(0.0, 1.0), true])
	await _client_step("levé du grappin (client)", "Mecha/Controls/Grabber_Seat", "request_leave")
	await _client_step("assis à la foreuse (client)", "Mecha/Controls/Drill_Seat", "request_sit")
	await _client_step("foreuse pilotée (client)", "Mecha/Controls/Drill_Seat", "drive", [Vector2(0.0, 1.0), true])
	await _client_step("levé de la foreuse (client)", "Mecha/Controls/Drill_Seat", "request_leave")
	await _client_step("assis sur le canapé (client)", "Mecha/Controls/Sofa_Left", "request_sit")
	await _client_step("levé du canapé (client)", "Mecha/Controls/Sofa_Left", "request_leave")
	await _client_step("caca ramassé (client)", "Mecha/Props/Poop", "request_pick")
	await _client_step("caca lancé (client)", "Mecha/Props/Poop", "request_throw", [Vector3(0.0, 0.0, 1.0)])

	_toilet()._drop_poop(false)
	await get_tree().create_timer(STEP_WAIT).timeout
	var arm: GrabberArm = _world.get_node("Mecha/GrabberArm") as GrabberArm
	arm.grab_node(_world.get_node("Mecha/Props").get_child(0) as Node3D, "poop")
	await get_tree().create_timer(STEP_WAIT * 3.0).timeout
	await _check("caca attrapé par le grappin et rangé dans le sac")
	await _inventory_steps()

	_director._travel(&"lobby")
	await get_tree().create_timer(STEP_WAIT * 2.0).timeout
	await _check("retour au camp")
	await _client_step("terminal : mission suivante (client)", "Level/Lobby/MissionTerminal/Next", "request_press")
	await _client_step("fléchettes du robot prises (client)", "Mecha/Controls/Darts", "darts_take")
	await _client_step("fléchette lancée (client)", "Mecha/Controls/Darts", "throw")
	await _client_step("fléchettes en main : assis au bras de fer, fléchettes rangées (client)", "Level/Lobby/Minigames/ArmWrestling/SeatLeft", "request_sit")
	await _client_step("levé du bras de fer, fléchettes revenues en main (client)", "Level/Lobby/Minigames/ArmWrestling/SeatLeft", "request_leave")
	await _client_step("G : une fléchette posée au sol (client)", "Mecha/Controls/Darts", "request_drop_one")
	await _client_step("fléchette au sol ramassée, celle-là seulement (client)", "Mecha/Controls/Darts",
		"stay:request_take_one", [_dart_on_floor()])
	await _client_step("G : fléchette reposée au sol (client)", "Mecha/Controls/Darts", "request_drop_one")
	await _client_step("G : la dernière fléchette posée au sol (client)", "Mecha/Controls/Darts", "request_drop_one")
	await _client_step("clic sur la cible : fléchettes remises (client)", "Mecha/Controls/Darts", "request_reset")
	await _dart_in_client_step()
	await _client_step("bras de fer : assis (client)", "Level/Lobby/Minigames/ArmWrestling/SeatLeft", "request_sit")
	await _client_step("bras de fer : levé (client)", "Level/Lobby/Minigames/ArmWrestling/SeatLeft", "request_leave")

	_director._travel(&"test_ground")
	await get_tree().create_timer(STEP_WAIT * 2.0).timeout
	await _check("retour en mission (niveau rechargé)")
	_level().get_node("MineableRocks/Rock3").apply_drill_damage(1.0e6)
	await get_tree().create_timer(STEP_WAIT).timeout
	await _check("rocher cassé après rechargement")

	_finish.rpc_id(_client_id)
	_log("NET TEST %s (%d étape(s) en échec)" % ["OK" if _failures == 0 else "ÉCHEC", _failures])
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0 if _failures == 0 else 1)


## Inventaire du client : deux cacas dans deux cases, changement de case, lancer d'un caca rangé refusé,
## levier refusé avec un caca en main, puis les deux cacas posés (G).
func _inventory_steps() -> void:
	_toilet()._drop_poop(false)
	_toilet()._drop_poop(false)
	await get_tree().create_timer(STEP_WAIT).timeout
	var poops: Array[String] = []
	for node: Node in get_tree().get_nodes_in_group(&"poops"):
		if (node as Poop).holder_peer_id == 0:
			poops.append(str(_world.get_path_to(node)))
	await _client_step("inventaire : 1er caca dans la case 1 (client)", poops[0], "request_pick")
	await _client_step("inventaire : 2e caca dans la case 2 (client)", poops[1], "request_pick")
	if (_world.get_node(poops[1]) as Poop).holder_slot != 1:
		_failures += 1
		_log("ÉCHEC  inventaire : le 2e caca n'est pas dans la case 2")
	await _client_hand_slot(1)
	await _client_refused("inventaire : le caca rangé ne se lance pas (client)", poops[0], "request_throw", true, [Vector3.FORWARD])
	await _client_step("inventaire : caca de la case 2 posé (client)", poops[1], "request_throw", [Vector3.ZERO])
	await _client_hand_slot(0)
	await _client_step("caca en main : levier attrapé, caca rangé (client)", "Mecha/Controls/LegL_Stick", "request_grab")
	if Inventory.has_item_in_hand(get_tree(), _client_id):
		_failures += 1
		_log("ÉCHEC  levier attrapé : le caca est encore en main")
	await _client_step("levier lâché, caca revenu en main (client)", "Mecha/Controls/LegL_Stick", "request_release")
	await _client_step("inventaire : caca de la case 1 posé (client)", poops[0], "request_throw", [Vector3.ZERO])
	await _crate_steps()


## Caisse portée à deux mains par le client : prise, levier refusé tant qu'il la porte, posée.
func _crate_steps() -> void:
	var crate: String = str(_world.get_path_to(_level().get_node("CargoCrates/Crate3")))
	await _client_step("caisse prise à deux mains (client)", crate, "request_pick")
	# À portée du levier d'abord (la caisse bouge avec le nain), puis la demande, qui doit être refusée.
	_client_action.rpc_id(_client_id, "Mecha/Controls/LegL_Stick", "goto", [])
	await get_tree().create_timer(STEP_WAIT).timeout
	await _check("caisse portée jusqu'au levier (client)")
	await _client_refused("caisse en main : le levier est refusé (client)", "Mecha/Controls/LegL_Stick", "request_grab")
	await _client_step("caisse posée (client)", crate, "stay:request_put_down")


## Le client choisit une case (touche 1 à 5) : l'hôte doit la voir sur son nain (propriété du client, répliquée).
func _client_hand_slot(slot: int) -> void:
	var step: String = "inventaire : case %d choisie (client)" % (slot + 1)
	_client_action.rpc_id(_client_id, "Mecha/Players/%d" % _client_id, "hand_slot", [slot])
	await get_tree().create_timer(STEP_WAIT).timeout
	if Dwarf.of_peer(_client_id).hand_slot != slot:
		_failures += 1
		_log("ÉCHEC  %s : l'hôte ne voit pas la case choisie" % step)
		return
	await _check(step)


## Fléchette plantée dans le nain du client (l'hôte simule le coup), puis le nain de l'hôte la lui retire.
func _dart_in_client_step() -> void:
	var darts: DartsGame = _world.get_node("Mecha/Controls/Darts") as DartsGame
	var client: Dwarf = Dwarf.of_peer(_client_id)
	var host: Dwarf = Dwarf.of_peer(1)
	darts._land(0, {"point": client.global_position, "dir": client.global_basis.z, "dwarf": client, "time": 0.1})
	await get_tree().create_timer(STEP_WAIT).timeout
	await _check("fléchette plantée dans le corps du client")
	var face: Vector3 = client.global_position + client.global_basis.y * 1.0
	darts._land(1, {"point": face, "dir": client.view_transform().basis.z, "dwarf": client, "time": 0.1})
	await get_tree().create_timer(STEP_WAIT).timeout
	if darts.dart_spot[1] != DartsGame.Spot.FACE:
		_failures += 1
		_log("ÉCHEC  fléchette de face : pas plantée au visage")
	await _check("fléchette plantée au visage du client")
	darts._put_on_board(1)
	host.global_position = client.global_position + client.global_basis.x * 0.8
	host.set(&"_world_position", host.global_position)   # dehors, le nain garde sa place dans le monde
	await get_tree().create_timer(0.6).timeout
	darts.request_pull.rpc_id(1, 0)
	await get_tree().create_timer(STEP_WAIT).timeout
	if darts.darts_held_by(1) != 1:
		_failures += 1
		_log("ÉCHEC  fléchette retirée : pas dans l'inventaire de l'hôte")
	await _check("fléchette retirée par l'hôte (dans son inventaire)")
	darts.request_drop_one.rpc_id(1)
	await get_tree().create_timer(STEP_WAIT).timeout
	await _check("fléchette posée par l'hôte (G)")


## Fait faire une action au client, vérifie que l'hôte l'a appliquée, puis compare.
func _client_step(step: String, path: String, action: String, args: Array = []) -> void:
	var before: Dictionary = NetAudit.snapshot(_world, true)
	_client_action.rpc_id(_client_id, path, action, args)
	await get_tree().create_timer(STEP_WAIT).timeout
	if NetAudit.diff(before, NetAudit.snapshot(_world, true)).is_empty():
		# L'hôte a refusé la demande (ou elle ne l'a jamais atteint) : rien n'a changé.
		_failures += 1
		_log("ÉCHEC  %s : la demande du client n'a rien changé chez l'hôte" % step)
		return
	await _check(step)


## Fait faire au client une demande que l'hôte doit refuser : rien ne doit changer.
## `stay` : le client ne se rapproche pas de l'objet (sinon il se place à portée, comme une étape normale).
func _client_refused(step: String, path: String, action: String, stay: bool = true, args: Array = []) -> void:
	var before: Dictionary = NetAudit.snapshot(_world, true)
	_client_action.rpc_id(_client_id, path, ("stay:" if stay else "") + action, args)
	await get_tree().create_timer(STEP_WAIT).timeout
	var diffs: PackedStringArray = NetAudit.diff(before, NetAudit.snapshot(_world, true))
	if diffs.is_empty():
		_log("OK     %s" % step)
	else:
		_failures += 1
		_log("ÉCHEC  %s : l'hôte a accepté la demande" % step)
		for line: String in diffs:
			_log("         %s" % line)


## Envoie l'état de l'hôte au client, qui compare et répond.
func _check(step: String) -> void:
	_pending_check = step
	_compare.rpc_id(_client_id, step, NetAudit.snapshot(_world))
	while _pending_check == step:
		await get_tree().process_frame


@rpc("any_peer", "reliable")
func _report(step: String, diffs: PackedStringArray) -> void:
	if diffs.is_empty():
		_log("OK     %s" % step)
	else:
		_failures += 1
		_log("ÉCHEC  %s" % step)
		for line: String in diffs:
			_log("         %s" % line)
	_pending_check = ""


# --- Client ---

func _run_client() -> void:
	# Laisse l'hôte préparer la partie avant d'arriver.
	await get_tree().create_timer(5.0).timeout
	var err: Error = NetworkManager.join_game("127.0.0.1", PORT)
	if err != OK:
		_log("connexion impossible : %s" % error_string(err))
		get_tree().quit(2)
		return
	_log("client connecté")


@rpc("authority", "reliable")
func _compare(step: String, host_state: Dictionary) -> void:
	var diffs: PackedStringArray = NetAudit.diff(host_state, NetAudit.snapshot(_world))
	_report.rpc_id(1, step, diffs)


@rpc("authority", "reliable")
func _client_action(path: String, action: String, args: Array) -> void:
	var target: Node3D = _world.get_node_or_null(path) as Node3D
	if target == null:
		_log("client : %s introuvable" % path)
		return
	if action.begins_with("stay:"):
		target.callv(&"rpc_id", [1, action.trim_prefix("stay:")] + args)
		return
	match action:
		"hand_slot":
			(target as Dwarf).hand_slot = args[0]   # touche 1 à 5 : le nain du client, répliqué
		"goto":
			# Se placer à portée sans rien demander.
			var walker: Node3D = _world.get_node_or_null("Mecha/Players/%d" % multiplayer.get_unique_id()) as Node3D
			var near: Vector3 = target.global_position + target.global_basis.z * 0.8
			walker.global_position = near
			walker.set(&"_world_position", near)
		"drive":
			# Assis : on envoie les commandes du poste pendant une seconde, comme le nain assis.
			for i: int in range(30):
				(target as Seat).submit_controls.rpc_id(1, args[0], Vector2.ZERO, args[1], 0)
				await get_tree().create_timer(1.0 / 30.0).timeout
			(target as Seat).submit_controls.rpc_id(1, Vector2.ZERO, Vector2.ZERO, false, 0)
		"robo_jet_tap":
			# Devant la télé (au sol du ventre), puis un clic sur l'écran, comme le joueur.
			var player: Node3D = _world.get_node_or_null("Mecha/Players/%d" % multiplayer.get_unique_id()) as Node3D
			var front: Vector3 = target.global_position + target.global_basis.z * 1.3 - target.global_basis.y * 1.2
			player.global_position = front
			player.set(&"_world_position", front)
			await get_tree().create_timer(0.6).timeout
			(target as RoboJetTouch).game.tap()
		"darts_take", "throw":
			# Devant la cible du salon (au sol du ventre), puis : prendre, ou lancer vers la cible.
			var thrower: Node3D = _world.get_node_or_null("Mecha/Players/%d" % multiplayer.get_unique_id()) as Node3D
			var stand: Vector3 = target.to_global(Vector3(0.0, -1.2, -1.6))
			thrower.global_position = stand
			await get_tree().create_timer(0.6).timeout
			if action == "darts_take":
				target.request_take.rpc_id(1)
			else:
				var eye: Vector3 = stand + target.global_basis.y * 0.95
				var aim: Vector3 = target.to_global(Vector3(0.0, 0.15, 0.0))
				target.request_throw.rpc_id(1, eye, (aim - eye).normalized())
		_:
			# On se place à portée (le nain glisse avec le robot : repère local au mécha), puis on demande.
			var dwarf: Node3D = _world.get_node_or_null("Mecha/Players/%d" % multiplayer.get_unique_id()) as Node3D
			if dwarf != null and not (action == "request_leave" or action == "request_release"):
				var spot: Vector3 = target.global_position + target.global_basis.z * 0.8
				dwarf.global_position = spot
				dwarf.set(&"_world_position", spot)   # dehors, le nain garde sa place dans le monde
				await get_tree().create_timer(0.6).timeout
			target.callv(&"rpc_id", [1, action] + args)


@rpc("authority", "reliable")
func _finish() -> void:
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0)


# --- Outils ---

## Jeu de la télé (Robo-Jet) : le client vise l'écran et clique, l'hôte lui donne la partie (joueur, graine) ;
## sans autre clic, son robot s'écrase chez lui et l'hôte garde son score (partie finie, record).
func _robo_jet_steps() -> void:
	var game: RoboJetGame = _world.get_node("Mecha/InteriorBelly/TvSet/RoboJet") as RoboJetGame
	await _client_step("télé : le client lance une partie de Robo-Jet", "Mecha/InteriorBelly/TvSet/Touch", "robo_jet_tap")
	if game.player_peer != _client_id:   # (la partie a pu déjà finir : personne ne clique)
		_failures += 1
		_log("ÉCHEC  télé : la partie n'est pas au client")
	var deadline: int = Time.get_ticks_msec() + 6000
	while game.running and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(STEP_WAIT).timeout
	if game.running:
		_failures += 1
		_log("ÉCHEC  télé : le robot du client ne s'est pas écrasé")
	await _check("télé : partie du client finie, score gardé par l'hôte")


## Accroupi du robot (M7.5) : ↓ par le pilote de l'hôte puis par celui du client = QTE de l'accroupi, joué
## jusqu'au bout (appuis de l'hôte), robot accroupi ; puis ↓ par les deux = relevé.
func _maneuver_steps(qte: QteSequence) -> void:
	var walker: MechaWalker = _world.get_node("Mecha/Walker") as MechaWalker
	var host_pad: PushButton = _world.get_node("Mecha/Controls/LegR_PadDown") as PushButton
	host_pad.pressed.emit(1)
	await _client_step("↓ par les deux pilotes : QTE de l'accroupi (client)", "Mecha/Controls/LegL_PadDown", "request_press")
	if not qte.active:
		_failures += 1
		_log("ÉCHEC  ↓ par les deux pilotes : pas de QTE")
		return
	while qte.active:
		for pad: PushButton in qte.expected_pads():   # deux boutons pour une étape « ensemble »
			pad.pressed.emit(1)
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(STEP_WAIT).timeout
	if not walker.crouched:
		_failures += 1
		_log("ÉCHEC  QTE de l'accroupi réussi : le robot n'est pas accroupi")
	await _check("robot accroupi")
	host_pad.pressed.emit(1)
	await _client_step("↓ par les deux pilotes : robot relevé (client)", "Mecha/Controls/LegL_PadDown", "request_press")
	await get_tree().create_timer(STEP_WAIT).timeout
	await _check("robot debout")


## Numéro d'une fléchette posée hors de la cible (au sol), -1 s'il n'y en a pas.
func _dart_on_floor() -> int:
	var darts: DartsGame = _world.get_node("Mecha/Controls/Darts") as DartsGame
	for i: int in DartsGame.DART_COUNT:
		if darts.dart_where[i] == DartsGame.Where.PLANTED and not darts.is_on_board(i):
			return i
	return -1


func _level() -> Node3D:
	return _director.get_level()


func _backpack() -> Backpack:
	return get_tree().get_first_node_in_group(&"backpacks") as Backpack


func _toilet() -> Toilet:
	return _world.find_children("*", "Seat", true, false).filter(
		func(n: Node) -> bool: return n is Toilet)[0] as Toilet


func _on_timeout() -> void:
	_log("délai dépassé")
	get_tree().quit(3)


func _log(text: String) -> void:
	print("[net_test %s] %s" % [_role, text])
