"""Bras fixe de la foreuse (M8 — Foreuse), fixé sur le flanc droit du mécha (+X).

Fiche
- Taille : 0,92 m de large (X), 2,25 m de long (Y), 2,05 m de haut (Z). Repère : un nain fait 1,2 m.
  Origine au centre du coude (0, 0, 0), placé dans mecha.tscn à (2.95, 3.40, -0.30).
  L'épaule remonte jusqu'à z = +1,63 m et s'ancrera contre la coque à x = -0,55 m (soit x_mécha = 2,40 m).
- Budget : 1200 triangles.
- Pièces : caisson d'épaule boulonné à la coque (IronDark, Copper), bras supérieur vertical (Paint, IronDark)
  avec vérin hydraulique arrière (Copper, Iron), articulation du coude à flasques (IronDark, Copper),
  berceau / fût externe de la glissière de foreuse (Paint, IronDark, durites Copper).

    blender -b --factory-startup --python blender/props/drill_arm.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402


def main():
    kit.new_scene()
    b = kit.Builder("DrillArm")

    # 1. Caisson d'épaule ancré contre le flanc droit du mécha (x = -0.575 .. -0.125, z = 0.77 .. 1.63)
    b.box((-0.575, -0.45, 0.77), (-0.125, 0.45, 1.63), "IronDark")
    # Platine de fixation contre la coque avec rivets en cuivre sur le flanc droit (+X) du caisson
    b.box((-0.595, -0.52, 0.72), (-0.575, 0.52, 1.68), "Iron")
    for sy in (-0.36, 0.36):
        b.rivet_row((-0.125, sy, 0.84), (-0.125, sy, 1.56), (1, 0, 0), spacing=0.24, size=0.028)
    # Tourillon cylindrique d'épaule
    b.cylinder((-0.125, 0.0, 1.22), (0.30, 0.0, 1.22), 0.28, "IronDark", segments=12)
    b.cylinder((0.30, 0.0, 1.22), (0.33, 0.0, 1.22), 0.20, "Copper", segments=12)

    # 2. Bras supérieur vertical (relie l'épaule z = 1.35 au coude z = 0.15)
    b.box((-0.25, -0.25, 0.15), (0.25, 0.25, 1.35), "Paint")
    # Ceintures de renfort sur le bras supérieur
    for zp in (0.38, 0.98):
        b.box((-0.268, -0.268, zp - 0.045), (0.268, 0.268, zp + 0.045), "IronDark")
        b.rivet_row((-0.268, 0.268, zp), (0.268, 0.268, zp), (0, 1, 0), spacing=0.16, size=0.024)
    # Vérin hydraulique à l'arrière du bras supérieur (ancré en haut et en bas sur le coude)
    b.cylinder((0.0, -0.34, 0.72), (0.0, -0.34, 1.32), 0.068, "Copper", segments=10)
    b.cylinder((0.0, -0.34, 0.22), (0.0, -0.34, 0.72), 0.038, "Iron", segments=8)
    b.box((-0.08, -0.38, 1.28), (0.08, -0.25, 1.38), "IronDark")
    b.box((-0.07, -0.38, 0.18), (0.07, -0.25, 0.27), "IronDark")

    # 3. Articulation du coude (autour de l'origine 0, 0, 0)
    b.box((-0.30, -0.30, -0.285), (0.30, 0.30, 0.285), "IronDark")
    for sx in (-1, 1):
        x0 = sx * 0.30
        x1 = sx * 0.335
        b.cylinder((x0, 0.0, 0.0), (x1, 0.0, 0.0), 0.21, "Copper", segments=12)

    # 4. Fût externe fixe de la foreuse (de y = 0.0 à y = 1.65) dans lequel coulisse le fût télescopique
    b.box((-0.24, 0.02, -0.24), (0.24, 1.62, 0.24), "Paint")
    # Rails de guidage latéraux en fer sombre + frettes rivetées
    for sx in (-1, 1):
        rx0 = sx * 0.24
        rx1 = sx * 0.285
        b.box((rx0, 0.10, -0.11), (rx1, 1.68, 0.11), "IronDark")
    for yp in (0.42, 1.02, 1.56):
        b.box((-0.265, yp - 0.05, -0.265), (0.265, yp + 0.05, 0.265), "IronDark")
        b.rivet_row((-0.20, yp, 0.265), (0.20, yp, 0.265), (0, 0, 1), spacing=0.14, size=0.024)
    # Collier de bouche en cuivre à l'avant du fût externe (y = 1.62 .. 1.72)
    b.box((-0.275, 1.62, -0.275), (0.275, 1.72, 0.275), "Copper")
    # Durite de pression en cuivre sur le dessus du fût
    b.pipe([(0.16, 0.12, 0.275), (0.16, 1.50, 0.275)], 0.032, "Copper", "IronDark", segments=8)

    b.finish()
    kit.save_and_export("drill_arm", budget_tris=1200)


main()
