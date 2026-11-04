extends Node3D
## Bac à sable des animations du nain : une rangée de nains de démonstration,
## chacun bloqué sur une animation, devant le nain jouable "1".

const STATES: Array[String] = ["idle", "walk", "air", "grab", "press", "sit"]


func _ready() -> void:
	var dwarf_scene: PackedScene = load("res://scenes/player/dwarf.tscn")
	for i: int in STATES.size():
		var demo: Dwarf = dwarf_scene.instantiate()
		demo.setup(100 + i, i % 4)       # peer fictif : pas d'autorité locale, donc pas de contrôle
		demo.position = Vector3(-2.5 + i * 1.0, 0.0, -3.0)
		demo.rotation.y = deg_to_rad(150.0 if i % 2 == 0 else -150.0)
		add_child(demo)
		(demo.get_node("Animator") as DwarfAnimator).preview_state = STATES[i]
		(demo.get_node("%NameLabel") as Label3D).text = STATES[i]
