class_name PunchMachine
extends StaticBody3D
## « Punch-O-Mètre » du garage : borne de coup de poing à réflexe (roadmap 4.4).
## - 1er appui sur le bouton de frappe : lance la jauge de puissance qui oscille à grande vitesse ;
## - 2e appui au bon moment (quand le curseur est tout en haut) : déclenche le coup de poing !
##   Le sac de frappe s'envole, le score (0 .. 999) s'affiche et la cloche sonne au-dessus de 800 points.
##
## Réseau : l'hôte est seul autoritaire sur `charging`, `strike_count`, `last_score`, `last_player`,
## `best_score` et `best_name` (répliqués par MultiplayerSynchronizer). L'impact déclenche un RPC
## `authority, call_local` pour animer le sac de frappe et le flash de la cloche chez tout le monde.

const MAX_CHARGE_TIME: float = 4.5
const GAUGE_SPEED: float = 4.2
const FONT: FontVariation = preload("res://assets/fonts/fredoka.tres")

## Vrai quand la jauge oscille en attente du second clic (le coup). Autorité : hôte.
var charging: bool = false
## Nombre de coups ou d'amorçages déclenchés. Autorité : hôte.
var strike_count: int = 0
var last_score: int = 0
var last_player: String = ""
var best_score: int = 0
var best_name: String = ""

var _charge_elapsed: float = 0.0
var _bag_swing: float = 0.0
var _bell_flash: float = 0.0

@onready var _hit_btn: PushButton = %HitButton
@onready var _cursor_mesh: MeshInstance3D = %GaugeCursor
@onready var _bell_light: OmniLight3D = %BellLight
@onready var _sign: Label3D = %Sign


func _ready() -> void:
	_sign.font = FONT
	_hit_btn.pressed.connect(_on_hit_pressed)


func _physics_process(delta: float) -> void:
	if charging:
		_charge_elapsed += delta
		if multiplayer.is_server() and _charge_elapsed >= MAX_CHARGE_TIME:
			_finish_strike(last_player)


func _process(delta: float) -> void:
	_bag_swing = maxf(_bag_swing - delta * 2.2, 0.0)
	_bell_flash = maxf(_bell_flash - delta * 2.5, 0.0)
	_hit_btn.lit = charging

	var ratio: float = _current_ratio() if charging else clampf(float(last_score) / 999.0, 0.05, 1.0)
	_cursor_mesh.position.y = lerpf(0.55, 2.05, ratio)
	_bell_light.light_energy = 3.2 if _bell_flash > 0.0 else (1.1 if charging else 0.4)
	_bell_light.light_color = Color(1.0, 0.85, 0.20) if _bell_flash > 0.0 else Color(1.0, 0.35, 0.18)

	var title: String = tr("PUNCH-O-MÈTRE")
	if charging:
		_sign.text = "%s\n%s — %s" % [title, last_player, tr("Frappez au sommet !")]
	elif last_score > 0:
		var rec: String = "%s : %d (%s)" % [tr("Record"), best_score, best_name]
		_sign.text = "%s\n%s : %d pts\n%s" % [title, last_player, last_score, rec]
	else:
		_sign.text = "%s\n%s" % [title, tr("Cliquez pour armer puis frapper")]


func _on_hit_pressed(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var p_name: String = Dwarf.name_of_peer(peer_id)
	strike_count += 1
	if not charging:
		charging = true
		_charge_elapsed = 0.0
		last_player = p_name
		_start_charge_fx.rpc()
	else:
		_finish_strike(p_name)


func _finish_strike(p_name: String) -> void:
	var ratio: float = _current_ratio()
	# Courbe généreuse près du sommet pour récompenser le bon timing.
	var points: int = clampi(roundi(pow(ratio, 0.75) * 999.0), 50, 999)
	charging = false
	last_score = points
	last_player = p_name
	if points > best_score:
		best_score = points
		best_name = p_name
	_play_strike_fx.rpc(points)


func _current_ratio() -> float:
	return absf(sin(_charge_elapsed * GAUGE_SPEED))


@rpc("authority", "call_local", "reliable")
func _start_charge_fx() -> void:
	_charge_elapsed = 0.0


@rpc("authority", "call_local", "reliable")
func _play_strike_fx(points: int) -> void:
	_bag_swing = 1.0
	if points >= 800:
		_bell_flash = 1.0
