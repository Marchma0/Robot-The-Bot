class_name MechaColliderSync
extends Node
## Colle les collisions du cockpit (coque, meubles) au mécha à chaque étape physique.
##
## Le mécha est déplacé avant les nains (Walker chez l'hôte, NetSmoother chez les clients, priorité -10).
## Mais Godot ne transmet la nouvelle place d'un corps physique au moteur physique qu'en fin d'étape :
## sans ce nœud, chaque nain se déplace contre un sol resté une étape en arrière (jusqu'à 13 cm en plein
## saut), décolle et retombe, et sa vue saute. Ce nœud passe juste après (priorité -5) et pousse tout de
## suite la place de chaque collision du mécha.
##
## Les meubles du cockpit sont des StaticBody3D : un AnimatableBody3D, avec Jolt, ne rejoint sa place
## qu'à l'étape suivante, même ainsi.
##
## Réseau : rien, chaque peer le fait pour son propre affichage.

## Toutes les combien d'étapes on refait la liste (objets apparus ou retirés : caisses, cacas…).
const REFRESH_TICKS: int = 30

@export var mecha: Node3D

var _bodies: Array[CollisionObject3D] = []
var _ticks: int = 0


func _ready() -> void:
	process_physics_priority = -5


func _physics_process(_delta: float) -> void:
	if _ticks % REFRESH_TICKS == 0:
		_refresh()
	_ticks += 1
	for body: CollisionObject3D in _bodies:
		if is_instance_valid(body) and body.is_inside_tree():
			body.force_update_transform()


func _refresh() -> void:
	_bodies.clear()
	for node: Node in mecha.find_children("*", "CollisionObject3D", true, false):
		# Les nains bougent eux-mêmes ; un corps rigide libre est placé par le moteur physique.
		if node is CharacterBody3D or (node is RigidBody3D and not (node as RigidBody3D).freeze):
			continue
		_bodies.append(node as CollisionObject3D)
