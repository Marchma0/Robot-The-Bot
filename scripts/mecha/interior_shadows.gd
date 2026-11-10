class_name InteriorShadows
extends Node
## Range le décor de l'intérieur du robot sur le calque de rendu « intérieur du robot » (calque 2).
##
## Le soleil des niveaux ne fait pas d'ombre avec ce calque (`shadow_caster_mask` sans le calque 2) : la
## coque cache déjà l'intérieur, et dessiner ces centaines de petits objets dans l'ombre du soleil coûtait
## environ un tiers de l'image. Les lampes du robot, elles, font toujours l'ombre des meubles.
##
## Seul le décor posé au départ est concerné (pas les nains ni les objets qui vont et viennent).
## Réseau : rien, purement visuel et local.

## Calque de rendu de l'intérieur (bit 2), à retirer du `shadow_caster_mask` d'un soleil.
const INTERIOR_LAYER: int = 2

@export var mecha: Node3D
## Branches du robot à ne pas toucher (nains, objets apparus en jeu).
@export var skip: Array[Node] = []


func _ready() -> void:
	# Après le premier placement des sous-scènes (leurs AABB doivent être à leur place).
	_apply.call_deferred()


func _apply() -> void:
	var volumes: Array[InteriorVolume] = []
	for node: Node in get_tree().get_nodes_in_group(&"mecha_interiors"):
		if mecha.is_ancestor_of(node):
			volumes.append(node as InteriorVolume)
	for node: Node in mecha.find_children("*", "GeometryInstance3D", true, false):
		if _is_skipped(node):
			continue
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		if _inside(geometry, volumes):
			geometry.layers = INTERIOR_LAYER


func _is_skipped(node: Node) -> bool:
	for branch: Node in skip:
		if branch == node or branch.is_ancestor_of(node):
			return true
	return false


## Vrai si toute la boîte de l'objet est dans l'intérieur (un objet qui dépasse dehors garde son ombre).
func _inside(geometry: GeometryInstance3D, volumes: Array[InteriorVolume]) -> bool:
	for volume: InteriorVolume in volumes:
		# Boîte de l'objet dans le repère du volume (centré sur le nœud).
		var box: AABB = volume.global_transform.affine_inverse() * geometry.global_transform * geometry.get_aabb()
		var half: Vector3 = volume.size / 2.0
		if AABB(-half, volume.size).encloses(box):
			return true
	return false
