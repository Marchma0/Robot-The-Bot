class_name InteriorVolume
extends Node3D
## Boîte qui délimite l'intérieur du mécha (ventre + tête), centrée sur le nœud.
## Un nain hors de toutes les boîtes est « dehors » : il ne suit plus le mécha.

@export var size: Vector3 = Vector3(4.6, 6.1, 4.0)


func _ready() -> void:
	add_to_group(&"mecha_interiors")


func contains(point: Vector3) -> bool:
	var local: Vector3 = to_local(point).abs()
	var half: Vector3 = size / 2.0
	return local.x <= half.x and local.y <= half.y and local.z <= half.z
