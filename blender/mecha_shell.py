"""Coque intérieure du mécha : tôles peintes rivetées, sol en plaques, plafond, structure, usure.

Relançable sans risque : textures régénérées, objets Shell_* reconstruits.
    blender -b blender/mecha.blend --python blender/mecha_shell.py
Sauvegarde mecha.blend et réexporte assets/models/mecha.glb.

Ce que fait le script :
1. Génère les textures (blender/textures/*.png) : tôles crème et sarcelle avec joints, rivets et coulures,
   sol en plaques striées boulonnées, plafond en panneaux.
2. Les applique aux matériaux WallCream, WallTeal, FloorPlate, Ceiling (projection en coordonnées monde,
   1 répétition de texture = 2 m, donc les joints tombent tous les mètres).
3. Supprime les traînées et fissures trop fines de Int_Wear (elles ressemblaient à des brindilles).
4. Construit Shell_Belly et Shell_Head : montants d'angle, poutres de plafond, tuyaux avec colliers.
"""

import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "tools"))
import prop_kit as kit  # noqa: E402

TEX_DIR = os.path.join(kit.ROOT, "blender", "textures")
TEX_SIZE = 1024          # pixels pour 2 m
METERS = 2.0
PX = TEX_SIZE / METERS   # pixels par mètre

# Volumes intérieurs (coordonnées Blender, mètres)
BELLY = dict(x=2.2, y=1.9, floor=2.6, ceil=5.4)
HEAD = dict(x=2.2, y=1.9, floor=5.6, ceil=8.3)
# Matériaux qui forment la coque (on ne vérifie pas les collisions avec eux)
SHELL_MATS = {"WallCream", "WallTeal", "FloorPlate", "Ceiling"}


# ---------------------------------------------------------------- textures

def _srgb(rgb):
    return np.clip(np.array(rgb, dtype=np.float32), 0, 1) ** (1 / 2.2)


def _blur(a, r):
    """Flou boîte séparable, en boucle (la texture se répète)."""
    for axis in (0, 1):
        acc = np.zeros_like(a)
        for d in range(-r, r + 1):
            acc += np.roll(a, d, axis=axis)
        a = acc / (2 * r + 1)
    return a


