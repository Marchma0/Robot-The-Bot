class_name RoboJetGame
extends Node
## « Robo-Jet », le jeu de la télé du salon : notre petit robot à réacteur doit passer entre les stalactites
## (en haut) et les poutres de mine (en bas). Un clic sur l'écran (RoboJetTouch) = un coup de réacteur.
## Un joueur à la fois ; les autres regardent la partie en direct. Meilleur score gardé pendant la partie.
## Dessiné par RoboJetScreen (dans le SubViewport de la télé).
##
## Réseau :
## - l'hôte décide qui joue (`request_play`) et tient, synchronisés : le joueur (`player_peer`, `player_name`),
##   la graine des obstacles (`seed_value`), la partie en cours (`running`) et le record (`best_score`,
##   `best_name`). Télé éteinte ou joueur parti : la partie s'arrête.
## - le joueur fait tourner sa partie chez lui (aucun délai entre son clic et le coup de réacteur) et envoie
##   la place du robot à tout le monde (`_stream`, comme un nain envoie sa position) ; les obstacles se
##   déduisent de la graine, donc chacun voit exactement la même partie. À la fin, il envoie son score (`request_end`).

const WIDTH: float = 340.0
const HEIGHT: float = 240.0
## Sol (haut des poutres de mine les plus basses) : le robot s'écrase dessous.
const FLOOR_Y: float = 222.0
const ROBOT_X: float = 80.0
## Rayon de la zone de choc du robot (px).
const ROBOT_RADIUS: float = 13.0
const GRAVITY: float = 820.0
const JET_SPEED: float = -235.0
const SCROLL_SPEED: float = 105.0
## Obstacles : une paire stalactite / poutre tous les SPACING px, ouverture de GAP px, large de OBSTACLE_W px.
const SPACING: float = 165.0
const GAP: float = 92.0
const OBSTACLE_W: float = 34.0
const FIRST_OBSTACLE_X: float = 300.0
## Temps (s) où la partie perdue reste affichée (« Boum ! ») avant le retour au titre.
const CRASH_SHOW_TIME: float = 1.6
## Envois de la place du robot par seconde.
const STREAM_RATE: float = 20.0

signal crashed(score: int)

@export var tv: TvSet

## Autorité : hôte (synchronisés).
var running: bool = false
var player_peer: int = 0
var player_name: String = ""
var seed_value: int = 0
var best_score: int = 0
var best_name: String = ""

## Partie affichée (chez le joueur : sa simulation ; chez les autres : ce qu'il envoie).
var robot_y: float = HEIGHT / 2.0
var robot_vy: float = 0.0
## Distance parcourue (px) : place des obstacles.
var distance: float = 0.0
var score: int = 0
## Temps depuis le dernier coup de réacteur (flamme à l'écran).
var since_jet: float = 10.0
## Temps depuis la dernière partie perdue (« Boum ! »), -1 = aucune.
var since_crash: float = -1.0

var _playing_locally: bool = false
var _stream_timer: float = 0.0


func _physics_process(delta: float) -> void:
	since_jet += delta
	if since_crash >= 0.0:
		since_crash += delta
	if multiplayer.is_server():
		_host_watch()
	var me: int = multiplayer.get_unique_id()
	if running and player_peer == me and not _playing_locally and since_crash < 0.0:
		_start_local()
	if not _playing_locally:
		return
	if not running or player_peer != me:
		_playing_locally = false   # partie arrêtée par l'hôte (télé éteinte…)
		return
	robot_vy += GRAVITY * delta
	robot_y += robot_vy * delta
	distance += SCROLL_SPEED * delta
	score = passed_obstacles()
	if _hits_something():
		_crash()
		return
	_stream_timer -= delta
	if _stream_timer <= 0.0:
		_stream_timer = 1.0 / STREAM_RATE
		_stream.rpc(robot_y, robot_vy, distance)


## Joueur local : clic sur l'écran. Pendant sa partie = coup de réacteur ; sinon, demande à jouer.
func tap() -> void:
	if tv == null or not tv.is_on():
		return
	var me: int = multiplayer.get_unique_id()
	if _playing_locally and player_peer == me:
		robot_vy = JET_SPEED
		since_jet = 0.0
		_jet.rpc()
	elif not running and (since_crash < 0.0 or since_crash > CRASH_SHOW_TIME * 0.5):
		request_play.rpc_id(1)


## Vrai si ce joueur peut lancer une partie (personne ne joue, télé allumée).
func can_start() -> bool:
	return tv != null and tv.is_on() and not running


