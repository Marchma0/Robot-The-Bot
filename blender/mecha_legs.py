"""Jambes du mécha : squelette + pièces rigides accrochées aux os (M7.1, marche en rythme).

Fiche
- Repère : celui du mécha (origine du mécha, l'avant regarde vers +Y). Les hanches sont à x = ±1.4, z = 2.2,
  juste sous la caisse (dessous à z = 2.3). Le robot est à gauche en -X (sa gauche), à droite en +X.
- Longueurs : cuisse 1,25 m, tibia 1,25 m, cheville à 0,35 m au-dessus de la semelle.
  Debout, la hanche est à 2,75 m du sol (genoux un peu pliés) : l'origine du mécha est 0,55 m au-dessus du sol.
- Pose de repos : jambes tendues à la verticale (l'IK de Godot les plie).
- Os : pelvis, leg_L_thigh, leg_L_shin, leg_L_foot, leg_R_thigh, leg_R_shin, leg_R_foot.
- Budget : 6000 triangles.
- Pièces : boîtier de hanche (IronDark, flasques en cuivre), cuisse effilée (Paint) avec plaque avant rivée et vérin
  en cuivre à l'arrière, genou (IronDark) avec genouillère, tibia évasé (Paint) avec bandes sombres et ouïes,
  cheville, pied plat à semelle sombre et bout crème (comme les anciens pieds).
- Collisions des pieds : ajoutées dans Godot (scenes/mecha/legs.tscn).

    blender -b --factory-startup --python blender/mecha_legs.py
"""

import os
import sys

import bpy
from mathutils import Matrix

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "tools"))
import prop_kit as kit  # noqa: E402

HIP_X, HIP_Z = 1.4, 2.2
THIGH, SHIN = 1.25, 1.25
KNEE_Z = HIP_Z - THIGH
ANKLE_Z = KNEE_Z - SHIN
SOLE_Z = ANKLE_Z - 0.35


