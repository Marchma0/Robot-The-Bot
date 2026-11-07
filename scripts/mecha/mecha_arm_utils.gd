class_name MechaArmUtils
extends RefCounted
## Utilitaires partagés par les bras du mécha (foreuse M8 et grappin M9).
## Permet notamment de masquer en mémoire les anciens bras statiques de `Ext_Details`
## sans modifier `blender/mecha.blend` ni `assets/models/mecha.glb` (verrouillés par M7).

const ARM_X_THRESHOLD: float = 2.37
const ARM_MAX_Y: float = 5.20


## Retire du maillage `Ext_Details` les triangles de l'ancien bras statique du côté `side_sign`
## (+1.0 = bras droit foreuse, -1.0 = bras gauche grappin).
static func strip_static_arm(details: MeshInstance3D, side_sign: float) -> void:
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
				if _is_arm_vertex(verts[i0], side_sign) or _is_arm_vertex(verts[i1], side_sign) or _is_arm_vertex(verts[i2], side_sign):
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


static func _is_arm_vertex(v: Vector3, side_sign: float) -> bool:
	return v.x * side_sign > ARM_X_THRESHOLD and v.y < ARM_MAX_Y
