class_name GarageHoops
extends StaticBody3D
## « Ferraille-Hoops » : panier de basket d'atelier dans le garage (roadmap 4.4).
## Un appui sur le bouton du râtelier à ballons lance un ballon de ferraille en cloche vers l'arceau
## de cuivre. Un tir de loin (à plus de 2,1 m du panneau) vaut 3 points, un tir de près vaut 2 points,
## et les paniers d'affilée font monter la série !
##
## Réseau : l'hôte est seul autoritaire sur `shots_taken`, `total_score`, `streak`, `last_shooter` et
## `best_streak` (répliqués par MultiplayerSynchronizer). La trajectoire en cloche du ballon est jouée
## chez tous les peers via un RPC `authority, call_local`.

const FLIGHT_DURATION: float = 0.75
const HOOP_TARGET: Vector3 = Vector3(0.0, 2.52, -0.45)
const RACK_ORIGIN: Vector3 = Vector3(0.95, 0.95, -0.35)
const FONT: FontVariation = preload("res://assets/fonts/fredoka.tres")

## Nombre total de tirs tentés. Autorité : hôte.
var shots_taken: int = 0
## Score total cumulé de l'équipe au panier. Autorité : hôte.
var total_score: int = 0
## Série actuelle de paniers réussis. Autorité : hôte.
var streak: int = 0
var best_streak: int = 0
var last_shooter: String = ""
var last_points: int = 0

var _flight_t: float = -1.0
var _flight_from: Vector3 = RACK_ORIGIN
var _flash_timer: float = 0.0

@onready var _shoot_btn: PushButton = %ShootButton
@onready var _flying_ball: MeshInstance3D = %FlyingBall
@onready var _hoop_light: OmniLight3D = %HoopLight
@onready var _sign: Label3D = %Sign


func _ready() -> void:
	_sign.font = FONT
	_shoot_btn.pressed.connect(_on_shoot_pressed)


func _process(delta: float) -> void:
	_flash_timer = maxf(_flash_timer - delta * 2.5, 0.0)
	_hoop_light.light_energy = 2.8 if _flash_timer > 0.0 else 0.7
	_hoop_light.light_color = Color(0.25, 1.0, 0.45) if _flash_timer > 0.0 else Color(1.0, 0.65, 0.25)

	if _flight_t >= 0.0:
		_flight_t += delta / FLIGHT_DURATION
		if _flight_t >= 1.0:
			_flying_ball.visible = false
			_flight_t = -1.0
			_flash_timer = 1.0
		else:
			_flying_ball.visible = true
			var p: Vector3 = _flight_from.lerp(HOOP_TARGET, _flight_t)
			p.y += sin(_flight_t * PI) * 1.35
			_flying_ball.position = p
			_flying_ball.rotation.x += delta * 12.0

	var title: String = tr("FERRAILLE-HOOPS")
	if shots_taken > 0:
		_sign.text = "%s\n%s : %d pts  (%s x%d)\n%s (+%d)" % [
			title, tr("Score"), total_score, tr("Série"), streak, last_shooter, last_points
		]
	else:
		_sign.text = "%s\n%s" % [title, tr("Tirez au panier !")]


func _on_shoot_pressed(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var dwarf: Dwarf = Dwarf.of_peer(peer_id)
	var start_local: Vector3 = RACK_ORIGIN
	var dist: float = 1.5
	if dwarf != null:
		start_local = to_local(dwarf.global_position + Vector3(0.0, 0.95, 0.0))
		dist = Vector2(start_local.x, start_local.z).length()
	var pts: int = 3 if dist >= 2.0 else 2
	shots_taken += 1
	streak += 1
	if streak > best_streak:
		best_streak = streak
	total_score += pts
	last_points = pts
	last_shooter = Dwarf.name_of_peer(peer_id)
	_play_shot_arc.rpc(start_local)


@rpc("authority", "call_local", "reliable")
func _play_shot_arc(start_local: Vector3) -> void:
	_flight_from = start_local
	_flight_t = 0.0
	_flying_ball.position = start_local
	_flying_ball.visible = true