## Nombre d'obstacles déjà passés.
func passed_obstacles() -> int:
	# L'obstacle i est passé quand son bord droit est derrière le robot.
	var passed: float = (distance + ROBOT_X - ROBOT_RADIUS - FIRST_OBSTACLE_X - OBSTACLE_W) / SPACING
	return maxi(0, ceili(passed))


## Milieu de l'ouverture de l'obstacle `index` (même tirage chez tout le monde grâce à la graine).
func gap_center(index: int) -> float:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(seed_value, index))
	return rng.randf_range(GAP / 2.0 + 26.0, FLOOR_Y - GAP / 2.0 - 18.0)


## Place (x à l'écran) de l'obstacle `index`.
func obstacle_x(index: int) -> float:
	return FIRST_OBSTACLE_X + index * SPACING - distance


## Demande à jouer (hôte) : accepté si la télé est allumée, que personne ne joue et que le nain est assez près
## (debout devant la télé ou sur le canapé).
@rpc("any_peer", "call_local", "reliable")
func request_play() -> void:
	if not multiplayer.is_server() or not can_start():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var dwarf: Dwarf = Dwarf.of_peer(sender)
	if dwarf == null or dwarf.global_position.distance_to(tv.global_position) > 5.5:
		return
	player_peer = sender
	player_name = dwarf.get_display_name()
	seed_value = randi()
	running = true
	_reset_view.rpc()


## Fin de partie (le joueur s'est écrasé) : l'hôte garde le record.
@rpc("any_peer", "call_local", "reliable")
func request_end(final_score: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != player_peer or not running:
		return
	if final_score > best_score:
		best_score = final_score
		best_name = player_name
	running = false
	_show_crash.rpc(final_score)


## Joueur → tout le monde : place du robot (les obstacles se déduisent de `distance`).
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _stream(y: float, vy: float, dist: float) -> void:
	if multiplayer.get_remote_sender_id() != player_peer:
		return
	robot_y = y
	robot_vy = vy
	distance = dist
	score = passed_obstacles()


## Joueur → tout le monde : un coup de réacteur (flamme).
@rpc("any_peer", "call_remote", "unreliable")
func _jet() -> void:
	if multiplayer.get_remote_sender_id() == player_peer:
		since_jet = 0.0


## Hôte → tout le monde : nouvelle partie, le robot repart du début.
@rpc("authority", "call_local", "reliable")
func _reset_view() -> void:
	robot_y = HEIGHT / 2.0
	robot_vy = 0.0
	distance = 0.0
	score = 0
	since_crash = -1.0
	since_jet = 10.0


## Hôte → tout le monde : la partie est perdue (« Boum ! » quelques instants).
@rpc("authority", "call_local", "reliable")
func _show_crash(final_score: int) -> void:
	score = final_score
	since_crash = 0.0
	crashed.emit(final_score)


func _start_local() -> void:
	_playing_locally = true
	robot_y = HEIGHT / 2.0
	robot_vy = JET_SPEED * 0.6
	distance = 0.0
	score = 0
	since_jet = 0.0
	_stream_timer = 0.0


func _crash() -> void:
	_playing_locally = false
	since_crash = 0.0   # pas de nouvelle partie le temps que l'hôte reçoive la fin
	_stream.rpc(robot_y, robot_vy, distance)
	request_end.rpc_id(1, score)


## Le robot touche le sol, le plafond, une stalactite ou une poutre.
func _hits_something() -> bool:
	if robot_y + ROBOT_RADIUS > FLOOR_Y or robot_y - ROBOT_RADIUS < 0.0:
		return true
	var first: int = maxi(0, int(floor((distance + ROBOT_X - ROBOT_RADIUS - FIRST_OBSTACLE_X - OBSTACLE_W) / SPACING)))
	for index: int in range(first, first + 2):
		var x: float = obstacle_x(index)
		if ROBOT_X + ROBOT_RADIUS < x or ROBOT_X - ROBOT_RADIUS > x + OBSTACLE_W:
			continue
		var center: float = gap_center(index)
		if robot_y - ROBOT_RADIUS < center - GAP / 2.0 or robot_y + ROBOT_RADIUS > center + GAP / 2.0:
			return true
	return false


## Hôte : la partie s'arrête si la télé s'éteint ou si le joueur part.
func _host_watch() -> void:
	if running and (tv == null or not tv.is_on() or Dwarf.of_peer(player_peer) == null):
		running = false
		_show_crash.rpc(score)
