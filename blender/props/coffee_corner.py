"""Coin café de la tête du mécha : meuble bas, percolateur en cuivre, tasses et bocal de grains.

Fiche
- Taille : 0,95 m de large, 0,42 m de profondeur, 0,65 m de haut (meuble) et 1,15 m avec le percolateur.
- Origine : au sol, au centre, dos au mur ; l'avant (les portes) regarde vers +Y.
  Placé par scenes/mecha/props/coffee_corner.tscn (collision) en Godot (-2.2, 5.6, 0.175),
  tournée vers la droite du mécha (vers la pièce).
- Budget : 2600 triangles.
- Pièces : meuble (Paint) à deux portes (poignées Copper), plan de travail (Wood), percolateur (cuivre, chaudière,
  manomètre, bec, voyant Bulb), 3 tasses (Cream, DartRed), bocal (Glass) de grains (Grime), sucrier.

    blender -b --factory-startup --python blender/props/coffee_corner.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HW = 0.475
D = 0.42
H = 0.65


def cup(b, x, y, z, mat):
    b.cylinder((x, y, z), (x, y, z + 0.06), 0.028, mat, 8)
    b.cylinder((x, y, z + 0.06), (x, y, z + 0.062), 0.022, "Grime", 8)
    b.box((x + 0.026, y - 0.004, z + 0.015), (x + 0.044, y + 0.004, z + 0.045), mat)


def main():
    kit.new_scene()
    b = kit.Builder("CoffeeCorner")
    y0, y1 = 0.0, D
    # meuble : socle en retrait, caisson, portes
    b.box((-HW + 0.03, y0 + 0.02, 0.0), (HW - 0.03, y1 - 0.04, 0.06), "IronDark")
    b.box((-HW, y0, 0.06), (HW, y1 - 0.02, H - 0.03), "Paint")
    for dx0, dx1 in ((-HW + 0.02, -0.005), (0.005, HW - 0.02)):
        b.box((dx0, y1 - 0.02, 0.09), (dx1, y1 - 0.008, H - 0.06), "Paint")
        b.box((dx0 + 0.04, y1 - 0.008, 0.13), (dx1 - 0.04, y1 - 0.004, H - 0.1), "Cream")
    for x in (-0.04, 0.03):
        b.box((x, y1 - 0.008, 0.38), (x + 0.012, y1 + 0.02, 0.48), "Copper")
    b.box((-HW - 0.01, y0, H - 0.03), (HW + 0.01, y1 + 0.01, H), "Wood")
    top = H
    # percolateur à gauche : socle, chaudière en cuivre, dôme, manomètre, bec, voyant
    px, py = -0.22, 0.2
    b.box((px - 0.12, py - 0.12, top), (px + 0.12, py + 0.12, top + 0.05), "IronDark")
    b.cylinder((px, py, top + 0.05), (px, py, top + 0.33), 0.1, "Copper", 12)
    b.cylinder((px, py, top + 0.33), (px, py, top + 0.4), 0.1, "Copper", 12, radius_end=0.05)
    b.sphere((px, py, top + 0.42), 0.03, "IronDark", 8)
    b.cylinder((px + 0.05, py + 0.08, top + 0.24), (px + 0.05, py + 0.12, top + 0.24), 0.035, "IronDark", 10)
    b.cylinder((px + 0.05, py + 0.12, top + 0.24), (px + 0.05, py + 0.124, top + 0.24), 0.028, "Cream", 10)
    b.cylinder((px - 0.03, py + 0.09, top + 0.15), (px - 0.03, py + 0.17, top + 0.15), 0.014, "Copper", 6)
    b.cylinder((px - 0.03, py + 0.17, top + 0.15), (px - 0.03, py + 0.17, top + 0.125), 0.012, "Copper", 6)
    b.cylinder((px + 0.07, py + 0.09, top + 0.08), (px + 0.07, py + 0.105, top + 0.08), 0.012, "Bulb", 6)
    cup(b, px - 0.03, py + 0.17, top + 0.05, "Cream")
    # tasses, bocal de grains, sucrier
    cup(b, 0.06, 0.3, top, "DartRed")
    cup(b, 0.16, 0.26, top, "Cream")
    b.cylinder((0.3, 0.15, top), (0.3, 0.15, top + 0.16), 0.055, "Glass", 10)
    b.cylinder((0.3, 0.15, top + 0.005), (0.3, 0.15, top + 0.11), 0.05, "Grime", 10)
    b.cylinder((0.3, 0.15, top + 0.16), (0.3, 0.15, top + 0.18), 0.06, "Copper", 10)
    b.cylinder((0.12, 0.1, top), (0.12, 0.1, top + 0.07), 0.04, "Cream", 10)
    b.cylinder((0.12, 0.1, top + 0.07), (0.12, 0.1, top + 0.085), 0.03, "Cream", 10, radius_end=0.012)
    b.finish()
    kit.save_and_export("coffee_corner", budget_tris=2600)


main()
