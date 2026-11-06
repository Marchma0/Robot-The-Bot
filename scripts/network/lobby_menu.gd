extends CanvasLayer
## Menu : héberger / rejoindre, via Steam (lobby d'amis, à distance) ou en local / VPN (adresse IP).
## Le panneau se cache pendant une partie ; un bandeau rappelle alors le code du lobby Steam.
## En partie : "pause" (Échap / Start) = quitter (temporaire), "invite_friends" (F2 / Select) = inviter.

@onready var _center: Control = $Center
@onready var _steam_status_label: Label = %SteamStatusLabel
@onready var _steam_host_button: Button = %SteamHostButton
@onready var _steam_code_edit: LineEdit = %SteamCodeEdit
@onready var _steam_join_button: Button = %SteamJoinButton
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _address_edit: LineEdit = %AddressEdit
@onready var _status_label: Label = %StatusLabel
@onready var _session_info: Control = %SessionInfo
@onready var _lobby_code_label: Label = %LobbyCodeLabel
@onready var _session_hints: HintBar = %SessionHints


func _ready() -> void:
	_steam_host_button.pressed.connect(_on_steam_host_pressed)
	_steam_join_button.pressed.connect(_on_steam_join_pressed)
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	NetworkManager.session_started.connect(_on_session_started)
	NetworkManager.session_ended.connect(_on_session_ended)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.steam_lobby_created.connect(_on_steam_lobby_created)
	_steam_status_label.text = NetworkManager.get_steam_status()
	_show_menu("")


func _unhandled_input(event: InputEvent) -> void:
	if not NetworkManager.is_online():
		return
	if event.is_action_pressed("pause"):
		NetworkManager.leave_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("invite_friends"):
		NetworkManager.invite_friends()
		get_viewport().set_input_as_handled()


func _on_steam_host_pressed() -> void:
	_set_buttons_disabled(true)
	_status_label.text = "Création du lobby Steam..."
	NetworkManager.host_game_steam()


func _on_steam_join_pressed() -> void:
	_set_buttons_disabled(true)
	_status_label.text = "Connexion au lobby Steam..."
	NetworkManager.join_game_steam(_steam_code_edit.text)


func _on_host_pressed() -> void:
	var err: Error = NetworkManager.host_game()
	if err != OK:
		_status_label.text = "Impossible d'héberger (%s)." % error_string(err)


func _on_join_pressed() -> void:
	var address: String = _address_edit.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	var err: Error = NetworkManager.join_game(address)
	if err != OK:
		_status_label.text = "Impossible de rejoindre (%s)." % error_string(err)
		return
	_set_buttons_disabled(true)
	_status_label.text = "Connexion à %s..." % address


func _on_session_started() -> void:
	var role: String = "hôte" if multiplayer.is_server() else "client %d" % multiplayer.get_unique_id()
	get_window().title = "mecha-nains — %s" % role
	_center.visible = false
	if NetworkManager.is_steam_session() and not multiplayer.is_server():
		_lobby_code_label.visible = false
		_session_hints.show_hints([InputHint.make(&"pause", &"exit")])
		_session_info.visible = true


func _on_steam_lobby_created(code: String) -> void:
	get_window().title = "mecha-nains — hôte Steam (code %s)" % code
	# Le code reste écrit (il faut pouvoir le donner) ; il est aussi copié dans le presse-papiers.
	_lobby_code_label.text = code
	_lobby_code_label.visible = true
	_session_hints.show_hints([InputHint.make(&"invite_friends", &"invite"), InputHint.make(&"pause", &"exit")])
	_session_info.visible = true


func _on_session_ended(reason: String) -> void:
	_show_menu(reason)


func _on_connection_failed(reason: String) -> void:
	_show_menu(reason)


func _show_menu(status: String) -> void:
	get_window().title = "mecha-nains"
	_center.visible = true
	_session_info.visible = false
	_set_buttons_disabled(false)
	_status_label.text = status


func _set_buttons_disabled(disabled: bool) -> void:
	var steam_ok: bool = NetworkManager.is_steam_available()
	_steam_host_button.disabled = disabled or not steam_ok
	_steam_join_button.disabled = disabled or not steam_ok
	_steam_code_edit.editable = steam_ok
	_host_button.disabled = disabled
	_join_button.disabled = disabled
