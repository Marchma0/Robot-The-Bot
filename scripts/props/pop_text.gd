class_name PopText
extends Label3D
## Texte qui jaillit au-dessus d'un mini-jeu (« MONSTRUEUX ! », « BONK ! »…) : il gonfle, rebondit, monte et s'efface.
## Purement visuel et local : créé par un RPC `authority, call_local` de l'hôte, chez chaque joueur.
## Le texte doit déjà être traduit (via tr() chez celui qui l'affiche).

const FONT: FontVariation = preload("res://assets/fonts/fredoka.tres")
const LIFE: float = 1.7
const RISE_SPEED: float = 0.55

var _age: float = 0.0
var _base_scale: float = 1.0


## Fait jaillir `text` en `local_pos` (repère de `parent`). `size` : 1 = normal, 1.6 = énorme.
static func spawn(parent: Node3D, local_pos: Vector3, text: String, color: Color, size: float = 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var pop: PopText = PopText.new()
	pop.text = text
	pop.font = FONT
	pop.font_size = 96
	pop.pixel_size = 0.0035
	pop.outline_size = 22
	pop.modulate = color
	pop.outline_modulate = Color(0.12, 0.05, 0.03)
	pop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pop.no_depth_test = true
	pop.render_priority = 10
	pop._base_scale = size
	pop.scale = Vector3.ONE * 0.01
	pop.position = local_pos
	parent.add_child(pop)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	# Apparition élastique (gonfle trop puis se pose), petite oscillation, puis fondu à la fin.
	var grow: float = minf(_age / 0.28, 1.0)
	var elastic: float = 1.0 + sin(grow * PI) * 0.45 if grow < 1.0 else 1.0
	var wobble: float = 1.0 + sin(_age * 18.0) * 0.04 * maxf(1.0 - _age, 0.0)
	scale = Vector3.ONE * maxf(_base_scale * grow * elastic * wobble, 0.01)
	rotation.z = sin(_age * 9.0) * 0.08 * maxf(1.0 - _age * 1.5, 0.0)
	position.y += RISE_SPEED * delta
	modulate.a = clampf((LIFE - _age) / 0.45, 0.0, 1.0)
	outline_modulate.a = modulate.a
