"""Masque de soudeur / casquette de garagiste pour nain (skin 2, 2.4 / 2.8).

Fiche
- Taille : 0,44 m (X) x 0,46 m (Y) x 0,32 m (Z), s'adapte par-dessus la tête du nain (HeadBone).
- Origine : au centre de la tête (0, 0, 0). Avant vers +Y dans Blender (-Z dans Godot).
- Budget : 600 triangles.
- Pièces : calotte en acier (IronDark), visière relevée de soudeur en cuivre (Copper) avec double oculaire
  lumineux (Neon, IronDark), bande rivetée latérale.

    blender -b --factory-startup --python blender/props/dwarf_hat_welder.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402


def main():
    kit.new_scene()
    b = kit.Builder("DwarfHatWelder")

    # Calotte métallique sur le haut du crâne
    b.box((-0.21, -0.22, 0.06), (0.21, 0.22, 0.25), "IronDark")
    b.box((-0.18, -0.19, 0.252), (0.18, 0.19, 0.30), "Iron")
    # Masque / lunettes de soudeur sur le front (côté +Y)
    b.box((-0.22, 0.04, 0.08), (0.22, 0.26, 0.22), "Copper")
    for sx in (-0.095, 0.095):
        b.cylinder((sx, 0.262, 0.15), (sx, 0.295, 0.15), 0.058, "IronDark", segments=8)
        b.cylinder((sx, 0.296, 0.15), (sx, 0.308, 0.15), 0.044, "Neon", segments=8)
    # Tourillons latéraux en cuivre
    for sx in (-1.0, 1.0):
        b.cylinder((sx * 0.222, 0.02, 0.14), (sx * 0.255, 0.02, 0.14), 0.045, "Copper", segments=8)

    b.finish()
    kit.save_and_export("dwarf_hat_welder", budget_tris=600)


main()
