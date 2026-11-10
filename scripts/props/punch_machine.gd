class_name PunchMachine
extends StaticBody3D
## « Punch-O-Mètre » du garage : borne de coup de poing (roadmap 4.4).
## - 1er appui sur le sac de frappe : la jauge de puissance se met à osciller, de plus en plus vite ;
## - 2e appui (par n'importe qui !) : le coup part. Au sommet de la jauge, le sac s'envole, la cloche sonne,
##   et au-delà de 900 points l'onde de choc souffle les nains autour.
## - Coup mou (ou trop lent à frapper) : la machine se vexe, un gant de boxe à ressort jaillit et renvoie
##   le frappeur en arrière.
##
## Réseau : l'hôte est seul autoritaire sur `charging`, `strike_count`, `last_score`, `last_player`,
## `best_score` et `best_name` (répliqués par MultiplayerSynchronizer). Le coup, le gant et l'onde de choc sont
## des effets d'un instant : RPC `authority, call_local` ; les projections passent par `Dwarf.knock_peer`.

## Temps max pour frapper une fois la jauge lancée (s), au-delà : « Trop lent ! » et le gant part.
const MAX_CHARGE_TIME: float = 4.0
## Vitesse de départ de la jauge, et accélération (la jauge oscille de plus en plus vite).
const GAUGE_SPEED: float = 3.6
const GAUGE_ACCEL: float = 0.5
## En dessous de ce score, le gant riposte.
const WEAK_SCORE: int = 350
## À partir de ce score, cloche ; à partir du suivant, onde de choc.
const BELL_SCORE: int = 800
const MONSTER_SCORE: int = 900
## Projections (m/s) : légères, juste de quoi reculer de 1 à 2 m.
const GLOVE_PUSH: float = 3.2
const GLOVE_LIFT: float = 3.0
const SHOCK_PUSH: float = 2.4
const SHOCK_LIFT: float = 2.6
const SHOCK_RADIUS: float = 4.0
## Le sac pend sous la potence, à cette place (repère de la borne).
const BAG_PIVOT: Vector3 = Vector3(0.0, 1.46, -0.27)
const BAG_LENGTH: float = 0.62
const BAG_RADIUS: float = 0.17
## Gant de boxe : sort du flanc de la colonne, à hauteur de nain, vers l'avant (-Z).
const GLOVE_ORIGIN: Vector3 = Vector3(0.3, 0.95, 0.0)
const GLOVE_REACH: float = 1.15
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
## Hôte : celui qui a lancé la jauge (le gant le vise s'il ne frappe pas à temps).
var _armer_peer: int = 0
var _bag_time: float = -1.0
var _bag_power: float = 0.0
var _bell_flash: float = 0.0
var _glove_time: float = -1.0
var _glove: Node3D
var _glove_arm: MeshInstance3D

@onready var _hit_btn: PushButton = %HitButton
@onready var _cursor_mesh: MeshInstance3D = %GaugeCursor
@onready var _bell_light: OmniLight3D = %BellLight
@onready var _sign: Label3D = %Sign


func _ready() -> void:
	_sign.font = FONT
	_make_bag()
	_make_glove()
	_hit_btn.pressed.connect(_on_hit_pressed)
	NetworkManager.session_ended.connect(func(_reason: String) -> void: charging = false)


func _physics_process(delta: float) -> void:
	if charging:
		_charge_elapsed += delta
		if multiplayer.is_server() and _charge_elapsed >= MAX_CHARGE_TIME:
			_too_slow()


func _process(delta: float) -> void:
	_bell_flash = maxf(_bell_flash - delta * 2.0, 0.0)
	_hit_btn.lit = charging
	_animate_bag(delta)
	_animate_glove(delta)

	var ratio: float = _current_ratio() if charging else clampf(float(last_score) / 999.0, 0.05, 1.0)
	_cursor_mesh.position.y = lerpf(0.28, 1.38, ratio)
	var flash_on: bool = _bell_flash > 0.0 and fmod(_bell_flash * 10.0, 1.0) > 0.4
	_bell_light.light_energy = 4.0 if flash_on else (1.1 if charging else 0.4)
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
	strike_count += 1
	if not charging:
		charging = true
		_charge_elapsed = 0.0
		_armer_peer = peer_id
		last_player = Dwarf.name_of_peer(peer_id)
		_start_charge_fx.rpc()
	else:
		_finish_strike(peer_id)


