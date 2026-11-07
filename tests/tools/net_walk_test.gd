extends Node
## Test réseau de la marche : lancer deux fois (une hôte, une cliente) :
##   Godot --path . res://tests/tools/net_walk_test.tscn -- host
##   Godot --path . res://tests/tools/net_walk_test.tscn -- client
## Le client place son nain à la console de gauche, attrape le joystick gauche et pousse ;
## l'hôte pousse le joystick droit en alternance. Chacun affiche où il voit le robot.

const MAIN: PackedScene = preload("res://scenes/main/main.tscn")

var _role: String = "host"
var _time: float = 0.0
var _walk_start: float = -1.0
var _next_print: float = 0.0
var _mecha: Node3D
var _walker: MechaWalker
var _sticks: Array[Lever] = []
var _interactor: Interactor


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_role = args[0]
	add_child(MAIN.instantiate())
	_mecha = get_tree().root.find_child("Mecha", true, false) as Node3D
	_walker = _mecha.get_node("Walker") as MechaWalker
	_sticks = [_mecha.get_node("Controls/LegL_Stick") as Lever, _mecha.get_node("Controls/LegR_Stick") as Lever]
	_walker.stepped.connect(func(leg: int) -> void: if _role == "host": print("   [hôte] pas jambe %d" % leg))
	await get_tree().create_timer(0.5).timeout
	if _role == "host":
		NetworkManager.host_game()
	else:
		NetworkManager.join_game("127.0.0.1")
		NetworkManager.session_started.connect(_client_setup)


func _client_setup() -> void:
	await get_tree().create_timer(1.5).timeout
	var me: Node3D = _mecha.get_node("Players/%d" % multiplayer.get_unique_id()) as Node3D
	me.position = Vector3(-1.22, 2.65, -0.75)   # devant la console de la jambe gauche
	await get_tree().create_timer(0.5).timeout
	_interactor = me.find_child("Interactor", true, false) as Interactor
	_interactor.set("_held", _sticks[0])
	_interactor.set("_grab_pending", true)
	_sticks[0].request_grab.rpc_id(1)
	await get_tree().create_timer(0.5).timeout
	print("[client] joystick gauche tenu par moi : %s (porteur %d)" % [str(_sticks[0].is_held_locally()), _sticks[0].holder_peer_id])
	_walk_start = _time + 0.5


func _physics_process(delta: float) -> void:
	_time += delta
	if _role == "client" and _walk_start > 0.0:
		var t: float = _time - _walk_start
		if t > 0.0 and t < 8.0:
			# Comme un joueur : un petit coup de souris vers l'avant toutes les secondes, jamais vers l'arrière.
			if int(t / 0.5) % 2 == 0 and fmod(t, 0.5) < 0.1:
				_interactor.drive_mouse(Vector2(0.0, 60.0))
	if _role == "host" and _time > 16.0 and _walker.phase == MechaWalker.Phase.WALKING and _walk_start > 0.0:
		_walker.fall()   # pour voir si le client reçoit la chute et le QTE
	if _role == "host" and multiplayer.get_peers().size() > 0:
		# L'hôte pousse le joystick droit en décalé (pas impairs).
		if _walk_start < 0.0:
			_walk_start = _time + 5.0
		var t: float = _time - _walk_start
		var push: bool = t > 0.0 and t < 8.0 and int(t / 0.5) % 2 == 1 and fmod(t, 0.5) < 0.15
		_sticks[1].value = Vector2(0.0, 1.0) if push else Vector2.ZERO
	if _time >= _next_print:
		_next_print = _time + 1.0
		print("[%s %4.1f s] robot=(%.2f, %.2f, %.2f) joystick G=%s porteur G=%d" % [
			_role, _time, _mecha.global_position.x, _mecha.global_position.y, _mecha.global_position.z,
			str(_sticks[0].value), _sticks[0].holder_peer_id])
	if _time > 18.5:
		get_tree().quit()


var _swing_frames: int = 0
var _phase_seen: Dictionary = {}
var _qte_seen: bool = false


func _process(_delta: float) -> void:
	if _walker == null:
		return
	if _walker.swinging_left or _walker.swinging_right:
		_swing_frames += 1
	_phase_seen[_walker.phase] = true
	var qte: QteSequence = _mecha.get_node("RecoveryQte") as QteSequence
	_qte_seen = _qte_seen or qte.active
	if _time > 17.5 and not _phase_seen.has(-1):
		_phase_seen[-1] = true
		print("[%s] images avec un pied en l'air : %d ; phases vues : %s ; QTE vu actif : %s" % [
			_role, _swing_frames, str(_phase_seen.keys()), str(_qte_seen)])
