"""Haut-de-forme Steampunk / Couronne Baron Cuivre pour nain (skin 3, 2.4).

Fiche
- Taille : 0,48 m (X) x 0,48 m (Y) x 0,44 m (Z), s'adapte sur la tête du nain (HeadBone).
- Origine : au centre de la tête (0, 0, 0). Avant vers +Y dans Blender (-Z dans Godot).
- Budget : 700 triangles.
- Pièces : large bord de chapeau en cuivre (Copper), haut cylindre riveté (IronDark, Copper), ruban rouge
  (DartRed), manomètre / badge lumineux à l'avant (Bulb, Brass/Yellow) et petite cheminée latérale.

    blender -b --factory-startup --python blender/props/dwarf_hat_crown.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402


def main():
    kit.new_scene()
    b = kit.Builder("DwarfHatCrown")

    # Bord du haut-de-forme
    b.cylinder((0.0, 0.0, 0.14), (0.0, 0.0, 0.18), 0.26, "Copper", segments=12)
    # Ruban rouge + fût du haut-de-forme
    b.cylinder((0.0, 0.0, 0.182), (0.0, 0.0, 0.24), 0.185, "DartRed", segments=12)
    b.cylinder((0.0, 0.0, 0.242), (0.0, 0.0, 0.44), 0.175, "IronDark", segments=12, radius_end=0.195)
    b.cylinder((0.0, 0.0, 0.442), (0.0, 0.0, 0.47), 0.205, "Copper", segments=12)
    # Manomètre lumineux à l'avant (+Y) + petite cheminée sur le côté (+X)
    b.cylinder((0.0, 0.186, 0.28), (0.0, 0.22, 0.28), 0.055, "Yellow", segments=8)
    b.cylinder((0.0, 0.222, 0.28), (0.0, 0.232, 0.28), 0.040, "Bulb", segments=8)
    b.cylinder((0.18, -0.02, 0.24), (0.21, -0.02, 0.52), 0.032, "Copper", segments=8)

    b.finish()
    kit.save_and_export("dwarf_hat_crown", budget_tris=700)


main()
