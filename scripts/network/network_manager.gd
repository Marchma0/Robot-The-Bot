extends Node
## Autoload "NetworkManager".
## Seul endroit qui crée le peer réseau (ENet en dev, Steam plus tard).
## Le reste du jeu n'utilise que ces signaux et méthodes, jamais le peer directement.

## Un joueur (y compris l'hôte lui-même, id 1) a rejoint la partie. Émis sur tous les peers.
signal player_joined(peer_id: int)
## Un joueur a quitté la partie. Émis sur tous les peers.
signal player_left(peer_id: int)
## La partie a démarré localement (on héberge, ou on est connecté à l'hôte).
signal session_started
## La partie est terminée localement (on est parti, ou l'hôte a fermé).
signal session_ended(reason: String)
## La tentative de connexion a échoué (hôte introuvable ou partie pleine).
signal connection_failed

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game(port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	# L'hôte compte pour un joueur : on accepte MAX_PLAYERS - 1 clients.
	var err: Error = peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	session_started.emit()
	player_joined.emit(multiplayer.get_unique_id())
	return OK


func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave_game() -> void:
	if not is_online():
		return
	_reset_peer()
	session_ended.emit("Partie quittée.")


func is_online() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func _reset_peer() -> void:
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _on_peer_connected(peer_id: int) -> void:
	player_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	player_left.emit(peer_id)


func _on_connected_to_server() -> void:
	session_started.emit()
	player_joined.emit(multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	_reset_peer()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	_reset_peer()
	session_ended.emit("L'hôte a fermé la partie.")