func _finish_strike(peer_id: int) -> void:
	var ratio: float = _current_ratio()
	# Courbe généreuse près du sommet pour récompenser le bon timing.
	var points: int = clampi(roundi(pow(ratio, 0.75) * 999.0), 50, 999)
	var p_name: String = Dwarf.name_of_peer(peer_id)
	charging = false
	last_score = points
	last_player = p_name
	var record: bool = points > best_score
	if record:
		best_score = points
		best_name = p_name
	_play_strike_fx.rpc(points, record)
	if points < WEAK_SCORE:
		_glove_punch(peer_id)
	elif points >= MONSTER_SCORE:
		_shockwave(peer_id)


## Hôte : personne n'a frappé à temps. Le gant part sur celui qui avait lancé la jauge.
func _too_slow() -> void:
	charging = false
	last_score = 0
	_play_too_slow_fx.rpc()
	_glove_punch(_armer_peer)


## Hôte : le gant jaillit et repousse le nain `peer_id` loin de la borne.
func _glove_punch(peer_id: int) -> void:
	_play_glove_fx.rpc()
	Dwarf.knock_peer(peer_id, _push_from_machine(peer_id, GLOVE_PUSH, GLOVE_LIFT))


## Hôte : onde de choc d'un coup monstrueux, elle souffle les autres nains proches (pas le frappeur).
func _shockwave(striker: int) -> void:
	for node: Node in get_tree().get_nodes_in_group(&"dwarves"):
		var dwarf: Dwarf = node as Dwarf
		if dwarf == null or dwarf.peer_id == striker:
			continue
		if dwarf.global_position.distance_to(global_position) <= SHOCK_RADIUS:
			Dwarf.knock_peer(dwarf.peer_id, _push_from_machine(dwarf.peer_id, SHOCK_PUSH, SHOCK_LIFT))


## Vitesse qui éloigne le nain `peer_id` de la borne (à plat), plus un petit coup vers le haut.
func _push_from_machine(peer_id: int, push: float, lift: float) -> Vector3:
	var dwarf: Dwarf = Dwarf.of_peer(peer_id)
	var away: Vector3 = -global_basis.z
	if dwarf != null:
		var flat: Vector3 = dwarf.global_position - global_position
		flat.y = 0.0
		if flat.length() > 0.05:
			away = flat.normalized()
	return away * push + Vector3.UP * lift


## Hauteur de la jauge (0..1) : elle oscille de plus en plus vite depuis le lancement.
func _current_ratio() -> float:
	var phase: float = GAUGE_SPEED * (_charge_elapsed + GAUGE_ACCEL * _charge_elapsed * _charge_elapsed)
	return absf(sin(phase))


@rpc("authority", "call_local", "reliable")
func _start_charge_fx() -> void:
	_charge_elapsed = 0.0
	SfxSynth.play(self, &"swish", BAG_PIVOT, -4.0, 1.6)


