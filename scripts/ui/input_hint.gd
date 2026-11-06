class_name InputHint
extends RefCounted
## Un indice à l'écran : « cette touche » (action de la Input Map) → « fait ceci » (icône).
## Remplace les textes d'aide : les commandes renvoient une liste d'indices.

## Fausses actions pour les mouvements (pas une touche, mais la souris ou un stick).
const LOOK: StringName = &"_look"            ## souris / stick droit
const MOVE_VERTICAL: StringName = &"_climb"  ## avancer-reculer / stick gauche haut-bas

const ICON_PATH: String = "res://assets/textures/ui/icons/%s.svg"

## Action de la Input Map (ou LOOK / MOVE_VERTICAL). Vide = pas de touche (simple état, ex. occupé).
var action: StringName
## Nom de l'icône (fichier assets/textures/ui/icons/<icon>.svg).
var icon: StringName

static var _icons: Dictionary[StringName, Texture2D] = {}


static func make(p_action: StringName, p_icon: StringName) -> InputHint:
	var hint: InputHint = InputHint.new()
	hint.action = p_action
	hint.icon = p_icon
	return hint


## Indice sans touche (ex. « occupé »).
static func state(p_icon: StringName) -> InputHint:
	return make(&"", p_icon)


static func get_icon(icon_name: StringName) -> Texture2D:
	if not _icons.has(icon_name):
		_icons[icon_name] = load(ICON_PATH % icon_name) as Texture2D
	return _icons[icon_name]


## Clé texte d'une liste d'indices (pour savoir si l'affichage doit changer).
static func key_of(hints: Array[InputHint]) -> String:
	var parts: PackedStringArray = []
	for hint: InputHint in hints:
		parts.append("%s:%s" % [hint.action, hint.icon])
	return ",".join(parts)
