extends Node3D
## Outil : captures de l'intérieur du mécha à hauteur de nain (build/views/interior_*.png), puis quitte.

const SHOTS: Array = [
	["ventre_vers_avant", Vector3(0.0, 3.55, 1.7), Vector3(0.0, 3.3, -1.9)],
	["ventre_vers_arriere", Vector3(0.0, 3.55, -1.7), Vector3(0.0, 3.3, 1.9)],
	["ventre_vers_gauche", Vector3(2.0, 3.55, 0.0), Vector3(-2.2, 3.3, 0.0)],
	["ventre_vers_droite", Vector3(-2.0, 3.55, 0.0), Vector3(2.2, 3.3, 0.0)],
	["tete_vers_avant", Vector3(0.0, 6.65, 1.7), Vector3(0.0, 6.5, -1.9)],
	["tete_vers_arriere", Vector3(0.0, 6.65, -1.7), Vector3(0.0, 6.4, 1.9)],
	["tete_vers_gauche", Vector3(2.0, 6.65, 0.0), Vector3(-2.2, 6.4, 0.0)],
	["tete_vers_droite", Vector3(-2.0, 6.65, 0.0), Vector3(2.2, 6.4, 0.0)],
]

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/views"))
	await get_tree().create_timer(1.5).timeout
	for shot: Array in SHOTS:
		_camera.global_position = shot[1]
		_camera.look_at(shot[2], Vector3.UP)
		_camera.reset_physics_interpolation()
		for i: int in 8:
			await get_tree().process_frame
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png("res://build/views/interior_%s.png" % shot[0])
	get_tree().quit()
