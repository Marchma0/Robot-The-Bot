"""Borne Punch-O-Mètre (4.4) : machine à coup de poing d'atelier avec colonne graduée et cloche.

Fiche
- Taille : 0,95 m de large (X), 1,1 m de profondeur (Y), hauteur 2,42 m (cloche au sommet).
- Origine : au sol, au centre. Le joueur se tient côté +Y (devant le ballon de frappe).
- Budget : 1600 triangles.
- Pièces : socle en tôle striée (IronDark, Yellow), colonne graduée (Paint, IronDark, Copper), rivets,
  cloche supérieure en cuivre (Copper, Bulb), potence avant avec amortisseur (Iron, Copper, DartRed).

    blender -b --factory-startup --python blender/props/punch_machine.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402


def main():
    kit.new_scene()
    b = kit.Builder("PunchMachine")

    # Socle au sol + tapis de frappe rayé
    b.box((-0.46, -0.52, 0.0), (0.46, 0.52, 0.08), "IronDark")
    b.box((-0.42, 0.05, 0.082), (0.42, 0.48, 0.095), "Yellow")
    for i in range(4):
        x0 = -0.36 + i * 0.20
        b.box((x0, 0.08, 0.096), (x0 + 0.09, 0.45, 0.102), "DartBlack")

    # Colonne arrière (y: -0.48..-0.08, z: 0.08..2.05)
    b.box((-0.38, -0.48, 0.082), (0.38, -0.08, 2.05), "Paint")
    b.box((-0.42, -0.50, 0.085), (-0.382, -0.06, 2.05), "IronDark")
    b.box((0.382, -0.50, 0.085), (0.42, -0.06, 2.05), "IronDark")
    # Cadre en cuivre pour l'échelle de puissance sur la face avant (y = -0.078..-0.06)
    b.box((-0.14, -0.078, 0.28), (-0.11, -0.058, 1.38), "Copper")
    b.box((0.11, -0.078, 0.28), (0.14, -0.058, 1.38), "Copper")
    b.box((-0.14, -0.078, 0.24), (0.14, -0.058, 0.278), "Copper")
    b.box((-0.14, -0.078, 1.382), (0.14, -0.058, 1.42), "Copper")
    b.rivet_row((-0.34, -0.08, 0.32), (-0.34, -0.08, 1.92), (0, 1, 0), spacing=0.20, size=0.018)
    b.rivet_row((0.34, -0.08, 0.32), (0.34, -0.08, 1.92), (0, 1, 0), spacing=0.20, size=0.018)

    # Cadran et cloche en cuivre au sommet (z: 2.05..2.38)
    b.box((-0.44, -0.50, 2.052), (0.44, 0.12, 2.24), "IronDark")
    b.box((-0.38, 0.122, 2.08), (0.38, 0.14, 2.21), "Copper")
    b.cylinder((0.0, -0.18, 2.242), (0.0, -0.18, 2.38), 0.18, "Copper", segments=10, radius_end=0.08)
    b.sphere((0.0, -0.18, 2.40), 0.055, "Bulb", segments=8)

    # Potence supérieure en col de cygne qui avance vers +Y (où pend le ballon de frappe)
    b.box((-0.18, -0.018, 1.52), (0.18, 0.36, 1.68), "Iron")
    b.box((-0.20, 0.18, 1.46), (0.20, 0.38, 1.518), "Copper")
    b.box((-0.22, -0.078, 1.44), (0.22, -0.02, 1.72), "IronDark")

    b.finish()
    kit.save_and_export("punch_machine", budget_tris=1600)


main()
