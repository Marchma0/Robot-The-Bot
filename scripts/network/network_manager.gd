extends Node
## Autoload "NetworkManager".
## Seul endroit qui crée le peer réseau : ENet (tests en local / réseau local) ou Steam
## (via SteamBackend, lobby + invitations). Le reste du jeu n'utilise que ces signaux et
## méthodes, jamais le peer ni Steam directement.

## Un joueur (y compris l'hôte lui-même, id 1) a rejoint la partie. Émis sur tous les peers.
signal player_joined(peer_id: int)
## Un joueur a quitté la partie. Émis sur tous les peers.
signal player_left(peer_id: int)
## La partie a démarré localement (on héberge, ou on est connecté à l'hôte).
signal session_started
## La partie est terminée localement (on est parti, ou l'hôte a fermé).
signal session_ended(reason: String)
## La tentative de connexion a échoué (hôte introuvable, partie pleine, erreur Steam…).
signal connection_failed(reason: String)
## Partie Steam hébergée : code du lobby à donner aux amis (déjà copié dans le presse-papiers).
signal steam_lobby_created(code: String)

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4

var _steam: SteamBackend


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_steam = SteamBackend.new()
	_steam.name = "Steam"
	_steam.host_ready.connect(_on_steam_host_ready)
	_steam.client_ready.connect(_on_steam_client_ready)
	_steam.failed.connect(_on_steam_failed)
	add_child(_steam)


# --- ENet (local / réseau local / VPN) ---

func host_game(port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	# L'hôte compte pour un joueur : on accepte MAX_PLAYERS - 1 clients.
	var err: Error = peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	_start_hosting(peer)
	return OK


func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


# --- Steam (lobby, invitations) ---

func is_steam_available() -> bool:
	return _steam.available


## Texte lisible sur l'état de Steam (pour le menu).
func get_steam_status() -> String:
	return _steam.status_text


## Pseudo du joueur local à afficher au-dessus de son nain : pseudo Steam si disponible,
## sinon "" (le nain affiche alors "Joueur N").
func get_local_player_name() -> String:
	return _steam.persona_name


## Asynchrone : steam_lobby_created + session_started en cas de succès, connection_failed sinon.
func host_game_steam() -> void:
	_steam.host()


## Asynchrone : session_started en cas de succès, connection_failed sinon.
func join_game_steam(lobby_code: String) -> void:
	_steam.join(lobby_code)


func invite_friends() -> void:
	_steam.invite_friends()


func is_steam_session() -> bool:
	return _steam.lobby_id != 0


# --- Commun ---

func leave_game() -> void:
	if not is_online():
		return
	_reset_peer()
	session_ended.emit("Partie quittée.")


func is_online() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func _start_hosting(peer: MultiplayerPeer) -> void:
	multiplayer.multiplayer_peer = peer
	session_started.emit()
	player_joined.emit(multiplayer.get_unique_id())


func _reset_peer() -> void:
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_steam.leave()


func _on_peer_connected(peer_id: int) -> void:
	# Partie pleine : l'hôte refuse les joueurs en trop (Steam ne bloque pas côté réseau).
	if multiplayer.is_server() and multiplayer.get_peers().size() > MAX_PLAYERS - 1:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	player_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	player_left.emit(peer_id)


func _on_connected_to_server() -> void:
	session_started.emit()
	player_joined.emit(multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	_reset_peer()
	connection_failed.emit("Connexion impossible (hôte introuvable ou partie pleine).")


func _on_server_disconnected() -> void:
	_reset_peer()
	session_ended.emit("L'hôte a fermé la partie.")


func _on_steam_host_ready(peer: MultiplayerPeer, lobby_id: int) -> void:
	_start_hosting(peer)
	var code: String = str(lobby_id)
	DisplayServer.clipboard_set(code)
	steam_lobby_created.emit(code)


func _on_steam_client_ready(peer: MultiplayerPeer) -> void:
	# La suite (session_started) arrive par multiplayer.connected_to_server, comme en ENet.
	multiplayer.multiplayer_peer = peer


func _on_steam_failed(reason: String) -> void:
	if is_online():
		_reset_peer()
	connection_failed.emit(reason)
