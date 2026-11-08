class_name DwarfClimb
extends Node
## Le nain sur la corde de la trappe : avancer / reculer = monter / descendre, saut = lâcher.
## Arrivé en haut, il se hisse sur le plancher du ventre (court trajet en arc).
##
## Réseau : le joueur déplace lui-même son nain (il a l'autorité dessus) ; l'hôte tient seulement
## qui est sur la corde (Rope.holder_peer_id). Utilisé par le nain local uniquement.

## Distance entre la corde et le nain qui grimpe (m).
const CLIMB_DISTANCE: float = 0.22
## On se hisse quand les pieds sont à cette distance sous le plancher (m).
const CLIMB_TOP_BELOW_FLOOR: float = 0.55
## Durée du mouvement pour se hisser sur le plancher (s).
const PULLUP_DURATION: float = 0.45

@export var dwarf: Dwarf
## Vitesse de grimpe (m/s).
@export var climb_speed: float = 1.4

## Se hisser : avancement (0..1, -1 = inactif), départ et arrivée (repère du parent du nain).
var _pullup_time: float = -1.0
var _pullup_from: Vector3 = Vector3.ZERO
var _pullup_to: Vector3 = Vector3.ZERO


## Vrai pendant qu'il se hisse sur le plancher.
func is_pulling_up() -> bool:
	return _pullup_time >= 0.0


## Une étape sur la corde. Renvoie la vitesse de grimpe (pour l'animation).
## Lâche la corde au saut, ou en haut pour se hisser.
func climb(rope: Rope, interactor: Interactor, delta: float) -> float:
	dwarf.rotation = Vector3(0.0, dwarf.rotation.y, 0.0)
	var climb_input: float = Input.get_axis("move_back", "move_forward")
	var top: float = rope.floor_height - CLIMB_TOP_BELOW_FLOOR
	var rope_height: float = clampf(rope.height_of(dwarf.global_position) + climb_input * climb_speed * delta, -rope.length, top)
	# Le nain se tient juste derrière la corde, face à elle.
	var rope_up: Vector3 = rope.global_basis.y
	var back: Vector3 = dwarf.global_basis.z - rope_up * dwarf.global_basis.z.dot(rope_up)
	dwarf.global_position = rope.point_at(rope_height) + back.normalized() * CLIMB_DISTANCE
	dwarf.velocity = Vector3.ZERO
	if Input.is_action_just_pressed("jump"):
		interactor.release_rope()
		dwarf.velocity = back.normalized() * 1.5 + rope_up * 1.5
	elif rope_height >= top - 0.001 and climb_input > 0.0:
		# Se hisser : court trajet en arc jusqu'au plancher, dans le repère du mécha.
		_pullup_from = dwarf.position
		_pullup_to = dwarf.get_parent().to_local(rope.to_global(rope.exit_point))
		_pullup_time = 0.0
		interactor.release_rope()
	return absf(climb_input) * climb_speed


## Une étape du hissage. Renvoie vrai tant qu'il n'est pas fini.
func update_pullup(delta: float) -> bool:
	_pullup_time += delta / PULLUP_DURATION
	var t: float = minf(_pullup_time, 1.0)
	dwarf.position = _pullup_from.lerp(_pullup_to, ease(t, -1.6)) + Vector3.UP * sin(PI * t) * 0.25
	dwarf.velocity = Vector3.ZERO
	if t >= 1.0:
		_pullup_time = -1.0
	return t < 1.0
