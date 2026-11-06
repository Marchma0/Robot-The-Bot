class_name Interactable
extends Area3D
## Base des commandes du cockpit (boutons, leviers…).
## Se vise au regard (couche physique "interactable"), se surligne, affiche un message.
## Toute action passe par une RPC vers l'hôte, qui vérifie que le joueur est à portée.

const INTERACTABLE_LAYER: int = 3
const HIGHLIGHT_COLOR: Color = Color(1.0, 0.95, 0.6, 0.35)

@export var display_name: String = "Commande"
## Distance max (en m) entre le nain et la commande pour l'utiliser.
@export var reach: float = 2.5
## Affiche une étiquette de debug au-dessus de la commande.
@export var show_debug: bool = false

static var _highlight_material: StandardMaterial3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(INTERACTABLE_LAYER, true)
	monitoring = false
	if _highlight_material == null:
		_highlight_material = StandardMaterial3D.new()
		_highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_highlight_material.albedo_color = HIGHLIGHT_COLOR


## Indices (touche → icône) affichés quand le joueur vise la commande. À surcharger.
func get_hints() -> Array[InputHint]:
	return [InputHint.make(&"interact", &"press")]


func set_highlighted(highlighted: bool) -> void:
	for mesh: GeometryInstance3D in _get_highlight_meshes():
		mesh.material_overlay = _highlight_material if highlighted else null


## Vrai si le nain du joueur `peer_id` est à moins de `max_distance` de la commande.
## Utilisé par l'hôte pour valider les demandes.
func is_peer_in_reach(peer_id: int, max_distance: float) -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"dwarves"):
		if node.name == str(peer_id):
			var dwarf: Node3D = node as Node3D
			return dwarf.global_position.distance_to(global_position) <= max_distance
	return false


## À surcharger : les meshes à surligner quand la commande est visée.
func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	return []
