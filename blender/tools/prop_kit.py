"""Kit commun pour construire des modèles par script (coque du mécha, objets de l'intérieur).

Pourquoi des scripts : un script est du texte, git sait le fusionner, et n'importe quelle IA peut le relire
et le modifier. Le .blend et le .glb sont générés à partir du script (le script fait foi).

Utilisation typique dans un script d'objet (blender/props/<nom>.py) :

    import sys, os
    sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
    import prop_kit as kit

    kit.new_scene()
    b = kit.Builder("Crate")
    b.box((-0.3, -0.3, 0.0), (0.3, 0.3, 0.5), "Wood")
    obj = b.finish()
    kit.save_and_export("crate", budget_tris=300)

Lancement : blender -b --factory-startup --python blender/props/<nom>.py
"""

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

# Palette partagée par TOUT l'intérieur (mêmes noms et valeurs que dans mecha.blend).
# nom: (couleur linéaire RGB, rugosité, métal, émission)
PALETTE = {
    "Board": ((0.120, 0.170, 0.140), 0.90, 0.0, 0.0),
    "Bulb": ((1.000, 0.800, 0.450), 0.40, 0.0, 4.0),
    "ButtonGreen": ((0.200, 0.700, 0.250), 0.75, 0.0, 0.0),
    "ButtonRed": ((0.800, 0.150, 0.100), 0.75, 0.0, 0.0),
    "Ceiling": ((0.700, 0.660, 0.580), 0.75, 0.0, 0.0),
    "Copper": ((0.780, 0.450, 0.220), 0.35, 0.9, 0.0),
    "Cream": ((0.860, 0.790, 0.630), 0.75, 0.0, 0.0),
    "Cushion": ((0.860, 0.600, 0.220), 0.90, 0.0, 0.0),
    "DartBlack": ((0.070, 0.070, 0.070), 0.80, 0.0, 0.0),
    "DartGreen": ((0.120, 0.400, 0.200), 0.80, 0.0, 0.0),
    "DartRed": ((0.700, 0.100, 0.080), 0.80, 0.0, 0.0),
    "FloorPlate": ((0.300, 0.310, 0.330), 0.60, 0.6, 0.0),
    "Glass": ((0.600, 0.800, 0.900), 0.05, 0.0, 0.0),
    "Grime": ((0.160, 0.130, 0.100), 1.00, 0.0, 0.0),
    "Iron": ((0.420, 0.430, 0.460), 0.45, 0.8, 0.0),
    "IronDark": ((0.170, 0.170, 0.190), 0.55, 0.7, 0.0),
    "Lamp": ((1.000, 0.750, 0.400), 0.75, 0.0, 3.0),
    "Paint": ((0.290, 0.470, 0.450), 0.75, 0.0, 0.0),
    "Paper": ((0.920, 0.860, 0.700), 0.90, 0.0, 0.0),
    "Patch": ((0.360, 0.400, 0.380), 0.60, 0.4, 0.0),
    "Plant": ((0.250, 0.500, 0.200), 0.90, 0.0, 0.0),
    "Rug": ((0.550, 0.150, 0.120), 1.00, 0.0, 0.0),
    "RugTrim": ((0.880, 0.720, 0.360), 1.00, 0.0, 0.0),
    "Rust": ((0.300, 0.170, 0.090), 1.00, 0.0, 0.0),
    "Velvet": ((0.170, 0.360, 0.240), 0.95, 0.0, 0.0),
    "WallCream": ((0.800, 0.740, 0.620), 0.75, 0.0, 0.0),
    "WallTeal": ((0.220, 0.360, 0.350), 0.75, 0.0, 0.0),
    "Wood": ((0.450, 0.280, 0.140), 0.75, 0.0, 0.0),
    "Yellow": ((0.900, 0.700, 0.150), 0.75, 0.0, 0.0),
}


