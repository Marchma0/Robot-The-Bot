class_name NetDebug
extends CanvasLayer
## Panneau de diagnostic réseau (touche F9, action « debug_network ») : ce que ce joueur reçoit vraiment.
## Pour chaque objet synchronisé (robot, pieds, nains) : nombre d'états reçus et âge du dernier.
## Un objet qui ne reçoit rien reste figé chez ce joueur. Le résumé est aussi écrit dans la sortie
## toutes les 5 s pendant une partie en ligne (visible dans le panneau Sortie de Godot).

const REFRESH: float = 0.25
const LOG_EVERY: float = 5.0

var _refresh: float = 0.0
var _log: float = LOG_EVERY

@onready var _label: Label = %Label


func _ready() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_network"):
		visible = not visible


func _process(delta: float) -> void:
	_refresh -= delta
	_log -= delta
	var online: bool = NetworkManager.is_online()
	if (visible and _refresh <= 0.0) or (online and _log <= 0.0):
		var text: String = _report()
		if visible:
			_label.text = text
		if online and _log <= 0.0:
			print("[diagnostic réseau]\n", text)
			_log = LOG_EVERY
		_refresh = REFRESH


func _report() -> String:
	var lines: PackedStringArray = []
	var me: int = multiplayer.get_unique_id()
	var kind: String = "Steam" if NetworkManager.is_steam_session() else ("ENet" if NetworkManager.is_online() else "hors ligne")
	lines.append("Réseau %s — moi : %d (%s) — autres : %s" % [
		kind, me, "hôte" if multiplayer.is_server() else "client", str(multiplayer.get_peers())])
	var mecha: Node3D = get_tree().root.find_child("Mecha", true, false) as Node3D
	if mecha != null:
		lines.append(_smoother_line("Robot", mecha.get_node_or_null("NetSmoother") as NetSmoother, mecha.global_position))
		var walker: MechaWalker = mecha.get_node_or_null("Walker") as MechaWalker
		if walker != null:
			lines.append(_smoother_line("Pied G", walker.get_node_or_null("FootL/NetSmoother") as NetSmoother,
				walker.get_foot_transform(0).origin))
			lines.append(_smoother_line("Pied D", walker.get_node_or_null("FootR/NetSmoother") as NetSmoother,
				walker.get_foot_transform(1).origin))
			lines.append("Marche : phase %s, jauge d'erreur %.2f, pieds en l'air G=%s D=%s" % [
				MechaWalker.Phase.keys()[walker.phase], walker.error_gauge,
				str(walker.swinging_left), str(walker.swinging_right)])
		for path: String in ["Controls/LegL_Stick", "Controls/LegR_Stick"]:
			var stick: Lever = mecha.get_node_or_null(path) as Lever
			if stick != null:
				lines.append("%s : tenu par %d, valeur (%.2f, %.2f)" % [
					path.get_file(), stick.holder_peer_id, stick.value.x, stick.value.y])
	for node: Node in get_tree().get_nodes_in_group(&"dwarves"):
		var dwarf: Node3D = node as Node3D
		lines.append(_smoother_line("Nain %s" % dwarf.name, dwarf.get_node_or_null("NetSmoother") as NetSmoother,
			dwarf.global_position))
	return "\n".join(lines)


func _smoother_line(label: String, smoother: NetSmoother, position: Vector3) -> String:
	if smoother == null:
		return "%s : (introuvable)" % label
	var where: String = "(%.1f, %.1f, %.1f)" % [position.x, position.y, position.z]
	if smoother.is_multiplayer_authority():
		return "%s : c'est moi qui l'envoie %s" % [label, where]
	if smoother.received_count == 0:
		return "%s : RIEN REÇU %s" % [label, where]
	var age: float = (Time.get_ticks_msec() - smoother.last_received_msec) / 1000.0
	return "%s : %d états reçus, dernier il y a %.2f s %s" % [label, smoother.received_count, age, where]
