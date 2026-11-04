class_name Dwarf
extends CharacterBody3D
## Nain contrôlé par un joueur. Placeholder M0 : pas encore de déplacement.
## Le nœud porte le peer id de son joueur comme nom, ce qui donne l'autorité.

const SLOT_COLORS: Array[Color] = [
	Color(0.85, 0.25, 0.2),
	Color(0.2, 0.5, 0.9),
	Color(0.3, 0.75, 0.3),
	Color(0.95, 0.75, 0.2),
]

var peer_id: int = 1
var slot: int = 0

@onready var _body_mesh: MeshInstance3D = %BodyMesh
@onready var _name_label: Label3D = %NameLabel


func _enter_tree() -> void:
	# Le nom est fixé par le spawner avant l'ajout à l'arbre, sur tous les peers.
	peer_id = name.to_int()
	set_multiplayer_authority(peer_id)


func _ready() -> void:
	_apply_slot_visuals()


## Appelé par le spawner avant add_child, avec les mêmes données sur tous les peers.
func setup(p_peer_id: int, p_slot: int) -> void:
	peer_id = p_peer_id
	slot = p_slot
	name = str(p_peer_id)


func _apply_slot_visuals() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = SLOT_COLORS[slot % SLOT_COLORS.size()]
	_body_mesh.material_override = material
	var suffix: String = " (toi)" if is_multiplayer_authority() else ""
	_name_label.text = "Joueur %d%s" % [slot + 1, suffix]