def material(name: str) -> bpy.types.Material:
    """Matériau de la palette (créé s'il n'existe pas dans le fichier)."""
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    if name not in PALETTE:
        raise KeyError("Matériau absent de la palette : %s (l'ajouter dans PALETTE)" % name)
    rgb, rough, metal, emission = PALETTE[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emission > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = (*rgb, 1.0)
    return mat


class Builder:
    """Construit un objet à partir de pièces simples, chacune avec un matériau de la palette."""

    def __init__(self, name: str):
        self.name = name
        self.bm = bmesh.new()
        self.materials: list = []

    def _index(self, mat_name: str) -> int:
        if mat_name not in self.materials:
            self.materials.append(mat_name)
        return self.materials.index(mat_name)

    def _tag(self, verts, mat_name: str) -> None:
        index = self._index(mat_name)
        for face in {f for v in verts for f in v.link_faces}:
            face.material_index = index

    def box(self, lo, hi, mat_name: str) -> None:
        """Boîte alignée sur les axes, entre les coins lo et hi (mètres)."""
        lo, hi = Vector(lo), Vector(hi)
        size = hi - lo
        matrix = Matrix.Translation((lo + hi) / 2) @ Matrix.Diagonal((*size, 1.0))
        result = bmesh.ops.create_cube(self.bm, size=1.0, matrix=matrix)
        self._tag(result["verts"], mat_name)

    def cylinder(self, p0, p1, radius: float, mat_name: str, segments: int = 10, radius_end: float = -1.0) -> None:
        """Cylindre (ou cône si radius_end >= 0) du point p0 au point p1."""
        p0, p1 = Vector(p0), Vector(p1)
        axis = p1 - p0
        rotation = Vector((0, 0, 1)).rotation_difference(axis.normalized()).to_matrix().to_4x4()
        matrix = Matrix.Translation((p0 + p1) / 2) @ rotation
        result = bmesh.ops.create_cone(
            self.bm, cap_ends=True, segments=segments, radius1=radius,
            radius2=radius if radius_end < 0 else radius_end, depth=axis.length, matrix=matrix,
        )
        self._tag(result["verts"], mat_name)

    def sphere(self, center, radius: float, mat_name: str, segments: int = 8) -> None:
        result = bmesh.ops.create_uvsphere(
            self.bm, u_segments=segments, v_segments=max(4, segments // 2), radius=radius,
            matrix=Matrix.Translation(Vector(center)),
        )
        self._tag(result["verts"], mat_name)

    def pipe(self, points, radius: float, mat_name: str, joint_mat: str = "", segments: int = 10) -> None:
        """Tuyau qui passe par une suite de points, avec un manchon à chaque coude."""
        for a, b in zip(points, points[1:]):
            self.cylinder(a, b, radius, mat_name, segments)
        for p in points[1:-1]:
            self.sphere(p, radius * 1.25, joint_mat or mat_name, segments)

    def rivet_row(self, start, end, normal, spacing: float = 0.1, size: float = 0.016,
                  depth: float = 0.006, mat_name: str = "Copper") -> None:
        """Rangée de rivets (petits cubes) posés sur une surface : de start à end, dépassant selon normal."""
        start, end, normal = Vector(start), Vector(end), Vector(normal).normalized()
        count = max(1, int(round((end - start).length / spacing)))
        half = Vector((size / 2,) * 3)
        for i in range(count + 1):
            center = start + (end - start) * (i / count) + normal * (depth / 2)
            extent = Vector((half.x if abs(normal.x) < 0.5 else depth / 2,
                             half.y if abs(normal.y) < 0.5 else depth / 2,
                             half.z if abs(normal.z) < 0.5 else depth / 2))
            self.box(center - extent, center + extent, mat_name)

    def finish(self, collection=None) -> bpy.types.Object:
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for mat_name in self.materials:
            mesh.materials.append(material(mat_name))
        for poly in mesh.polygons:
            poly.use_smooth = False
        obj = bpy.data.objects.new(self.name, mesh)
        (collection or bpy.context.scene.collection).objects.link(obj)
        return obj


def remove_objects(prefix: str) -> None:
    """Supprime les objets dont le nom commence par prefix (pour reconstruire proprement)."""
    for obj in [o for o in bpy.data.objects if o.name.startswith(prefix)]:
        mesh = obj.data if obj.type == "MESH" else None
        bpy.data.objects.remove(obj, do_unlink=True)
        if mesh is not None and mesh.users == 0:
            bpy.data.meshes.remove(mesh)


def new_scene() -> None:
    """Scène vide (pour un objet construit de zéro)."""
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)


def count_tris(objects) -> int:
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objects if o.type == "MESH")


def export_glb(path: str) -> None:
    """Export glTF binaire : objets visibles au rendu, modificateurs appliqués, sans caméra ni lumière."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_renderable=True,
        export_apply=True,
        export_cameras=False,
        export_lights=False,
        export_yup=True,
    )


def save_and_export(name: str, budget_tris: int, folder: str = "props") -> None:
    """Sauvegarde blender/<folder>/<name>.blend, exporte assets/models/<folder>/<name>.glb, vérifie le budget."""
    objects = [o for o in bpy.data.objects if o.type == "MESH" and not o.hide_render]
    tris = count_tris(objects)
    for obj in objects:
        if any(abs(s - 1.0) > 1e-4 for s in obj.scale):
            raise RuntimeError("%s : échelle non appliquée (%s)" % (obj.name, tuple(obj.scale)))
    if tris > budget_tris:
        raise RuntimeError("%s : %d triangles, budget %d dépassé" % (name, tris, budget_tris))
    blend = os.path.join(ROOT, "blender", folder, name + ".blend")
    os.makedirs(os.path.dirname(blend), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    export_glb(os.path.join(ROOT, "assets", "models", folder, name + ".glb"))
    print("prop_kit : %s OK — %d triangles (budget %d)" % (name, tris, budget_tris))
