"""Canapé club du salon (ventre du mécha) : velours vert, accoudoirs et dossier roulés, capitonnage, plaid.

Fiche
- Taille : 1,40 m de large, 0,58 m de profondeur, assise à 0,45 m (comme l'ancien), dossier à 0,91 m.
- Origine : au sol, au centre ; l'avant (assises) regarde vers +Y.
  Placé contre le mur gauche du ventre, tourné de -90° : Blender (-1.89, 0.05, 2.6) = Godot (-1.89, 2.6, -0.05).
- Budget : 2500 triangles.
- Pièces : 4 pieds tournés et socle (Wood), caisse (Velvet), 2 coussins d'assise avec passepoil (Board),
  dossier capitonné à boudin roulé (boutons en cuivre), 2 accoudoirs roulés avec volute et clou en cuivre,
  2 coussins décoratifs (Cushion, DartRed), plaid (RugTrim) sur l'accoudoir droit.
- Collisions et places assises : déjà dans mecha.tscn (Hull/Sofa, Hull/SofaBack, Controls/Sofa_Left, Sofa_Right).

    blender -b --factory-startup --python blender/props/sofa.py
"""

import math
import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HW, HD = 0.70, 0.29          # demi-largeur, demi-profondeur
SEAT_Z = 0.45
ARM_IN = 0.52                # bord intérieur des accoudoirs


def main():
    kit.new_scene()
    b = kit.Builder("Sofa")
    # pieds tournés + socle en bois
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (HW - 0.07), sy * (HD - 0.07)
            b.cylinder((x, y, 0.0), (x, y, 0.08), 0.025, "Wood", segments=8, radius_end=0.035)
    b.box((-HW, -HD, 0.08), (HW, HD - 0.02, 0.12), "Wood")
    # caisse
    b.box((-HW + 0.01, -HD, 0.12), (HW - 0.01, HD, 0.33), "Velvet")
    # coussins d'assise + passepoil
    for x0, x1 in ((-ARM_IN, -0.01), (0.01, ARM_IN)):
        b.box((x0, -0.17, 0.33), (x1, HD + 0.01, SEAT_Z), "Velvet")
        b.cylinder((x0 + 0.01, HD + 0.01, SEAT_Z - 0.012), (x1 - 0.01, HD + 0.01, SEAT_Z - 0.012), 0.012, "Board", segments=6)
    # dossier : panneau capitonné + boudin roulé
    b.box((-HW + 0.01, -HD, 0.33), (HW - 0.01, -0.12, 0.82), "Velvet")
    b.cylinder((-HW + 0.01, -0.2, 0.82), (HW - 0.01, -0.2, 0.82), 0.09, "Velvet", segments=12)
    for z in (0.56, 0.71):
        b.rivet_row((-ARM_IN + 0.08, -0.12, z), (ARM_IN - 0.08, -0.12, z), (0, 1, 0), spacing=0.15, size=0.022, depth=0.008)
    # accoudoirs roulés avec volute à l'avant
    for sx in (-1, 1):
        x0, x1 = sorted((sx * ARM_IN, sx * HW))
        xc = (x0 + x1) / 2
        b.box((x0, -HD, 0.33), (x1, HD, 0.55), "Velvet")
        b.cylinder((xc, -HD + 0.02, 0.55), (xc, HD, 0.55), 0.095, "Velvet", segments=12)
        b.cylinder((xc, HD, 0.55), (xc, HD + 0.02, 0.55), 0.1, "Velvet", segments=12)            # volute
        b.cylinder((xc, HD + 0.02, 0.55), (xc, HD + 0.03, 0.55), 0.03, "Copper", segments=10)    # clou
        b.cylinder((xc, HD, 0.25), (xc, HD + 0.012, 0.25), 0.02, "Copper", segments=8)
    # coussins décoratifs, penchés contre le dossier
    for x, mat in ((-0.33, "Cushion"), (0.36, "DartRed")):
        b.tilted_box((x, -0.06, 0.6), (0.3, 0.08, 0.28), math.radians(18), mat)
    # plaid jeté sur l'accoudoir droit du canapé (+X), qui retombe vers l'extérieur
    xr = HW + 0.005
    b.box((ARM_IN + 0.02, -0.1, 0.62), (xr, 0.16, 0.66), "RugTrim")
    b.box((xr, -0.1, 0.3), (xr + 0.015, 0.16, 0.66), "RugTrim")
    for y in (-0.06, 0.04, 0.12):
        b.box((xr + 0.015, y, 0.3), (xr + 0.02, y + 0.02, 0.64), "Cushion")                  # rayures
    b.finish()
    kit.save_and_export("sofa", budget_tris=2500)


main()
