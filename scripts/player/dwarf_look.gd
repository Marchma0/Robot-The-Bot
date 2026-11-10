class_name DwarfLook
extends Node
## Apparence d'un nain : couleur de son joueur, skin (tenue + chapeau 3D + barbe), pseudo au-dessus de la tête,
## et ce qu'on voit de son propre corps à la première personne (roadmap 2.4 / 4.5).
##
## Réseau : chaque peer applique l'apparence à partir de `slot`, `skin_index` et `color_index` (synchronisés
## sur `Dwarf`).

const HAT_WELDER_SCENE: PackedScene = preload("res://assets/models/props/dwarf_hat_welder.glb")
const HAT_CROWN_SCENE: PackedScene = preload("res://assets/models/props/dwarf_hat_crown.glb")

const SKIN_COUNT: int = 3
const SKIN_TITLES: Array[String] = [
	"Mineur Classique",
	"Garagiste Soudeur",
	"Baron Cuivre",
]

const SLOT_COLORS: Array[Color] = [
	Color(0.85, 0.25, 0.2),
	Color(0.2, 0.5, 0.9),
	Color(0.3, 0.75, 0.3),
	Color(0.95, 0.75, 0.2),
	Color(0.62, 0.28, 0.85),
	Color(0.95, 0.45, 0.12),
]

const COLOR_TITLES: Array[String] = [
	"Rouge Garage",
	"Bleu Cobalt",
	"Vert Émeraude",
	"Or Solaire",
	"Violet Plasma",
	"Orange Chantier",
]

## Nom du matériau Blender qui prend la couleur du joueur.
const TUNIC_MATERIAL: String = "Tunic"

@export var body_model: Node3D
@export var head_model: Node3D
@export var name_label: Label3D

var _first_person: bool = false


## Couleur et skin du joueur `slot` sur le corps et la tête, et pseudo au-dessus.
func apply(slot: int, display_name: String, skin_idx: int = 0, color_idx: int = -1) -> void:
	tint_model(body_model, slot, skin_idx, color_idx)
	tint_model(head_model, slot, skin_idx, color_idx)
	_attach_hats(head_model, skin_idx)
	if _first_person:
		set_first_person()
	set_display_name(display_name)


func set_display_name(text: String) -> void:
	name_label.text = text


## Donne la couleur et le skin du joueur `slot` à un modèle de nain (le sien, ou celui du portrait de la bulle d'état).
func tint_model(model: Node3D, slot: int, skin_idx: int = 0, color_idx: int = -1) -> void:
	if model == null:
		return
	var effective_color_idx: int = color_idx if color_idx >= 0 else (slot % SLOT_COLORS.size())
	var tunic: StandardMaterial3D = StandardMaterial3D.new()
	tunic.albedo_color = SLOT_COLORS[posmod(effective_color_idx, SLOT_COLORS.size())]
	tunic.roughness = 0.75 if skin_idx == 0 else 0.55
	tunic.metallic = 0.25 if skin_idx == 2 else 0.05

	var beard_mat: StandardMaterial3D = null
	var trousers_mat: StandardMaterial3D = null
	var trim_mat: StandardMaterial3D = null
	if skin_idx == 1:
		# Garagiste Soudeur : barbe charbon, pantalon bleu atelier, cuir/métal sombre.
		beard_mat = StandardMaterial3D.new()
		beard_mat.albedo_color = Color(0.16, 0.14, 0.13)
		beard_mat.roughness = 0.85
		trousers_mat = StandardMaterial3D.new()
		trousers_mat.albedo_color = Color(0.16, 0.22, 0.30)
		trousers_mat.roughness = 0.75
		trim_mat = StandardMaterial3D.new()
		trim_mat.albedo_color = Color(0.22, 0.25, 0.28)
		trim_mat.metallic = 0.75
		trim_mat.roughness = 0.40
	elif skin_idx == 2:
		# Baron Cuivre : barbe blanche royale, pantalon velours bordeaux, casque et ornements dorés.
		beard_mat = StandardMaterial3D.new()
		beard_mat.albedo_color = Color(0.92, 0.90, 0.85)
		beard_mat.roughness = 0.70
		trousers_mat = StandardMaterial3D.new()
		trousers_mat.albedo_color = Color(0.28, 0.11, 0.14)
		trousers_mat.roughness = 0.65
		trim_mat = StandardMaterial3D.new()
		trim_mat.albedo_color = Color(0.95, 0.76, 0.22)
		trim_mat.metallic = 0.85
		trim_mat.roughness = 0.28

	for mesh: MeshInstance3D in meshes_of(model):
		if mesh.mesh == null:
			continue
		for i: int in mesh.get_surface_override_material_count():
			var source: Material = mesh.mesh.surface_get_material(i)
			if source == null:
				continue
			var mat_name: String = source.resource_name
			if mat_name == TUNIC_MATERIAL:
				mesh.set_surface_override_material(i, tunic)
			elif mat_name == "Beard":
				mesh.set_surface_override_material(i, beard_mat)
			elif mat_name == "Trousers":
				mesh.set_surface_override_material(i, trousers_mat)
			elif mat_name == "Copper" or mat_name == "Iron":
				mesh.set_surface_override_material(i, trim_mat)

	var sub_head: Node3D = model.find_child("HeadModel", true, false) as Node3D
	if sub_head != null:
		_attach_hats(sub_head, skin_idx)


## Joueur local, vue à la première personne : on voit son vrai corps (en baissant les yeux : ventre, bras,
## mains, jambes ; un objet en main ou une caisse portée), seule la tête ne garde que son ombre (la caméra
## est dedans). Pas de pseudo non plus.
func set_first_person() -> void:
	_first_person = true
	name_label.visible = false
	for mesh: MeshInstance3D in meshes_of(head_model):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


static func skin_title(skin_idx: int) -> String:
	return TranslationServer.translate(SKIN_TITLES[posmod(skin_idx, SKIN_TITLES.size())])


static func color_title(color_idx: int, slot: int = 0) -> String:
	var idx: int = color_idx if color_idx >= 0 else (slot % COLOR_TITLES.size())
	return TranslationServer.translate(COLOR_TITLES[posmod(idx, COLOR_TITLES.size())])


static func meshes_of(model: Node3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if model == null:
		return meshes
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	return meshes


func _attach_hats(target_head: Node3D, skin_idx: int) -> void:
	if target_head == null:
		return
	var hat_welder: Node3D = target_head.get_node_or_null("HatWelder") as Node3D
	if hat_welder == null:
		hat_welder = HAT_WELDER_SCENE.instantiate() as Node3D
		hat_welder.name = "HatWelder"
		hat_welder.position = Vector3(0.0, 0.08, 0.0)
		target_head.add_child(hat_welder)
	var hat_crown: Node3D = target_head.get_node_or_null("HatCrown") as Node3D
	if hat_crown == null:
		hat_crown = HAT_CROWN_SCENE.instantiate() as Node3D
		hat_crown.name = "HatCrown"
		hat_crown.position = Vector3(0.0, 0.14, 0.0)
		target_head.add_child(hat_crown)
	hat_welder.visible = (skin_idx == 1)
	hat_crown.visible = (skin_idx == 2)
