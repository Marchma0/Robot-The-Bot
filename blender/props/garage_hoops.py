"""Panier de basket d'atelier « Ferraille-Hoops » (4.4) : panneau riveté, arceau en cuivre et bac à ballons.

Fiche
- Taille : largeur 1,6 m (X), profondeur 1,2 m (Y), hauteur 2,65 m (arceau à 2,05 m).
- Origine : au sol, au pied du poteau. Le joueur lance depuis +Y vers -Y.
- Budget : 1800 triangles.
- Pièces : socle lesté (IronDark), poteau en acier (Iron), panneau en tôle (WallCream, Copper, DartRed),
  arceau en cuivre (Copper) et chaînes (Iron), bac de ballons à droite avec distributeur (Paint, Yellow).

    blender -b --factory-startup --python blender/props/garage_hoops.py
"""

import math
import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402


def main():
    kit.new_scene()
    b = kit.Builder("GarageHoops")

    # Socle lourd et poteau vertical (en y = -0.35)
    b.box((-0.55, -0.60, 0.0), (0.55, -0.10, 0.14), "IronDark")
    b.box((-0.12, -0.45, 0.142), (0.12, -0.25, 2.35), "Iron")

    # Panneau de basket (x: -0.75..0.75, z: 1.85..2.65, face avant en y = -0.16)
    b.box((-0.76, -0.24, 1.84), (0.76, -0.16, 2.66), "IronDark")
    b.box((-0.70, -0.158, 1.90), (0.70, -0.14, 2.60), "WallCream")
    # Rectangle de visée rouge autour de l'arceau
    b.box((-0.26, -0.138, 1.98), (0.26, -0.130, 2.02), "DartRed")
    b.box((-0.26, -0.138, 2.30), (0.26, -0.130, 2.34), "DartRed")
    b.box((-0.26, -0.138, 2.022), (-0.22, -0.130, 2.298), "DartRed")
    b.box((0.22, -0.138, 2.022), (0.26, -0.130, 2.298), "DartRed")

    # Arceau en cuivre (octogone en y = +0.18, z = 2.02, rayon 0.28)
    ring_y = 0.18
    ring_z = 2.02
    ring_r = 0.28
    b.box((-0.10, -0.135, ring_z - 0.03), (0.10, -0.08, ring_z + 0.03), "Copper")
    segs = 8
    for i in range(segs):
        a0 = 2.0 * math.pi * i / segs
        a1 = 2.0 * math.pi * (i + 1) / segs
        p0 = (math.cos(a0) * ring_r, ring_y + math.sin(a0) * ring_r, ring_z)
        p1 = (math.cos(a1) * ring_r, ring_y + math.sin(a1) * ring_r, ring_z)
        b.cylinder(p0, p1, 0.022, "Copper", segments=6)
        # Chaînette de filet sous chaque nœud
        b.cylinder((p0[0] * 0.95, p0[1], ring_z - 0.03),
                   (p0[0] * 0.68, ring_y + (p0[1] - ring_y) * 0.68, ring_z - 0.28), 0.008, "Iron", segments=4)

    # Bac distributeur de ballons devant à droite (x: 0.58..1.08, y: 0.40..0.90)
    b.box((0.58, 0.40, 0.0), (1.08, 0.90, 0.56), "Paint")
    b.box((0.56, 0.38, 0.562), (1.10, 0.92, 0.62), "Yellow")
    b.sphere((0.75, 0.58, 0.66), 0.12, "Copper", segments=8)
    b.sphere((0.92, 0.72, 0.66), 0.12, "Iron", segments=8)

    b.finish()
    kit.save_and_export("garage_hoops", budget_tris=1800)


main()
