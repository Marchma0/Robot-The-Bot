"""Étagère de bric-à-brac au mur du fond de la tête : livres, bocaux, lampe à pétrole, bouilloire, vieux poste radio.

Fiche
- Taille : 1,70 m de large, 0,24 m de profondeur, deux planches à 0,65 m et 1,23 m du sol (1,55 m avec les objets).
- Origine : au pied du mur, au centre ; l'avant regarde vers +Y (l'arrière est contre le mur, en y = 0).
  Placée en Godot (0.1, 5.6, 1.9), tournée vers l'avant du mécha.
- Budget : 3200 triangles.
- Pièces : 2 planches (Wood) sur équerres (IronDark), livres de couleurs, serre-livres, bocaux (Glass) de couleurs,
  lampe à pétrole (Copper, Bulb), bouilloire (Copper), poste radio (Wood, Cream, Copper), rouleaux de plans (Paper),
  petit cactus (Plant) en pot.

    blender -b --factory-startup --python blender/props/junk_shelf.py
"""

import os
import random
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HW = 0.85
D = 0.24
LOW, HIGH = 0.65, 1.23
T = 0.025


def shelf(b, z):
    b.box((-HW, 0.0, z), (HW, D, z + T), "Wood")
    for x in (-HW + 0.15, HW - 0.15):
        b.box((x - 0.012, 0.0, z - 0.16), (x + 0.012, 0.03, z), "IronDark")      # montant contre le mur
        b.box((x - 0.012, 0.0, z - 0.02), (x + 0.012, D - 0.04, z), "IronDark")  # bras sous la planche


def books(b, x, z, rng, count):
    colors = ["DartRed", "Velvet", "Cushion", "Paint", "Ochre", "Cream", "IronDark"]
    for _ in range(count):
        w = rng.uniform(0.022, 0.04)
        h = rng.uniform(0.16, 0.24)
        d = rng.uniform(0.13, 0.17)
        b.box((x, 0.03, z), (x + w, 0.03 + d, z + h), rng.choice(colors))
        x += w + 0.003
    return x


def jar(b, x, z, mat):
    b.cylinder((x, 0.12, z), (x, 0.12, z + 0.13), 0.04, "Glass", 8)
    b.cylinder((x, 0.12, z + 0.003), (x, 0.12, z + 0.08), 0.035, mat, 8)
    b.cylinder((x, 0.12, z + 0.13), (x, 0.12, z + 0.145), 0.043, "Copper", 8)


def main():
    kit.new_scene()
    rng = random.Random(7)
    b = kit.Builder("JunkShelf")
    shelf(b, LOW)
    shelf(b, HIGH)
    z = LOW + T
    # planche basse : livres + serre-livre, bocaux, cactus
    x = books(b, -0.78, z, rng, 9)
    b.box((x + 0.004, 0.06, z), (x + 0.02, 0.18, z + 0.12), "Copper")
    for k, mat in enumerate(("DartRed", "Yellow", "Plant", "Ochre")):
        jar(b, -0.2 + k * 0.1, z, mat)
    b.cylinder((0.33, 0.12, z), (0.33, 0.12, z + 0.08), 0.05, "Terracotta", 8, radius_end=0.06)
    b.cylinder((0.33, 0.12, z + 0.08), (0.33, 0.12, z + 0.2), 0.03, "Plant", 8, radius_end=0.022)
    b.cylinder((0.36, 0.12, z + 0.13), (0.4, 0.12, z + 0.17), 0.012, "Plant", 6)
    # rouleaux de plans couchés
    for k in range(3):
        b.cylinder((0.5, 0.06 + k * 0.05, z + 0.022 + (k % 2) * 0.03), (0.78, 0.06 + k * 0.05, z + 0.022 + (k % 2) * 0.03),
                   0.022, "Paper", 8)
    z = HIGH + T
    # planche haute : lampe à pétrole, bouilloire, poste radio, livres couchés
    b.cylinder((-0.7, 0.12, z), (-0.7, 0.12, z + 0.04), 0.06, "Copper", 10)
    b.cylinder((-0.7, 0.12, z + 0.04), (-0.7, 0.12, z + 0.16), 0.035, "Bulb", 10)
    b.cylinder((-0.7, 0.12, z + 0.16), (-0.7, 0.12, z + 0.2), 0.045, "Copper", 10, radius_end=0.02)
    b.cylinder((-0.42, 0.12, z), (-0.42, 0.12, z + 0.12), 0.08, "Copper", 10, radius_end=0.06)
    b.sphere((-0.42, 0.12, z + 0.13), 0.02, "IronDark", 6)
    b.cylinder((-0.36, 0.14, z + 0.06), (-0.31, 0.16, z + 0.12), 0.012, "Copper", 6)
    b.box((-0.08, 0.04, z), (0.28, 0.21, z + 0.2), "Wood")                      # radio
    b.box((-0.06, 0.21, z + 0.04), (0.14, 0.213, z + 0.17), "Cream")            # grille
    for k in range(5):
        b.box((-0.05, 0.213, z + 0.055 + k * 0.024), (0.13, 0.216, z + 0.065 + k * 0.024), "IronDark")
    for k in range(2):
        b.cylinder((0.21, 0.21, z + 0.07 + k * 0.07), (0.21, 0.23, z + 0.07 + k * 0.07), 0.022, "Copper", 8)
    b.cylinder((0.25, 0.08, z + 0.2), (0.25, 0.08, z + 0.32), 0.004, "Iron", 4)  # antenne
    for k in range(3):   # livres couchés
        b.box((0.4, 0.04 + k * 0.004, z + k * 0.03), (0.66 - k * 0.02, 0.2 - k * 0.006, z + k * 0.03 + 0.028),
              ("DartRed", "Velvet", "Ochre")[k])
    b.finish()
    kit.save_and_export("junk_shelf", budget_tris=3200, ground=False)


main()
