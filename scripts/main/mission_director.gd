class_name MissionDirector
extends Node
## Enchaîne le camp (lobby) et les missions (M12).
## - Le niveau courant (`current_level`) est créé par l'hôte dans `level_container`, chez chaque joueur.
## - Hôte : lance une mission (terminal du camp) ou ramène au camp (bouton dans le robot),
##   seulement si tous les nains sont à bord : fondu au noir chez tout le monde, changement de niveau,
##   le robot (et les nains dedans) est replacé au point `MechaStart` du niveau, puis le fondu s'éclaircit.
##
## Réseau : le niveau est créé par l'hôte avec un MultiplayerSpawner (`LevelSpawner`), jamais chargé par
## chaque joueur de son côté : un client a donc toujours le niveau avant de recevoir l'état de ses objets,
## y compris s'il arrive en cours de partie (voir docs/reseau.md). Le fondu passe par un RPC.
## Le robot est replacé par l'hôte (MechaWalker.reset_to), sa place est déjà synchronisée.

signal level_changed(level_id: StringName)

const LOBBY: StringName = &"lobby"
## Niveaux connus : identifiant -> scène. Chaque scène a un Marker3D `MechaStart`
## (et le camp un nœud `PlayerSpawns` avec un Marker3D par joueur).
const LEVELS: Dictionary[StringName, String] = {
	&"lobby": "res://scenes/levels/lobby.tscn",
	&"dev_tutorial": "res://scenes/levels/dev_tutorial.tscn",
	&"test_ground": "res://scenes/levels/test_ground.tscn",
}

## Missions proposées au terminal du camp, dans l'ordre. `id` vide = verrouillée (pas encore faite).
const MISSIONS: Array[Dictionary] = [
	{"id": &"dev_tutorial", "title": "Tuto (dev)"},
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

## Niveau chargé (le même chez tout le monde : c'est l'hôte qui le crée).
var current_level: StringName = &""

var _level: Node3D = null
var _busy: bool = false
var _level_spawner: MultiplayerSpawner


func _ready() -> void:
	add_to_group(&"mission_director")
	NetworkManager.session_ended.connect(_on_session_ended)
	NetworkManager.session_joining.connect(_on_session_joining)
	if return_button != null:
		return_button.set_meta(&"layer", return_button.collision_layer)
		return_button.pressed.connect(func(_peer_id: int) -> void: return_to_lobby())
	_level_spawner = MultiplayerSpawner.new()
	_level_spawner.name = "LevelSpawner"
	add_child(_level_spawner)
	_level_spawner.spawn_path = _level_spawner.get_path_to(level_container)
	_level_spawner.spawn_function = _spawn_level
	# Hors ligne (menu), on est son propre hôte : le camp s'affiche derrière le menu.
	_set_level(LOBBY)


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
	_set_level(level_id)
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


## Hôte : remplace le niveau courant (le spawner le recrée chez tous les clients).
func _set_level(level_id: StringName) -> void:
	if not multiplayer.is_server() or level_container == null or not LEVELS.has(level_id):
		return
	_drop_level()
	_level_spawner.spawn(level_id)


## Exécuté chez chaque peer (hôte compris) avec le même identifiant de niveau.
func _spawn_level(data: Variant) -> Node:
	var level_id: StringName = StringName(data)
	_level = (load(LEVELS[level_id]) as PackedScene).instantiate() as Node3D
	current_level = level_id
	_level.ready.connect(_on_level_ready.bind(level_id), CONNECT_ONE_SHOT)
	return _level


## Retire le niveau tout de suite (son nom est libéré pour le suivant).
func _drop_level() -> void:
	for child: Node in level_container.get_children():
		level_container.remove_child(child)
		child.queue_free()
	_level = null


func _on_level_ready(level_id: StringName) -> void:
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
	_set_level(LOBBY)
	_place_mecha()


func _on_session_joining() -> void:
	# On rejoint une partie : notre camp local disparaît, l'hôte va envoyer le sien.
	_drop_level()
	current_level = &""
