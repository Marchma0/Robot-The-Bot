class_name MissionDirector
extends Node
## Enchaîne le camp (lobby) et les missions (M12).
## - Charge le niveau courant (`current_level`) dans `level_container`, chez chaque joueur.
## - Hôte : lance une mission (terminal du camp) ou ramène au camp (bouton dans le robot),
##   seulement si tous les nains sont à bord : fondu au noir chez tout le monde, changement de niveau,
##   le robot (et les nains dedans) est replacé au point `MechaStart` du niveau, puis le fondu s'éclaircit.
##
## Réseau : l'hôte est autoritaire sur `current_level` (répliqué, aussi pour ceux qui arrivent en cours
## de partie) ; chaque peer charge lui-même la scène du niveau. Le fondu passe par un RPC.
## Le robot est replacé par l'hôte (MechaWalker.reset_to), sa place est déjà synchronisée.

signal level_changed(level_id: StringName)

const LOBBY: StringName = &"lobby"
## Niveaux connus : identifiant -> scène. Chaque scène a un Marker3D `MechaStart`
## (et le camp un nœud `PlayerSpawns` avec un Marker3D par joueur).
const LEVELS: Dictionary[StringName, String] = {
	&"lobby": "res://scenes/levels/lobby.tscn",
	&"test_ground": "res://scenes/levels/test_ground.tscn",
}

## Missions proposées au terminal du camp, dans l'ordre. `id` vide = verrouillée (pas encore faite).
const MISSIONS: Array[Dictionary] = [
	{"id": &"test_ground", "title": "Terrain d'essai"},
	{"id": &"", "title": "Mission 1"},
	{"id": &"", "title": "Mission 2"},
]

@export var level_container: Node3D
@export var mecha: Node3D
@export var walker: MechaWalker
@export var fader: ScreenFader
## Bouton « retour au camp » dans le robot : n'apparaît qu'en mission.
@export var return_button: PushButton

## Niveau chargé. Autorité : hôte (synchronisé).
var current_level: StringName = &"":
	set(value):
		if value == current_level:
			return
		current_level = value
		if is_node_ready():
			_load_level(value)

var _level: Node3D = null
var _busy: bool = false


func _ready() -> void:
	add_to_group(&"mission_director")
	NetworkManager.session_ended.connect(_on_session_ended)
	if return_button != null:
		return_button.set_meta(&"layer", return_button.collision_layer)
		return_button.pressed.connect(func(_peer_id: int) -> void: return_to_lobby())
	if current_level == &"":
		current_level = LOBBY
	if _level == null:
		_load_level(current_level)


## Vrai au camp.
func in_lobby() -> bool:
	return current_level == LOBBY


## Le niveau chargé (pour y trouver des points d'apparition).
func get_level() -> Node3D:
	return _level


## Nombre de nains à bord du robot, et nombre total (calculé localement : les places sont synchronisées).
func count_aboard() -> Vector2i:
	var total: int = 0
	var aboard: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"dwarves"):
		var dwarf: Node3D = node as Node3D
		total += 1
		if _is_aboard(dwarf.global_position + dwarf.global_basis.y * 0.6):
			aboard += 1
	return Vector2i(aboard, total)


## Tout le monde à bord (et au moins un joueur) : on peut partir.
func everyone_aboard() -> bool:
	var count: Vector2i = count_aboard()
	return count.y > 0 and count.x == count.y


## Hôte : lance la mission `level_id` (terminal). Refusé si quelqu'un n'est pas à bord.
func start_mission(level_id: StringName) -> bool:
	if not multiplayer.is_server() or _busy or not in_lobby() or not LEVELS.has(level_id):
		return false
	if not everyone_aboard():
		return false
	_travel(level_id)
	return true


## Hôte : ramène tout le monde au camp (bouton dans le robot). Refusé si quelqu'un n'est pas à bord.
func return_to_lobby() -> bool:
	if not multiplayer.is_server() or _busy or in_lobby() or not everyone_aboard():
		return false
	_travel(LOBBY)
	return true


@rpc("authority", "call_local", "reliable")
func _fade(to_black: bool) -> void:
	if fader != null:
		fader.fade(to_black)


func _travel(level_id: StringName) -> void:
	_busy = true
	_fade.rpc(true)
	await get_tree().create_timer(ScreenFader.FADE_TIME + 0.1).timeout
	current_level = level_id
	await _place_mecha()
	await get_tree().create_timer(0.3).timeout
	_fade.rpc(false)
	_busy = false


## Replace le robot au point de départ du niveau (hôte).
func _place_mecha() -> void:
	if walker == null or _level == null:
		return
	var start: Node3D = _level.get_node_or_null("MechaStart") as Node3D
	var xform: Transform3D = start.global_transform if start != null else Transform3D.IDENTITY
	await walker.reset_to(xform)


func _load_level(level_id: StringName) -> void:
	if _level != null:
		_level.queue_free()
		_level = null
	var path: String = LEVELS.get(level_id, "")
	if path.is_empty() or level_container == null:
		return
	_level = (load(path) as PackedScene).instantiate() as Node3D
	level_container.add_child(_level)
	if return_button != null:
		# Au camp, pas de bouton de retour : on le cache et on ne peut plus le viser.
		return_button.visible = level_id != LOBBY
		return_button.collision_layer = return_button.get_meta(&"layer", return_button.collision_layer) \
			if level_id != LOBBY else 0
	level_changed.emit(level_id)


func _is_aboard(point: Vector3) -> bool:
	for volume: Node in get_tree().get_nodes_in_group(&"mecha_interiors"):
		if (volume as InteriorVolume).contains(point):
			return true
	return false


func _on_session_ended(_reason: String) -> void:
	# Hors ligne : retour au camp, robot à sa place (chacun pour soi).
	_busy = false
	if fader != null:
		fader.fade(false)
	current_level = LOBBY
	_place_mecha()
