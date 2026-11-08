"""Pendule d'échecs du jeu de dames, posée sur la table basse du salon (ventre du mécha).

Fiche
- Taille : 0,16 m de large, 0,065 m de profondeur, 0,09 m de haut (sans les poussoirs).
- Origine : au sol, au centre ; l'avant (les deux cadrans) regarde vers +Y.
  Placée par scenes/mecha/props/chess_clock.tscn, elle-même posée sur la table (coffee_table.tscn),
  cadrans tournés vers le canapé.
- Budget : 700 triangles.
- Pièces : boîtier en bois au dessus en pente (Wood), plaque du dessus et pieds (IronDark), deux cadrans
  (lunette IronDark, fond Cream, 4 repères DartBlack, petit drapeau rouge DartRed en haut), deux douilles de
  poussoir (Copper). Les poussoirs et les aiguilles bougent : ils sont ajoutés dans Godot (CheckersClock).

    blender -b --factory-startup --python blender/props/chess_clock.py
"""

import math
import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HW = 0.08             # demi-largeur
D0, D1 = -0.032, 0.032  # arrière, avant
H_BACK, H_FRONT = 0.09, 0.08
DIAL_X = 0.038        # centre des cadrans (± x)
DIAL_Z = 0.042
DIAL_R = 0.027


def main():
    kit.new_scene()
    b = kit.Builder("ChessClock")
    # boîtier : profil (y, z) au dessus en pente, sur 4 pieds
    b.prism_x([(D0, 0.006), (D1, 0.006), (D1, H_FRONT), (D0, H_BACK)], -HW, HW, "Wood")
    for sx in (-1, 1):
        for y in (D0 + 0.008, D1 - 0.008):
            b.box((sx * (HW - 0.016), y - 0.005, 0.0), (sx * (HW - 0.006), y + 0.005, 0.006), "IronDark")
    # plaque du dessus (suit la pente, 2 mm au-dessus) et douilles des poussoirs
    b.prism_x([(D0 + 0.004, H_BACK - 0.0005), (D1 - 0.004, H_FRONT + 0.0005),
               (D1 - 0.004, H_FRONT + 0.0025), (D0 + 0.004, H_BACK + 0.0025)], -HW + 0.006, HW - 0.006, "IronDark")
    for sx in (-1, 1):
        z_top = H_BACK + 0.0025 + (H_FRONT - H_BACK) * 0.5
        b.cylinder((sx * DIAL_X, 0.0, z_top - 0.002), (sx * DIAL_X, 0.0, z_top + 0.008), 0.013, "Copper", 12)
    # cadrans : lunette, fond, repères, drapeau
    for sx in (-1, 1):
        cx = sx * DIAL_X
        b.cylinder((cx, D1, DIAL_Z), (cx, D1 + 0.006, DIAL_Z), DIAL_R, "IronDark", 16)
        b.cylinder((cx, D1 + 0.006, DIAL_Z), (cx, D1 + 0.008, DIAL_Z), DIAL_R - 0.004, "Cream", 16)
        for k in range(4):
            a = k * math.pi / 2
            px, pz = cx + math.sin(a) * (DIAL_R - 0.009), DIAL_Z + math.cos(a) * (DIAL_R - 0.009)
            b.box((px - 0.0015, D1 + 0.008, pz - 0.0015), (px + 0.0015, D1 + 0.0095, pz + 0.0015), "DartBlack")
        b.box((cx + 0.004, D1 + 0.008, DIAL_Z + DIAL_R - 0.012), (cx + 0.011, D1 + 0.0095, DIAL_Z + DIAL_R - 0.007),
              "DartRed")
    b.finish()
    kit.save_and_export("chess_clock", budget_tris=700)


main()
