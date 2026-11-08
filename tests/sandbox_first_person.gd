extends Node3D
## Bac à sable de la vue du joueur (3.10, façon Lethal Company / Deep Rock Galactic) : un nain local dans le salon.
## Au repos et en regardant ses pieds, on ne voit ni son torse ni ses bras ; en appuyant et pendant chaque emote,
## les bras de vue montent dans le champ, toujours à la première personne.
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
	var arms: DwarfViewArms = _dwarf.find_child("ViewArms", true, false) as DwarfViewArms
	TestCheck.expect(arms != null and not arms.visible, "au repos : pas de bras dans le champ")
	var body: MeshInstance3D = _body_mesh()
	TestCheck.expect(body != null and body.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "le torse ne garde que son ombre")
	var head_y: float = (_dwarf.get_node("%Camera") as Camera3D).global_position.y - _dwarf.global_position.y
	TestCheck.expect(head_y > 0.75 and head_y < 1.1, "les yeux sont à hauteur de tête (%.2f m)" % head_y)
	await _shot("0_devant")
	_dwarf._look(Vector2(0.0, -1.0))
	await _shot("1_regard_bas")
	TestCheck.expect(not arms.visible, "en regardant ses pieds : pas de bras")
	_dwarf._look(Vector2(0.0, 1.0))

	_dwarf.anim_press_count += 1
	await _shot("2_appui", 0.25)
	TestCheck.expect(arms.visible, "en appuyant : le bras monte dans le champ")
	await _wait(1.0)
	TestCheck.expect(not arms.visible, "après l'appui : le bras redescend")

	for i: int in Emotes.count():
		_dwarf._play_emote(i)
		var name_id: String = String(Emotes.LIST[i]["animation"]).trim_prefix("emote_")
		await _shot("3_emote_%s" % name_id, 0.95)
		TestCheck.expect(arms.visible and arms.is_raised(), "emote « %s » : on voit ses bras, à la première personne" % Emotes.LIST[i]["label"])
		_dwarf.anim_emote = Emotes.NONE
		await _wait(0.4)
	if quit_when_done or TestCheck.is_auto():
		TestCheck.finish(get_tree())


func _body_mesh() -> MeshInstance3D:
	for mesh: MeshInstance3D in DwarfLook.meshes_of(_dwarf.get_node("BodyModel")):
		if mesh.skin != null:
			return mesh
	return null


func _shot(shot_name: String, delay: float = 0.4) -> void:
	await _wait(delay)
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/first_person_%s.png" % shot_name)


func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
