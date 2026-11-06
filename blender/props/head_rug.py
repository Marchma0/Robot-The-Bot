"""Tapis rond tressé au centre de la tête du mécha.

Fiche
- Taille : 1,5 m de diamètre, 1,4 cm d'épaisseur (plat : on marche dessus, pas de collision).
- Origine : au sol, au centre. Placé en Blender (0.2, 0.1, 5.6) = Godot (0.2, 5.6, -0.1).
- Budget : 600 triangles.
- Pièces : 5 anneaux concentriques de couleurs alternées, chacun 1 mm plus haut que le précédent (pas de faces superposées).

    blender -b --factory-startup --python blender/props/head_rug.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

RINGS = [(0.75, "RugTrim"), (0.63, "Velvet"), (0.50, "Cushion"), (0.36, "Velvet"), (0.21, "RugTrim")]


def main():
    kit.new_scene()
    b = kit.Builder("HeadRug")
    for i, (radius, mat) in enumerate(RINGS):
        b.cylinder((0, 0, i * 0.0005), (0, 0, 0.010 + i * 0.001), radius, mat, segments=20)
    b.finish()
    kit.save_and_export("head_rug", budget_tris=600)


main()
