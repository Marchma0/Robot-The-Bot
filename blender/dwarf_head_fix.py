"""Tête du nain (faite à la main dans blender/dwarf.blend) : corrige les faces superposées puis réexporte la tête.

Les yeux et la barbe touchaient le bord du casque dans le même plan : ces faces clignotaient en jeu. Pour chaque
paire, la plus petite des deux pièces avance de 1,5 mm dans le sens de sa face (elle passe devant, comme un
autocollant). Relançable : quand il n'y a plus rien à corriger, le script ne bouge plus rien.

    blender -b blender/dwarf.blend --python blender/dwarf_head_fix.py

Sauvegarde blender/dwarf.blend, exporte assets/models/dwarf_head.glb (tête seule, origine sur l'os `head`),
puis passe les contrôles (check_asset, roundtrip_glb).
"""

import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "tools"))
import check_asset  # noqa: E402
import prop_kit as kit  # noqa: E402
import roundtrip_glb  # noqa: E402

STEP = 0.0015   # m
PASSES = 6


def pieces(bm):
    """Pièces séparées du maillage : pour chaque sommet, l'indice de sa pièce ; et la taille de chaque pièce."""
    piece_of, sizes, seen = {}, [], set()
    for start in bm.verts:
        if start in seen:
            continue
        stack, verts = [start], []
        while stack:
            v = stack.pop()
            if v in seen:
                continue
            seen.add(v)
            verts.append(v)
            stack += [e.other_vert(v) for e in v.link_edges]
        lo = Vector([min(v.co[i] for v in verts) for i in range(3)])
        hi = Vector([max(v.co[i] for v in verts) for i in range(3)])
        for v in verts:
            piece_of[v.index] = len(sizes)
        sizes.append((verts, (hi - lo).length))
    return piece_of, sizes


def fix(obj) -> int:
    moved = 0
    for _ in range(PASSES):
        issues = kit.find_z_fighting(obj)
        if not issues:
            break
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.faces.ensure_lookup_table()
        piece_of, sizes = pieces(bm)
        wanted = {}
        for *_info, face_a, face_b in issues:
            fa, fb = bm.faces[face_a], bm.faces[face_b]
            pa, pb = piece_of[fa.verts[0].index], piece_of[fb.verts[0].index]
            small, face = (pa, fa) if sizes[pa][1] <= sizes[pb][1] else (pb, fb)
            wanted.setdefault(small, []).append(face.normal.copy())
        for piece, normals in wanted.items():
            push = sum(normals, Vector()).normalized() * STEP
            for v in sizes[piece][0]:
                v.co += push
            moved += 1
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
    return moved


def main() -> None:
    head = bpy.data.objects["DwarfHead"]
    print("dwarf_head_fix : %d pièce(s) déplacée(s)" % fix(head))
    report = check_asset.check([head], "dwarf_head", ground=False)
    if report.failed:
        raise RuntimeError("dwarf_head_fix : contrôles ratés, rien n'est écrit")
    origin = head.location.copy()
    head.location = (0.0, 0.0, 0.0)   # la tête s'exporte dans le repère de l'os `head`
    bpy.context.view_layer.update()
    expected = roundtrip_glb.expected_from_scene([head])
    glb = os.path.join(kit.ROOT, "assets", "models", "dwarf_head.glb")
    bpy.ops.object.select_all(action="DESELECT")
    head.select_set(True)
    bpy.context.view_layer.objects.active = head
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True, export_apply=False,
                              export_cameras=False, export_lights=False, export_yup=True, export_animations=False)
    head.location = origin
    bpy.ops.wm.save_mainfile()
    if not roundtrip_glb.check_export(glb, expected):
        raise RuntimeError("dwarf_head_fix : le .glb réimporté ne correspond pas à la tête")
    print("dwarf_head_fix : OK")


main()
