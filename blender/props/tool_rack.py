"""Râtelier à outils : panneau perforé au mur gauche de la tête, au-dessus du coin café.

Fiche
- Taille : 0,85 m de large, 0,45 m de haut, 8 cm de saillie avec les outils.
- Origine : sur le mur, au centre du panneau ; l'avant regarde vers +Y (l'arrière est contre le mur, en y = 0).
  Placé en Godot (-2.2, 6.97, 0.18), tourné vers la droite du mécha (vers la pièce).
- Budget : 1600 triangles.
- Pièces : panneau (Wood) sur cadre (IronDark), trous (IronDark), marteau, clé plate, tournevis, scie,
  pince, mètre ruban (Yellow), crochets (Copper).

    blender -b --factory-startup --python blender/props/tool_rack.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HW, HH = 0.425, 0.225
D = 0.02
F = D + 0.012      # devant des crochets : les outils sont posés ici


def hook(b, x, z):
    b.box((x - 0.004, D, z - 0.004), (x + 0.004, F, z + 0.004), "Copper")


def main():
    kit.new_scene()
    b = kit.Builder("ToolRack")
    b.box((-HW, 0.0, -HH), (HW, D, HH), "Wood")
    b.box((-HW - 0.015, 0.0, HH), (HW + 0.015, D + 0.005, HH + 0.02), "IronDark")
    b.box((-HW - 0.015, 0.0, -HH - 0.02), (HW + 0.015, D + 0.005, -HH), "IronDark")
    # trous du panneau perforé (petits carrés sombres)
    for i in range(12):
        for j in range(5):
            x = -HW + 0.05 + i * 0.07
            z = -HH + 0.04 + j * 0.09
            b.box((x - 0.005, D, z - 0.005), (x + 0.005, D + 0.001, z + 0.005), "IronDark")
    # marteau
    x = -0.33
    hook(b, x, 0.12)
    b.box((x - 0.012, F, -0.17), (x + 0.012, F + 0.02, 0.09), "Wood")
    b.box((x - 0.06, F - 0.004, 0.09), (x + 0.07, F + 0.028, 0.14), "IronDark")
    # clé plate
    x = -0.18
    hook(b, x, 0.15)
    b.box((x - 0.012, F, -0.12), (x + 0.012, F + 0.008, 0.11), "Iron")
    b.box((x - 0.035, F, 0.11), (x + 0.035, F + 0.008, 0.17), "Iron")
    b.box((x - 0.01, F + 0.001, 0.13), (x + 0.01, F + 0.009, 0.175), "Wood")   # gueule ouverte : fond sombre
    # tournevis
    x = -0.06
    hook(b, x, 0.13)
    b.cylinder((x, F + 0.015, 0.13), (x, F + 0.015, 0.02), 0.018, "DartRed", 8)
    b.cylinder((x, F + 0.015, 0.02), (x, F + 0.015, -0.15), 0.005, "Iron", 6)
    # scie
    x = 0.12
    hook(b, x, 0.15)
    b.box((x - 0.04, F, 0.05), (x + 0.04, F + 0.025, 0.18), "Wood")
    b.box((x - 0.035, F + 0.008, -0.19), (x + 0.07, F + 0.012, 0.05), "Iron")
    # pince
    x = 0.28
    hook(b, x, 0.14)
    for dx in (-0.015, 0.015):
        b.box((x + dx - 0.008, F, -0.08), (x + dx + 0.008, F + 0.012, 0.06), "DartRed")
    b.box((x - 0.02, F, 0.06), (x + 0.02, F + 0.014, 0.13), "IronDark")
    # mètre ruban
    b.cylinder((0.37, D + 0.002, -0.12), (0.37, D + 0.04, -0.12), 0.035, "Yellow", 10)
    b.cylinder((0.37, D + 0.04, -0.12), (0.37, D + 0.044, -0.12), 0.015, "IronDark", 8)
    b.finish()
    kit.save_and_export("tool_rack", budget_tris=1600, ground=False)


main()
