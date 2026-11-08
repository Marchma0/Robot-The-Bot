class_name Possession
extends RefCounted
## Ce qu'un joueur tient ou occupe : un levier, un siège ou la corde. Un seul à la fois, et il faut
## avoir la main vide (aucun objet de l'inventaire en main, voir Inventory). Chacun de ces objets se range
## dans le groupe `GROUP`.
##
## Réseau : l'hôte appelle `is_peer_busy` avant d'accepter une demande (attraper, s'asseoir…), et
## `holds_control` avant de laisser ramasser un objet dans l'inventaire.
## Rien n'est stocké ici : la réponse se déduit des porteurs déjà répliqués de chaque objet,
## donc elle ne peut pas se désynchroniser.
## Nouveau type d'objet qu'on tient : l'ajouter dans `holder_of`, et à `GROUP` dans son `_ready`.

const GROUP: StringName = &"possessions"


## Peer qui tient ou occupe `node` (0 = personne).
static func holder_of(node: Node) -> int:
	if node is Lever:
		return (node as Lever).holder_peer_id
	if node is Seat:
		return (node as Seat).occupant_peer_id
	if node is Rope:
		return (node as Rope).holder_peer_id
	return 0


## Vrai si le joueur `peer_id` ne peut pas prendre un levier, un siège ou la corde : il tient ou occupe
## déjà quelque chose (autre que `except`), ou il a un objet en main.
static func is_peer_busy(tree: SceneTree, peer_id: int, except: Node = null) -> bool:
	return holds_control(tree, peer_id, except) or Inventory.has_item_in_hand(tree, peer_id)


## Vrai si le joueur `peer_id` tient un levier, la corde, ou est assis (autre que `except`).
static func holds_control(tree: SceneTree, peer_id: int, except: Node = null) -> bool:
	for node: Node in tree.get_nodes_in_group(GROUP):
		if node != except and holder_of(node) == peer_id:
			return true
	return false
