class_name GarageHoops
extends StaticBody3D
## « Ferraille-Hoops » : panier de basket d'atelier dans le garage (roadmap 4.4).
## - 1er appui sur le râtelier : arme le tir, la jauge de puissance oscille à grande vitesse.
## - 2e appui : déclenche le shoot !
##   * Timing parfait (65% .. 88%) : « SWISH ! », panier direct, son net et étincelles dorées !
##     Un tir de loin (à plus de 2 m) rapporte 3 points, un tir de près 2 points. Les séries font grimper le multiplicateur.
##   * Timing raté (trop fort ou trop mou) : « CLANG ! », le ballon en ferraille ricoche violemment
##     sur l'arceau et part percuter un nain dans la zone (petit vol plané comique et « BONK ! »).
## - Démarre automatiquement une session « 30s Chrono » dès le premier shoot, avec sirène de fin et record d'atelier !
##
## Réseau : l'hôte est autoritaire sur la physique du tir, les scores et les sessions (MultiplayerSynchronizer).
## Les trajectoires, étincelles, sons et projections sont joués via RPC `authority, call_local` et `Dwarf.knock_peer`.

const FLIGHT_DURATION: float = 0.7
const BOUNCE_DURATION: float = 0.45
const HOOP_TARGET: Vector3 = Vector3(0.0, 2.05, 0.18)
const BACKBOARD_HIT: Vector3 = Vector3(0.0, 2.25, -0.14)
const RACK_ORIGIN: Vector3 = Vector3(0.95, 0.95, -0.35)
const SESSION_DURATION: float = 30.0
const CHARGE_MAX_TIME: float = 2.5
const GAUGE_SPEED: float = 4.8
const FONT: FontVariation = preload("res://assets/fonts/fredoka.tres")

## Vrai quand la jauge de tir est armée. Autorité : hôte.
var charging: bool = false
## Chrono restant de la session 30 s (0 = aucune session). Autorité : hôte.
var session_timer: float = 0.0
var session_score: int = 0
var best_session_score: int = 0
var best_session_name: String = ""

## Statistiques globales. Autorité : hôte.
var shots_taken: int = 0
var total_score: int = 0
var streak: int = 0
var best_streak: int = 0
var last_shooter: String = ""
var last_points: int = 0

var _charge_elapsed: float = 0.0
var _armer_peer: int = 0
var _flash_timer: float = 0.0

## Animation locale de vol du ballon.
var _ball_flight_t: float = -1.0
var _ball_start: Vector3 = RACK_ORIGIN
var _ball_target: Vector3 = HOOP_TARGET
var _ball_arc_height: float = 1.35
var _ball_bouncing: bool = false
var _ball_bounce_target: Vector3 = Vector3.ZERO
var _ball_target_peer: int = 0

@onready var _shoot_btn: PushButton = %ShootButton
@onready var _flying_ball: MeshInstance3D = %FlyingBall
@onready var _hoop_light: OmniLight3D = %HoopLight
@onready var _sign: Label3D = %Sign


func _ready() -> void:
	_sign.font = FONT
	_shoot_btn.pressed.connect(_on_shoot_pressed)
	NetworkManager.session_ended.connect(func(_reason: String) -> void:
		charging = false
		session_timer = 0.0
	)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if session_timer > 0.0:
		session_timer -= delta
		if session_timer <= 0.0:
			session_timer = 0.0
			_finish_session()
	if charging:
		_charge_elapsed += delta
		if _charge_elapsed >= CHARGE_MAX_TIME:
			_release_shot(_armer_peer)


func _process(delta: float) -> void:
	_flash_timer = maxf(_flash_timer - delta * 2.5, 0.0)
	_hoop_light.light_energy = 2.8 if _flash_timer > 0.0 else (1.4 if charging else 0.7)
	_hoop_light.light_color = Color(0.25, 1.0, 0.45) if _flash_timer > 0.0 else (Color(1.0, 0.35, 0.15) if charging else Color(1.0, 0.65, 0.25))
	_shoot_btn.lit = charging

	_update_flying_ball(delta)
	_update_sign()


