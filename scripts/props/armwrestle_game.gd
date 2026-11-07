class_name ArmwrestleGame
extends Node3D
## Bras de fer du camp (M12.1). Deux nains s'assoient sur les tonneaux (`seat_left`, `seat_right`) ;
## après « 3, 2, 1 », chacun martèle son bouton : chaque clic pousse la machine à bras mécaniques de son côté,
## qui revient doucement au centre. Le premier qui la fait basculer à fond a gagné. Une nouvelle manche
## repart toute seule tant que les deux joueurs restent assis.
##
## Réseau : les clics arrivent sur l'hôte par RPC (`submit_push`, envoyé par le nain assis, voir Seat.game).
## L'hôte est autoritaire sur `state`, `balance`, `timer` et les noms (répliqués) ; chaque peer anime la
## machine et le panneau à partir de cet état.

enum State { WAITING, COUNTDOWN, FIGHT, WIN }

const COUNTDOWN_TIME: float = 3.0
const WIN_TIME: float = 3.5
## Poussée d'un clic, et retour vers le centre par seconde (il faut marteler pour avancer).
const PUSH: float = 0.08
const RESIST: float = 0.06
## Bascule max de la machine (rad) quand un joueur gagne.
const MAX_TILT: float = deg_to_rad(68.0)
const FONT: FontVariation = preload("res://assets/fonts/fredoka.tres")

@export var seat_left: Seat
@export var seat_right: Seat

## État de la manche. Autorité : hôte.
var state: int = State.WAITING
## Rapport de force : -1 = le joueur de gauche a gagné, +1 = celui de droite. Autorité : hôte.
var balance: float = 0.0
## Temps restant du compte à rebours ou de l'affichage du gagnant. Autorité : hôte.
var timer: float = 0.0
## Noms des deux joueurs et du gagnant. Autorité : hôte.
var left_name: String = ""
var right_name: String = ""
var winner_name: String = ""

var _shown_balance: float = 0.0
var _shake: float = 0.0

@onready var _arms: Node3D = %Arms
@onready var _sign: Label3D = %Sign


func _ready() -> void:
	_sign.font = FONT
	NetworkManager.session_ended.connect(func(_reason: String) -> void: _reset(State.WAITING))


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var left: int = seat_left.occupant_peer_id if seat_left != null else 0
	var right: int = seat_right.occupant_peer_id if seat_right != null else 0
	left_name = _name_of(left)
	right_name = _name_of(right)
	var both: bool = left != 0 and right != 0
	match state:
		State.WAITING:
			balance = move_toward(balance, 0.0, delta)
			if both:
				_reset(State.COUNTDOWN)
		State.COUNTDOWN:
			timer -= delta
			if not both:
				_reset(State.WAITING)
			elif timer <= 0.0:
				state = State.FIGHT
		State.FIGHT:
			if not both:
				_reset(State.WAITING)
				return
			# Victoire testée avant le retour au centre (sinon on resterait bloqué juste sous 1).
			if absf(balance) >= 1.0:
				balance = signf(balance)
				winner_name = right_name if balance > 0.0 else left_name
				state = State.WIN
				timer = WIN_TIME
			else:
				balance = move_toward(balance, 0.0, RESIST * delta)
		State.WIN:
			timer -= delta
			if timer <= 0.0:
				_reset(State.COUNTDOWN if both else State.WAITING)


func _process(delta: float) -> void:
	_shown_balance = lerpf(_shown_balance, balance, 1.0 - exp(-14.0 * delta))
	_shake = (_shake + delta * 40.0) if state == State.FIGHT else 0.0
	var tremble: float = sin(_shake) * 0.025 if state == State.FIGHT else 0.0
	_arms.rotation.x = _shown_balance * MAX_TILT + tremble
	_sign.text = _sign_text()


## Clic d'un joueur assis (hôte). Pousse la machine du côté de son tonneau.
@rpc("any_peer", "call_local", "reliable")
func submit_push() -> void:
	if not multiplayer.is_server() or state != State.FIGHT:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if seat_left != null and sender == seat_left.occupant_peer_id:
		balance = maxf(balance - PUSH, -1.0)
	elif seat_right != null and sender == seat_right.occupant_peer_id:
		balance = minf(balance + PUSH, 1.0)


func _sign_text() -> String:
	var names: String = "%s  vs  %s" % [left_name if left_name != "" else "?", right_name if right_name != "" else "?"]
	match state:
		State.COUNTDOWN:
			return "%s\n%d" % [names, ceili(maxf(timer, 0.01))]
		State.FIGHT:
			return "%s\nTirez !" % names
		State.WIN:
			return "%s\n%s gagne !" % [names, winner_name]
	return "BRAS DE FER\nasseyez-vous à deux"


func _reset(new_state: int) -> void:
	state = new_state
	timer = COUNTDOWN_TIME if new_state == State.COUNTDOWN else 0.0
	if new_state != State.WAITING:
		balance = 0.0
	winner_name = ""


func _name_of(peer_id: int) -> String:
	if peer_id == 0:
		return ""
	for node: Node in get_tree().get_nodes_in_group(&"dwarves"):
		if node.name == str(peer_id):
			var player: String = str(node.get(&"player_name"))
			return player if player != "" else "Nain %d" % peer_id
	return "Nain %d" % peer_id
