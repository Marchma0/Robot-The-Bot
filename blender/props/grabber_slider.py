"""Avant-bras télescopique et poignet avec caméra du grappin (M9 — Grappin).

Fiche
- Taille : 0,70 m de large (X), 2,14 m de long hors-tout (Y : fût arrière de 1,65 m + poignet de 0,49 m),
  0,89 m de haut (Z). Repère : un nain fait 1,2 m.
- Origine : au centre du col du poignet (0, 0, 0), juste derrière la pince ; au repos placé à z = -1,80 m
  du coude, de sorte que le fût arrière (1,65 m) ne dépasse jamais derrière le coude.
- Budget : 1100 triangles.
- Pièces : fût d'avant-bras en peinture sarcelle et acier (Paint, IronDark, Iron), 2 tiges hydrauliques en cuivre
  (Copper), poignet blindé de la pince (IronDark, Copper), tourelle de caméra embarquée sur le dessus
  avec objectif vitré (IronDark, Copper, Glass) et phare d'éclairage (Lamp).

    blender -b --factory-startup --python blender/props/grabber_slider.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402


def main():
    kit.new_scene()
    b = kit.Builder("GrabberSlider")

    # 1. Fût d'avant-bras (y = -1.65 .. 0.0) qui loge jusqu'au coude sans dépasser à l'arrière
    b.box((-0.22, -1.65, -0.22), (0.22, 0.0, 0.22), "Paint")
    for yp in (-1.50, -0.95, -0.35):
        b.box((-0.242, yp - 0.045, -0.242), (0.242, yp + 0.045, 0.242), "IronDark")
        b.rivet_row((-0.18, yp, 0.242), (0.18, yp, 0.242), (0, 0, 1), spacing=0.14, size=0.022)
    # 2 tiges hydrauliques en cuivre sur les flancs
    for sx in (-1, 1):
        px = sx * 0.25
        b.cylinder((px, -1.60, 0.0), (px, 0.12, 0.0), 0.036, "Copper", segments=8)

    # 2. Poignet en cuivre et chape de pince (y = 0.0 .. 0.48)
    b.box((-0.285, 0.0, -0.285), (0.285, 0.18, 0.285), "Copper")
    b.box((-0.35, 0.18, -0.32), (0.35, 0.48, 0.32), "IronDark")
    for sx in (-1, 1):
        px = sx * 0.24
        b.cylinder((px, 0.44, -0.35), (px, 0.44, 0.35), 0.065, "Copper", segments=10)

    # 3. Boîtier de caméra embarquée sur le dessus du poignet (z = 0.285 .. 0.56, y = -0.04 .. 0.39)
    b.box((-0.06, 0.04, 0.285), (0.06, 0.20, 0.36), "Copper")
    b.box((-0.14, -0.02, 0.36), (0.14, 0.32, 0.54), "IronDark")
    b.cylinder((0.0, 0.32, 0.45), (0.0, 0.37, 0.45), 0.068, "Copper", segments=10)
    b.cylinder((0.0, 0.37, 0.45), (0.0, 0.39, 0.45), 0.052, "Glass", segments=10)
    b.box((0.14, 0.14, 0.40), (0.21, 0.30, 0.50), "IronDark")
    b.box((0.15, 0.30, 0.415), (0.20, 0.32, 0.485), "Lamp")

    b.finish()
    kit.save_and_export("grabber_slider", budget_tris=1100, ground=False)


main()
