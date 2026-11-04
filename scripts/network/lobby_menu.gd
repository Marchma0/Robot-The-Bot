extends CanvasLayer
## Menu minimal : héberger / rejoindre. Se cache pendant une partie.
## "pause" (Échap / Start) en partie = quitter la partie (temporaire, pour les tests).

@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _address_edit: LineEdit = %AddressEdit
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	NetworkManager.session_started.connect(_on_session_started)
	NetworkManager.session_ended.connect(_on_session_ended)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	_show_menu("")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and NetworkManager.is_online():
		NetworkManager.leave_game()
		get_viewport().set_input_as_handled()


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
	visible = false


func _on_session_ended(reason: String) -> void:
	_show_menu(reason)


func _on_connection_failed() -> void:
	_show_menu("Connexion impossible (hôte introuvable ou partie pleine).")


func _show_menu(status: String) -> void:
	get_window().title = "mecha-nains"
	visible = true
	_set_buttons_disabled(false)
	_status_label.text = status


func _set_buttons_disabled(disabled: bool) -> void:
	_host_button.disabled = disabled
	_join_button.disabled = disabled
