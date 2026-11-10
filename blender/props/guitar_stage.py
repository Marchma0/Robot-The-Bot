"""Scène de guitare QTE du garage (4.4) : estrade rock d'atelier, amplis à lampes, écran de partition.

Fiche
- Taille : estrade de 2,6 m (X) x 2,0 m (Y), hauteur 0,18 m ; mur d'amplis à l'arrière (-Y) jusqu'à 1,50 m ;
  pupitre de partition devant le joueur (+Y) à 0,78 m. Repère : un nain fait 1,2 m.
- Origine : au sol, au centre de l'estrade. Le musicien se tient au centre (0, 0, 0.18) face à +Y (le public).
- Budget : 2400 triangles.
- Pièces : estrade (Wood, IronDark) et tapis (Rug, RugTrim), 2 colonnes d'amplis à lampes (IronDark, Copper,
  Bulb, Canvas), pied de micro (Iron, Copper), pupitre d'écran QTE incliné (IronDark, Copper, Neon) et 2 spots.

    blender -b --factory-startup --python blender/props/guitar_stage.py
"""

import math
import os
import sys

from mathutils import Vector

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

STAGE_Z = 0.16


def main():
    kit.new_scene()
    b = kit.Builder("GuitarStage")

    # Estrade en bois cerclée d'acier sombre + tapis de scène
    b.box((-1.3, -1.0, 0.0), (1.3, 1.0, STAGE_Z), "IronDark")
    b.box((-1.24, -0.94, STAGE_Z + 0.001), (1.24, 0.94, STAGE_Z + 0.02), "Wood")
    b.box((-0.65, -0.36, STAGE_Z + 0.022), (0.65, 0.36, STAGE_Z + 0.032), "Rug")
    b.box((-0.70, -0.40, STAGE_Z + 0.021), (0.70, -0.365, STAGE_Z + 0.030), "RugTrim")
    b.box((-0.70, 0.365, STAGE_Z + 0.021), (0.70, 0.40, STAGE_Z + 0.030), "RugTrim")

    # Deux gros amplis à lampes à l'arrière de l'estrade (x = -0.82 et +0.82, y = -0.65)
    for sx in (-1.0, 1.0):
        ax = sx * 0.82
        b.box((ax - 0.36, -0.88, STAGE_Z + 0.023), (ax + 0.36, -0.42, STAGE_Z + 0.86), "IronDark")
        b.box((ax - 0.30, -0.418, STAGE_Z + 0.08), (ax + 0.30, -0.405, STAGE_Z + 0.80), "Canvas")
        for gx in (-0.14, 0.14):
            for gz in (STAGE_Z + 0.25, STAGE_Z + 0.62):
                b.cylinder((ax + gx, -0.404, gz), (ax + gx, -0.39, gz), 0.11, "Copper", segments=10)
        b.box((ax - 0.32, -0.84, STAGE_Z + 0.865), (ax + 0.32, -0.46, STAGE_Z + 1.18), "Paint")
        b.box((ax - 0.28, -0.458, STAGE_Z + 0.92), (ax + 0.28, -0.445, STAGE_Z + 1.12), "Copper")
        for lx in (-0.16, 0.0, 0.16):
            b.cylinder((ax + lx, -0.65, STAGE_Z + 1.182), (ax + lx, -0.65, STAGE_Z + 1.32), 0.035, "Bulb", segments=8)

        # Spot de scène aux coins avant de l'estrade
        fx = sx * 1.05
        b.box((fx - 0.12, 0.72, STAGE_Z + 0.023), (fx + 0.12, 0.90, STAGE_Z + 0.18), "IronDark")
        b.box((fx - 0.09, 0.71, STAGE_Z + 0.05), (fx + 0.09, 0.718, STAGE_Z + 0.15), "Bulb")

    # Pied de micro devant le musicien (légèrement à droite : x = -0.46, y = 0.52)
    b.cylinder((-0.46, 0.52, STAGE_Z + 0.023), (-0.46, 0.52, STAGE_Z + 0.06), 0.12, "IronDark", segments=10)
    b.cylinder((-0.46, 0.52, STAGE_Z + 0.062), (-0.46, 0.52, STAGE_Z + 0.98), 0.018, "Iron", segments=6)
    b.sphere((-0.46, 0.47, STAGE_Z + 1.02), 0.045, "Copper", segments=8)

    # Pupitre retour de scène au centre-avant (y = 0.72) incliné
    b.cylinder((0.0, 0.72, STAGE_Z + 0.023), (0.0, 0.72, 0.58), 0.045, "IronDark", segments=8)
    b.tilted_box(Vector((0.0, 0.72, 0.76)), (0.72, 0.26, 0.38), math.radians(-18.0), "IronDark")
    b.tilted_box(Vector((0.0, 0.72, 0.97)), (0.68, 0.28, 0.04), math.radians(-18.0), "Neon")

    b.finish()
    kit.save_and_export("guitar_stage", budget_tris=2400)


main()
