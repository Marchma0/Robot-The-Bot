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

# Palette partagée par TOUS les modèles (direction artistique : docs/modeles_3d.md).
# Couleurs de jouet peint, valeurs moyennes à claires et saturées : les ombres viennent de la lumière, pas des couleurs.
# Le noir pur est réservé aux contours (shader dans Godot). Les noms ne changent pas : les scripts s'en servent.
# Un .blend déjà construit (mecha.blend…) garde ses anciennes couleurs tant que son script n'est pas relancé.
# nom: (couleur linéaire RGB, rugosité, métal, émission)
PALETTE = {
    # --- Robot et métal (récupéré à la casse, repeint, rafistolé)
    "Paint": ((0.100, 0.360, 0.330), 0.70, 0.0, 0.0),        # peinture sarcelle du robot : ressort sur les décors chauds
    "Patch": ((0.520, 0.300, 0.120), 0.65, 0.3, 0.0),        # tôle rapportée d'une autre couleur (rustine)
    "Iron": ((0.360, 0.380, 0.440), 0.45, 0.8, 0.0),         # acier gris-bleu
    "IronDark": ((0.090, 0.100, 0.140), 0.55, 0.7, 0.0),     # acier sombre bleu nuit (jamais noir)
    "Copper": ((0.850, 0.400, 0.150), 0.35, 0.9, 0.0),       # cuivre et laiton des détails
    "Rust": ((0.420, 0.150, 0.050), 1.00, 0.0, 0.0),
    "Grime": ((0.130, 0.100, 0.080), 1.00, 0.0, 0.0),
    "Yellow": ((0.950, 0.620, 0.050), 0.70, 0.0, 0.0),       # jaune chantier : ce qu'on peut toucher
    "ButtonGreen": ((0.100, 0.750, 0.150), 0.60, 0.0, 0.0),
    "ButtonRed": ((0.850, 0.080, 0.050), 0.60, 0.0, 0.0),
    # --- Intérieur du robot (coque : mecha_shell.py)
    "WallCream": ((0.780, 0.620, 0.420), 0.75, 0.0, 0.0),
    "WallTeal": ((0.060, 0.220, 0.210), 0.75, 0.0, 0.0),
    "FloorPlate": ((0.260, 0.280, 0.320), 0.60, 0.6, 0.0),
    "Ceiling": ((0.520, 0.460, 0.380), 0.75, 0.0, 0.0),
    "Cream": ((0.820, 0.680, 0.460), 0.75, 0.0, 0.0),
    # --- Lumières et écrans (émissifs : guident l'œil)
    "Lamp": ((1.000, 0.620, 0.220), 0.75, 0.0, 4.0),         # lanternes, ampoules ambre
    "Bulb": ((1.000, 0.750, 0.380), 0.40, 0.0, 4.0),
    "Neon": ((0.050, 0.750, 1.000), 0.40, 0.0, 3.0),         # écrans à tube, rayon tracteur
    "Ore": ((0.100, 0.900, 0.750), 0.30, 0.0, 2.0),          # veines de minerai qui brillent
    "Glass": ((0.450, 0.700, 0.850), 0.05, 0.0, 0.0),
    # --- Mine et nature
    "Wood": ((0.420, 0.220, 0.090), 0.75, 0.0, 0.0),
    "Canvas": ((0.800, 0.680, 0.480), 0.95, 0.0, 0.0),
    "RockDark": ((0.300, 0.180, 0.130), 0.95, 0.0, 0.0),     # roche brune
    "Slate": ((0.180, 0.200, 0.280), 0.90, 0.0, 0.0),        # roche ardoise gris-bleu (grottes)
    "Sand": ((0.800, 0.550, 0.300), 1.00, 0.0, 0.0),
    "Terracotta": ((0.620, 0.240, 0.110), 0.95, 0.0, 0.0),
    "Ochre": ((0.850, 0.420, 0.120), 0.95, 0.0, 0.0),
    "Scrub": ((0.350, 0.420, 0.120), 0.95, 0.0, 0.0),
    "Plant": ((0.150, 0.500, 0.100), 0.90, 0.0, 0.0),
    # --- Vie des nains (tissus, jeux, papier)
    "Velvet": ((0.080, 0.320, 0.180), 0.95, 0.0, 0.0),
    "Cushion": ((0.880, 0.520, 0.120), 0.90, 0.0, 0.0),
    "Rug": ((0.550, 0.100, 0.070), 1.00, 0.0, 0.0),
    "RugTrim": ((0.900, 0.650, 0.250), 1.00, 0.0, 0.0),
    "Paper": ((0.900, 0.800, 0.600), 0.90, 0.0, 0.0),
    "Board": ((0.060, 0.100, 0.090), 0.90, 0.0, 0.0),
    "DartBlack": ((0.030, 0.030, 0.040), 0.80, 0.0, 0.0),
    "DartGreen": ((0.060, 0.380, 0.150), 0.80, 0.0, 0.0),
    "DartRed": ((0.750, 0.060, 0.040), 0.80, 0.0, 0.0),
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
    # Faces arrière masquées (export glTF « simple face ») : les objets sont des volumes fermés,
    # et deux faces dos à dos ne peuvent plus clignoter.
    mat.use_backface_culling = True
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
        """Boîte alignée sur les axes, entre les coins lo et hi (mètres, dans n'importe quel ordre)."""
        lo, hi = Vector(map(min, lo, hi)), Vector(map(max, lo, hi))   # sinon faces retournées
        size = hi - lo
        matrix = Matrix.Translation((lo + hi) / 2) @ Matrix.Diagonal((*size, 1.0))
        result = bmesh.ops.create_cube(self.bm, size=1.0, matrix=matrix)
        self._tag(result["verts"], mat_name)

    def tilted_box(self, center, size, tilt_x: float, mat_name: str) -> None:
        """Boîte de dimensions size, centrée sur center, tournée de tilt_x radians autour de l'axe X."""
        matrix = Matrix.Translation(Vector(center)) @ Matrix.Rotation(tilt_x, 4, "X") @ Matrix.Diagonal((*size, 1.0))
        result = bmesh.ops.create_cube(self.bm, size=1.0, matrix=matrix)
        self._tag(result["verts"], mat_name)

    def frustum(self, center_xy, z0: float, z1: float, half_bottom, half_top, mat_name: str) -> None:
        """Boîte qui s'affine (ou s'évase) de z0 à z1 : demi-tailles (x, y) en bas et en haut."""
        cx, cy = center_xy
        rings = []
        for z, (hx, hy) in ((z0, half_bottom), (z1, half_top)):
            rings.append([self.bm.verts.new((cx + sx * hx, cy + sy * hy, z))
                          for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
        bottom, top = rings
        faces = [self.bm.faces.new(bottom[::-1]), self.bm.faces.new(top)]
        for i in range(4):
            j = (i + 1) % 4
            faces.append(self.bm.faces.new((bottom[i], bottom[j], top[j], top[i])))
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        index = self._index(mat_name)
        for face in faces:
            face.material_index = index

    def prism_x(self, profile_yz, x0: float, x1: float, mat_name: str) -> None:
        """Prisme : profil convexe (liste de points (y, z) dans l'ordre) extrudé de x0 à x1."""
        left = [self.bm.verts.new((x0, y, z)) for y, z in profile_yz]
        right = [self.bm.verts.new((x1, y, z)) for y, z in profile_yz]
        faces = [self.bm.faces.new(left[::-1]), self.bm.faces.new(right)]
        n = len(profile_yz)
        for i in range(n):
            j = (i + 1) % n
            faces.append(self.bm.faces.new((left[i], left[j], right[j], right[i])))
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        index = self._index(mat_name)
        for face in faces:
            face.material_index = index

    def extrude(self, outline_xy, z0: float, z1: float, mat_name: str, matrix=None) -> None:
        """Forme quelconque (même creuse, ex. une croix) : contour (x, y) dans l'ordre, extrudé de z0 à z1.
        matrix (optionnelle) place la pièce : ex. Translation @ Rotation pour la dresser ou l'incliner."""
        matrix = matrix or Matrix.Identity(4)
        bottom = [self.bm.verts.new(matrix @ Vector((x, y, z0))) for x, y in outline_xy]
        top = [self.bm.verts.new(matrix @ Vector((x, y, z1))) for x, y in outline_xy]
        faces = [self.bm.faces.new(bottom[::-1]), self.bm.faces.new(top)]
        n = len(outline_xy)
        for i in range(n):
            j = (i + 1) % n
            faces.append(self.bm.faces.new((bottom[i], bottom[j], top[j], top[i])))
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        index = self._index(mat_name)
        for face in faces:
            face.material_index = index

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

    def rock(self, center, size, mat_name: str, jitter: float = 0.18, rng=None, flat_bottom: bool = True) -> None:
        """Bloc de roche facetté : boîte de dimensions size dont chaque coin est déplacé au hasard
        (jitter = fraction de la taille). flat_bottom garde la base à plat pour la poser au sol.
        rng : un random.Random pour des rochers identiques à chaque export."""
        import random
        rng = rng or random.Random(0)
        size = Vector(size)
        matrix = Matrix.Translation(Vector(center)) @ Matrix.Diagonal((*size, 1.0))
        result = bmesh.ops.create_cube(self.bm, size=1.0, matrix=matrix)
        bottom = Vector(center).z - size.z / 2
        # Base plate un peu enfoncée, de façon différente pour chaque rocher : deux bases ne sont
        # jamais dans le même plan (sinon elles clignotent là où les rochers se chevauchent).
        sink = rng.uniform(0.004, 0.12)
        for v in result["verts"]:
            move = Vector((rng.uniform(-1, 1) * size.x, rng.uniform(-1, 1) * size.y,
                           rng.uniform(-1, 1) * size.z)) * jitter
            if flat_bottom and v.co.z <= bottom + 1e-4:
                move.z = -sink
            v.co += move
        # Les faces carrées déformées ne sont plus planes : on les coupe en triangles (facettes nettes).
        faces = list({f for v in result["verts"] for f in v.link_faces})
        bmesh.ops.triangulate(self.bm, faces=faces)
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


def _clip(subject, clip):
    """Intersection de deux polygones convexes 2D (sens trigo), Sutherland-Hodgman."""
    out = subject
    for i in range(len(clip)):
        a, b = clip[i], clip[(i + 1) % len(clip)]
        inp, out = out, []
        if not inp:
            break
        for j in range(len(inp)):
            p, q = inp[j], inp[(j + 1) % len(inp)]
            side_p = (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
            side_q = (b[0] - a[0]) * (q[1] - a[1]) - (b[1] - a[1]) * (q[0] - a[0])
            if side_p >= 0:
                out.append(p)
            if (side_p >= 0) != (side_q >= 0):
                t = side_p / (side_p - side_q)
                out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
    return out


def _area(poly):
    return 0.5 * sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1]
                     for i in range(len(poly)))


def find_z_fighting(obj, min_area: float = 2e-6):
    """Faces superposées (même plan, même sens, matériaux différents) : elles clignotent en jeu.

    Deux faces dos à dos (sens opposés) ne sont pas signalées : ce sont deux pièces qui se touchent,
    leurs faces sont cachées l'une par l'autre. Renvoie une liste de (matériau A, matériau B, centre, aire, normale, face A, face B).
    """
    mesh = obj.data
    names = [m.name if m else "" for m in mesh.materials]
    mw = obj.matrix_world
    groups = {}
    for poly in mesh.polygons:
        n = (mw.to_3x3() @ poly.normal).normalized()
        pts = [mw @ mesh.vertices[i].co for i in poly.vertices]
        key = (round(n.x, 3), round(n.y, 3), round(n.z, 3), round(n.dot(pts[0]) * 2000))
        groups.setdefault(key, []).append((poly, n, pts))
    issues = []
    for faces in groups.values():
        if len(faces) < 2:
            continue
        n = faces[0][1]
        u = n.orthogonal().normalized()
        v = n.cross(u)
        depth = n.dot(faces[0][2][0])
        flat = []
        for poly, _, pts in faces:
            p2 = [(p.dot(u), p.dot(v)) for p in pts]
            if _area(p2) < 0:
                p2.reverse()
            flat.append((poly, p2))
        for i in range(len(flat)):
            for j in range(i + 1, len(flat)):
                pa, a2 = flat[i]
                pb, b2 = flat[j]
                ma, mb = names[pa.material_index], names[pb.material_index]
                if ma == mb:
                    continue
                inter = _clip(a2, b2)
                if len(inter) >= 3 and abs(_area(inter)) > min_area:
                    # centre de la zone superposée (point qui appartient aux deux faces), en coordonnées monde
                    cx = sum(p[0] for p in inter) / len(inter)
                    cy = sum(p[1] for p in inter) / len(inter)
                    c = u * cx + v * cy + n * depth
                    issues.append((ma, mb, tuple(round(x, 4) for x in c), abs(_area(inter)), tuple(n), pa.index, pb.index))
    return issues


def save_and_export(name: str, budget_tris: int, folder: str = "props", ground: bool = True) -> None:
    """Contrôle le modèle (check_asset : budget, transformations, au sol, géométrie, nommage, UV, faces superposées),
    sauvegarde blender/<folder>/<name>.blend, exporte assets/models/<folder>/<name>.glb, puis vérifie le .glb en le
    réimportant dans un Blender vide (roundtrip_glb). Un contrôle raté arrête tout, avant d'écrire quoi que ce soit.
    `ground` : faux pour un objet qui n'est pas posé au sol (accroché au mur, au plafond, pièce d'un mécanisme).
    Variable d'environnement ROBOT_CHECK_ONLY=1 : contrôle seulement, rien n'est écrit."""
    import check_asset
    import roundtrip_glb
    objects = [o for o in bpy.data.objects if o.type in {"MESH", "ARMATURE"} and not o.hide_render]
    report = check_asset.check(objects, name, budget_tris, ground)
    if report.failed:
        raise RuntimeError("%s : %d contrôle(s) raté(s), export annulé (détail ci-dessus)" % (name, report.failed))
    if os.environ.get("ROBOT_CHECK_ONLY"):
        print("prop_kit : %s contrôlé, rien n'est écrit (ROBOT_CHECK_ONLY)" % name)
        return
    expected = roundtrip_glb.expected_from_scene(objects)
    blend = os.path.join(ROOT, "blender", folder, name + ".blend")
    os.makedirs(os.path.dirname(blend), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    glb = os.path.join(ROOT, "assets", "models", folder, name + ".glb")
    export_glb(glb)
    if not roundtrip_glb.check_export(glb, expected):
        raise RuntimeError("%s : le .glb réimporté ne correspond pas au modèle (détail ci-dessus)" % name)
    tris = count_tris(objects)
    print("prop_kit : %s OK — %d triangles (budget %d)" % (name, tris, budget_tris))
