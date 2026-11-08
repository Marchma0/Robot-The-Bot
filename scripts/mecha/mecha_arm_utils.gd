class_name MechaArmUtils
extends RefCounted
## Limites d'orientation des bras du mécha (foreuse et grappin), partagées avec les tests (sandbox_arms).

## Limites d'orientation des bras, pour qu'ils ne traversent jamais la coque.
## L'épaule est à 0,58 m du flanc (x ±2,95 contre ±2,37) et 1,8 m derrière l'avant de la coque :
## vers l'intérieur, au-delà de 7° le bras (0,35 m de demi-largeur) entrerait dans la cabine.
const YAW_INWARD_MAX: float = deg_to_rad(7.0)
const YAW_OUTWARD_MAX: float = deg_to_rad(60.0)
const PITCH_MIN: float = deg_to_rad(-44.0)
const PITCH_MAX: float = deg_to_rad(24.0)


## Borne le lacet d'un bras : peu vers la coque, beaucoup vers l'extérieur.
## `side_sign` : +1.0 = bras droit (foreuse, l'intérieur est un lacet positif), -1.0 = bras gauche (grappin).
static func clamp_yaw(yaw: float, side_sign: float) -> float:
	return clampf(yaw * side_sign, -YAW_OUTWARD_MAX, YAW_INWARD_MAX) * side_sign


static func clamp_pitch(pitch: float) -> float:
	return clampf(pitch, PITCH_MIN, PITCH_MAX)
