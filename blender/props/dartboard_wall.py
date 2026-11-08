"""Cible de fléchettes décorative, au mur du fond du salon (ventre du mécha), avec trois fléchettes plantées.

Fiche
- Taille : 0,50 m de diamètre, 4 cm d'épaisseur (fléchettes : 12 cm de plus).
- Origine : sur le mur, au centre de la cible ; l'avant regarde vers +Y (l'arrière est contre le mur, en y = 0).
  Placée en Godot (0.0, 3.85, 1.9), tournée vers l'avant du mécha.
- Budget : 1600 triangles.
- Pièces : planche de fond (Wood), cible en anneaux (DartBlack / Cream / DartRed / DartGreen), fil de cuivre,
  3 fléchettes (Iron, DartRed).

    blender -b --factory-startup --python blender/props/dartboard_wall.py
"""

import math
import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

SEG = 20


def disc(b, r, y0, y1, mat):
    b.cylinder((0, y0, 0), (0, y1, 0), r, mat, SEG)


def main():
    kit.new_scene()
    b = kit.Builder("DartboardWall")
    disc(b, 0.25, 0.0, 0.02, "Wood")
    # anneaux du plus grand au plus petit, chacun 1,5 mm plus en avant
    rings = [(0.215, "DartBlack"), (0.19, "DartRed"), (0.175, "Cream"), (0.12, "DartGreen"),
             (0.105, "DartBlack"), (0.04, "DartRed"), (0.018, "DartGreen")]
    y = 0.02
    for r, mat in rings:
        disc(b, r, y, y + 0.006, mat)
        y += 0.0015
    # secteurs blancs : fines baguettes de cuivre en croix devant les anneaux
    for k in range(4):
        a = k * math.pi / 4
        p0 = (math.cos(a) * 0.19, y + 0.006, math.sin(a) * 0.19)
        p1 = (-math.cos(a) * 0.19, y + 0.006, -math.sin(a) * 0.19)
        b.cylinder(p0, p1, 0.002, "Copper", 4)
    # 3 fléchettes plantées, légèrement de biais
    for x, z, tilt in ((0.05, 0.06, 0.15), (-0.08, -0.02, -0.1), (0.015, -0.11, 0.05)):
        tip = (x, y, z)
        back = (x + tilt * 0.12, y + 0.12, z + 0.02)
        b.cylinder(tip, back, 0.005, "Iron", 6)
        bx, by, bz = back
        b.box((bx - 0.022, by - 0.04, bz - 0.002), (bx + 0.022, by, bz + 0.002), "DartRed")
        b.box((bx - 0.002, by - 0.04, bz - 0.022), (bx + 0.002, by, bz + 0.022), "DartRed")
    b.finish()
    kit.save_and_export("dartboard_wall", budget_tris=1600)


main()
