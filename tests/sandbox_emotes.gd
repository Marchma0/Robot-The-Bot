extends Node3D
## Bac à sable des emotes : une rangée de nains de démonstration qui rejouent chacun
## une emote, plus deux nains accroupis, devant le nain jouable "1"
## (maintenir B / LB pour la roue, Ctrl / B manette pour s'accroupir ; bulle d'état en haut à droite).

const EXTRA_STATES: Array[String] = ["crouch", "crouch_walk"]


func _ready() -> void:
	var dwarf_scene: PackedScene = load("res://scenes/player/dwarf.tscn")
	var count: int = Emotes.count() + EXTRA_STATES.size()
	for i: int in count:
		var demo: Dwarf = dwarf_scene.instantiate()
		demo.setup(100 + i, i % 4)       # peer fictif : pas d'autorité locale, donc pas de contrôle
		demo.position = Vector3(-(count - 1) / 2.0 + i * 1.0, 0.0, -3.0)
		demo.rotation.y = PI
		add_child(demo)
		var animator: DwarfAnimator = demo.get_node("Animator")
		var label: Label3D = demo.get_node("%NameLabel")
		if i < Emotes.count():
			animator.preview_emote = i
			label.text = Emotes.LIST[i]["label"]
		else:
			animator.preview_state = EXTRA_STATES[i - Emotes.count()]
			label.text = "Accroupi" if animator.preview_state == "crouch" else "Se dandine"
