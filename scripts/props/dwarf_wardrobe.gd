class_name DwarfWardrobe
extends StaticBody3D
## Vestiaire des nains dans le garage (roadmap 2.4 / 4.5).
## Trois boutons poussoirs devant le miroir éclairé :
## - `PrevSkin` / `NextSkin` : changent la tenue complète et le couvre-chef 3D du nain qui appuie
##   (Mineur Classique, Garagiste Soudeur, Baron Cuivre) ;
## - `CycleColor` : change la couleur de la combinaison du nain qui appuie (6 couleurs d'atelier).
##
## Réseau : les boutons sont des `PushButton` (l'hôte valide la portée et émet `pressed(peer_id)`).
## L'hôte met à jour le nain du joueur (`set_wardrobe_look.rpc`) ainsi que l'affichage du vestiaire
## (`last_skin`, `last_color`, `last_player`, synchronisés par MultiplayerSynchronizer).

const FONT: FontVariation = preload("res://assets/fonts/fredoka.tres")

## Dernier skin choisi au vestiaire (affiché sur l'enseigne). Autorité : hôte.
var last_skin: int = 0
## Dernière couleur choisie au vestiaire. Autorité : hôte.
var last_color: int = 0
## Nom du dernier nain passé au vestiaire. Autorité : hôte.
var last_player: String = ""

@onready var _prev_btn: PushButton = %PrevSkin
@onready var _next_btn: PushButton = %NextSkin
@onready var _color_btn: PushButton = %CycleColor
@onready var _sign: Label3D = %Sign


func _ready() -> void:
	_sign.font = FONT
	_prev_btn.pressed.connect(_on_skin_step.bind(-1))
	_next_btn.pressed.connect(_on_skin_step.bind(1))
	_color_btn.pressed.connect(_on_color_step)


func _process(_delta: float) -> void:
	var header: String = tr("VESTIAIRE DES NAINS")
	var skin_str: String = "%s : %s" % [tr("Tenue"), DwarfLook.skin_title(last_skin)]
	var col_str: String = "%s : %s" % [tr("Couleur"), DwarfLook.color_title(last_color)]
	if last_player != "":
		_sign.text = "%s\n%s — %s\n%s" % [header, last_player, skin_str, col_str]
	else:
		_sign.text = "%s\n%s\n%s" % [header, skin_str, col_str]


func _on_skin_step(peer_id: int, step: int) -> void:
	if not multiplayer.is_server():
		return
	var dwarf: Dwarf = Dwarf.of_peer(peer_id)
	if dwarf == null:
		return
	var next_skin: int = posmod(dwarf.skin_index + step, DwarfLook.SKIN_COUNT)
	var cur_color: int = dwarf.color_index if dwarf.color_index >= 0 else (dwarf.slot % DwarfLook.SLOT_COLORS.size())
	last_skin = next_skin
	last_color = cur_color
	last_player = dwarf.get_display_name()
	dwarf.set_wardrobe_look.rpc(next_skin, dwarf.color_index)


func _on_color_step(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var dwarf: Dwarf = Dwarf.of_peer(peer_id)
	if dwarf == null:
		return
	var base_color: int = dwarf.color_index if dwarf.color_index >= 0 else (dwarf.slot % DwarfLook.SLOT_COLORS.size())
	var next_color: int = posmod(base_color + 1, DwarfLook.SLOT_COLORS.size())
	last_skin = dwarf.skin_index
	last_color = next_color
	last_player = dwarf.get_display_name()
	dwarf.set_wardrobe_look.rpc(dwarf.skin_index, next_color)
