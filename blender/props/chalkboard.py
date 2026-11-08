"""Ardoise des scores, au mur du fond du salon (ventre du mécha), à côté de la cible.

Fiche
- Taille : 0,46 m de large, 0,60 m de haut, 5 cm d'épaisseur (avec l'auget).
- Origine : sur le mur, au centre de l'ardoise ; l'avant regarde vers +Y (l'arrière est contre le mur, en y = 0).
  Placée en Godot (0.57, 3.84, 1.9), tournée vers l'avant du mécha.
- Budget : 600 triangles.
- Pièces : cadre (Wood), ardoise vierge (Board) : les scores y sont écrits à la craie en jeu
  (scenes/mecha/props/darts_board.tscn, ChalkScoreboard), auget (Wood) avec une craie
  et une éponge (Ochre), clou et ficelle d'accroche.

    blender -b --factory-startup --python blender/props/chalkboard.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HW, HH = 0.23, 0.27     # demi-largeur, demi-hauteur du cadre
FR = 0.03               # largeur du cadre
D = 0.025               # épaisseur


def main():
    kit.new_scene()
    b = kit.Builder("Chalkboard")
    # ardoise puis cadre (le cadre dépasse de 4 mm devant l'ardoise)
    b.box((-HW + 0.01, 0.002, -HH + 0.01), (HW - 0.01, D - 0.004, HH - 0.01), "Board")
    b.box((-HW, 0.0, HH - FR), (HW, D, HH), "Wood")
    b.box((-HW, 0.0, -HH), (HW, D, -HH + FR), "Wood")
    b.box((-HW, 0.0, -HH + FR), (-HW + FR, D, HH - FR), "Wood")
    b.box((HW - FR, 0.0, -HH + FR), (HW, D, HH - FR), "Wood")
    # auget + craie + éponge
    b.box((-HW + 0.02, D, -HH - 0.01), (HW - 0.02, D + 0.035, -HH + 0.012), "Wood")
    b.box((-0.1, D + 0.008, -HH + 0.012), (-0.03, D + 0.02, -HH + 0.024), "Cream")
    b.box((0.06, D + 0.004, -HH + 0.012), (0.15, D + 0.03, -HH + 0.04), "Ochre")
    # clou et ficelle
    b.box((-0.008, 0.0, HH + 0.1), (0.008, 0.03, HH + 0.116), "Iron")
    b.tilted_box((0.0, 0.012, HH + 0.05), (0.004, 0.004, 0.11), 0.0, "Ochre")
    b.finish()
    kit.save_and_export("chalkboard", budget_tris=600)


main()
