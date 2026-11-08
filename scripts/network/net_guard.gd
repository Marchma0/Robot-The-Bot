class_name NetGuard
extends Node
## Garde-fous réseau, actifs dans toutes les parties (enfant de NetworkManager) :
## - Touche `net_audit` (F9), chez n'importe quel joueur : l'hôte envoie sa photo du monde
##   (`NetAudit.snapshot`) à tous les clients, chacun la compare à ce qu'il voit et le résultat
##   s'affiche chez tout le monde (détail des écarts dans la console). Marche aussi en Steam.
## - Chez l'hôte : erreur dans la console si un objet réseau (nœud avec un MultiplayerSynchronizer)
##   est créé en jeu hors d'un MultiplayerSpawner. Les clients ne le verraient jamais.
## Le monde comparé est le nœud du groupe `net_world` (World dans main.tscn).

const SHOW_TIME: float = 6.0

var _label: Label
var _hide_timer: float = 0.0


func _ready() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16.0, 16.0)
	_label.add_theme_font_size_override(&"font_size", 20)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	_label.visible = false
	layer.add_child(_label)
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	if _hide_timer > 0.0:
		_hide_timer -= delta
		if _hide_timer <= 0.0:
			_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"net_audit") and NetworkManager.is_online():
		_request_audit.rpc_id(1)
		get_viewport().set_input_as_handled()


## N'importe quel joueur -> hôte : lance la comparaison chez tous les clients.
@rpc("any_peer", "call_local", "reliable")
func _request_audit() -> void:
	if not multiplayer.is_server():
		return
	var world: Node = get_tree().get_first_node_in_group(&"net_world")
	if world == null:
		return
	if multiplayer.get_peers().is_empty():
		_show("Synchro : aucun client à comparer")
		return
	_show("Synchro : comparaison en cours…")
	_compare.rpc(NetAudit.snapshot(world))


## Hôte -> clients : chacun compare la photo de l'hôte à la sienne.
@rpc("authority", "reliable")
func _compare(host_state: Dictionary) -> void:
	var world: Node = get_tree().get_first_node_in_group(&"net_world")
	if world == null:
		return
	var diffs: PackedStringArray = NetAudit.diff(host_state, NetAudit.snapshot(world))
	_print_diffs("Synchro (moi, joueur %d)" % multiplayer.get_unique_id(), diffs)
	_report.rpc_id(1, diffs)


## Client -> hôte : résultat de la comparaison.
@rpc("any_peer", "reliable")
func _report(diffs: PackedStringArray) -> void:
	if multiplayer.is_server():
		_print_diffs("Synchro (joueur %d)" % multiplayer.get_remote_sender_id(), diffs)


func _print_diffs(title: String, diffs: PackedStringArray) -> void:
	if diffs.is_empty():
		print("%s : OK, identique à l'hôte" % title)
		_show("%s : OK" % title)
		return
	print("%s : %d écart(s) avec l'hôte" % [title, diffs.size()])
	for line: String in diffs:
		print("    " + line)
	_show("%s : %d écart(s), voir la console" % [title, diffs.size()])


func _show(text: String) -> void:
	_label.text = text
	_label.visible = true
	_hide_timer = SHOW_TIME


## Hôte : un objet réseau créé en jeu doit passer par un MultiplayerSpawner.
## Un nœud posé dans une scène a un `owner` : seul le premier nœud d'une scène créée en jeu n'en a pas.
func _on_node_added(node: Node) -> void:
	if node.owner != null or not NetworkManager.is_online() or not multiplayer.is_server():
		return
	if not _has_synchronizer(node) or _is_spawned(node):
		return
	push_error("Réseau : « %s » est créé hors d'un MultiplayerSpawner, les clients ne le verront pas " % node.get_path()
		+ "(ajouter sa scène à un spawner, voir docs/reseau.md).")


func _has_synchronizer(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is MultiplayerSynchronizer:
			return true
	return false


func _is_spawned(node: Node) -> bool:
	var parent: Node = node.get_parent()
	for spawner: Node in get_tree().root.find_children("*", "MultiplayerSpawner", true, false):
		var s: MultiplayerSpawner = spawner as MultiplayerSpawner
		if s.get_node_or_null(s.spawn_path) != parent:
			continue
		if s.spawn_function.is_valid():
			return true
		for i: int in s.get_spawnable_scene_count():
			if s.get_spawnable_scene(i) == node.scene_file_path:
				return true
	return false
