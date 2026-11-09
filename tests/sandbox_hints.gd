extends Node3D
## Bac à sable de l'interface minimaliste : un nain local dans le ventre vise des commandes.
## Les gestes évidents (clic pour utiliser, souris pour viser) ne s'affichent jamais ; une touche moins évidente
## (E pour prendre les fléchettes) s'affiche en petit à droite du point de visée ; avec un objet en main, plus de
## « lancer / poser » à côté du viseur (seul un petit G sur la case de l'inventaire).
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

	await _aim("Controls/Rope", "corde")
	TestCheck.expect(_bar_key().is_empty(), "corde visée : rien d'affiché (clic évident)")
	await _aim("Controls/BeamSwitch_Belly", "interrupteur")
	TestCheck.expect(_bar_key().is_empty(), "interrupteur visé : rien d'affiché (clic évident)")
	await _aim("Controls/Darts", "flechettes")
	TestCheck.expect(_bar_key().contains("interact"), "fléchettes visées : la touche E s'affiche (%s)" % _bar_key())

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
	return (_dwarf.get("_hud") as PlayerHud).get_node("%HintBar").get("_key")


func _shot(shot_name: String, delay: float) -> void:
	await _wait(delay)
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/hints_%s.png" % shot_name)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
