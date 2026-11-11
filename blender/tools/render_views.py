"""Planche de vues d'un modèle, pour que l'IA (ou un humain) vérifie la forme sous tous les angles.

Produit UNE image PNG en grille 3 x 2 :
    ligne du haut : AVANT  | DROITE du modèle | ARRIÈRE
    ligne du bas  : GAUCHE | DESSUS (avant en bas de l'image) | 3/4 avant-droit
Convention : l'avant d'un modèle regarde vers +Y dans Blender (devient l'avant -Z dans Godot).
Toutes les vues sont orthographiques et à la MÊME échelle : on peut comparer les proportions
d'une vue à l'autre. Une grille au sol fait 1 m par case. Les dimensions sont affichées dans la console.

Ne modifie pas la scène : tout ce qui est créé est supprimé et les réglages sont restaurés.

Utilisation
-----------
1) En ligne de commande (sans MCP, marche pour toutes les IA) :
     blender -b blender/mecha.blend --python blender/tools/render_views.py -- --out build/views/mecha.png
   Options après « -- » :
     --out CHEMIN        fichier PNG de sortie (défaut : build/views/<nom du .blend>.png)
     --target NOMS       objets ou collections à montrer, séparés par des virgules (défaut : tout ce qui est visible)
     --size PIXELS       taille d'une vue (défaut : 512)
     --ref               repères d'échelle à côté du modèle : un nain (1,2 m) et une porte (2 m de haut)

2) Depuis le MCP Blender (Blender ouvert) :
     exec(open(r"<projet>/blender/tools/render_views.py", encoding="utf-8").read(), {"__name__": "render_views"})
   puis dans le même code : render_views(out=r"<projet>/build/views/x.png", target=["Mecha"])
   (ou plus simple : exécuter le fichier puis appeler la fonction depuis le dictionnaire passé à exec).
"""

import math
import os
import sys
import tempfile

import bpy
import numpy as np
from mathutils import Matrix, Vector

# (nom, direction depuis le centre vers la caméra)
# Convention du projet : l'AVANT d'un modèle regarde vers +Y dans Blender (= -Z, l'avant, dans Godot après export glTF).
# « droite » / « gauche » = côtés du modèle lui-même : il regarde vers +Y, donc sa droite est en +X
# (ex. le mécha : foreuse = main droite en +X, grappin = main gauche en -X).
VIEWS = [
    ("avant", Vector((0, 1, 0))),
    ("droite", Vector((1, 0, 0))),
    ("arriere", Vector((0, -1, 0))),
    ("gauche", Vector((-1, 0, 0))),
    ("dessus", Vector((0, 0, 1))),
    ("3/4 avant-droit", Vector((1, 1, 0.7)).normalized()),
]
COLUMNS = 3
GAP = 6  # pixels entre les vues
BACKGROUND = (0.16, 0.17, 0.19)
GRID_COLOR = (0.32, 0.34, 0.38)


REF_COLOR = (0.45, 0.62, 0.85)
DWARF_HEIGHT = 1.2   # m (capsule de collision du nain)
DOOR_SIZE = (0.9, 2.0)


