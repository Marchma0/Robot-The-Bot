class_name Inventory
extends RefCounted
## Inventaire d'un nain : `SIZE` cases (barre en bas de l'écran). L'objet de la case choisie
## (`Dwarf.hand_slot`) est dans sa main : il le lance (clic) ou le pose (G). Les autres sont rangés.
## Un caca prend une case, les fléchettes du robot en prennent une pour toutes.
##
## Réseau : rien n'est stocké ici. Chaque objet qu'on peut avoir sur soi garde lui-même, dans son état
## synchronisé par l'hôte, qui l'a et dans quelle case ; le contenu des cases s'en déduit, donc il ne peut
## pas se désynchroniser. La case choisie est écrite par le joueur sur son nain (répliquée).
## L'hôte choisit la case d'un objet ramassé (`free_slot`) et refuse s'il n'y en a plus.
##
## Un objet qu'on peut avoir sur soi se range dans le groupe `GROUP` et a ces méthodes :
## - `inventory_entries(peer_id: int) -> Array[Dictionary]` : ce que ce joueur en a, une entrée par case
##   occupée : {"slot": int, "icon": StringName (icône de assets/textures/ui/icons/), "count": int} ;
## - `throw_from_hand(origin: Vector3, direction: Vector3) -> void` : joueur local, le lancer (demande à l'hôte) ;
## - `drop_from_hand() -> void` : joueur local, le poser (demande à l'hôte).

const SIZE: int = 5
const GROUP: StringName = &"inventory_items"


## Les cases du joueur `peer_id` : `SIZE` entrées, {} = vide, sinon {"icon", "count", "node"}.
static func slots_of(tree: SceneTree, peer_id: int) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for i: int in SIZE:
		slots.append({})
	if peer_id == 0:
		return slots
	for node: Node in tree.get_nodes_in_group(GROUP):
		var entries: Array[Dictionary] = node.call(&"inventory_entries", peer_id)
		for entry: Dictionary in entries:
			var index: int = entry["slot"]
			if index < 0 or index >= SIZE:
				continue
			if slots[index].is_empty():
				slots[index] = {"icon": entry["icon"], "count": entry["count"], "node": node}
			else:
				slots[index]["count"] += entry["count"]
	return slots


## Hôte : la case où ranger un nouvel objet du joueur, -1 si tout est plein.
## La case en main si elle est libre, sinon la première libre.
static func free_slot(tree: SceneTree, peer_id: int) -> int:
	var slots: Array[Dictionary] = slots_of(tree, peer_id)
	var hand: int = hand_slot_of(peer_id)
	if slots[hand].is_empty():
		return hand
	for i: int in SIZE:
		if slots[i].is_empty():
			return i
	return -1


## La case choisie par le joueur (celle dont l'objet est en main).
static func hand_slot_of(peer_id: int) -> int:
	var dwarf: Dwarf = Dwarf.of_peer(peer_id)
	return clampi(dwarf.hand_slot, 0, SIZE - 1) if dwarf != null else 0


## L'objet que le joueur a en main : {} si sa case choisie est vide.
static func item_in_hand(tree: SceneTree, peer_id: int) -> Dictionary:
	return slots_of(tree, peer_id)[hand_slot_of(peer_id)]


static func has_item_in_hand(tree: SceneTree, peer_id: int) -> bool:
	return not item_in_hand(tree, peer_id).is_empty()
