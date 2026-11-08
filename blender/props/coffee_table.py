"""Table basse du salon avec un damier et une tasse (ventre du mécha, devant le canapé).

Fiche
- Taille : 0,45 (X) x 0,55 (Y) m, 0,34 m de haut (à hauteur de genou de nain).
- Origine : au sol, au centre ; long côté selon Y. Placée par scenes/mecha/props/coffee_table.tscn (collision)
  en Godot (-1.025, 2.6, -0.075).
- Budget : 2400 triangles.
- Pièces : plateau à chant biseauté, ceinture, 4 pieds fuselés (Wood), tablette basse avec des journaux (Paper),
  damier 8 x 8 (DartBlack / Cream) sur un socle (IronDark), tasse fumante (Cream, Grime).
  Les pions ne sont pas dans le modèle : le jeu de dames les crée et les déplace (scripts/props/checkers_game.gd,
  mêmes mesures : damier de 0,3 m centré en y = -0,06, cases à z = H + 0,009).

    blender -b --factory-startup --python blender/props/coffee_table.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HX, HY, H = 0.225, 0.275, 0.34
TOP = 0.03


def main():
    kit.new_scene()
    b = kit.Builder("CoffeeTable")
    # plateau : dalle + chant biseauté
    b.frustum((0, 0), H - TOP, H - 0.012, (HX - 0.012, HY - 0.012), (HX, HY), "Wood")
    b.box((-HX, -HY, H - 0.012), (HX, HY, H), "Wood")
    # ceinture sous le plateau (retrait de 3 cm)
    b.box((-HX + 0.03, -HY + 0.03, H - TOP - 0.05), (HX - 0.03, HY - 0.03, H - TOP), "Wood")
    # pieds fuselés
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * (HX - 0.045), sy * (HY - 0.045)
            b.frustum((cx, cy), 0.0, H - TOP - 0.05, (0.016, 0.016), (0.024, 0.024), "Wood")
    # tablette basse + journaux
    b.box((-HX + 0.05, -HY + 0.05, 0.08), (HX - 0.05, HY - 0.05, 0.095), "Wood")
    b.box((-0.12, -0.16, 0.095), (0.1, 0.08, 0.103), "Paper")
    b.box((-0.1, -0.12, 0.103), (0.12, 0.13, 0.11), "Cream")
    # damier : socle + 64 cases (1 mm au-dessus du socle)
    board = 0.3
    cell = board / 8
    z = H
    b.box((-board / 2 - 0.012, -board / 2 - 0.012 - 0.06, z), (board / 2 + 0.012, board / 2 + 0.012 - 0.06, z + 0.008), "IronDark")
    for i in range(8):
        for j in range(8):
            x0 = -board / 2 + i * cell
            y0 = -board / 2 + j * cell - 0.06
            b.box((x0, y0, z + 0.008), (x0 + cell, y0 + cell, z + 0.009), "DartBlack" if (i + j) % 2 else "Cream")
    # tasse de café
    mx, my = 0.11, 0.2
    b.cylinder((mx, my, z), (mx, my, z + 0.07), 0.03, "Cream", 10)
    b.cylinder((mx, my, z + 0.07), (mx, my, z + 0.072), 0.025, "Grime", 10)
    b.box((mx + 0.03, my - 0.005, z + 0.015), (mx + 0.05, my + 0.005, z + 0.025), "Cream")
    b.box((mx + 0.04, my - 0.005, z + 0.025), (mx + 0.05, my + 0.005, z + 0.05), "Cream")
    b.box((mx + 0.03, my - 0.005, z + 0.05), (mx + 0.05, my + 0.005, z + 0.06), "Cream")
    b.finish()
    kit.save_and_export("coffee_table", budget_tris=2400)


main()
