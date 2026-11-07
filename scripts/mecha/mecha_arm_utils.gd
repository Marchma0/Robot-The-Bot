class_name MechaArmUtils
extends RefCounted
## Utilitaires partagés par les bras du mécha (foreuse M8 et grappin M9).
## Permet notamment de masquer en mémoire les anciens bras statiques de `Ext_Details`
## sans modifier `blender/mecha.blend` ni `assets/models/mecha.glb` (verrouillés par M7).

const ARM_X_THRESHOLD: float = 2.37
const ARM_MAX_Y: float = 5.20

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


## Retire du maillage `Ext_Details` les triangles de l'ancien bras statique du côté `side_sign`
## (+1.0 = bras droit foreuse, -1.0 = bras gauche grappin).
static func strip_static_arm(details: MeshInstance3D, side_sign: float) -> void:
	_strip(details, func(v: Vector3) -> bool: return v.x * side_sign > ARM_X_THRESHOLD and v.y < ARM_MAX_Y)


## Retire d'un maillage du mécha les triangles qui ont un sommet dans `box` (repère du maillage).
## Sert à effacer un reste de vieux décor de `mecha.blend` sans modifier le fichier (verrouillé par M7).
static func strip_box(details: MeshInstance3D, box: AABB) -> void:
	_strip(details, func(v: Vector3) -> bool: return box.has_point(v))


static func _strip(details: MeshInstance3D, removed: Callable) -> void:
	if details == null or details.mesh == null:
		return
	var src_mesh: Mesh = details.mesh
	var out_mesh: ArrayMesh = ArrayMesh.new()
	for s: int in range(src_mesh.get_surface_count()):
		var st: SurfaceTool = SurfaceTool.new()
		st.create_from(src_mesh, s)
		var arrays: Array = st.commit_to_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var mat: Material = src_mesh.surface_get_material(s)
		if indices.size() >= 3:
			var kept_indices: PackedInt32Array = PackedInt32Array()
			var tri_count: int = indices.size() / 3
			for t: int in range(tri_count):
				var i0: int = indices[t * 3]
				var i1: int = indices[t * 3 + 1]
				var i2: int = indices[t * 3 + 2]
				if removed.call(verts[i0]) or removed.call(verts[i1]) or removed.call(verts[i2]):
					continue
				kept_indices.append(i0)
				kept_indices.append(i1)
				kept_indices.append(i2)
			if kept_indices.is_empty():
				continue
			arrays[Mesh.ARRAY_INDEX] = kept_indices
			out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out_mesh.surface_set_material(out_mesh.get_surface_count() - 1, mat)
		elif verts.size() >= 3:
			out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out_mesh.surface_set_material(out_mesh.get_surface_count() - 1, mat)
	details.mesh = out_mesh

