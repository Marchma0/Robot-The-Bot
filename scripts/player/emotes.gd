class_name Emotes
extends RefCounted
## Liste des emotes de la roue (B / LB), dans l'ordre de la roue en partant du haut,
## dans le sens des aiguilles d'une montre. L'index dans cette liste est ce qui est
## synchronisé sur le réseau : ajouter les nouvelles emotes à la fin.
##
## - animation : action Blender exportée dans dwarf_body.glb
## - loop      : true = emote en boucle (corps entier), arrêtée en bougeant ; false = geste du haut du corps
## - duration  : durée du geste (s), pour la caméra et la fin de l'état

const NONE: int = -1

const LIST: Array[Dictionary] = [
	{"label": "Coucou", "animation": &"emote_wave", "loop": false, "duration": 1.5},
	{"label": "Pouce levé", "animation": &"emote_thumbs_up", "loop": false, "duration": 1.6},
	{"label": "Pointer", "animation": &"emote_point", "loop": false, "duration": 1.7},
	{"label": "Applaudir", "animation": &"emote_clap", "loop": false, "duration": 1.9},
	{"label": "Danse", "animation": &"emote_dance", "loop": true, "duration": 0.0},
	{"label": "Je sais pas", "animation": &"emote_shrug", "loop": false, "duration": 1.35},
	{"label": "Salut nain", "animation": &"emote_salute", "loop": false, "duration": 1.75},
	{"label": "Doigt d'honneur", "animation": &"emote_middle_finger", "loop": false, "duration": 1.85},
]


static func count() -> int:
	return LIST.size()


static func is_valid(index: int) -> bool:
	return index >= 0 and index < LIST.size()


static func is_loop(index: int) -> bool:
	return is_valid(index) and LIST[index]["loop"]