func _update_sign() -> void:
	var title: String = tr("FERRAILLE-HOOPS")
	if session_timer > 0.0:
		_sign.text = "%s — 30s CHRONO : %ds\n%s : %d pts  (%s x%d)\n%s" % [
			title, ceili(session_timer), tr("Score"), session_score, tr("Série"), streak,
			tr("Tirez au pic de la jauge !") if charging else last_shooter
		]
	elif shots_taken > 0:
		var best_txt: String = " | %s : %d (%s)" % [tr("Record 30s"), best_session_score, best_session_name] if best_session_score > 0 else ""
		_sign.text = "%s\n%s : %d pts  (%s x%d)%s\n%s (+%d)" % [
			title, tr("Score"), total_score, tr("Série"), streak, best_txt, last_shooter, last_points
		]
	else:
		_sign.text = "%s\n%s" % [title, tr("Cliquez pour armer la jauge puis tirez !")]


func _update_flying_ball(delta: float) -> void:
	if _ball_flight_t < 0.0:
		_flying_ball.visible = false
		return
	
	_flying_ball.visible = true
	_flying_ball.rotation.x += delta * 14.0
	_flying_ball.rotation.y += delta * 7.0

	var dur: float = BOUNCE_DURATION if _ball_bouncing else FLIGHT_DURATION
	_ball_flight_t += delta / dur
	if _ball_flight_t >= 1.0:
		if not _ball_bouncing and _ball_bounce_target != Vector3.ZERO:
			# Fin du premier arc : impact sur l'arceau, début du ricochet !
			_ball_bouncing = true
			_ball_flight_t = 0.0
			_ball_start = _ball_target
			_ball_target = _ball_bounce_target
			_ball_arc_height = 0.6
			SfxSynth.play(self, &"clang", HOOP_TARGET, 2.0, 1.1)
			PopText.spawn(self, HOOP_TARGET + Vector3(0.0, 0.4, 0.0), tr("CLANG !"), Color(1.0, 0.35, 0.2), 1.2)
			FxBurst.spawn(self, HOOP_TARGET, [Color(1.0, 0.7, 0.2), Color(0.9, 0.9, 0.9)], 14, 3.0)
		else:
			# Fin complète du vol
			if _ball_bouncing:
				SfxSynth.play(self, &"bonk", _ball_target, 2.0, 1.2)
				PopText.spawn(self, _ball_target + Vector3(0.0, 0.5, 0.0), tr("BONK !"), Color(1.0, 0.2, 0.15), 1.4)
			_ball_flight_t = -1.0
			_ball_bouncing = false
			_flying_ball.visible = false
			_flash_timer = 1.0
		return

	var p: Vector3 = _ball_start.lerp(_ball_target, _ball_flight_t)
	p.y += sin(_ball_flight_t * PI) * _ball_arc_height
	_flying_ball.position = p


