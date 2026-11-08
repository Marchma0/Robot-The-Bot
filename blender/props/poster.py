"""Affiche encadrée au mur du fond du salon (ventre du mécha) : un robot trapu dessiné, façon réclame.

Fiche
- Taille : 0,50 m de large, 0,70 m de haut, 2,5 cm d'épaisseur.
- Origine : sur le mur, au centre ; l'avant regarde vers +Y (l'arrière est contre le mur, en y = 0).
  Placée en Godot (-0.7, 3.95, 1.9), tournée vers l'avant du mécha.
- Budget : 600 triangles.
- Pièces : cadre (Copper), papier (Paper), bandeau du titre (DartRed) et ses lettres (Cream),
  dessin du robot (Paint, Cream, Copper, IronDark), soleil (Yellow), lignes de texte (IronDark), coin corné.

    blender -b --factory-startup --python blender/props/poster.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HW, HH = 0.25, 0.35
FR = 0.022


def main():
    kit.new_scene()
    b = kit.Builder("Poster")
    b.box((-HW + 0.005, 0.002, -HH + 0.005), (HW - 0.005, 0.012, HH - 0.005), "Paper")
    b.box((-HW, 0.0, HH - FR), (HW, 0.02, HH), "Copper")
    b.box((-HW, 0.0, -HH), (HW, 0.02, -HH + FR), "Copper")
    b.box((-HW, 0.0, -HH + FR), (-HW + FR, 0.02, HH - FR), "Copper")
    b.box((HW - FR, 0.0, -HH + FR), (HW, 0.02, HH - FR), "Copper")
    f = 0.012
    # bandeau du titre et ses « lettres »
    b.box((-0.2, f, 0.2), (0.2, f + 0.002, 0.3), "DartRed")
    for i in range(6):
        x = -0.16 + i * 0.056
        b.box((x, f + 0.002, 0.23), (x + 0.035, f + 0.004, 0.27), "Cream")
    # soleil
    b.cylinder((0.155, f, 0.13), (0.155, f + 0.002, 0.13), 0.04, "Yellow", 12)
    # robot : jambes, ventre, col, tête, yeux
    for x in (-0.075, 0.035):
        b.box((x, f, -0.2), (x + 0.04, f + 0.002, -0.1), "IronDark")
    b.box((-0.1, f, -0.1), (0.1, f + 0.002, 0.03), "Paint")
    b.box((-0.06, f, 0.03), (0.06, f + 0.002, 0.045), "Cream")
    b.box((-0.085, f, 0.045), (0.085, f + 0.002, 0.15), "Paint")
    for x in (-0.04, 0.04):
        b.cylinder((x, f + 0.002, 0.1), (x, f + 0.004, 0.1), 0.026, "Copper", 10)
        b.cylinder((x, f + 0.004, 0.1), (x, f + 0.006, 0.1), 0.015, "Cream", 10)
    b.box((-0.03, f + 0.002, -0.07), (0.03, f + 0.004, -0.01), "Copper")     # hublot du ventre
    # lignes de texte
    for i, w in enumerate((0.36, 0.3, 0.33)):
        z = -0.24 - i * 0.03
        b.box((-w / 2, f, z), (w / 2, f + 0.002, z + 0.012), "IronDark")
    # coin corné en bas à droite
    b.box((HW - 0.07, f, -HH + 0.03), (HW - 0.03, f + 0.004, -HH + 0.07), "Cream")
    b.finish()
    kit.save_and_export("poster", budget_tris=600)


main()
