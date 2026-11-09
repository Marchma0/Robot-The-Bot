class_name Interactable
extends Area3D
## Base des commandes du cockpit (boutons, leviers…).
## Se vise au regard (couche physique "interactable"), se surligne, affiche un message.
## Toute action passe par une RPC vers l'hôte, qui vérifie que le joueur est à portée.
##
## Nouvelle commande : hériter de cette classe et surcharger `interact` (et `get_hints`).
## L'Interactor n'a pas à changer.

## Résultat de `interact` : rien, action faite tout de suite (bouton…), ou objet demandé
## qu'on va tenir ou occuper (levier, siège… voir Possession et `get_claim`).
enum Use { NONE, DONE, CLAIM }

const INTERACTABLE_LAYER: int = 3
## Surbrillance de la commande visée : lueur chaude sur ses bords, qui respire.
const HIGHLIGHT_SHADER: Shader = preload("res://scenes/mecha/controls/interact_highlight.gdshader")

@export var display_name: String = "Commande"
## Distance max (en m) entre le nain et la commande pour l'utiliser.
@export var reach: float = 2.5
## Affiche une étiquette de debug au-dessus de la commande.
@export var show_debug: bool = false
## Utilisable assis sur un simple siège (canapé), au clic : ex. le jeu de dames de la table basse.
@export var usable_seated: bool = false

static var _highlight_material: ShaderMaterial


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(INTERACTABLE_LAYER, true)
	monitoring = false
	if _highlight_material == null:
		_highlight_material = ShaderMaterial.new()
		_highlight_material.shader = HIGHLIGHT_SHADER


## Joueur local : il vise la commande et vient d'appuyer sur E (`press`) ou clic / RT (`grab`).
## `hands_free` : il ne tient rien. Envoie sa demande à l'hôte et dit ce qui se passe. À surcharger.
func interact(_press: bool, _grab: bool, _hands_free: bool) -> Use:
	return Use.NONE


## Vrai si l'utiliser range l'objet de l'inventaire en main (levier, siège, corde…) : avec un objet en main,
## l'Interactor la traite comme à main vide (clic = l'attraper, pas lancer). Pas possible avec un objet
## lourd (caisse) : il faut le poser. À surcharger.
func stows_hand_item() -> bool:
	return false


## Après `Use.CLAIM` : l'objet que le joueur va tenir ou occuper (lui-même, ou ex. le caca de sa poignée).
func get_claim() -> Node:
	return self


## Indices (touche → icône) affichés quand le joueur vise la commande. À surcharger.
func get_hints() -> Array[InputHint]:
	return [InputHint.make(&"grab", &"press")]


func set_highlighted(highlighted: bool) -> void:
	for mesh: GeometryInstance3D in _get_highlight_meshes():
		mesh.material_overlay = _highlight_material if highlighted else null


## Vrai si le nain du joueur `peer_id` est à moins de `max_distance` de la commande.
## Utilisé par l'hôte pour valider les demandes.
func is_peer_in_reach(peer_id: int, max_distance: float) -> bool:
	return Dwarf.is_peer_near(peer_id, global_position, max_distance)


## À surcharger : les meshes à surligner quand la commande est visée.
func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	return []
