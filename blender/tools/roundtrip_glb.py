"""Aller-retour d'un .glb : on réimporte le fichier exporté dans un Blender vide et on vérifie qu'on retrouve le modèle
(triangles, taille à 1 % près, os, animations). Attrape un export raté : objet oublié, modificateur non appliqué,
mauvaise échelle, animation perdue. `prop_kit.save_and_export` l'appelle après chaque export (`check_export`).

Utilisation seule (le .blend donne ce qu'on attend ; sans lui, on affiche seulement ce que contient le .glb) :

    blender -b --factory-startup --python blender/tools/roundtrip_glb.py -- assets/models/props/barrel.glb --blend blender/props/barrel.blend

Avec --blend, on attend les objets visibles au rendu du fichier (maillages et squelettes) et toutes ses actions.
"""

import json
import math
import os
import subprocess
import sys

import bpy
from mathutils import Vector

SIZE_TOLERANCE = 0.01        # 1 % de la taille
SIZE_MIN_TOLERANCE = 0.002   # m (petits objets)
TRIS_TOLERANCE = 0.005       # 0,5 %


def measure(objects, actions=()) -> dict:
    """Triangles, taille (X, Y, Z en m), nombre d'os et noms des animations d'un ensemble d'objets."""
    # L’import glTF ajoute une petite sphère pour dessiner les os : ce n’est pas le modèle.
    bone_shapes = {pb.custom_shape for o in objects if o.type == "ARMATURE" for pb in o.pose.bones if pb.custom_shape}
    meshes = [o for o in objects if o.type == "MESH" and o not in bone_shapes]
    # Maillage final (modificateurs appliqués, comme à l’export).
    depsgraph = bpy.context.evaluated_depsgraph_get()
    lo = Vector((math.inf,) * 3)
    hi = Vector((-math.inf,) * 3)
    triangles = 0
    for obj in meshes:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        matrix = obj.matrix_world
        triangles += sum(len(p.vertices) - 2 for p in mesh.polygons)
        for v in mesh.vertices:
            p = matrix @ v.co
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
        evaluated.to_mesh_clear()
    return {
        "triangles": triangles,
        "size": list(hi - lo) if meshes else [0.0, 0.0, 0.0],
        "bones": sum(len(o.data.bones) for o in objects if o.type == "ARMATURE"),
        "actions": sorted(a.name for a in actions),
    }


def expected_from_scene(objects=None) -> dict:
    """Ce que l'export doit contenir : les objets donnés (par défaut ceux visibles au rendu) et les actions du fichier."""
    if objects is None:
        objects = [o for o in bpy.context.scene.objects if not o.hide_render]
    objects = [o for o in objects if o.type in {"MESH", "ARMATURE"}]
    has_rig = any(o.type == "ARMATURE" for o in objects)
    actions = [a for a in bpy.data.actions if a.users > 0 or a.use_fake_user] if has_rig else []
    return measure(objects, actions)


def check_export(path: str, expected: dict) -> bool:
    """Depuis un script Blender : refait l'aller-retour de `path` dans un autre Blender, vide, et compare."""
    script = os.path.abspath(__file__)
    result = subprocess.run(
        [bpy.app.binary_path, "-b", "--factory-startup", "--python", script, "--",
         os.path.abspath(path), "--expect", json.dumps(expected)],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    for line in result.stdout.splitlines():
        if line.startswith(("roundtrip_glb", "  ")):
            print(line)
    if result.returncode not in (0, 1):
        print(result.stderr[-2000:])
    return result.returncode == 0


def roundtrip(path: str, expected: dict = None) -> bool:
    """Dans un Blender vide : importe `path`, mesure, compare à `expected`. Vrai si tout correspond."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
    got = measure(list(bpy.context.scene.objects), list(bpy.data.actions))
    return _report(os.path.basename(path), got, expected)


def _report(name: str, got: dict, expected: dict) -> bool:
    print("roundtrip_glb : %s" % name)
    print("  contenu : %d triangles, taille %.3f x %.3f x %.3f m, %d os, %d animations"
          % (got["triangles"], *got["size"], got["bones"], len(got["actions"])))
    if expected is None:
        return True
    failures = []
    if abs(got["triangles"] - expected["triangles"]) > max(1, expected["triangles"] * TRIS_TOLERANCE):
        failures.append("triangles : %d au lieu de %d" % (got["triangles"], expected["triangles"]))
    for axis, g, e in zip("XYZ", got["size"], expected["size"]):
        if abs(g - e) > max(SIZE_MIN_TOLERANCE, e * SIZE_TOLERANCE):
            failures.append("taille %s : %.3f m au lieu de %.3f m" % (axis, g, e))
    if got["bones"] != expected["bones"]:
        failures.append("os : %d au lieu de %d" % (got["bones"], expected["bones"]))
    # L'import peut ajouter le nom de l'objet à celui de l'action : on cherche le nom attendu au début.
    missing = [a for a in expected["actions"] if not any(g.startswith(a) for g in got["actions"])]
    if missing:
        failures.append("animations perdues : " + ", ".join(missing))
    for line in failures:
        print("  FAIL  " + line)
    print("  => %s" % ("FAIL" if failures else "PASS (même modèle après l'aller-retour)"))
    return not failures


def _parse_args(argv):
    args = argv[argv.index("--") + 1:] if "--" in argv else []
    blend = args[args.index("--blend") + 1] if "--blend" in args else ""
    expect = json.loads(args[args.index("--expect") + 1]) if "--expect" in args else None
    paths = [a for a in args if a.endswith(".glb")]
    return paths, blend, expect


if __name__ == "__main__":
    glb_paths, blend_path, expected_stats = _parse_args(sys.argv)
    if not glb_paths:
        print("roundtrip_glb : donner le chemin d'un .glb après « -- »")
        sys.exit(2)
    if blend_path:
        bpy.ops.wm.open_mainfile(filepath=os.path.abspath(blend_path))
        expected_stats = expected_from_scene()
    ok = all([roundtrip(p, expected_stats) for p in glb_paths])
    sys.exit(0 if ok else 1)
