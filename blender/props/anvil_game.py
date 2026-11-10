"""Enclume de forge en rythme (4.4) : enclume sur billot cerclé, bac de trempe et colonne de rythme.

Fiche
- Taille : 1,2 m (X) x 0,9 m (Y), table d'enclume à 0,72 m, totem de jauge à 1,56 m.
- Origine : au sol, au centre du billot. Le joueur se tient côté +Y.
- Budget : 1400 triangles.
- Pièces : billot de bois massif (Wood) cerclé de fer (IronDark), enclume de forgeron à bigorne (Iron, IronDark),
  seau de trempe en cuivre (Copper, Wood), totem arrière d'affichage du rythme encadré de cuivre (IronDark, Copper, Bulb).

    blender -b --factory-startup --python blender/props/anvil_game.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402


def main():
    kit.new_scene()
    b = kit.Builder("AnvilGame")

    # Socle commun en tôle sous le billot et le totem
    b.box((-0.68, -0.54, 0.0), (0.52, 0.38, 0.03), "IronDark")

    # Billot en bois massif + cerclages
    b.cylinder((0.0, 0.0, 0.032), (0.0, 0.0, 0.44), 0.34, "Wood", segments=12, radius_end=0.31)
    b.cylinder((0.0, 0.0, 0.08), (0.0, 0.0, 0.13), 0.342, "IronDark", segments=12)
    b.cylinder((0.0, 0.0, 0.34), (0.0, 0.0, 0.39), 0.322, "IronDark", segments=12)

    # Enclume de forgeron (socle, taille, table et bigorne)
    b.box((-0.26, -0.16, 0.442), (0.26, 0.16, 0.52), "IronDark")
    b.box((-0.18, -0.11, 0.522), (0.18, 0.11, 0.62), "Iron")
    b.box((-0.28, -0.14, 0.622), (0.24, 0.14, 0.72), "Iron")
    # Bigorne conique à droite (+X) et talon à gauche (-X)
    b.cylinder((0.242, 0.0, 0.67), (0.46, 0.0, 0.68), 0.065, "Iron", segments=8, radius_end=0.015)
    b.box((-0.36, -0.10, 0.65), (-0.282, 0.10, 0.718), "Iron")

    # Seau de trempe à gauche (-X) avec tenailles posées
    b.cylinder((-0.48, -0.05, 0.032), (-0.48, -0.05, 0.38), 0.17, "Wood", segments=10, radius_end=0.20)
    b.cylinder((-0.48, -0.05, 0.28), (-0.48, -0.05, 0.32), 0.198, "Copper", segments=10)

    # Totem de jauge / score à l'arrière (y = -0.42) avec cadre en cuivre et lanterne au sommet
    b.box((-0.22, -0.50, 0.032), (0.22, -0.35, 1.48), "IronDark")
    b.box((-0.18, -0.348, 0.78), (-0.15, -0.33, 1.42), "Copper")
    b.box((0.15, -0.348, 0.78), (0.18, -0.33, 1.42), "Copper")
    b.box((-0.25, -0.52, 1.482), (0.25, -0.33, 1.56), "Copper")
    b.sphere((0.0, -0.42, 1.61), 0.048, "Bulb", segments=8)

    b.finish()
    kit.save_and_export("anvil_game", budget_tris=1400)


main()
