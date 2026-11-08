extends Node3D
## Bac à sable de la vue du joueur (3.10, façon Lethal Company) : un nain local dans le salon du robot.
## Première personne : on voit ses bras, pas son torse ni sa tête (ils gardent leur ombre), et les yeux
## suivent l'os de la tête. Une emote fait passer la caméra en troisième personne, puis elle revient.
## Captures (vue réelle du joueur) dans build/views/first_person_*.png.

const DWARF_SCENE: PackedScene = preload("res://scenes/player/dwarf.tscn")

@export var quit_when_done: bool = true

var _dwarf: Dwarf

@onready var _mecha: Node3D = $Mecha


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	_dwarf = DWARF_SCENE.instantiate() as Dwarf
	_dwarf.setup(1, 0)
	_mecha.get_node("Players").add_child(_dwarf)
	_dwarf.position = Vector3(-0.3, 2.65, 0.6)
	_dwarf.rotation.y = PI * 0.75   # vers la trappe et le bouton du retour au camp
	await _wait(1.2)
	var look: DwarfLook = _dwarf.get_node("%Look")
	var rig: DwarfCamera = _dwarf.get_node("%CameraRig")
	var arms: MeshInstance3D = _dwarf.find_child("FirstPersonArms", true, false) as MeshInstance3D
	TestCheck.expect(arms != null and arms.visible and arms.mesh.get_surface_count() > 0, "première personne : les bras sont visibles")
	var body: MeshInstance3D = _body_mesh()
	TestCheck.expect(body != null and body.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "première personne : le torse ne garde que son ombre")
	var head_y: float = (_dwarf.get_node("%Camera") as Camera3D).global_position.y - _dwarf.global_position.y
	TestCheck.expect(head_y > 0.75 and head_y < 1.1, "les yeux sont à hauteur de tête (%.2f m)" % head_y)
	await _shot("0_devant")

	_dwarf._look(Vector2(0.0, -1.0))
	await _shot("1_regard_bas")
	_dwarf._look(Vector2(0.0, 0.7))
	_dwarf.anim_press_count += 1
	await _shot("2_appui", 0.25)

	_dwarf._look(Vector2(0.0, 0.3))
	_dwarf._play_emote(0)
	await _wait(0.6)
	TestCheck.expect(rig.is_third_person(), "emote : la caméra passe à la troisième personne")
	TestCheck.expect(body.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON and not arms.visible, "emote : on voit tout son nain")
	TestCheck.expect(not (_dwarf.get_node("%Interactor") as RayCast3D).enabled, "emote : on ne vise plus rien")
	await _shot("3_emote", 0.2)
	await _wait(2.0)
	TestCheck.expect(not rig.is_third_person() and arms.visible, "fin de l'emote : retour aux yeux")
	TestCheck.expect((_dwarf.get_node("%Interactor") as RayCast3D).enabled, "fin de l'emote : on vise de nouveau")
	look.set_third_person(false)
	if quit_when_done or TestCheck.is_auto():
		TestCheck.finish(get_tree())


func _body_mesh() -> MeshInstance3D:
	for mesh: MeshInstance3D in DwarfLook.meshes_of(_dwarf.get_node("BodyModel")):
		if mesh.skin != null and mesh.name != "FirstPersonArms":
			return mesh
	return null


func _shot(shot_name: String, delay: float = 0.4) -> void:
	await _wait(delay)
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/first_person_%s.png" % shot_name)


func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
