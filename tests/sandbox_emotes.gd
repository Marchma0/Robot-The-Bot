extends Node3D
## Bac à sable des emotes : une rangée de nains de démonstration qui rejouent chacun
## une emote, devant le nain jouable "1" (maintenir B / LB pour ouvrir la roue).


func _ready() -> void:
	var dwarf_scene: PackedScene = load("res://scenes/player/dwarf.tscn")
	for i: int in Emotes.count():
		var demo: Dwarf = dwarf_scene.instantiate()
		demo.setup(100 + i, i % 4)       # peer fictif : pas d'autorité locale, donc pas de contrôle
		demo.position = Vector3(-3.5 + i * 1.0, 0.0, -3.0)
		demo.rotation.y = PI
		add_child(demo)
		(demo.get_node("Animator") as DwarfAnimator).preview_emote = i
		(demo.get_node("%NameLabel") as Label3D).text = Emotes.LIST[i]["label"]
