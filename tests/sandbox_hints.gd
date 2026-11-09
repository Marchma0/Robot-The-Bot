extends Node3D
## Bac à sable de l'interface sobre : un nain local dans le ventre vise des commandes.
## Rien de visé = simple point ; une commande visée = le viseur devient un anneau, l'objet s'illumine, et l'icône
## de l'action s'affiche en petit à côté (logo seul, sans touche ; la cible propose « remettre » si des fléchettes traînent) ;
## avec un objet en main, plus de « lancer / poser » à côté du viseur (seul un petit G sur la case de l'inventaire).
## Captures dans build/views/hints_*.png.

const DWARF_SCENE: PackedScene = preload("res://scenes/player/dwarf.tscn")
const POOP_SCENE: PackedScene = preload("res://scenes/props/poop.tscn")

var _dwarf: Dwarf
var _camera: Camera3D

@onready var _mecha: Node3D = $Mecha


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	_dwarf = DWARF_SCENE.instantiate() as Dwarf
	_dwarf.setup(1, 0)
	_mecha.get_node("Players").add_child(_dwarf)
	_dwarf.position = Vector3(0.0, 2.65, 0.6)
	_camera = _dwarf.get_node("%Camera") as Camera3D
	await _wait(1.0)

	_dwarf.rotation.y = PI / 2.0   # vers un mur nu
	await _shot("rien", 0.4)
	TestCheck.expect(not _crosshair().targeting, "rien de visé : simple point")
	TestCheck.expect(_bar_key().is_empty(), "rien de visé : rien d'affiché")

	await _aim("Controls/Rope", "corde")
	TestCheck.expect(_crosshair().targeting, "corde visée : le viseur devient un anneau")
	TestCheck.expect(_bar_key() == "grab:climb", "corde visée : l'icône « grimper » seule, sans touche (%s)" % _bar_key())
	TestCheck.expect(_bar_glyph_count() == 0, "corde visée : pas de dessin de touche pour le clic")
	await _aim("Controls/BeamSwitch_Belly", "interrupteur")
	TestCheck.expect(_crosshair().targeting, "interrupteur visé : anneau")
	await _aim("Controls/Darts", "flechettes")
	TestCheck.expect(_bar_key().ends_with(":dart"), "fléchettes visées : le logo fléchette (%s)" % _bar_key())
	TestCheck.expect(_bar_glyph_count() == 0, "fléchettes visées : le logo seul, sans touche")
	var darts: DartsGame = _mecha.get_node("Controls/Darts") as DartsGame
	darts._land(0, {"point": darts.to_global(Vector3(1.0, -0.5, -0.3)), "dir": Vector3.DOWN, "time": 0.0})
	await _wait(0.3)
	TestCheck.expect(_bar_key().ends_with(":darts_reset"), "une fléchette traîne : la cible propose de les remettre (%s)" % _bar_key())
	await _shot("cible_remettre", 0.1)
	darts._put_on_board(0)

	var poop: Poop = POOP_SCENE.instantiate() as Poop
	_mecha.get_node("Props").add_child(poop)
	poop.holder_slot = 0
	poop.holder_peer_id = 1
	_dwarf.rotation.y = 0.0
	_dwarf.get_node("%Head").rotation.x = 0.0
	await _shot("caca_en_main", 0.6)
	TestCheck.expect(_bar_key().is_empty(), "caca en main : ni « lancer » ni « poser » à côté du viseur (%s)" % _bar_key())
	TestCheck.finish(get_tree())


## Place le nain à un mètre de la commande `path` (côté centre du ventre), tourné vers elle, puis capture.
func _aim(path: String, shot_name: String) -> void:
	var target: Node3D = _mecha.get_node(path) as Node3D
	var local_target: Vector3 = _mecha.to_local(target.global_position)
	var away: Vector3 = Vector3(-local_target.x, 0.0, 0.6 - local_target.z)
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	_dwarf.position = Vector3(local_target.x, 2.65, local_target.z) + away * 1.0
	_dwarf.rotation.y = atan2(away.x, away.z)
	await _wait(0.3)
	var eye: Vector3 = _camera.global_position
	var flat: float = Vector2(target.global_position.x - eye.x, target.global_position.z - eye.z).length()
	_dwarf.get_node("%Head").rotation.x = atan2(target.global_position.y - eye.y, flat)
	await _shot(shot_name, 0.4)


func _bar_key() -> String:
	return _hud().get_node("%HintBar").get("_key")


## Nombre de touches dessinées à côté du viseur (les icônes seules ne comptent pas).
func _bar_glyph_count() -> int:
	return _hud().get_node("%HintBar").find_children("*", "InputGlyph", true, false).filter(
		func(n: Node) -> bool: return not n.is_queued_for_deletion()).size()


func _crosshair() -> Crosshair:
	return _hud().crosshair


func _hud() -> PlayerHud:
	return _dwarf.get("_hud") as PlayerHud


func _shot(shot_name: String, delay: float) -> void:
	await _wait(delay)
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/hints_%s.png" % shot_name)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