def build_rig():
    data = bpy.data.armatures.new("LegsRig")
    rig = bpy.data.objects.new("LegsRig", data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    pelvis = data.edit_bones.new("pelvis")
    pelvis.head, pelvis.tail = (0, 0, HIP_Z), (0, 0, HIP_Z + 0.3)
    for side, sx in (("L", -1), ("R", 1)):
        x = sx * HIP_X
        thigh = data.edit_bones.new("leg_%s_thigh" % side)
        thigh.head, thigh.tail, thigh.parent = (x, 0, HIP_Z), (x, 0, KNEE_Z), pelvis
        shin = data.edit_bones.new("leg_%s_shin" % side)
        shin.head, shin.tail, shin.parent, shin.use_connect = (x, 0, KNEE_Z), (x, 0, ANKLE_Z), thigh, True
        foot = data.edit_bones.new("leg_%s_foot" % side)
        foot.head, foot.tail, foot.parent = (x, 0, ANKLE_Z), (x, 0.6, ANKLE_Z), shin
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def attach(obj, rig, bone):
    """Accroche une pièce rigide à un os sans la déplacer."""
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    bpy.context.view_layer.update()
    obj.matrix_world = Matrix.Identity(4)


def thigh_parts(b, x):
    b.cylinder((x - 0.48, 0, HIP_Z), (x + 0.48, 0, HIP_Z), 0.32, "IronDark", segments=14)          # boîtier de hanche
    for sx in (-1, 1):
        b.cylinder((x + sx * 0.48, 0, HIP_Z), (x + sx * 0.51, 0, HIP_Z), 0.23, "Copper", segments=12)
    b.frustum((x, 0.0), KNEE_Z + 0.12, HIP_Z - 0.12, (0.31, 0.34), (0.38, 0.41), "Paint")
    b.frustum((x, 0.36), KNEE_Z + 0.25, HIP_Z - 0.3, (0.23, 0.035), (0.28, 0.04), "IronDark")    # plaque avant
    for z in (KNEE_Z + 0.32, HIP_Z - 0.32):
        b.rivet_row((x - 0.2, 0.4, z), (x + 0.2, 0.4, z), (0, 1, 0), spacing=0.08, size=0.03, depth=0.012)
    # vérin à l'arrière de la cuisse
    b.cylinder((x, -0.45, HIP_Z - 0.2), (x, -0.45, KNEE_Z + 0.55), 0.07, "Copper", segments=10)
    b.cylinder((x, -0.45, KNEE_Z + 0.55), (x, -0.45, KNEE_Z + 0.2), 0.035, "Iron", segments=8)
    b.box((x - 0.07, -0.45, HIP_Z - 0.28), (x + 0.07, -0.33, HIP_Z - 0.18), "IronDark")


def shin_parts(b, x):
    b.cylinder((x - 0.4, 0, KNEE_Z), (x + 0.4, 0, KNEE_Z), 0.3, "IronDark", segments=14)           # genou
    for sx in (-1, 1):
        b.cylinder((x + sx * 0.4, 0, KNEE_Z), (x + sx * 0.43, 0, KNEE_Z), 0.2, "Copper", segments=12)
    b.box((x - 0.24, 0.27, KNEE_Z - 0.14), (x + 0.24, 0.39, KNEE_Z + 0.24), "Cream")                 # genouillère
    b.frustum((x, 0.0), ANKLE_Z + 0.12, KNEE_Z - 0.1, (0.37, 0.37), (0.31, 0.32), "Paint")
    for z in (KNEE_Z - 0.35, ANKLE_Z + 0.35):
        b.frustum((x, 0.0), z - 0.04, z + 0.04, (0.364, 0.364), (0.356, 0.356), "IronDark")          # bandes
    for i in range(3):
        z = ANKLE_Z + 0.55 + i * 0.07
        b.box((x - 0.16, 0.345, z), (x + 0.16, 0.37, z + 0.025), "IronDark")                         # ouïes
    b.cylinder((x, -0.37, KNEE_Z - 0.3), (x, -0.37, ANKLE_Z + 0.3), 0.05, "Copper", segments=8)    # durite


def foot_parts(b, x):
    b.cylinder((x - 0.36, 0, ANKLE_Z), (x + 0.36, 0, ANKLE_Z), 0.25, "IronDark", segments=14)      # cheville
    b.box((x - 0.55, -0.6, SOLE_Z), (x + 0.55, 0.9, SOLE_Z + 0.14), "IronDark")                      # semelle
    b.box((x - 0.46, -0.5, SOLE_Z + 0.14), (x + 0.46, 0.7, ANKLE_Z - 0.05), "Paint")                # dessus
    b.box((x - 0.53, 0.9, SOLE_Z), (x + 0.53, 1.14, SOLE_Z + 0.24), "Cream")                         # bout de pied
    b.box((x - 0.48, -0.68, SOLE_Z), (x + 0.48, -0.6, SOLE_Z + 0.2), "IronDark")                     # talon
    for sx in (-1, 1):
        b.rivet_row((x + sx * 0.55, -0.5, SOLE_Z + 0.07), (x + sx * 0.55, 0.8, SOLE_Z + 0.07),
                    (sx, 0, 0), spacing=0.15, size=0.03, depth=0.012)


def main():
    kit.new_scene()
    for arm in list(bpy.data.armatures):
        bpy.data.armatures.remove(arm)
    rig = build_rig()
    for side, sx in (("L", -1), ("R", 1)):
        x = sx * HIP_X
        for part, func in (("thigh", thigh_parts), ("shin", shin_parts), ("foot", foot_parts)):
            b = kit.Builder("Leg_%s_%s" % (side, part))
            func(b, x)
            attach(b.finish(), rig, "leg_%s_%s" % (side, part))
    kit.save_and_export("mecha_legs", budget_tris=6000, folder="")


main()
