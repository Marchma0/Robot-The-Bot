extends Node3D
## Bac à sable de la vue du joueur (2.7) : un nain local dans le salon. On voit son vrai corps (pas de bras de vue
## à part) : en baissant les yeux, ventre, mains et pieds ; seule la tête ne garde que son ombre. Un caca en main
## est dans la main droite, bras tendu, et reste dans le champ en regardant en bas comme en haut ; une caisse est
## portée à deux mains, entre les mains. Les emotes se jouent sur le corps.
## Captures (vue réelle du joueur) dans build/views/first_person_*.png.

const DWARF_SCENE: PackedScene = preload("res://scenes/player/dwarf.tscn")
const POOP_SCENE: PackedScene = preload("res://scenes/props/poop.tscn")
const CRATE_SCENE: PackedScene = preload("res://scenes/props/cargo_crate.tscn")

@export var quit_when_done: bool = true

var _dwarf: Dwarf
var _camera: Camera3D

@onready var _mecha: Node3D = $Mecha


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	_dwarf = DWARF_SCENE.instantiate() as Dwarf
	_dwarf.setup(1, 0)
	_mecha.get_node("Players").add_child(_dwarf)
	_dwarf.position = Vector3(-0.3, 2.65, 0.6)
	_dwarf.rotation.y = PI * 0.75   # vers la trappe et le bouton du retour au camp
	_camera = _dwarf.get_node("%Camera") as Camera3D
	await _wait(1.2)
	TestCheck.expect(_dwarf.find_child("ViewArms", true, false) == null, "plus de bras de vue à part")
	var body: MeshInstance3D = _body_mesh()
	TestCheck.expect(body != null and body.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "le corps est visible")
	for mesh: MeshInstance3D in DwarfLook.meshes_of(_dwarf.get_node("%HeadModel")):
		TestCheck.expect(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "la tête ne garde que son ombre")
	var head_y: float = _camera.global_position.y - _dwarf.global_position.y
	TestCheck.expect(head_y > 0.75 and head_y < 1.1, "les yeux sont à hauteur de tête (%.2f m)" % head_y)
	var palm: Vector3 = _dwarf.global_transform.affine_inverse() * _dwarf.get_hold_transform().origin
	TestCheck.expect(palm.distance_to(Vector3(0.36, 0.4, 0.0)) < 0.12, "bras le long du corps : la main est en bas à droite (%s)" % palm)
	await _shot("0_devant")
	await _look_shot("1_regard_bas", -1.2)
	await _look_shot("1_regard_bas_moitie", -0.7)
	# Tout en bas : le regard s'arrête avant d'entrer dans le torse (on voyait à travers son corps).
	_dwarf._look(Vector2(0.0, -3.0))
	var lowest: float = _dwarf.get_node("%Head").rotation.x
	TestCheck.expect(lowest >= -Dwarf.MAX_PITCH_DOWN - 0.001, "regard vers le bas limité (%.0f°)" % rad_to_deg(lowest))
	await _look_shot("1_regard_pieds", lowest)
	Input.action_press("crouch")
	await _look_shot("1_accroupi_regard_bas", -1.2, 0.6)
	Input.action_release("crouch")
	await _wait(0.4)

	# Caca en main : dans la main droite, toujours dans le champ.
	var poop: Poop = POOP_SCENE.instantiate() as Poop
	_mecha.get_node("Props").add_child(poop)
	poop.holder_slot = 0
	poop.holder_peer_id = 1
	await _wait(0.5)
	TestCheck.expect(_dwarf.anim_hold_item and not _dwarf.anim_carrying, "caca en main : animation « tenir à une main »")
	for pitch: float in [0.0, -1.0, 0.9]:
		_set_pitch(pitch)
		await _shot("2_caca_%+.1f" % pitch, 0.4)
		_expect_in_view(poop.global_position, "caca en main, regard à %.1f rad" % pitch)
		var hand: Vector3 = _dwarf.get_node("BodyModel/DwarfRig/Skeleton3D/HandBone/Palm").global_position
		TestCheck.expect(poop.global_position.distance_to(hand) < 0.05, "le caca est dans la main")
	_set_pitch(0.0)
	_dwarf.anim_throw_count += 1
	await _shot("2_caca_lancer", 0.2)
	poop.holder_peer_id = 0
	poop.queue_free()
	await _wait(0.4)
	TestCheck.expect(not _dwarf.anim_hold_item, "main vide : plus d'animation")

	# Caisse portée à deux mains.
	var crate: CargoCrate = CRATE_SCENE.instantiate() as CargoCrate
	_mecha.get_node("Props").add_child(crate)
	crate.holder_slot = 0
	crate.holder_peer_id = 1
	await _wait(0.5)
	TestCheck.expect(_dwarf.anim_carrying and not _dwarf.anim_hold_item, "caisse : animation « porter à deux mains »")
	await _shot("3_caisse")
	await _look_shot("3_caisse_regard_bas", -0.8)
	# Le modèle de la caisse est accroché au nain : il avance exactement avec lui (avant, il était replacé
	# à chaque image et avançait par à-coups).
	var crate_model: Node3D = crate.get_model()
	TestCheck.expect(crate_model.get_parent() == _dwarf, "caisse portée : son modèle est accroché au nain")
	crate.queue_free()
	await _wait(0.4)
	TestCheck.expect(not is_instance_valid(crate_model), "caisse supprimée pendant qu'on la porte : son modèle part avec elle")

	for i: int in Emotes.count():
		_dwarf._play_emote(i)
		var name_id: String = String(Emotes.LIST[i]["animation"]).trim_prefix("emote_")
		await _shot("4_emote_%s" % name_id, 0.95)
		_dwarf.anim_emote = Emotes.NONE
		await _wait(0.4)
	var wheel: EmoteWheel = _dwarf._hud.emote_wheel
	Input.action_press("emote_wheel")   # touche maintenue, sinon le nain referme la roue
	await _wait(0.1)
	wheel.push_mouse(Vector2(80.0, -40.0))
	await _shot("5_roue", 0.2)
	TestCheck.expect(wheel._icons.size() == Emotes.count(), "roue d'emotes : une image par emote")
	Input.action_release("emote_wheel")
	await _wait(0.1)
	if quit_when_done or TestCheck.is_auto():
		TestCheck.finish(get_tree())


func _body_mesh() -> MeshInstance3D:
	for mesh: MeshInstance3D in DwarfLook.meshes_of(_dwarf.get_node("BodyModel")):
		if mesh.skin != null:
			return mesh
	return null


func _set_pitch(pitch: float) -> void:
	_dwarf.get_node("%Head").rotation.x = pitch


func _look_shot(shot_name: String, pitch: float, delay: float = 0.4) -> void:
	_set_pitch(pitch)
	await _shot(shot_name, delay)
	_set_pitch(0.0)


## Le point `point` est dans l'image d'un écran 16:9 (calculé avec l'angle de vue : marche aussi sans fenêtre).
func _expect_in_view(point: Vector3, what: String) -> void:
	var local: Vector3 = _camera.global_transform.affine_inverse() * point
	var half_v: float = tan(deg_to_rad(_camera.fov) / 2.0)
	var shown: bool = local.z < -0.05 and absf(local.y / local.z) < half_v 		and absf(local.x / local.z) < half_v * 16.0 / 9.0
	TestCheck.expect(shown, what + " : dans le champ (%s)" % local)


func _shot(shot_name: String, delay: float = 0.4) -> void:
	await _wait(delay)
	await TestCheck.frame_drawn(get_tree())
	TestCheck.save_view(get_viewport(), "res://build/views/first_person_%s.png" % shot_name)


func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
