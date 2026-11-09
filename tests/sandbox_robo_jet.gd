extends Node3D
## Bac à sable du jeu de la télé (Robo-Jet), on est l'hôte, sans réseau. Un nain devant la télé ; un pilote
## automatique clique au bon moment pour passer des obstacles, puis lâche : le robot s'écrase, le record est
## gardé ; une partie s'arrête quand on éteint la télé. Images dans build/views/robo_jet_<nom>.png.

const DWARF_SCENE: PackedScene = preload("res://scenes/player/dwarf.tscn")

var _autopilot: bool = false

@onready var _mecha: Node3D = $Mecha
@onready var _tv: TvSet = $Mecha/InteriorBelly/TvSet
@onready var _game: RoboJetGame = $Mecha/InteriorBelly/TvSet/RoboJet
@onready var _camera: Camera3D = $Camera


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	var dwarf: Dwarf = DWARF_SCENE.instantiate() as Dwarf
	dwarf.setup(1, 0)
	_mecha.get_node("Players").add_child(dwarf)
	dwarf.global_position = _tv.to_global(Vector3(0.0, -1.0, -1.4))
	await _wait(1.0)
	_place_camera()
	await _shot("0_titre")
	TestCheck.expect(_tv.is_on() and not _game.running, "télé allumée : écran titre, personne ne joue")

	_game.tap()
	await _wait(0.2)
	TestCheck.expect(_game.running and _game.player_peer == 1, "clic sur l'écran : la partie commence")
	_autopilot = true
	await _wait(10.0)
	await _shot("1_en_jeu")
	TestCheck.expect(_game.running and _game.score >= 3, "le pilote automatique passe des obstacles (score %d)" % _game.score)
	_autopilot = false
	var score: int = _game.score
	await _wait(2.5)
	TestCheck.expect(not _game.running, "plus de clic : le robot s'écrase")
	TestCheck.expect(_game.best_score >= score and _game.best_name != "", "record gardé (%d, %s)" % [_game.best_score, _game.best_name])
	await _wait(0.1)
	await _shot("2_boum")
	await _wait(2.0)
	await _shot("3_titre_record")

	_game.tap()
	await _wait(0.2)
	TestCheck.expect(_game.running, "nouvelle partie")
	_tv.power.is_on = false
	await _wait(0.2)
	TestCheck.expect(not _game.running, "télé éteinte : la partie s'arrête")
	_game.tap()
	await _wait(0.2)
	TestCheck.expect(not _game.running, "télé éteinte : un clic ne lance rien")
	TestCheck.finish(get_tree())


func _physics_process(_delta: float) -> void:
	_place_camera()
	if not _autopilot or not _game.running:
		return
	# Clique dès que le robot passe sous le milieu de la prochaine ouverture et qu'il descend.
	var next: int = _game.passed_obstacles()
	var target: float = _game.gap_center(next) + 10.0
	if _game.robot_y > target and _game.robot_vy > 0.0:
		_game.tap()


func _place_camera() -> void:
	_camera.global_position = _tv.to_global(Vector3(-0.05, 0.0, -0.75))
	_camera.look_at(_tv.to_global(Vector3(-0.05, 0.0, -0.157)), _mecha.global_basis.y)


func _shot(shot_name: String) -> void:
	await TestCheck.frame_drawn(get_tree())
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/robo_jet_%s.png" % shot_name)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
