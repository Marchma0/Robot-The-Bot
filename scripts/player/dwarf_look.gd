class_name DwarfLook
extends Node
## Apparence d'un nain : couleur de son joueur, pseudo au-dessus de la tête, et ce qu'on voit
## de son propre corps à la première personne.
##
## Réseau : rien à envoyer. Chaque peer calcule l'apparence à partir de données déjà synchronisées
## (place du joueur, pseudo). Les skins (roadmap 2.4) viendront ici, sur le même principe.

const SLOT_COLORS: Array[Color] = [
	Color(0.85, 0.25, 0.2),
	Color(0.2, 0.5, 0.9),
	Color(0.3, 0.75, 0.3),
	Color(0.95, 0.75, 0.2),
]
## Nom du matériau Blender qui prend la couleur du joueur.
const TUNIC_MATERIAL: String = "Tunic"

@export var body_model: Node3D
@export var head_model: Node3D
@export var name_label: Label3D


## Couleur du joueur `slot` sur le corps et la tête, et pseudo au-dessus.
func apply(slot: int, display_name: String) -> void:
	tint_model(body_model, slot)
	tint_model(head_model, slot)
	set_display_name(display_name)


func set_display_name(text: String) -> void:
	name_label.text = text


## Donne la couleur du joueur `slot` (matériau "Tunic" du modèle Blender) à un modèle de nain
## (le sien, ou celui du portrait de la bulle d'état).
func tint_model(model: Node3D, slot: int) -> void:
	var tunic: StandardMaterial3D = StandardMaterial3D.new()
	tunic.albedo_color = SLOT_COLORS[slot % SLOT_COLORS.size()]
	tunic.roughness = 0.8
	for mesh: MeshInstance3D in meshes_of(model):
		for i: int in mesh.get_surface_override_material_count():
			var source: Material = mesh.mesh.surface_get_material(i)
			if source and source.resource_name == TUNIC_MATERIAL:
				mesh.set_surface_override_material(i, tunic)


## Joueur local, vue à la première personne : on voit son vrai corps (en baissant les yeux : ventre, bras,
## mains, jambes ; un objet en main ou une caisse portée), seule la tête ne garde que son ombre (la caméra
## est dedans). Pas de pseudo non plus.
func set_first_person() -> void:
	name_label.visible = false
	for mesh: MeshInstance3D in meshes_of(head_model):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


static func meshes_of(model: Node3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	return meshes
