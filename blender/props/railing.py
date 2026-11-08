"""Garde-corps d'un trou dans le plancher (trappe du ventre, trou du rayon dans la tête), côté pièce fermé.

Fiche
- Taille : 0,98 m de large, 0,95 m de haut (à la poitrine d'un nain de 1,2 m), 7 cm d'épaisseur.
- Origine : au sol, au centre ; la main courante est selon X. Symétrique avant / arrière.
  Placé par scenes/mecha/props/railing.tscn (collision) : trappe Godot (-1.70, 2.6, 0.93),
  trou du rayon Godot (1.75, 5.6, 1.0).
- Budget : 700 triangles.
- Pièces : 2 poteaux (IronDark) sur platines boulonnées (Copper), main courante (Wood), lisse basse (IronDark),
  2 barreaux, plinthe (IronDark) pour que rien ne roule dans le trou, bande d'avertissement (Yellow / DartBlack).

    blender -b --factory-startup --python blender/props/railing.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HW = 0.49           # demi-largeur
POST_X = 0.42       # axe des poteaux
H = 0.95


def main():
    kit.new_scene()
    b = kit.Builder("Railing")
    for x in (-POST_X, POST_X):
        b.box((x - 0.045, -0.045, 0.0), (x + 0.045, 0.045, 0.012), "Copper")          # platine
        for bx in (-0.03, 0.03):
            b.box((x + bx - 0.008, -0.008, 0.012), (x + bx + 0.008, 0.008, 0.02), "IronDark")   # boulons
        b.box((x - 0.025, -0.025, 0.012), (x + 0.025, 0.025, H - 0.07), "IronDark")    # poteau
    # main courante en bois, bout arrondi par des chanfreins
    b.frustum((0, 0), H - 0.07, H - 0.05, (HW - 0.01, 0.03), (HW, 0.035), "Wood")
    b.box((-HW, -0.035, H - 0.05), (HW, 0.035, H - 0.02), "Wood")
    b.frustum((0, 0), H - 0.02, H, (HW, 0.035), (HW - 0.01, 0.025), "Wood")
    # lisse basse et barreaux
    b.box((-POST_X + 0.025, -0.012, 0.45), (POST_X - 0.025, 0.012, 0.48), "IronDark")
    for x in (-0.14, 0.14):
        b.box((x - 0.01, -0.01, 0.1), (x + 0.01, 0.01, H - 0.07), "IronDark")
    # plinthe avec bande d'avertissement jaune et noire (côté pièce, +Y)
    b.box((-POST_X + 0.025, -0.01, 0.012), (POST_X - 0.025, 0.01, 0.1), "IronDark")
    for i in range(8):
        x0 = -POST_X + 0.03 + i * 0.1
        b.box((x0, 0.01, 0.025), (min(x0 + 0.05, POST_X - 0.03), 0.013, 0.085), "Yellow")
    b.finish()
    kit.save_and_export("railing", budget_tris=700)


main()