@rpc("authority", "call_local", "reliable")
func _play_strike_fx(points: int, record: bool) -> void:
	_bag_time = 0.0
	_bag_power = clampf(float(points) / 999.0, 0.1, 1.0)
	var bag_pos: Vector3 = BAG_PIVOT + Vector3(0.0, -BAG_LENGTH * 0.6, 0.0)
	SfxSynth.play(self, &"punch", bag_pos, 0.0, lerpf(1.3, 0.75, _bag_power))
	var pop_pos: Vector3 = Vector3(0.0, 2.75, -0.3)
	if points >= MONSTER_SCORE:
		_bell_flash = 1.6
		SfxSynth.play(self, &"bell", Vector3(0.0, 2.3, 0.18), 2.0)
		PopText.spawn(self, pop_pos, tr("MONSTRUEUX !"), Color(1.0, 0.3, 0.15), 1.6)
		FxBurst.spawn(self, Vector3(0.0, 2.4, 0.0), [Color(1.0, 0.85, 0.2), Color(1.0, 0.5, 0.1), Color.WHITE], 36, 5.0)
	elif points >= BELL_SCORE:
		_bell_flash = 1.0
		SfxSynth.play(self, &"bell", Vector3(0.0, 2.3, 0.18))
		PopText.spawn(self, pop_pos, tr("BRUTAL !"), Color(1.0, 0.6, 0.15), 1.3)
		FxBurst.spawn(self, Vector3(0.0, 2.4, 0.0), [Color(1.0, 0.85, 0.2), Color.WHITE], 18, 3.5)
	elif points >= 600:
		PopText.spawn(self, pop_pos, tr("Costaud !"), Color(1.0, 0.85, 0.3), 1.1)
	elif points >= WEAK_SCORE:
		PopText.spawn(self, pop_pos, tr("Pas mal…"), Color(0.85, 0.9, 1.0), 1.0)
	elif points >= 200:
		PopText.spawn(self, pop_pos, tr("Chatouille !"), Color(1.0, 0.6, 0.85), 1.1)
	else:
		PopText.spawn(self, pop_pos, tr("Bisou…"), Color(1.0, 0.45, 0.75), 1.2)
	if record and points >= WEAK_SCORE:
		SfxSynth.play(self, &"fanfare", Vector3(0.0, 2.3, 0.0), -2.0)
		PopText.spawn(self, pop_pos + Vector3(0.0, 0.45, 0.0), tr("RECORD !"), Color(0.4, 1.0, 0.5), 0.9)


@rpc("authority", "call_local", "reliable")
func _play_too_slow_fx() -> void:
	SfxSynth.play(self, &"buzzer", Vector3(0.0, 2.2, 0.0), -3.0)
	PopText.spawn(self, Vector3(0.0, 2.75, -0.3), tr("Trop lent !"), Color(0.75, 0.85, 1.0), 1.2)


@rpc("authority", "call_local", "reliable")
func _play_glove_fx() -> void:
	_glove_time = 0.0
	SfxSynth.play(self, &"boing", GLOVE_ORIGIN, 0.0)
	SfxSynth.play(self, &"punch", GLOVE_ORIGIN + Vector3(0.0, 0.0, -GLOVE_REACH), 2.0, 1.2)


## Sac de frappe : se balance après un coup (un tour complet sur un coup monstrueux), puis se calme.
func _animate_bag(delta: float) -> void:
	if _bag_time < 0.0:
		_hit_btn.rotation.x = 0.0
		return
	_bag_time += delta
	var angle: float
	if _bag_power >= float(MONSTER_SCORE) / 999.0 and _bag_time < 0.55:
		angle = -TAU * smoothstep(0.0, 0.55, _bag_time)   # tour complet par-dessus la potence
	else:
		var t: float = _bag_time - (0.55 if _bag_power >= float(MONSTER_SCORE) / 999.0 else 0.0)
		angle = -sin(t * 7.0) * exp(-t * 2.2) * lerpf(0.25, 1.4, _bag_power)
	_hit_btn.rotation.x = angle
	if _bag_time > 3.0:
		_bag_time = -1.0


