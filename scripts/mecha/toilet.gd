class_name Toilet
extends Seat
## Toilettes : on s'y assoit (E) pour faire caca, en réussissant le mini-jeu « Poussée »
## (PoopMinigame, affiché chez le joueur assis). Réussi : un caca tombe dans la cuvette.
## Une partie sur 20 est légendaire : le caca est doré.
##
## Réseau : l'hôte lance chaque partie (numéro + doré ou non, tiré par l'hôte) chez le
## joueur assis, qui joue localement puis renvoie son résultat. L'hôte vérifie que c'est
## bien l'occupant, la bonne partie et une durée plausible, puis fait apparaître le caca
## dans `props_root` (un MultiplayerSpawner le crée chez tout le monde).

const POOP_SCENE: PackedScene = preload("res://scenes/props/poop.tscn")
## Chance qu'une partie soit légendaire (caca doré).
const GOLD_CHANCE: float = 0.05
## Durée minimale d'une partie (s) : en dessous, le résultat est refusé.
const MIN_ROUND_TIME: float = 2.0
## Pause entre deux parties tant qu'on reste assis (s).
const ROUND_PAUSE: float = 1.6
## Nombre max de cacas ordinaires dans le mécha en même temps.
const MAX_POOPS: int = 6

## Nœud (dans le mécha) où les cacas apparaissent, surveillé par un MultiplayerSpawner.
@export var props_root: Node3D

## Côté joueur assis : dernière partie reçue de l'hôte (numéro, doré).
var local_round_id: int = 0
var local_round_golden: bool = false

var _round_id: int = 0
var _round_golden: bool = false
var _round_active: bool = false
var _round_time: float = 0.0
var _pause: float = 0.0
var _last_occupant: int = 0

@onready var _bowl_point: Marker3D = %BowlPoint


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if occupant_peer_id != _last_occupant:
		_last_occupant = occupant_peer_id
		_round_active = false
		_pause = 0.6
	if occupant_peer_id == 0:
		return
	if _round_active:
		_round_time += delta
	else:
		_pause -= delta
		if _pause <= 0.0:
			_round_id += 1
			_round_golden = randf() < GOLD_CHANCE
			_round_active = true
			_round_time = 0.0
			start_round.rpc_id(occupant_peer_id, _round_id, _round_golden)


func get_hints() -> Array[InputHint]:
	if is_seated_locally():
		return [InputHint.make(&"interact", &"stand_up")]
	if occupant_peer_id != 0:
		return [InputHint.state(&"locked")]
	return [InputHint.make(&"interact", &"toilet")]


## Hôte -> joueur assis : une nouvelle partie commence.
@rpc("authority", "call_local", "reliable")
func start_round(round_id: int, golden: bool) -> void:
	local_round_id = round_id
	local_round_golden = golden


## Joueur assis -> hôte : résultat de la partie.
@rpc("any_peer", "call_local", "reliable")
func submit_result(round_id: int, success: bool) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != occupant_peer_id or round_id != _round_id or not _round_active:
		return
	if success and _round_time < MIN_ROUND_TIME:
		success = false   # réussite impossible aussi vite : refusée (un échec rapide, lui, est normal)
	_round_active = false
	_pause = ROUND_PAUSE
	if success:
		_drop_poop(_round_golden)


func _drop_poop(golden: bool = false) -> void:
	if props_root == null:
		return
	if not golden and _count_ordinary_poops() >= MAX_POOPS:
		return
	var poop: Poop = POOP_SCENE.instantiate()
	poop.golden = golden
	props_root.add_child(poop, true)
	poop.global_position = _bowl_point.global_position


func _count_ordinary_poops() -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"poops"):
		if not (node as Poop).golden:
			count += 1
	return count
