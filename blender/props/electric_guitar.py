"""Guitare électrique low-poly d'atelier (4.4) : tenue par le nain ou posée sur le stand de scène.

Fiche
- Taille : longueur 0,78 m (X), largeur 0,30 m (Z), épaisseur 0,06 m (Y). Repère : un nain fait 1,2 m.
- Origine : au centre du corps de la guitare.
- Budget : 600 triangles.
- Pièces : caisse en V asymétrique (DartRed, Copper), plaque (Cream), micros et chevalet (Iron, Copper),
  manche (Wood) et tête à éclairs (DartRed, Bulb).

    blender -b --factory-startup --python blender/props/electric_guitar.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402


def main():
    kit.new_scene()
    b = kit.Builder("ElectricGuitar")

    # Corps de la guitare (X: -0.26..0.14, Z: -0.15..0.15)
    b.box((-0.24, -0.025, -0.13), (0.12, 0.025, 0.13), "DartRed")
    b.box((-0.28, -0.022, 0.02), (-0.08, 0.022, 0.17), "DartRed")
    b.box((-0.28, -0.022, -0.17), (-0.06, 0.022, -0.02), "DartRed")
    # Plaque avant en cuivre + micros
    b.box((-0.18, 0.026, -0.09), (0.08, 0.032, 0.08), "Copper")
    b.box((-0.14, 0.033, -0.045), (-0.09, 0.040, 0.045), "IronDark")
    b.box((-0.02, 0.033, -0.045), (0.03, 0.040, 0.045), "Iron")
    # Manche en bois + tête lumineuse
    b.box((0.122, -0.016, -0.028), (0.48, 0.018, 0.028), "Wood")
    b.box((0.482, -0.018, -0.045), (0.60, 0.020, 0.055), "Copper")
    b.sphere((0.55, 0.024, 0.0), 0.022, "Bulb", segments=6)

    b.finish()
    kit.save_and_export("electric_guitar", budget_tris=600)


main()
