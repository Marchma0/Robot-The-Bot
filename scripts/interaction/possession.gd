class_name Possession
extends RefCounted
## Ce qu'un joueur tient ou occupe : un levier, un siège, la corde, un caca ou les fléchettes du robot.
## Un joueur n'en a qu'un à la fois. Chacun de ces objets se range dans le groupe `GROUP`.
##
## Réseau : l'hôte appelle `is_peer_busy` avant d'accepter une demande (attraper, s'asseoir, ramasser…).
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
	if node is Poop:
		return (node as Poop).holder_peer_id
	if node is DartsGame:
		return (node as DartsGame).thrower_peer_id
	return 0


## Vrai si le joueur `peer_id` tient ou occupe déjà quelque chose (autre que `except`).
static func is_peer_busy(tree: SceneTree, peer_id: int, except: Node = null) -> bool:
	for node: Node in tree.get_nodes_in_group(GROUP):
		if node != except and holder_of(node) == peer_id:
			return true
	return false