def render_views(out: str = "", target=None, size: int = 512, ref: bool = False) -> str:
    scene = bpy.context.scene
    objects = _collect_targets(target)
    if not objects:
        raise RuntimeError("render_views : aucun objet visible à montrer")

    model_lo, model_hi = _world_bounds(objects)
    references = _add_references(model_lo, model_hi) if ref else []
    objects = objects + references
    lo, hi = _world_bounds(objects)
    center = (lo + hi) / 2
    dims = hi - lo
    radius = max(dims.length / 2, 0.05)
    ortho_scale = radius * 2 * 1.08

    if not out:
        blend = os.path.splitext(os.path.basename(bpy.data.filepath))[0] or "scene"
        out = os.path.join(_project_root(), "build", "views", blend + ".png")
    out = os.path.abspath(out)  # Blender n'enregistre pas les images aux chemins relatifs
    os.makedirs(os.path.dirname(out), exist_ok=True)

    saved = _save_settings(scene, objects)
    created = list(references)
    tmp_dir = tempfile.mkdtemp(prefix="render_views_")
    tiles = []
    try:
        _setup_render(scene, size, objects)
        created.append(_add_ground_grid(lo.z, center, radius))
        cam_data = bpy.data.cameras.new("_rv_cam")
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = ortho_scale
        cam_data.clip_start = 0.01
        cam_data.clip_end = radius * 10
        cam = bpy.data.objects.new("_rv_cam", cam_data)
        scene.collection.objects.link(cam)
        created.append(cam)
        scene.camera = cam

        for name, direction in VIEWS:
            cam.location = center + direction * radius * 4
            if abs(direction.z) > 0.99:
                cam.rotation_euler = (0.0, 0.0, math.pi)  # vue de dessus : l'avant (+Y) en bas de l'image
            else:
                # la caméra regarde selon son -Z, son haut est son +Y, aligné sur le haut du monde (+Z)
                cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
            path = os.path.join(tmp_dir, name.replace("/", "_") + ".png")
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            tiles.append(_load_pixels(path, size))
    finally:
        for obj in created:
            data = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if isinstance(data, bpy.types.Camera):
                bpy.data.cameras.remove(data)
            elif isinstance(data, bpy.types.Mesh):
                bpy.data.meshes.remove(data)
        _restore_settings(scene, saved)

    _write_sheet(tiles, size, out)
    print(
        "render_views : %s\n  vues : %s\n  dimensions (m) : largeur X %.2f, profondeur Y %.2f, hauteur Z %.2f\n"
        "  grille au sol : 1 case = 1 m, toutes les vues à la même échelle"
        % (out, " | ".join(n for n, _ in VIEWS), *(model_hi - model_lo))
    )
    if ref:
        height = (model_hi - model_lo).z
        print("  repères (en bleu, à droite du modèle) : un nain de %.1f m, une porte de %.1f m ; "
              "le modèle fait %.2f fois la hauteur d'un nain" % (DWARF_HEIGHT, DOOR_SIZE[1], height / DWARF_HEIGHT))
    return out


def _collect_targets(target):
    view_layer = bpy.context.view_layer
    if not target:
        return [o for o in view_layer.objects if o.visible_get() and o.type in {"MESH", "CURVE", "SURFACE", "META", "FONT"}]
    if isinstance(target, str):
        target = [t.strip() for t in target.split(",") if t.strip()]
    found = []
    for name in target:
        if name in bpy.data.collections:
            found += list(bpy.data.collections[name].all_objects)
        elif name in bpy.data.objects:
            obj = bpy.data.objects[name]
            found += [obj] + list(obj.children_recursive)
        else:
            raise RuntimeError("render_views : objet ou collection introuvable : " + name)
    return [o for o in found if o.type in {"MESH", "CURVE", "SURFACE", "META", "FONT"}]


def _world_bounds(objects):
    lo = Vector((math.inf,) * 3)
    hi = Vector((-math.inf,) * 3)
    for obj in objects:
        for corner in obj.bound_box:
            p = obj.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
    return lo, hi


def _save_settings(scene, shown):
    return {
        "engine": scene.render.engine,
        "camera": scene.camera,
        "filepath": scene.render.filepath,
        "res": (scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage),
        "film_transparent": scene.render.film_transparent,
        "format": (scene.render.image_settings.file_format, scene.render.image_settings.color_mode),
        "shading": {k: getattr(scene.display.shading, k) for k in ("light", "color_type", "show_cavity", "show_object_outline", "show_shadows")},
        "hidden": {o.name: o.hide_render for o in scene.objects},
    }


def _restore_settings(scene, saved):
    scene.render.engine = saved["engine"]
    scene.camera = saved["camera"]
    scene.render.filepath = saved["filepath"]
    scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = saved["res"]
    scene.render.film_transparent = saved["film_transparent"]
    scene.render.image_settings.file_format, scene.render.image_settings.color_mode = saved["format"]
    for key, value in saved["shading"].items():
        setattr(scene.display.shading, key, value)
    for name, value in saved["hidden"].items():
        if name in scene.objects:
            scene.objects[name].hide_render = value


def _setup_render(scene, size, objects):
    try:
        scene.render.engine = "BLENDER_WORKBENCH"
    except TypeError as err:
        raise RuntimeError("render_views : moteur Workbench indisponible (%s)" % err)
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "MATERIAL"
    shading.show_cavity = True
    shading.show_object_outline = True
    shading.show_shadows = False
    # On ne montre que la cible (la grille, ajoutée ensuite, est visible)
    names = {o.name for o in objects}
    for obj in scene.objects:
        obj.hide_render = obj.name not in names