def _noise(rng, cells, blur):
    small = rng.random((cells, cells)).astype(np.float32)
    big = np.kron(small, np.ones((TEX_SIZE // cells, TEX_SIZE // cells), dtype=np.float32))
    return _blur(big, blur)


def _disc(img, cx, cy, r, factor):
    y0, y1 = int(cy - r - 1), int(cy + r + 2)
    x0, x1 = int(cx - r - 1), int(cx + r + 2)
    yy, xx = np.mgrid[y0:y1, x0:x1]
    mask = (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r
    ys, xs = yy[mask] % TEX_SIZE, xx[mask] % TEX_SIZE
    img[ys, xs] *= factor


def _rivet(img, cx, cy, r=4.5):
    _disc(img, cx + 1.5, cy - 1.5, r, 0.62)   # ombre (en bas à droite ; la ligne 0 est en bas)
    _disc(img, cx, cy, r, 1.16)               # tête du rivet
    _disc(img, cx - 1.2, cy + 1.2, r * 0.45, 1.10)  # reflet


def _seams(img, panel_w, panel_h, dark=0.42, light=1.10):
    w = 4
    for k in range(int(METERS / panel_w)):
        x = int(round(k * panel_w * PX))
        img[:, (np.arange(x - w // 2, x + w // 2)) % TEX_SIZE] *= dark
        img[:, (np.arange(x + w // 2, x + w // 2 + 2)) % TEX_SIZE] *= light
    for k in range(int(METERS / panel_h)):
        y = int(round(k * panel_h * PX))
        img[(np.arange(y - w // 2, y + w // 2)) % TEX_SIZE, :] *= dark
        img[(np.arange(y - w // 2 - 2, y - w // 2)) % TEX_SIZE, :] *= light


def _rivet_rows(img, panel_w, panel_h, spacing):
    inset = 0.045 * PX
    for kx in range(int(METERS / panel_w)):
        for ky in range(int(METERS / panel_h)):
            x0, y0 = kx * panel_w * PX, ky * panel_h * PX
            x1, y1 = x0 + panel_w * PX, y0 + panel_h * PX
            n = max(2, int(round(panel_w / spacing)))
            for i in range(n + 1):
                x = x0 + inset + (x1 - x0 - 2 * inset) * i / n
                _rivet(img, x, y0 + inset)
                _rivet(img, x, y1 - inset)
            n = max(2, int(round(panel_h / spacing)))
            for i in range(1, n):
                y = y0 + inset + (y1 - y0 - 2 * inset) * i / n
                _rivet(img, x0 + inset, y)
                _rivet(img, x1 - inset, y)


def _streaks(img, rng, count, color, strength):
    """Coulures verticales qui descendent (ligne 0 = bas de la texture)."""
    col = _srgb(color)
    for _ in range(count):
        x = int(rng.integers(0, TEX_SIZE))
        top = int(rng.integers(0, TEX_SIZE))
        length = int(rng.integers(int(0.08 * PX), int(0.45 * PX)))
        width = int(rng.integers(2, 6))
        for i in range(length):
            a = strength * (1 - i / length) ** 1.5
            ys = (top - i) % TEX_SIZE
            xs = np.arange(x, x + width) % TEX_SIZE
            img[ys, xs] = img[ys, xs] * (1 - a) + col * a


def _chips(img, rng, count, color, max_len_m=0.06):
    """Éclats de peinture (petites taches qui montrent le métal en dessous)."""
    col = _srgb(color)
    for _ in range(count):
        cx, cy = rng.integers(0, TEX_SIZE, size=2)
        r = rng.uniform(1.5, max_len_m * PX / 2)
        yy, xx = np.mgrid[-int(r) - 1:int(r) + 2, -int(r) - 1:int(r) + 2]
        mask = (xx / r) ** 2 + (yy / (r * rng.uniform(0.3, 1.0))) ** 2 <= 1
        ys, xs = (yy[mask] + cy) % TEX_SIZE, (xx[mask] + cx) % TEX_SIZE
        img[ys, xs] = col


def make_wall(name, rgb, seed, panel_h=1.0, kicks=False):
    rng = np.random.default_rng(seed)
    base = _srgb(rgb)
    img = np.ones((TEX_SIZE, TEX_SIZE, 3), dtype=np.float32) * base
    # teinte légèrement différente par panneau + variations douces
    for kx in range(2):
        for ky in range(int(METERS / panel_h)):
            ys = slice(int(ky * panel_h * PX), int((ky + 1) * panel_h * PX))
            img[ys, kx * TEX_SIZE // 2:(kx + 1) * TEX_SIZE // 2] *= rng.uniform(0.95, 1.04)
    img *= (0.93 + 0.12 * _noise(rng, 16, 24))[..., None]
    _streaks(img, rng, 22, (0.20, 0.13, 0.08), 0.35)   # rouille
    _streaks(img, rng, 14, (0.10, 0.09, 0.08), 0.22)   # crasse
    if kicks:
        _chips(img, rng, 90, (0.33, 0.34, 0.36))
    else:
        _chips(img, rng, 30, (0.36, 0.37, 0.39), 0.03)
    _seams(img, 1.0, panel_h)
    _rivet_rows(img, 1.0, panel_h, 0.125)
    return _save(name, img)


def make_floor(name, rgb, seed):
    rng = np.random.default_rng(seed)
    base = _srgb(rgb)
    img = np.ones((TEX_SIZE, TEX_SIZE, 3), dtype=np.float32) * base
    # tôle striée : petits bâtonnets en relief orientés à ±45° en alternance
    cell = 22
    yy, xx = np.mgrid[0:TEX_SIZE, 0:TEX_SIZE]
    cx, cy = xx // cell, yy // cell
    u = (xx % cell) - cell / 2 + 0.5
    v = (yy % cell) - cell / 2 + 0.5
    sign = np.where((cx + cy) % 2 == 0, 1.0, -1.0)
    ru = (u + sign * v) / np.sqrt(2)
    rv = (-sign * u + v) / np.sqrt(2)
    bar = (ru / 7.5) ** 2 + (rv / 2.2) ** 2 <= 1
    shadow = ((ru - 1.2) / 7.5) ** 2 + ((rv + 1.2) / 2.2) ** 2 <= 1
    img[shadow & ~bar] *= 0.72
    img[bar] *= 1.22
    # usure : zones de passage plus claires, taches sombres
    img *= (0.88 + 0.22 * _noise(rng, 8, 40))[..., None]
    img *= (0.94 + 0.08 * _noise(rng, 32, 6))[..., None]
    _seams(img, 1.0, 1.0, dark=0.35, light=1.15)
    for kx in range(2):
        for ky in range(2):
            for dx in (0.05, 0.95):
                for dy in (0.05, 0.95):
                    _rivet(img, (kx + dx) * PX, (ky + dy) * PX, 6)
    return _save(name, img)


def make_ceiling(name, rgb, seed):
    rng = np.random.default_rng(seed)
    img = np.ones((TEX_SIZE, TEX_SIZE, 3), dtype=np.float32) * _srgb(rgb)
    img *= (0.94 + 0.10 * _noise(rng, 16, 24))[..., None]
    _streaks(img, rng, 8, (0.12, 0.10, 0.08), 0.18)
    _seams(img, 1.0, 1.0, dark=0.5)
    _rivet_rows(img, 1.0, 1.0, 0.2)
    return _save(name, img)


def _save(name, rgb_img):
    os.makedirs(TEX_DIR, exist_ok=True)
    path = os.path.join(TEX_DIR, name + ".png")
    rgba = np.ones((TEX_SIZE, TEX_SIZE, 4), dtype=np.float32)
    rgba[..., :3] = np.clip(rgb_img, 0, 1)
    img = bpy.data.images.get(name + ".png") or bpy.data.images.new(name + ".png", TEX_SIZE, TEX_SIZE, alpha=False)
    if img.size[0] != TEX_SIZE:
        img.scale(TEX_SIZE, TEX_SIZE)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    img.reload()
    return img


def textured_material(mat_name, image, roughness, metallic):
    mat = kit.material(mat_name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    tex = next((n for n in nodes if n.type == "TEX_IMAGE"), None) or nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.location = (bsdf.location.x - 320, bsdf.location.y)
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic


# ---------------------------------------------------------------- UV en projection monde

def world_uvs(obj):
    mesh = obj.data
    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    uv = mesh.uv_layers.active.data
    mw = obj.matrix_world
    shell_idx = {i for i, m in enumerate(mesh.materials) if m and m.name in SHELL_MATS}
    for poly in mesh.polygons:
        if poly.material_index not in shell_idx:
            continue
        n = poly.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        for li in poly.loop_indices:
            p = mw @ mesh.vertices[mesh.loops[li].vertex_index].co
            if axis == 0:
                u, v = p.y, p.z
            elif axis == 1:
                u, v = p.x, p.z
            else:
                u, v = p.x, p.y
            uv[li].uv = (u / METERS, v / METERS)


# ---------------------------------------------------------------- usure

def clean_wear():
    """Retire les petits traits de rouille / fissures (lus comme des brindilles), garde les taches."""
    obj = bpy.data.objects["Int_Wear"]
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    names = [m.name if m else "" for m in mesh.materials]
    seen, doomed = set(), []
    for v in bm.verts:
        if v in seen:
            continue
        stack, comp = [v], []
        while stack:
            x = stack.pop()
            if x in seen:
                continue
            seen.add(x)
            comp.append(x)
            stack += [e.other_vert(x) for e in x.link_edges]
        faces = {f for p in comp for f in p.link_faces}
        mats = {names[f.material_index] for f in faces}
        dims = sorted(max(p.co[i] for p in comp) - min(p.co[i] for p in comp) for i in range(3))
        if mats <= {"Rust", "Grime"} and dims[1] < 0.15:
            doomed += comp
    bmesh.ops.delete(bm, geom=list(set(doomed)), context="VERTS")
    bm.to_mesh(mesh)
    bm.free()
    print("mecha_shell : usure, %d sommets de traits fins retirés" % len(set(doomed)))


# Meubles remplacés par des objets (blender/props/) : boîtes englobantes exactes des anciennes pièces.
REPLACED = {
    "Int_Belly": [
        # consoles des jambes (gauche, droite) : caisson, rehausse arrière, plateau incliné -> props/console.py
        ((-1.5, 1.2, 2.6), (-0.5, 1.8, 3.1)), ((-1.5, 1.6, 3.1), (-0.5, 1.72, 3.18)), ((-1.52, 1.1813, 3.0378), (-0.48, 1.7187, 3.2822)),
        ((0.5, 1.2, 2.6), (1.5, 1.8, 3.1)), ((0.5, 1.6, 3.1), (1.5, 1.72, 3.18)), ((0.48, 1.1813, 3.0378), (1.52, 1.7187, 3.2822)),
    ],
    "Int_Decor": [
        # canapé du salon -> props/sofa.py
        ((-2.15, -0.62, 2.6), (-2.09, -0.56, 2.68)), ((-2.15, 0.66, 2.6), (-2.09, 0.72, 2.68)),
        ((-1.69, -0.62, 2.6), (-1.63, -0.56, 2.68)), ((-1.69, 0.66, 2.6), (-1.63, 0.72, 2.68)),
        ((-2.18, -0.65, 2.68), (-1.6, 0.75, 2.93)), ((-1.98, -0.5, 2.93), (-1.62, 0.04, 3.05)),
        ((-1.98, 0.06, 2.93), (-1.62, 0.6, 3.05)), ((-2.18, -0.65, 2.93), (-1.98, 0.75, 3.45)),
        ((-2.18, -0.65, 2.93), (-1.6, -0.5, 3.18)), ((-1.61, -0.62, 2.98), (-1.595, -0.53, 3.1)),
        ((-2.18, 0.6, 2.93), (-1.6, 0.75, 3.18)), ((-1.61, 0.63, 2.98), (-1.595, 0.72, 3.1)),
        ((-1.971, 0.28, 3.051), (-1.789, 0.58, 3.349)), ((-1.962, -0.465, 3.035), (-1.798, -0.175, 3.325)),
    ],
    "Int_Head": [
        # console de la foreuse -> props/console.py
        ((0.65, 1.15, 5.6), (1.55, 1.75, 6.1)), ((0.65, 1.55, 6.1), (1.55, 1.67, 6.18)), ((0.63, 1.1313, 6.0378), (1.57, 1.6687, 6.2822)),
        # siège du grappin -> props/grabber_chair.py
        ((-1.32, 0.63, 5.6), (-0.88, 1.07, 5.63)), ((-1.15, 0.8, 5.62), (-1.05, 0.9, 5.92)), ((-1.35, 0.62, 5.91), (-0.85, 1.08, 5.99)),
        ((-1.35, 0.58, 5.99), (-0.85, 0.64, 6.45)), ((-0.88, 0.66, 6.12), (-0.82, 1.0, 6.16)), ((-1.38, 0.66, 6.12), (-1.32, 1.0, 6.16)),
        ((-0.87, 0.95, 5.99), (-0.83, 0.99, 6.12)), ((-1.37, 0.95, 5.99), (-1.33, 0.99, 6.12)),
        # bureau du grappin (le cadre de l'écran reste) -> props/grabber_desk.py
        ((-1.5, 1.35, 5.6), (-0.7, 1.75, 6.02)), ((-1.52, 1.33, 6.02), (-0.68, 1.77, 6.06)),
    ],
}


def remove_replaced_furniture():
    for name, boxes in REPLACED.items():
        obj = bpy.data.objects[name]
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        mw = obj.matrix_world
        seen, doomed, hits = set(), [], 0
        for v in bm.verts:
            if v in seen:
                continue
            stack, comp = [v], []
            while stack:
                x = stack.pop()
                if x in seen:
                    continue
                seen.add(x)
                comp.append(x)
                stack += [e.other_vert(x) for e in x.link_edges]
            pts = [mw @ p.co for p in comp]
            lo = Vector([min(p[i] for p in pts) for i in range(3)])
            hi = Vector([max(p[i] for p in pts) for i in range(3)])
            for blo, bhi in boxes:
                if all(abs(lo[i] - blo[i]) < 0.006 and abs(hi[i] - bhi[i]) < 0.006 for i in range(3)):
                    doomed += comp
                    hits += 1
                    break
        bmesh.ops.delete(bm, geom=list(set(doomed)), context="VERTS")
        bm.to_mesh(obj.data)
        bm.free()
        print("mecha_shell : %s, %d anciens meubles retirés" % (name, hits))


def remove_toilet_planks():
    """Retire les cloisons en planches de la cabine des toilettes (remplacées par l'objet toilet_cabin)."""
    obj = bpy.data.objects["Int_Toilet"]
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    names = [m.name if m else "" for m in mesh.materials]
    mw = obj.matrix_world
    seen, doomed = set(), []
    for v in bm.verts:
        if v in seen:
            continue
        stack, comp = [v], []
        while stack:
            x = stack.pop()
            if x in seen:
                continue
            seen.add(x)
            comp.append(x)
            stack += [e.other_vert(x) for e in x.link_edges]
        pts = [mw @ p.co for p in comp]
        lo = Vector([min(p[i] for p in pts) for i in range(3)])
        hi = Vector([max(p[i] for p in pts) for i in range(3)])
        mats = {names[f.material_index] for p in comp for f in p.link_faces}
        in_side = lo.x >= -0.89 and hi.x <= -0.82        # cloison droite (porte)
        in_front = lo.y >= -0.94 and hi.y <= -0.87       # cloison avant
        if mats <= {"Wood", "Cushion", "IronDark"} and (in_side or in_front) and hi.z - lo.z > 0.05:
            doomed += comp
    bmesh.ops.delete(bm, geom=list(set(doomed)), context="VERTS")
    bm.to_mesh(mesh)
    bm.free()
    print("mecha_shell : toilettes, %d sommets de planches retirés" % len(set(doomed)))


# ---------------------------------------------------------------- structure

class Obstacles:
    """Boîtes englobantes des pièces de décor existantes, pour ne rien poser dessus."""

    def __init__(self):
        self.boxes = []
        for obj in bpy.data.objects:
            if obj.type != "MESH" or not obj.name.startswith("Int_") or obj.hide_render:
                continue
            mesh = obj.data
            bm = bmesh.new()
            bm.from_mesh(mesh)
            bm.transform(obj.matrix_world)
            names = [m.name if m else "" for m in mesh.materials]
            seen = set()
            for v in bm.verts:
                if v in seen:
                    continue
                stack, comp = [v], []
                while stack:
                    x = stack.pop()
                    if x in seen:
                        continue
                    seen.add(x)
                    comp.append(x)
                    stack += [e.other_vert(x) for e in x.link_edges]
                faces = {f for p in comp for f in p.link_faces}
                if faces and all(names[f.material_index] in SHELL_MATS for f in faces):
                    continue
                lo = Vector([min(p.co[i] for p in comp) for i in range(3)])
                hi = Vector([max(p.co[i] for p in comp) for i in range(3)])
                size = hi - lo
                # baguette / plinthe collée au mur : fine selon X ou Y, peu haute -> un montant peut la recouvrir
                thin_axis = min(range(3), key=lambda i: size[i])
                trim = thin_axis in (0, 1) and size[thin_axis] < 0.08 and size.z <= 0.15
                if size.length < 4.0:
                    self.boxes.append((lo, hi, trim))
            bm.free()

    def free(self, lo, hi, margin=0.01, ignore_trims=False):
        for blo, bhi, trim in self.boxes:
            if ignore_trims and trim:
                continue
            if all(lo[i] < bhi[i] - margin and hi[i] > blo[i] + margin for i in range(3)):
                return False
        return True


def build_room(b, room, obstacles, beams_y, pipe_runs, label):
    x, y, z0, z1 = room["x"], room["y"], room["floor"], room["ceil"]
    post = 0.10
    # montants d'angle (cornières) + plinthe métallique
    for sx in (-1, 1):
        for sy in (-1, 1):
            lo = Vector((min(sx * x, sx * (x - post)), min(sy * y, sy * (y - post)), z0))
            hi = Vector((max(sx * x, sx * (x - post)), max(sy * y, sy * (y - post)), z1))
            if obstacles.free(lo, hi, ignore_trims=True):
                b.box(lo, hi, "IronDark")
                for zz in np.arange(z0 + 0.25, z1 - 0.1, 0.45):
                    c = Vector(((x - post / 2) * sx, (y - post - 0.005) * sy, zz))
                    b.box(c - Vector((0.012, 0.006, 0.012)), c + Vector((0.012, 0.006, 0.012)), "Copper")
            else:
                print("mecha_shell : %s, angle (%d,%d) occupé, pas de montant" % (label, sx, sy))
    # poutres de plafond en I (le long de X)
    depth, width = 0.10, 0.14
    for by in beams_y:
        x_lo, x_hi = -x, x
        lo = Vector((x_lo, by - width / 2, z1 - depth))
        hi = Vector((x_hi, by + width / 2, z1))
        if not obstacles.free(lo, hi):
            # raccourcir jusqu'à ce que ça passe
            while x_hi - x_lo > 1.0 and not obstacles.free(Vector((x_lo, lo.y, lo.z)), Vector((x_hi, hi.y, hi.z))):
                x_hi -= 0.1
        b.box((x_lo, by - width / 2, z1 - 0.02), (x_hi, by + width / 2, z1), "IronDark")            # semelle haute
        b.box((x_lo, by - 0.015, z1 - depth + 0.02), (x_hi, by + 0.015, z1 - 0.02), "IronDark")     # âme
        b.box((x_lo, by - width / 2, z1 - depth), (x_hi, by + width / 2, z1 - depth + 0.02), "IronDark")  # semelle basse
        for xx in np.arange(x_lo + 0.2, x_hi - 0.1, 0.5):
            b.box((xx - 0.01, by - width / 2 + 0.01, z1 - depth - 0.006), (xx + 0.01, by + width / 2 - 0.01, z1 - depth), "Copper")
    # tuyaux avec colliers
    for points, radius, mat in pipe_runs:
        b.pipe([Vector(p) for p in points], radius, mat, "IronDark")
        for a, c in zip(points, points[1:]):
            a, c = Vector(a), Vector(c)
            n = int((c - a).length / 0.7)
            for i in range(1, n + 1):
                p = a + (c - a) * (i / (n + 1))
                b.cylinder(p - (c - a).normalized() * 0.02, p + (c - a).normalized() * 0.02, radius * 1.35, "IronDark", 10)


def build_structure():
    kit.remove_objects("Shell_")
    obstacles = Obstacles()

    belly = kit.Builder("Shell_Belly")
    build_room(
        belly, BELLY, obstacles, beams_y=(-0.55, 1.2),
        pipe_runs=[
            # suite du tuyau de cuivre vertical du mur droit : il longe le plafond jusqu'au mur avant
            ([(2.08, -0.6, 5.22), (2.08, 1.80, 5.22), (2.08, 1.80, 4.6)], 0.04, "Copper"),
            # gros tuyau en fer le long du mur droit, juste sous le plafond
            ([(2.165, -0.9, 5.25), (2.165, 1.82, 5.25)], 0.032, "Iron"),
        ],
        label="ventre",
    )
    shell_belly = belly.finish()

    head = kit.Builder("Shell_Head")
    build_room(
        head, HEAD, obstacles, beams_y=(-0.6, 0.9),
        pipe_runs=[
            ([(2.12, -0.95, 8.13), (2.12, 1.80, 8.13)], 0.04, "Copper"),
            ([(-0.75, -1.84, 8.13), (1.25, -1.84, 8.13)], 0.035, "Iron"),
        ],
        label="tête",
    )
    shell_head = head.finish()
    print("mecha_shell : structure %d + %d triangles" % (kit.count_tris([shell_belly]), kit.count_tris([shell_head])))


# ---------------------------------------------------------------- main

def main():
    textured_material("WallCream", make_wall("wall_cream", kit.PALETTE["WallCream"][0], 11), 0.65, 0.0)
    textured_material("WallTeal", make_wall("wall_teal", kit.PALETTE["WallTeal"][0], 12, panel_h=0.5, kicks=True), 0.6, 0.0)
    textured_material("FloorPlate", make_floor("floor_plate", kit.PALETTE["FloorPlate"][0], 13), 0.55, 0.6)
    textured_material("Ceiling", make_ceiling("ceiling", kit.PALETTE["Ceiling"][0], 14), 0.75, 0.0)
    for name in ("Int_Belly", "Int_Head", "Int_HeadFront", "Int_Slab"):
        world_uvs(bpy.data.objects[name])
    clean_wear()
    remove_toilet_planks()
    remove_replaced_furniture()
    build_structure()
    bpy.ops.wm.save_mainfile()
    kit.export_glb(os.path.join(kit.ROOT, "assets", "models", "mecha.glb"))
    print("mecha_shell : mecha.blend sauvegardé, mecha.glb exporté")


main()
