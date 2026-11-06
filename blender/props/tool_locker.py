"""Armoire à outils en tôle (tête du mécha, mur droit), avec une caisse à outils rouge dessus.

Fiche
- Taille : 0,80 m de large, 0,42 m de profondeur, 1,05 m de haut (+ caisse à outils de 0,15 m).
- Origine : au sol, au centre ; l'avant (portes) regarde vers +Y.
  Placée contre le mur droit, tournée de +90° : Blender (1.93, 0.52, 5.6), Godot (1.93, 5.6, -0.52).
- Budget : 1800 triangles.
- Pièces : caisson (Paint), pieds, socle et cadre (IronDark), 2 portes avec ouïes d'aération, poignées en cuivre,
  rivets, étiquette jaune, caisse à outils (ButtonRed) avec poignée.
- Collision : scenes/mecha/props/tool_locker.tscn (boîte 0,80 x 1,05 x 0,42).

    blender -b --factory-startup --python blender/props/tool_locker.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

W, D, H = 0.80, 0.42, 1.05
FEET = 0.06


def main():
    kit.new_scene()
    b = kit.Builder("ToolLocker")
    x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
    # pieds + socle
    for sx in (x0 + 0.03, x1 - 0.07):
        for sy in (y0 + 0.03, y1 - 0.07):
            b.box((sx, sy, 0.0), (sx + 0.04, sy + 0.04, FEET), "IronDark")
    b.box((x0, y0, FEET), (x1, y1, FEET + 0.05), "IronDark")
    # caisson
    b.box((x0, y0, FEET + 0.05), (x1, y1 - 0.01, H - 0.03), "Paint")
    b.box((x0 - 0.01, y0 - 0.01, H - 0.03), (x1 + 0.01, y1 + 0.01, H), "IronDark")   # couvercle débordant
    # portes : deux panneaux, avec un joint au milieu
    front = y1
    for (dx0, dx1) in ((x0 + 0.02, -0.005), (0.005, x1 - 0.02)):
        b.box((dx0, front - 0.012, FEET + 0.07), (dx1, front, H - 0.05), "Paint")
        # cadre de porte
        b.box((dx0, front, FEET + 0.07), (dx1, front + 0.006, FEET + 0.1), "IronDark")
        b.box((dx0, front, H - 0.08), (dx1, front + 0.006, H - 0.05), "IronDark")
        # ouïes d'aération en haut de la porte
        for i in range(4):
            z = H - 0.2 - i * 0.035
            b.box((dx0 + 0.06, front, z), (dx1 - 0.06, front + 0.012, z + 0.012), "IronDark")
        b.rivet_row((dx0 + 0.03, front + 0.006, FEET + 0.085), (dx1 - 0.03, front + 0.006, FEET + 0.085),
                    (0, 1, 0), spacing=0.09, size=0.012)
    # poignées verticales au centre
    for hx in (-0.03, 0.03):
        b.box((hx - 0.008, front, 0.5), (hx + 0.008, front + 0.03, 0.66), "Copper")
    # étiquette jaune
    b.box((0.07, front, 0.3), (0.27, front + 0.004, 0.38), "Yellow")
    # caisse à outils posée dessus (décalée vers l'avant, loin du mur)
    tx0, tx1, ty0, ty1, tz = -0.25, 0.12, -0.02, 0.17, H
    b.box((tx0, ty0, tz), (tx1, ty1, tz + 0.11), "ButtonRed")
    b.box((tx0 - 0.005, ty0 - 0.005, tz + 0.11), (tx1 + 0.005, ty1 + 0.005, tz + 0.125), "ButtonRed")
    b.box((tx0 + 0.04, (ty0 + ty1) / 2 - 0.01, tz + 0.125), (tx0 + 0.06, (ty0 + ty1) / 2 + 0.01, tz + 0.17), "IronDark")
    b.box((tx1 - 0.06, (ty0 + ty1) / 2 - 0.01, tz + 0.125), (tx1 - 0.04, (ty0 + ty1) / 2 + 0.01, tz + 0.17), "IronDark")
    b.box((tx0 + 0.04, (ty0 + ty1) / 2 - 0.01, tz + 0.16), (tx1 - 0.04, (ty0 + ty1) / 2 + 0.01, tz + 0.175), "IronDark")
    b.box((tx0 + 0.02, ty1, tz + 0.06), (tx0 + 0.06, ty1 + 0.008, tz + 0.09), "Iron")       # fermoirs
    b.box((tx1 - 0.06, ty1, tz + 0.06), (tx1 - 0.02, ty1 + 0.008, tz + 0.09), "Iron")
    b.finish()
    kit.save_and_export("tool_locker", budget_tris=1800)


main()
