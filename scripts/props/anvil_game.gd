class_name AnvilGame
extends StaticBody3D
## « Forge Naine » : mini-jeu d'enclume rythmique dans le coin forge du garage (roadmap 4.4).
## Le lingot incandescent sur l'enclume pulse en température : 3 coups de marteau bien rythmés
## (bouton de frappe devant l'enclume) forgent un Pignon d'Or ! Frapper quand l'anneau de chaleur
## est au plus vif rapporte un bonus de qualité maximale.
##
## Réseau : l'hôte est seul autoritaire sur `total_strikes`, `current_strikes`, `forged_ingots`,
## `last_quality`, `last_smith`, `best_quality` et `best_smith` (répliqués par MultiplayerSynchronizer).
## Chaque coup de marteau déclenche un RPC `authority, call_local` pour animer l'abattement du marteau
## et la gerbe d'étincelles chez tous les joueurs.

const STRIKES_PER_INGOT: int = 3
const HEAT_SPEED: float = 4.6
const FONT: FontVariation = preload("res://assets/fonts/fredoka.tres")

## Nombre total de coups de marteau donnés. Autorité : hôte.
var total_strikes: int = 0
## Coups sur le lingot en cours (0 .. STRIKES_PER_INGOT - 1). Autorité : hôte.
var current_strikes: int = 0
## Nombre de lingots forgés au total. Autorité : hôte.
var forged_ingots: int = 0
var last_quality: int = 0
var last_smith: String = ""
var best_quality: int = 0
var best_smith: String = ""

var _heat_clock: float = 0.0
var _hammer_anim: float = 0.0
var _spark_timer: float = 0.0
var _current_quality_accum: int = 0

@onready var _strike_btn: PushButton = %StrikeButton
@onready var _hammer_pivot: Node3D = %HammerPivot
@onready var _heat_ring: MeshInstance3D = %HeatRing
@onready var _sparks: Node3D = %Sparks
@onready var _forge_light: OmniLight3D = %ForgeLight
@onready var _sign: Label3D = %Sign


func _ready() -> void:
	_sign.font = FONT
	_strike_btn.pressed.connect(_on_strike_pressed)


func _physics_process(delta: float) -> void:
	_heat_clock += delta


func _process(delta: float) -> void:
	_hammer_anim = maxf(_hammer_anim - delta * 4.5, 0.0)
	_spark_timer = maxf(_spark_timer - delta * 3.0, 0.0)
	_sparks.visible = _spark_timer > 0.0
	if _spark_timer > 0.0:
		_sparks.rotation.y += delta * 18.0

	var heat: float = _heat_ratio()
	var s: float = lerpf(0.65, 1.35, heat)
	_heat_ring.scale = Vector3(s, 1.0, s)
	_strike_btn.lit = heat > 0.72
	_hammer_pivot.rotation.z = sin(_hammer_anim * PI) * 0.95
	_forge_light.light_energy = 2.8 if _spark_timer > 0.0 else lerpf(0.9, 1.8, heat)

	var title: String = tr("FORGE NAINE")
	var progress: String = "%s : %d / %d" % [tr("Martelage"), current_strikes, STRIKES_PER_INGOT]
	if forged_ingots > 0:
		_sign.text = "%s\n%s  |  %s : %d\n%s : %d%% (%s)" % [
			title, progress, tr("Forgés"), forged_ingots, tr("Qualité max"), best_quality, best_smith
		]
	elif total_strikes > 0:
		_sign.text = "%s\n%s — %s" % [title, last_smith, progress]
	else:
		_sign.text = "%s\n%s" % [title, tr("Frappez en rythme au pic de chaleur !")]


func _on_strike_pressed(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var smith: String = Dwarf.name_of_peer(peer_id)
	var heat: float = _heat_ratio()
	var strike_qual: int = clampi(roundi(lerpf(20.0, 35.0, heat)), 15, 35)
	total_strikes += 1
	last_smith = smith
	if current_strikes == 0:
		_current_quality_accum = 0
	_current_quality_accum += strike_qual
	current_strikes += 1
	if current_strikes >= STRIKES_PER_INGOT:
		current_strikes = 0
		forged_ingots += 1
		last_quality = clampi(_current_quality_accum, 50, 100)
		if last_quality > best_quality:
			best_quality = last_quality
			best_smith = smith
	_play_hammer_fx.rpc()


func _heat_ratio() -> float:
	return 0.5 + 0.5 * sin(_heat_clock * HEAT_SPEED)


@rpc("authority", "call_local", "reliable")
func _play_hammer_fx() -> void:
	_hammer_anim = 1.0
	_spark_timer = 0.35
