"""Télé à tube sur bras mural (ventre du mécha, mur droit). L'image animée est un écran ajouté dans Godot.

Fiche
- Taille : 0,84 m de large, 0,62 m de haut, 0,16 m de saillie (bras compris).
- Origine : sur le mur, au centre de l'écran ; l'avant regarde vers +Y (l'arrière est contre le mur, en y = 0).
  Placée par scenes/mecha/props/tv_set.tscn (écran animé + lueur) en Godot (2.2, 3.86, -0.26),
  tournée vers la gauche du mécha (vers la pièce).
- Écran : rectangle de 0,68 x 0,48 m, centré en z = 0, à poser devant la face avant (y = FRONT, voir plus bas).
- Budget : 1600 triangles.
- Pièces : platine et bras de fixation (IronDark), coque (Paint) aux coins chanfreinés, cadre de l'écran (IronDark),
  panneau de boutons à droite (Cream, boutons Copper, voyant Lamp), grille de haut-parleur, antennes (Iron, Copper).

    blender -b --factory-startup --python blender/props/tv_set.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

FRONT = 0.155         # face avant de la télé (l'écran Godot se pose 2 mm devant)
BACK = 0.05           # arrière de la coque
HW, HH = 0.42, 0.31   # demi-taille de la coque
SCREEN_HW, SCREEN_HH = 0.34, 0.24


def main():
    kit.new_scene()
    b = kit.Builder("TvSet")
    # fixation murale : platine + bras
    b.box((-0.12, 0.0, -0.1), (0.12, 0.015, 0.1), "IronDark")
    b.box((-0.04, 0.015, -0.05), (0.04, BACK + 0.003, 0.05), "IronDark")
    # coque : boîte + arrière plus petit (le tube cathodique)
    b.box((-HW, BACK + 0.02, -HH), (HW, FRONT - 0.01, HH), "Paint")
    b.box((-HW + 0.06, BACK, -HH + 0.06), (HW - 0.06, BACK + 0.02, HH - 0.06), "Paint")
    # chanfreins sur l'avant (bandeau un peu plus petit, 1 cm devant)
    b.box((-HW + 0.012, FRONT - 0.01, -HH + 0.012), (HW - 0.012, FRONT, HH - 0.012), "Paint")
    # cadre de l'écran (4 baguettes qui dépassent de 4 mm)
    sx0, sx1 = -HW + 0.03, -HW + 0.03 + 2 * SCREEN_HW
    sz0, sz1 = -SCREEN_HH, SCREEN_HH
    t = 0.02
    b.box((sx0 - t, FRONT, sz1), (sx1 + t, FRONT + 0.004, sz1 + t), "IronDark")
    b.box((sx0 - t, FRONT, sz0 - t), (sx1 + t, FRONT + 0.004, sz0), "IronDark")
    b.box((sx0 - t, FRONT, sz0), (sx0, FRONT + 0.004, sz1), "IronDark")
    b.box((sx1, FRONT, sz0), (sx1 + t, FRONT + 0.004, sz1), "IronDark")
    # panneau de boutons à droite de l'écran
    px0, px1 = sx1 + t + 0.004, HW - 0.012
    b.box((px0, FRONT, -HH + 0.03), (px1, FRONT + 0.003, HH - 0.03), "Cream")
    for z in (0.16, 0.04):
        b.cylinder(((px0 + px1) / 2, FRONT + 0.003, z), ((px0 + px1) / 2, FRONT + 0.025, z), 0.016, "Copper", 10)
    b.cylinder(((px0 + px1) / 2, FRONT + 0.003, -0.06), ((px0 + px1) / 2, FRONT + 0.008, -0.06), 0.006, "Lamp", 6)
    for i in range(5):   # grille du haut-parleur
        z = -0.12 - i * 0.025
        b.box((px0 + 0.006, FRONT + 0.003, z), (px1 - 0.006, FRONT + 0.006, z + 0.01), "IronDark")
    # antennes
    b.box((-0.06, 0.09, HH), (0.06, 0.12, HH + 0.03), "IronDark")
    b.cylinder((-0.02, 0.105, HH + 0.03), (-0.2, 0.105, HH + 0.24), 0.005, "Iron", 5)
    b.cylinder((0.02, 0.105, HH + 0.03), (0.17, 0.105, HH + 0.26), 0.005, "Iron", 5)
    b.sphere((-0.2, 0.105, HH + 0.24), 0.012, "Copper", 6)
    b.sphere((0.17, 0.105, HH + 0.26), 0.012, "Copper", 6)
    b.finish()
    kit.save_and_export("tv_set", budget_tris=1600)


main()
