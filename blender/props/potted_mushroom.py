"""Champignon rouge à pois en pot de terre cuite, avec un petit rejeton (déco des nains).

Fiche
- Taille : pot de 0,29 m de diamètre, 0,47 m de haut au total.
- Origine : au sol, au centre ; l'avant regarde vers +Y (le rejeton est sur l'avant droit).
  Ventre : posé sur une caisse (wood_crate) dans le coin avant gauche. Tête : « champignon géant » à l'échelle 1,5,
  par terre dans le coin avant gauche (scenes/mecha/props/potted_mushroom.tscn, avec collision).
- Budget : 1300 triangles.
- Pièces : pot (Terracotta) avec son rebord, terre (Grime), pied (Cream), chapeau en 3 cônes (DartRed),
  lamelles (Cream), pois (Cream), petit champignon à côté.

    blender -b --factory-startup --python blender/props/potted_mushroom.py
"""

import math
import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402


def mushroom(b, x, y, z, scale, top_dots=True):
    """Pied + chapeau à pois, posé en (x, y, z)."""
    s = scale
    b.cylinder((x, y, z), (x, y, z + 0.16 * s), 0.036 * s, "Cream", 10, radius_end=0.03 * s)
    cap = z + 0.13 * s
    b.cylinder((x, y, cap - 0.006 * s), (x, y, cap), 0.12 * s, "Cream", 14)          # lamelles
    b.cylinder((x, y, cap), (x, y, cap + 0.04 * s), 0.135 * s, "DartRed", 14, radius_end=0.12 * s)
    b.cylinder((x, y, cap + 0.04 * s), (x, y, cap + 0.08 * s), 0.12 * s, "DartRed", 14, radius_end=0.075 * s)
    b.cylinder((x, y, cap + 0.08 * s), (x, y, cap + 0.105 * s), 0.075 * s, "DartRed", 14, radius_end=0.0)
    # pois : à moitié enfoncés dans le chapeau
    for i in range(7):
        a = i * math.tau / 7 + 0.3
        r = 0.112 * s
        b.sphere((x + math.cos(a) * r, y + math.sin(a) * r, cap + 0.032 * s), 0.02 * s, "Cream", 6)
    for i in range(4 if top_dots else 0):
        a = i * math.tau / 4 + 1.0
        r = 0.065 * s
        b.sphere((x + math.cos(a) * r, y + math.sin(a) * r, cap + 0.083 * s), 0.016 * s, "Cream", 6)


def main():
    kit.new_scene()
    b = kit.Builder("PottedMushroom")
    # pot évasé + rebord
    b.cylinder((0, 0, 0.0), (0, 0, 0.18), 0.1, "Terracotta", 12, radius_end=0.135)
    b.cylinder((0, 0, 0.16), (0, 0, 0.2), 0.145, "Terracotta", 12)
    b.cylinder((0, 0, 0.2), (0, 0, 0.205), 0.125, "Grime", 12)
    mushroom(b, -0.015, -0.01, 0.205, 1.0)
    mushroom(b, 0.08, 0.07, 0.205, 0.42, top_dots=False)
    b.finish()
    kit.save_and_export("potted_mushroom", budget_tris=1300)


main()
