"""Plafonnier carré grillagé (ventre et tête du mécha).

Fiche
- Taille : 0,30 x 0,30 m, 0,13 m de haut, accroché au plafond.
- Origine : au plafond, au centre (tout le plafonnier est sous z = 0) ; symétrique.
  Ventre : Godot (-0.9, 5.4, -0.4) et (0.9, 5.4, -0.4). Tête : Godot (0, 8.3, 0), à l'échelle 1,3.
- Budget : 500 triangles.
- Pièces : platine (Copper), boîtier (IronDark), verre lumineux (Lamp), grille de protection (Iron),
  4 vis (Copper).

    blender -b --factory-startup --python blender/props/ceiling_light.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402


def main():
    kit.new_scene()
    b = kit.Builder("CeilingLight")
    b.box((-0.15, -0.15, -0.02), (0.15, 0.15, 0.0), "Copper")
    b.frustum((0, 0), -0.09, -0.02, (0.11, 0.11), (0.13, 0.13), "IronDark")
    b.box((-0.1, -0.1, -0.11), (0.1, 0.1, -0.09), "Lamp")
    # grille : 2 + 2 barreaux sous le verre, et un cadre
    for k in (-0.04, 0.04):
        b.box((-0.11, k - 0.005, -0.125), (0.11, k + 0.005, -0.115), "Iron")
        b.box((k - 0.005, -0.11, -0.13), (k + 0.005, 0.11, -0.12), "Iron")
    for s in (-1, 1):
        b.box((-0.115, s * 0.105 - 0.006, -0.12), (0.115, s * 0.105 + 0.006, -0.088), "Iron")
        b.box((s * 0.105 - 0.006, -0.099, -0.12), (s * 0.105 + 0.006, 0.099, -0.088), "Iron")
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((sx * 0.13 - 0.008, sy * 0.13 - 0.008, -0.024), (sx * 0.13 + 0.008, sy * 0.13 + 0.008, -0.018), "Copper")
    b.finish()
    kit.save_and_export("ceiling_light", budget_tris=500, ground=False)


main()
