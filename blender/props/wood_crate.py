"""Caisse en bois cerclée de fer (ventre du mécha : pile près du rayon, tabouret du champignon).

Fiche
- Taille : 0,42 x 0,42 m au sol, 0,36 m de haut (genou d'un nain).
- Origine : au sol, au centre ; l'avant (le marquage) regarde vers +Y.
  Placée par scenes/mecha/props/wood_crate.tscn (collision), à plusieurs endroits et plusieurs tailles.
- Budget : 1200 triangles.
- Pièces : caisse (Wood), planches en relief sur les 4 faces et le couvercle, cornières en fer (IronDark),
  clous en cuivre, marquage au pochoir (Ochre).

    blender -b --factory-startup --python blender/props/wood_crate.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

S = 0.21        # demi-côté
H = 0.36
SLAT = 0.006    # relief des planches
GUARD = 0.012   # relief des cornières


def main():
    kit.new_scene()
    b = kit.Builder("WoodCrate")
    b.box((-S, -S, 0.0), (S, S, H), "Wood")
    # planches horizontales sur les 4 faces (3 rangées), entre les cornières
    rows = [(0.02, 0.115), (0.125, 0.235), (0.245, 0.34)]
    for z0, z1 in rows:
        b.box((-S + 0.04, S, z0), (S - 0.04, S + SLAT, z1), "Wood")           # avant
        b.box((-S + 0.04, -S - SLAT, z0), (S - 0.04, -S, z1), "Wood")         # arrière
        b.box((S, -S + 0.04, z0), (S + SLAT, S - 0.04, z1), "Wood")           # droite
        b.box((-S - SLAT, -S + 0.04, z0), (-S, S - 0.04, z1), "Wood")         # gauche
    # couvercle : 3 planches
    for y0, y1 in ((-S + 0.02, -0.075), (-0.065, 0.065), (0.075, S - 0.02)):
        b.box((-S + 0.02, y0, H), (S - 0.02, y1, H + SLAT), "Wood")
    # cornières (dépassent un peu en haut et en bas : pas de faces superposées)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x0, x1 = sorted((sx * (S + GUARD), sx * (S - 0.03)))
            y0, y1 = sorted((sy * (S + GUARD), sy * (S - 0.03)))
            b.box((x0, y0, -0.003), (x1, y1, H + 0.009), "IronDark")
    # clous en cuivre au bout de chaque planche de face
    for z0, z1 in rows:
        z = (z0 + z1) / 2
        for x in (-S + 0.06, S - 0.06):
            b.box((x - 0.008, S + SLAT, z - 0.008), (x + 0.008, S + SLAT + 0.004, z + 0.008), "Copper")
            b.box((x - 0.008, -S - SLAT - 0.004, z - 0.008), (x + 0.008, -S - SLAT, z + 0.008), "Copper")
    # marquage au pochoir sur la planche du milieu (une flèche « haut » et un trait)
    f = S + SLAT
    b.box((-0.02, f, 0.15), (0.02, f + 0.002, 0.21), "Ochre")
    b.box((-0.05, f, 0.19), (0.05, f + 0.002, 0.205), "Ochre")
    b.box((0.08, f, 0.15), (0.14, f + 0.002, 0.165), "Ochre")
    b.finish()
    kit.save_and_export("wood_crate", budget_tris=1200)


main()