func _on_shoot_pressed(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not charging:
		charging = true
		_charge_elapsed = 0.0
		_armer_peer = peer_id
		last_shooter = Dwarf.name_of_peer(peer_id)
		if session_timer <= 0.0:
			session_timer = SESSION_DURATION
			session_score = 0
		_play_charge_fx.rpc()
	else:
		_release_shot(peer_id)


func _release_shot(peer_id: int) -> void:
	charging = false
	shots_taken += 1
	var dwarf: Dwarf = Dwarf.of_peer(peer_id)
	var start_local: Vector3 = RACK_ORIGIN
	var dist: float = 1.5
	if dwarf != null:
		start_local = to_local(dwarf.global_position + Vector3(0.0, 0.95, 0.0))
		dist = Vector2(start_local.x, start_local.z).length()

	var ratio: float = absf(sin(_charge_elapsed * GAUGE_SPEED))
	var is_swish: bool = ratio >= 0.60 and ratio <= 0.90
	var shooter_name: String = Dwarf.name_of_peer(peer_id)
	last_shooter = shooter_name

	if is_swish:
		var pts: int = 3 if dist >= 2.0 else 2
		streak += 1
		if streak > best_streak:
			best_streak = streak
		total_score += pts
		session_score += pts
		last_points = pts
		_play_swish_fx.rpc(start_local, pts, streak)
	else:
		streak = 0
		last_points = 0
		# Choix du nain visé par le rebond (le tireur ou un copain proche)
		var victim_peer: int = peer_id
		var victim_local: Vector3 = start_local + Vector3(0.0, -0.4, 0.0)
		var target_dwarf: Dwarf = dwarf
		# Si quelqu'un est devant le panier, on peut lui envoyer dessus !
		for d_node: Node in get_tree().get_nodes_in_group(&"dwarves"):
			var other: Dwarf = d_node as Dwarf
			if other != null and other.peer_id != peer_id:
				var d_pos: Vector3 = to_local(other.global_position)
				if d_pos.length() < 5.0 and randf() < 0.5:
					victim_peer = other.peer_id
					victim_local = d_pos + Vector3(0.0, 0.6, 0.0)
					target_dwarf = other
					break
		
		# Petit coup comique sur la victime
		if target_dwarf != null:
			var push_dir: Vector3 = (target_dwarf.global_position - to_global(HOOP_TARGET)).normalized()
			push_dir.y = 0.0
			Dwarf.knock_peer(victim_peer, push_dir * 2.6 + Vector3.UP * 2.8)

		var target_arceau: Vector3 = BACKBOARD_HIT if ratio > 0.90 else HOOP_TARGET
		_play_brick_fx.rpc(start_local, target_arceau, victim_local, victim_peer)


func _finish_session() -> void:
	if session_score > best_session_score:
		best_session_score = session_score
		best_session_name = last_shooter
	_play_session_end_fx.rpc(session_score)


@rpc("authority", "call_local", "reliable")
func _play_charge_fx() -> void:
	SfxSynth.play(self, &"swish", RACK_ORIGIN, -3.0, 1.4)


@rpc("authority", "call_local", "reliable")
func _play_swish_fx(start_pos: Vector3, pts: int, cur_streak: int) -> void:
	_ball_flight_t = 0.0
	_ball_bouncing = false
	_ball_start = start_pos
	_ball_target = HOOP_TARGET
	_ball_arc_height = 1.35
	_ball_bounce_target = Vector3.ZERO
	_flash_timer = 1.2
	SfxSynth.play(self, &"swish", HOOP_TARGET, 2.0, 0.9)
	SfxSynth.play(self, &"ding", HOOP_TARGET, 1.0, 1.2)
	var txt: String = tr("3 POINTS !") if pts == 3 else tr("PANIER !")
	if cur_streak > 1:
		txt += " (x%d)" % cur_streak
	PopText.spawn(self, HOOP_TARGET + Vector3(0.0, 0.55, 0.0), txt, Color(0.3, 1.0, 0.4), 1.4)
	FxBurst.spawn(self, HOOP_TARGET, [Color(1.0, 0.85, 0.2), Color(0.2, 0.9, 0.4), Color.WHITE], 24, 3.8)


@rpc("authority", "call_local", "reliable")
func _play_brick_fx(start_pos: Vector3, target_hoop: Vector3, bounce_target: Vector3, victim: int) -> void:
	_ball_flight_t = 0.0
	_ball_bouncing = false
	_ball_start = start_pos
	_ball_target = target_hoop
	_ball_arc_height = 1.45
	_ball_bounce_target = bounce_target
	_ball_target_peer = victim


@rpc("authority", "call_local", "reliable")
func _play_session_end_fx(final_pts: int) -> void:
	SfxSynth.play(self, &"buzzer", Vector3(0.0, 2.5, 0.0), 3.0)
	PopText.spawn(self, Vector3(0.0, 3.2, 0.0), "%s : %d pts !" % [tr("FIN DU CHRONO"), final_pts], Color(1.0, 0.6, 0.2), 1.6)
	if final_pts >= 10:
		SfxSynth.play(self, &"fanfare", Vector3(0.0, 2.5, 0.0), 1.0)