## Gant de boxe : jaillit d'un coup (ressort), reste une fraction de seconde, puis rentre en tremblant.
func _animate_glove(delta: float) -> void:
	if _glove_time < 0.0:
		_glove.visible = false
		return
	_glove_time += delta
	var ext: float
	if _glove_time < 0.09:
		ext = _glove_time / 0.09
	elif _glove_time < 0.35:
		ext = 1.0 + sin((_glove_time - 0.09) * 40.0) * 0.06 * (0.35 - _glove_time) / 0.26
	else:
		ext = maxf(1.0 - (_glove_time - 0.35) / 0.4, 0.0)
	_glove.visible = ext > 0.01
	var reach: float = GLOVE_REACH * ext
	_glove.position = GLOVE_ORIGIN + Vector3(0.0, 0.0, -reach)
	_glove_arm.scale = Vector3(1.0, 1.0, maxf(reach, 0.01))
	_glove_arm.position = Vector3(0.0, 0.0, reach * 0.5)
	if _glove_time > 0.8:
		_glove_time = -1.0


## Le bouton de frappe devient le sac : son chapeau prend la forme d'un sac de cuir pendu sous la potence
## (il brille quand il faut frapper, et le contour s'affiche quand on le vise).
func _make_bag() -> void:
	var cap: MeshInstance3D = _hit_btn.get_node(^"Cap") as MeshInstance3D
	var btn_scale: float = _hit_btn.scale.x
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = BAG_RADIUS / btn_scale
	capsule.height = BAG_LENGTH / btn_scale
	capsule.radial_segments = 12
	capsule.rings = 3
	cap.mesh = capsule
	cap.position.y = -BAG_LENGTH * 0.5 / btn_scale
	(_hit_btn.get_node(^"Base") as Node3D).visible = false
	# Chaîne entre la potence et le sac.
	var chain: MeshInstance3D = MeshInstance3D.new()
	var chain_mesh: CylinderMesh = CylinderMesh.new()
	chain_mesh.top_radius = 0.015 / btn_scale
	chain_mesh.bottom_radius = 0.015 / btn_scale
	chain_mesh.height = 0.12 / btn_scale
	chain_mesh.radial_segments = 6
	chain.mesh = chain_mesh
	chain.material_override = _flat_material(Color(0.35, 0.35, 0.38), 0.8)
	chain.position = Vector3(0.0, -0.06 / btn_scale, 0.0)
	_hit_btn.add_child(chain)


## Gant de boxe rouge au bout d'un bras en accordéon, caché tant qu'il ne sort pas.
func _make_glove() -> void:
	_glove = Node3D.new()
	_glove.position = GLOVE_ORIGIN
	_glove.visible = false
	add_child(_glove)
	var fist: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.26
	sphere.radial_segments = 12
	sphere.rings = 6
	fist.mesh = sphere
	fist.material_override = _flat_material(Color(0.85, 0.08, 0.06), 0.1)
	_glove.add_child(fist)
	var thumb: MeshInstance3D = MeshInstance3D.new()
	var thumb_mesh: SphereMesh = SphereMesh.new()
	thumb_mesh.radius = 0.06
	thumb_mesh.height = 0.12
	thumb.mesh = thumb_mesh
	thumb.material_override = fist.material_override
	thumb.position = Vector3(-0.12, 0.04, -0.02)
	_glove.add_child(thumb)
	var cuff: MeshInstance3D = MeshInstance3D.new()
	var cuff_mesh: CylinderMesh = CylinderMesh.new()
	cuff_mesh.top_radius = 0.1
	cuff_mesh.bottom_radius = 0.1
	cuff_mesh.height = 0.08
	cuff_mesh.radial_segments = 10
	cuff.mesh = cuff_mesh
	cuff.material_override = _flat_material(Color(0.95, 0.93, 0.88), 0.0)
	cuff.rotation.x = PI / 2.0
	cuff.position = Vector3(0.0, 0.0, 0.15)
	_glove.add_child(cuff)
	_glove_arm = MeshInstance3D.new()
	var arm_mesh: BoxMesh = BoxMesh.new()
	arm_mesh.size = Vector3(0.07, 0.07, 1.0)
	_glove_arm.mesh = arm_mesh
	_glove_arm.material_override = _flat_material(Color(0.75, 0.6, 0.2), 0.7)
	_glove.add_child(_glove_arm)


func _flat_material(color: Color, metallic: float) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = 0.5
	return mat