def _add_references(lo, hi):
    """Silhouette d'un nain (1,2 m) et cadre de porte (0,9 x 2 m), posés au sol à droite du modèle (+X)."""
    import bmesh

    mat = bpy.data.materials.get("_rv_ref_mat") or bpy.data.materials.new("_rv_ref_mat")
    mat.diffuse_color = (*REF_COLOR, 1.0)
    x = hi.x + 0.6
    y = (lo.y + hi.y) / 2
    z = lo.z
    pieces = {
        "_rv_ref_nain": [
            ("sphere", (x, y, z + 0.32), (0.22, 0.2, 0.32)),        # jambes et ventre
            ("sphere", (x, y, z + 0.62), (0.3, 0.24, 0.24)),        # torse
            ("sphere", (x, y, z + 0.98), (0.2, 0.2, 0.22)),         # tête (haut à 1,2 m)
        ],
        "_rv_ref_porte": [
            ("box", (x + 0.8, y, z + DOOR_SIZE[1] / 2), (0.06, 0.1, DOOR_SIZE[1])),
            ("box", (x + 0.8 + DOOR_SIZE[0], y, z + DOOR_SIZE[1] / 2), (0.06, 0.1, DOOR_SIZE[1])),
            ("box", (x + 0.8 + DOOR_SIZE[0] / 2, y, z + DOOR_SIZE[1] - 0.03), (DOOR_SIZE[0] + 0.06, 0.1, 0.06)),
        ],
    }
    created = []
    for name, parts in pieces.items():
        bm = bmesh.new()
        for kind, center, dims in parts:
            matrix = Matrix.Translation(center) @ Matrix.Diagonal((*dims, 1.0))
            if kind == "box":
                bmesh.ops.create_cube(bm, size=1.0, matrix=matrix)
            else:
                bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=1.0, matrix=matrix)
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(mat)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        created.append(obj)
    return created


def _add_ground_grid(z, center, radius):
    """Grille de 1 m posée sous le modèle (visible en vues de côté comme une ligne de sol)."""
    import bmesh

    half = math.ceil(radius) + 1
    mesh = bpy.data.meshes.new("_rv_grid")
    bm = bmesh.new()
    cx, cy = round(center.x), round(center.y)
    w = 0.012
    for i in range(-half, half + 1):
        for (x0, y0, x1, y1) in (
            (cx + i - w, cy - half, cx + i + w, cy + half),
            (cx - half, cy + i - w, cx + half, cy + i + w),
        ):
            v = [bm.verts.new((a, b, z - 0.002)) for a, b in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
            bm.faces.new(v)
    bm.to_mesh(mesh)
    bm.free()
    mat = bpy.data.materials.get("_rv_grid_mat") or bpy.data.materials.new("_rv_grid_mat")
    mat.diffuse_color = (*GRID_COLOR, 1.0)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new("_rv_grid", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.hide_render = False
    return obj


def _load_pixels(path, size):
    img = bpy.data.images.load(path)
    px = np.empty(size * size * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(size, size, 4)  # lignes du bas vers le haut


def _write_sheet(tiles, size, out):
    rows = math.ceil(len(tiles) / COLUMNS)
    width = COLUMNS * size + (COLUMNS + 1) * GAP
    height = rows * size + (rows + 1) * GAP
    sheet = np.ones((height, width, 4), dtype=np.float32)
    sheet[:, :, :3] = 0.05
    for index, tile in enumerate(tiles):
        row, col = divmod(index, COLUMNS)
        y0 = height - (row + 1) * (size + GAP)  # rangée 0 en haut de l'image
        x0 = GAP + col * (size + GAP)
        alpha = tile[:, :, 3:4]
        bg = np.array(BACKGROUND, dtype=np.float32)
        sheet[y0:y0 + size, x0:x0 + size, :3] = tile[:, :, :3] * alpha + bg * (1 - alpha)
    img = bpy.data.images.new("_rv_sheet", width, height, alpha=False)
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def _project_root():
    if bpy.data.filepath:
        # le .blend est dans <projet>/blender/
        return os.path.dirname(os.path.dirname(os.path.abspath(bpy.data.filepath)))
    return os.getcwd()


def _parse_args(argv):
    args = argv[argv.index("--") + 1:] if "--" in argv else []
    opts = {"out": "", "target": None, "size": 512, "ref": False}
    i = 0
    while i < len(args):
        key = args[i].lstrip("-")
        if key == "ref":
            opts["ref"] = True
            i += 1
        elif key in opts and i + 1 < len(args):
            opts[key] = int(args[i + 1]) if key == "size" else args[i + 1]
            i += 2
        else:
            i += 1
    return opts


if __name__ == "__main__":
    render_views(**_parse_args(sys.argv))
