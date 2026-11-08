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
## Os dont les triangles restent visibles à la première personne (bras, doigts, pouces).
const ARM_BONE_PREFIXES: Array[String] = ["arm_", "finger_", "thumb_"]
## Les bras vus à la première personne sont avancés et un peu remontés (repère du corps, -Z = devant) :
## sans ça, les gestes restent au bord de l'écran. Seul le joueur local les voit (son ombre reste à sa place).
const FIRST_PERSON_ARMS_OFFSET: Vector3 = Vector3(0.0, 0.06, -0.16)

@export var body_model: Node3D
@export var head_model: Node3D
@export var name_label: Label3D

var _body_hidden: bool = false
var _first_person: bool = false
var _third_person: bool = false
var _slot: int = 0
## Bras visibles à la première personne (copie du corps, joueur local seulement).
var _arms: MeshInstance3D = null


## Couleur du joueur `slot` sur le corps et la tête, et pseudo au-dessus.
func apply(slot: int, display_name: String) -> void:
	_slot = slot
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


## Joueur local, vue à la première personne (façon Lethal Company) : on ne voit de soi que ses bras et
## ses mains, qui font les gestes devant soi ; le torse, les jambes et la tête ne gardent que leur ombre.
## Ni son pseudo. Les bras sont une copie du corps réduite aux triangles des os des bras (`_build_arms`).
func set_first_person() -> void:
	_first_person = true
	name_label.visible = false
	_arms = _build_arms()
	_refresh()


## Masque même les bras (le corps garde son ombre). Sert pendant le traveling de caméra vers un poste,
## qui passe à travers les bras du nain.
func set_body_hidden(value: bool) -> void:
	if value != _body_hidden:
		_body_hidden = value
		_refresh()


## Vue à la troisième personne (pendant une emote) : on voit tout son nain.
func set_third_person(value: bool) -> void:
	if value != _third_person:
		_third_person = value
		_refresh()


static func meshes_of(model: Node3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	return meshes


func _refresh() -> void:
	var whole: bool = _third_person or not _first_person
	for mesh: MeshInstance3D in meshes_of(body_model):
		if mesh == _arms:
			mesh.visible = _first_person and not whole and not _body_hidden
			continue
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if whole \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


## Copie du corps (même squelette, mêmes animations) qui ne garde que les triangles des bras et des mains.
func _build_arms() -> MeshInstance3D:
	var body: MeshInstance3D = null
	for mesh: MeshInstance3D in meshes_of(body_model):
		if mesh.skin != null and not head_model.is_ancestor_of(mesh):
			body = mesh
	if body == null:
		return null
	var skeleton: Skeleton3D = body.get_node_or_null(body.skeleton) as Skeleton3D
	var arm_binds: Dictionary[int, bool] = {}
	for bind: int in body.skin.get_bind_count():
		var bone_name: String = body.skin.get_bind_name(bind)
		if bone_name.is_empty() and skeleton != null:
			bone_name = skeleton.get_bone_name(body.skin.get_bind_bone(bind))
		if ARM_BONE_PREFIXES.any(func(prefix: String) -> bool: return bone_name.begins_with(prefix)):
			arm_binds[bind] = true
	var source: Mesh = body.mesh
	var arms_mesh: ArrayMesh = ArrayMesh.new()
	for surface: int in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(surface)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var vertex_count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		if bones.is_empty() or vertex_count == 0:
			continue
		@warning_ignore("integer_division")
		var per_vertex: int = bones.size() / vertex_count
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null \
				else PackedInt32Array(range(vertex_count))
		var kept: PackedInt32Array = PackedInt32Array()
		for t: int in range(0, indices.size(), 3):
			var keep: bool = true
			for k: int in 3:
				keep = keep and arm_binds.has(_main_bone(bones, weights, indices[t + k], per_vertex))
			if keep:
				kept.append_array([indices[t], indices[t + 1], indices[t + 2]])
		if kept.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = kept
		var flags: int = source.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		arms_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		arms_mesh.surface_set_material(arms_mesh.get_surface_count() - 1, source.surface_get_material(surface))
	var arms: MeshInstance3D = MeshInstance3D.new()
	arms.name = "FirstPersonArms"
	arms.mesh = arms_mesh
	arms.skin = body.skin
	arms.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_sibling(arms)
	# Décalage exprimé dans le repère du nain, ramené dans celui du parent du maillage.
	var parent: Node3D = arms.get_parent() as Node3D
	var dwarf_node: Node3D = body_model.get_parent() as Node3D
	arms.transform = body.transform
	arms.position += parent.global_basis.inverse() * (dwarf_node.global_basis * FIRST_PERSON_ARMS_OFFSET)
	arms.skeleton = arms.get_path_to(skeleton) if skeleton != null else body.skeleton
	tint_model(body_model, _slot)   # couleur du joueur sur la tunique des manches
	return arms


## Os qui pèse le plus sur le sommet `vertex` (index de liaison de la peau).
static func _main_bone(bones: PackedInt32Array, weights: PackedFloat32Array, vertex: int, per_vertex: int) -> int:
	var best: int = -1
	var best_weight: float = -1.0
	for k: int in per_vertex:
		var w: float = weights[vertex * per_vertex + k]
		if w > best_weight:
			best_weight = w
			best = bones[vertex * per_vertex + k]
	return best
