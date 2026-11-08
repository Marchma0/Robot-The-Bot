"""Tonneau en bois cerclé de cuivre, avec un robinet (ventre du mécha, coin avant droit).

Fiche
- Taille : 0,40 m de diamètre au ventre, 0,57 m de haut.
- Origine : au sol, au centre ; le robinet regarde vers +Y.
  Placé par scenes/mecha/props/barrel.tscn (collision cylindre) en Godot (1.9, 2.6, -1.55).
- Budget : 900 triangles.
- Pièces : deux troncs de cône (Wood, bombé), 4 cerclages (Copper), couvercle cerclé (IronDark),
  bonde, robinet avec sa poignée, petite flaque sous le robinet (Grime).

    blender -b --factory-startup --python blender/props/barrel.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

H = 0.57
R_END = 0.17
R_MID = 0.20
SEG = 14


def radius_at(z: float) -> float:
    t = 1.0 - abs(z - H / 2) / (H / 2)
    return R_END + (R_MID - R_END) * t


def main():
    kit.new_scene()
    b = kit.Builder("Barrel")
    b.cylinder((0, 0, 0.0), (0, 0, H / 2), R_END, "Wood", SEG, radius_end=R_MID)
    b.cylinder((0, 0, H / 2), (0, 0, H), R_MID, "Wood", SEG, radius_end=R_END)
    for z in (0.05, 0.19, 0.38, 0.52):
        r = radius_at(z) + 0.008
        b.cylinder((0, 0, z - 0.016), (0, 0, z + 0.016), r, "Copper", SEG)
    # couvercle : cercle de fer et bonde
    b.cylinder((0, 0, H - 0.004), (0, 0, H + 0.008), R_END - 0.006, "IronDark", SEG)
    b.cylinder((0, 0, H + 0.008), (0, 0, H + 0.012), R_END - 0.03, "Wood", SEG)
    for x in (-0.07, 0.0, 0.07):   # joints entre les planches du couvercle
        b.box((x - 0.003, -R_END + 0.05, H + 0.012), (x + 0.003, R_END - 0.05, H + 0.014), "IronDark")
    b.cylinder((0.035, 0.06, H + 0.012), (0.035, 0.06, H + 0.03), 0.025, "Copper", 8)
    # robinet
    b.cylinder((0, R_END + 0.005, 0.11), (0, R_END + 0.07, 0.11), 0.016, "Copper", 8)
    b.cylinder((0, R_END + 0.07, 0.11), (0, R_END + 0.07, 0.07), 0.012, "Copper", 8)
    b.box((-0.03, R_END + 0.05, 0.135), (0.03, R_END + 0.065, 0.15), "IronDark")
    b.box((-0.004, R_END + 0.05, 0.12), (0.004, R_END + 0.065, 0.135), "IronDark")
    # petite flaque
    b.cylinder((0, R_END + 0.09, 0.0005), (0, R_END + 0.09, 0.003), 0.05, "Grime", 10)
    b.finish()
    kit.save_and_export("barrel", budget_tris=900)


main()
