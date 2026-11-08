"""Bras de vue du nain (première personne, façon Lethal Company / Deep Rock Galactic).

Fiche
- Ce que voit le joueur de lui-même : deux bras (manche de tunique, revers en cuir, main avec un doigt tendu,
  trois doigts repliés et un pouce), accrochés au squelette du nain (`DwarfRig` de blender/dwarf.blend) :
  toutes les animations du nain (press, grab, throw, emote_*…) les animent telles quelles.
- Taille : bras d'un nain de 1,2 m (épaule en z = 0,78, poignet en z = 0,45), un peu plus fins que ceux du
  corps (ils sont vus de près).
- Budget : 1800 triangles.
- Pièces (par os) : arm_* = épaule, manche, brassard, revers, paume, doigts repliés ; finger_* = doigt tendu ;
  thumb_* = pouce. Matériaux du nain : Tunic (prend la couleur du joueur), Leather, Copper, Skin.

Lit blender/dwarf.blend (sans le modifier), retire le corps et la tête, construit les bras et produit
blender/dwarf_fp_arms.blend + assets/models/dwarf_fp_arms.glb (squelette + bras + toutes les actions) :

    blender -b blender/dwarf.blend --python blender/dwarf_fp_arms.py
"""

import os
import sys

import bpy

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
sys.path.append(os.path.join(ROOT, "blender", "tools"))
import prop_kit as kit  # noqa: E402

SHOULDER_Z, WRIST_Z = 0.78, 0.45
SHOULDER_X, WRIST_X = 0.3, 0.36
WRIST_Y = 0.02


def part(name, group, build):
    """Une pièce construite par `build(b)`, entièrement liée à l'os `group`."""
    b = kit.Builder(name)
    build(b)
    obj = b.finish()
    vg = obj.vertex_groups.new(name=group)
    vg.add([v.index for v in obj.data.vertices], 1.0, "REPLACE")
    return obj


def arm_parts(side, sx):
    wx = sx * WRIST_X
    inner = -sx   # côté du corps (où est le pouce)

    def arm(b):
        b.sphere((sx * SHOULDER_X, 0.0, SHOULDER_Z), 0.072, "Tunic", 10)
        b.cylinder((sx * SHOULDER_X, 0.0, SHOULDER_Z), (wx, WRIST_Y, WRIST_Z + 0.05), 0.07, "Tunic", 12, 0.06)
        # brassard de cuivre au coude, revers de cuir au poignet
        b.cylinder((sx * 0.33, 0.01, 0.62), (sx * 0.335, 0.012, 0.595), 0.071, "Copper", 12, 0.069)
        b.cylinder((wx, WRIST_Y, WRIST_Z + 0.06), (wx, WRIST_Y, WRIST_Z + 0.005), 0.073, "Leather", 12, 0.068)
        # paume (un peu aplatie) et trois doigts repliés devant
        b.box((wx - 0.036, -0.036, 0.355), (wx + 0.036, 0.046, WRIST_Z + 0.012), "Skin")
        for k in range(3):
            fx = wx - inner * (0.0 + k * 0.023)
            b.box((fx - 0.0105, 0.046, 0.362), (fx + 0.0105, 0.08, 0.408), "Skin")

    def finger(b):
        fx = wx + inner * 0.023
        b.cylinder((fx, 0.058, 0.43), (fx, 0.058, 0.335), 0.0125, "Skin", 8)
        b.sphere((fx, 0.058, 0.335), 0.0125, "Skin", 8)

    def thumb(b):
        tx = wx + inner * 0.042
        b.cylinder((tx, -0.02, 0.42), (tx, 0.05, 0.42), 0.015, "Skin", 8)
        b.sphere((tx, 0.05, 0.42), 0.015, "Skin", 8)

    return [
        part("FPArm_%s" % side, "arm_%s" % side, arm),
        part("FPFinger_%s" % side, "finger_%s" % side, finger),
        part("FPThumb_%s" % side, "thumb_%s" % side, thumb),
    ]


def main():
    for name in ("DwarfBody", "DwarfHead"):
        obj = bpy.data.objects.get(name)
        if obj is not None:
            bpy.data.objects.remove(obj, do_unlink=True)
    rig = bpy.data.objects["DwarfRig"]
    pieces = []
    for side, sx in (("L", -1), ("R", 1)):
        pieces += arm_parts(side, sx)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in pieces:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = pieces[0]
    bpy.ops.object.join()
    arms = bpy.context.view_layer.objects.active
    arms.name = "FPArms"
    arms.data.name = "FPArms"
    arms.parent = rig
    mod = arms.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    tris = kit.count_tris([arms])
    print("dwarf_fp_arms : %d triangles (budget 1800)" % tris)
    if tris > 1800:
        raise SystemExit("budget de triangles dépassé")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "blender", "dwarf_fp_arms.blend"))
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    arms.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(ROOT, "assets", "models", "dwarf_fp_arms.glb"),
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_cameras=False,
        export_lights=False,
        export_yup=True,
        export_animations=True,
    )


main()
