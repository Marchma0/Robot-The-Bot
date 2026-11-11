"""Couvercle articulé du sac à dos du mécha (M10 — Inventaire).

Fiche
- Taille : 3,28 m de large, 1,24 m de profondeur, 0,52 m de haut.
- Origine : sur l'axe des charnières (0, 0, 0), qui correspond à (0, -0.32, 2.52) dans le repère de backpack.py
  (soit (0, 2.52, 0.32) en local dans backpack.tscn).
  Fermé (rotation X = 0), le rabat couvre l'ouverture vers -Y (Blender) / +Z (Godot).
  Ouvert, il pivote autour de X pour dégager le puits du sac.
- Budget : 1000 triangles.
- Pièces : dôme chanfreiné (Paint, WallCream), rebord en fer (IronDark) avec rivets (Copper), 2 sangles profilées
  qui épousent le chanfrein du dôme (Wood) avec fermoirs en cuivre, poignée supérieure en cuivre, charnières (Iron).

    blender -b --factory-startup --python blender/props/backpack_lid.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

W = 3.28          # largeur (légèrement débordante sur le caisson de 3,20 m)
D = 1.16          # profondeur depuis la charnière (y = 0, à y_sac = -0.32) jusqu'au bord arrière (y = -1.16, y_sac = -1.48)


def main():
    kit.new_scene()
    b = kit.Builder("BackpackLid")

    x0, x1 = -W / 2, W / 2
    y_hinge = 0.06
    y_front = -D

    # 1. Jupe / rebord métallique inférieur du couvercle
    b.box((x0, y_front, -0.025), (x1, y_hinge, 0.075), "IronDark")
    b.rivet_row((x0 + 0.18, y_front, 0.025), (x1 - 0.18, y_front, 0.025),
                (0, -1, 0), spacing=0.26, size=0.026)

    # 2. Dôme chanfreiné en tôle peinte (frustum)
    cx, cy = 0.0, (y_front + y_hinge) / 2
    hx, hy = W / 2 - 0.025, (y_hinge - y_front) / 2 - 0.025
    b.frustum((cx, cy), 0.075, 0.30, (hx, hy), (hx - 0.20, hy - 0.18), "Paint")

    # Plaque supérieure crème
    top_y0 = cy - (hy - 0.18)
    top_y1 = cy + (hy - 0.18)
    b.box((-hx + 0.28, top_y0 + 0.05, 0.30), (hx - 0.28, top_y1 - 0.05, 0.33), "WallCream")

    # 3. Deux sangles profilées qui épousent la pente du dôme (alignées sur sx = ±0.82 du sac)
    for sx in (-0.82, 0.82):
        # Segment plat sur le dessus du dôme
        b.box((sx - 0.088, top_y0, 0.298), (sx + 0.088, top_y1, 0.342), "Wood")
        # Segment incliné côté arrière (y_front -> top_y0)
        b.prism_x(
            [(y_front - 0.020, 0.065), (top_y0 + 0.01, 0.298), (top_y0, 0.342), (y_front - 0.020, 0.11)],
            sx - 0.088, sx + 0.088, "Wood",
        )
        # Segment incliné côté charnière (top_y1 -> y_hinge)
        b.prism_x(
            [(top_y1 - 0.01, 0.298), (y_hinge - 0.02, 0.07), (y_hinge - 0.02, 0.115), (top_y1, 0.342)],
            sx - 0.088, sx + 0.088, "Wood",
        )
        # Retombée verticale et fermoir en cuivre sur le bord avant (-Y)
        b.box((sx - 0.086, y_front - 0.022, -0.10), (sx + 0.086, y_front + 0.006, 0.08), "Wood")
        b.box((sx - 0.105, y_front - 0.036, -0.125), (sx + 0.105, y_front + 0.010, -0.015), "Copper")

    # 4. Poignée supérieure en cuivre au centre du couvercle
    for px in (-0.30, 0.30):
        b.cylinder((px, cy, 0.325), (px, cy, 0.40), 0.026, "IronDark", segments=8)
    b.cylinder((-0.33, cy, 0.40), (0.33, cy, 0.40), 0.032, "Copper", segments=10)

    # 5. Manchons de charnière sur l'axe (0, 0, 0)
    for hx_pos in (-1.24, -0.68, 0.68, 1.24):
        b.cylinder((hx_pos - 0.10, 0.0, 0.0), (hx_pos + 0.10, 0.0, 0.0), 0.056, "Iron", segments=10)
        b.cylinder((hx_pos - 0.105, 0.0, 0.0), (hx_pos + 0.105, 0.0, 0.0), 0.030, "Copper", segments=8)

    b.finish()
    kit.save_and_export("backpack_lid", budget_tris=1000, ground=False)


main()
