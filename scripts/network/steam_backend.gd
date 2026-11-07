class_name SteamBackend
extends Node
## Tout ce qui touche à Steam (GodotSteam) est ici, et n'est utilisé que par NetworkManager.
## Accès dynamique au singleton "Steam" et à la classe "SteamMultiplayerPeer" : le projet
## reste valide (et jouable en ENet) même si l'addon GodotSteam ou le client Steam est absent.
##
## Flux :
##   héberger : createLobby (amis, 4 places) -> lobby_created -> SteamMultiplayerPeer.create_host
##   rejoindre : joinLobby (code ou invitation Steam) -> lobby_joined -> create_client(propriétaire)

## Le lobby est créé : NetworkManager installe ce peer en tant qu'hôte.
signal host_ready(peer: MultiplayerPeer, lobby_id: int)
## Le lobby est rejoint : NetworkManager installe ce peer en tant que client.
signal client_ready(peer: MultiplayerPeer)
signal failed(reason: String)

## App ID de test de Valve ("Spacewar"), à remplacer par le vrai App ID du jeu.
const APP_ID: int = 480
const MAX_MEMBERS: int = 4
const LOBBY_TYPE_FRIENDS_ONLY: int = 1
const LOBBY_CREATED_OK: int = 1
const ENTER_RESPONSE_SUCCESS: int = 1
const VIRTUAL_PORT: int = 0

## Vrai si Steam est initialisé et utilisable.
var available: bool = false
## Explication lisible de l'état de Steam (affichée dans le menu).
var status_text: String = ""
## Pseudo Steam du joueur local ("" si Steam indisponible).
var persona_name: String = ""
var lobby_id: int = 0

var _steam: Object = null


func _ready() -> void:
	if not Engine.has_singleton("Steam") or not ClassDB.class_exists("SteamMultiplayerPeer"):
		status_text = "Steam indisponible (addon GodotSteam absent)"
		return
	_steam = Engine.get_singleton("Steam")
	# Normalement déjà initialisé au lancement par GodotSteam (section [steam] de project.godot) :
	# il faut que ce soit fait avant la création de la fenêtre, sinon l'overlay Steam ne
	# s'accroche pas au jeu (pas d'invitation F2). Ici : seulement si ça n'a pas été fait.
	if int(_steam.call("getSteamID")) == 0:
		var result: Dictionary = _steam.call("steamInitEx", APP_ID, true)
		if int(result.get("status", 1)) != 0:
			status_text = "Steam indisponible : lance le client Steam puis relance le jeu"
			push_warning("Steam : %s" % result.get("verbal", "échec de l'initialisation"))
			return
	available = true
	persona_name = _steam.call("getPersonaName")
	status_text = "Steam : connecté en tant que %s" % persona_name
	_steam.connect("lobby_created", _on_lobby_created)
	_steam.connect("lobby_joined", _on_lobby_joined)
	_steam.connect("join_requested", _on_join_requested)
	_join_from_command_line()


func host() -> void:
	if not available:
		failed.emit(status_text)
		return
	_steam.call("createLobby", LOBBY_TYPE_FRIENDS_ONLY, MAX_MEMBERS)


## Rejoint un lobby à partir de son code (l'identifiant numérique du lobby).
func join(code: String) -> void:
	if not available:
		failed.emit(status_text)
		return
	var id: int = code.strip_edges().to_int()
	if id <= 0:
		failed.emit("Code de lobby invalide")
		return
	_steam.call("joinLobby", id)


## Ouvre la fenêtre d'invitation d'amis de l'overlay Steam.
## Sans overlay (désactivé dans Steam) : ouvre la liste d'amis du client Steam, où
## clic droit sur un ami → « Inviter à jouer » marche aussi (on est dans le lobby).
func invite_friends() -> void:
	if not available or lobby_id == 0:
		return
	if _steam.call("isOverlayEnabled"):
		_steam.call("activateGameOverlayInviteDialog", lobby_id)
	else:
		push_warning("Steam : overlay indisponible, ouverture de la liste d'amis")
		OS.shell_open("steam://open/friends")


func leave() -> void:
	if available and lobby_id != 0:
		_steam.call("leaveLobby", lobby_id)
		_steam.call("clearRichPresence")
	lobby_id = 0


func _on_lobby_created(result: int, new_lobby_id: int) -> void:
	if result != LOBBY_CREATED_OK:
		failed.emit("Création du lobby Steam impossible (code %d)" % result)
		return
	lobby_id = new_lobby_id
	_steam.call("setLobbyJoinable", lobby_id, true)
	_steam.call("setLobbyData", lobby_id, "name", "Mécha de %s" % _steam.call("getPersonaName"))
	# Permet aux amis de rejoindre depuis la liste d'amis Steam ("Rejoindre la partie").
	_steam.call("setRichPresence", "connect", "+connect_lobby %d" % lobby_id)
	var peer: MultiplayerPeer = _new_peer()
	var err: Error = peer.call("create_host", VIRTUAL_PORT)
	if err != OK:
		failed.emit("Hôte Steam impossible (%s)" % error_string(err))
		leave()
		return
	host_ready.emit(peer, lobby_id)


func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != ENTER_RESPONSE_SUCCESS:
		failed.emit("Impossible de rejoindre le lobby (code %d)" % response)
		return
	var owner_id: int = _steam.call("getLobbyOwner", joined_lobby_id)
	if owner_id == _steam.call("getSteamID"):
		return   # l'hôte reçoit aussi cet événement pour son propre lobby
	lobby_id = joined_lobby_id
	var peer: MultiplayerPeer = _new_peer()
	var err: Error = peer.call("create_client", owner_id, VIRTUAL_PORT)
	if err != OK:
		failed.emit("Connexion Steam impossible (%s)" % error_string(err))
		leave()
		return
	client_ready.emit(peer)


## En Steam, chaque client n'est connecté qu'à l'hôte : le relais doit être activé pour que
## l'hôte retransmette aux autres clients ce qu'un client envoie (ex. la position de son nain).
## Désactivé par défaut dans SteamMultiplayerPeer : sans lui, les clients ne se voient pas bouger.
func _new_peer() -> MultiplayerPeer:
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	peer.call("set_server_relay", true)
	return peer


## Un ami a accepté une invitation ou cliqué "Rejoindre la partie" pendant que le jeu tourne.
func _on_join_requested(requested_lobby_id: int, _friend_id: int) -> void:
	_steam.call("joinLobby", requested_lobby_id)


## Jeu lancé par Steam depuis une invitation : "+connect_lobby <id>" sur la ligne de commande.
func _join_from_command_line() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	var index: int = args.find("+connect_lobby")
	if index >= 0 and index + 1 < args.size():
		join(args[index + 1])
