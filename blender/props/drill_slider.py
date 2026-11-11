"""Fût télescopique coulissant et mandrin de la foreuse (M8 — Foreuse).

Fiche
- Taille : 0,83 m de large (X), 2,43 m de long hors-tout (Y : tige arrière de 1,65 m + tête de 0,78 m),
  0,96 m de haut (Z). Repère : un nain fait 1,2 m.
- Origine : au centre de la face arrière du carter du mandrin (0, 0, 0) ; au repos placé à z = -1,72 m
  dans DrillArm, de sorte que la tige arrière (1,65 m) rentre entièrement dans le fût externe sans jamais
  dépasser derrière le coude.
- Budget : 1000 triangles.
- Pièces : fût télescopique interne en acier (Iron) et bagues sombres (IronDark), 2 tiges de vérin latérales
  en cuivre (Copper), gros bloc moteur / mandrin avant (IronDark, Paint), couronne de butée en cuivre
  rivetée (Copper) et projecteur de travail ambré (Lamp).

    blender -b --factory-startup --python blender/props/drill_slider.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402


def main():
    kit.new_scene()
    b = kit.Builder("DrillSlider")

    # 1. Fût télescopique arrière (y = -1.65 .. 0.0) qui loge entièrement dans le fût externe au repos
    b.box((-0.165, -1.65, -0.165), (0.165, 0.0, 0.165), "Iron")
    for yp in (-1.45, -0.95, -0.45):
        b.box((-0.182, yp - 0.04, -0.182), (0.182, yp + 0.04, 0.182), "IronDark")
    for sx in (-1, 1):
        px = sx * 0.235
        b.cylinder((px, -1.62, 0.0), (px, 0.12, 0.0), 0.038, "Copper", segments=8)

    # 2. Bloc moteur / carter du mandrin (y = 0.0 .. 0.68)
    b.box((-0.38, 0.0, -0.38), (0.38, 0.68, 0.38), "IronDark")
    for sx in (-1, 1):
        x0 = sx * 0.38
        x1 = sx * 0.405
        b.box((x0, 0.08, -0.28), (x1, 0.58, 0.28), "Paint")
        b.rivet_row((x1, 0.14, 0.22), (x1, 0.52, 0.22), (sx, 0, 0), spacing=0.12, size=0.024)
        b.rivet_row((x1, 0.14, -0.22), (x1, 0.52, -0.22), (sx, 0, 0), spacing=0.12, size=0.024)

    # Grille d'aération sur le dessus du carter moteur
    b.box((-0.26, 0.10, 0.38), (0.26, 0.46, 0.415), "Iron")
    # Projecteur de forage sur le haut du mandrin
    b.box((-0.11, 0.50, 0.38), (0.11, 0.66, 0.54), "IronDark")
    b.box((-0.08, 0.66, 0.43), (0.08, 0.675, 0.51), "Lamp")

    # 3. Grande couronne avant en cuivre rivetée (y = 0.68 .. 0.78) qui porte la mèche rotative
    b.box((-0.415, 0.68, -0.415), (0.415, 0.78, 0.415), "Copper")
    b.rivet_row((-0.32, 0.78, 0.34), (0.32, 0.78, 0.34), (0, 1, 0), spacing=0.16, size=0.026, mat_name="IronDark")
    b.rivet_row((-0.32, 0.78, -0.34), (0.32, 0.78, -0.34), (0, 1, 0), spacing=0.16, size=0.026, mat_name="IronDark")

    b.finish()
    kit.save_and_export("drill_slider", budget_tris=1000, ground=False)


main()
