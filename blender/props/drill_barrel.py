"""Fût externe de la foreuse (M8 — Foreuse) : tourne avec le coude, la glissière coulisse dedans.

Fiche
- Taille : 0,57 m de large (X), 1,72 m de long (Y), 0,58 m de haut (Z). Repère : un nain fait 1,2 m.
- Origine au centre du coude (0, 0, 0) : même repère que drill_arm.py, placé sous DrillArm/ElbowPivot.
  Sorti de drill_arm.py pour que la foreuse puisse s'orienter (lacet + tangage) depuis son poste.
- Budget : 600 triangles.
- Pièces : fût peint (Paint), rails de guidage et frettes rivetées (IronDark), collier de bouche (Copper),
  durite de pression (Copper).

    blender -b --factory-startup --python blender/props/drill_barrel.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402


def main():
    kit.new_scene()
    b = kit.Builder("DrillBarrel")

    # Fût externe (de y = 0.02 à y = 1.62) dans lequel coulisse le fût télescopique
    b.box((-0.24, 0.02, -0.24), (0.24, 1.62, 0.24), "Paint")
    # Rails de guidage latéraux en fer sombre + frettes rivetées
    for sx in (-1, 1):
        rx0 = sx * 0.24
        rx1 = sx * 0.285
        b.box((rx0, 0.10, -0.11), (rx1, 1.68, 0.11), "IronDark")
    for yp in (0.42, 1.02, 1.56):
        b.box((-0.265, yp - 0.05, -0.265), (0.265, yp + 0.05, 0.265), "IronDark")
        b.rivet_row((-0.20, yp, 0.265), (0.20, yp, 0.265), (0, 0, 1), spacing=0.14, size=0.024)
    # Collier de bouche en cuivre à l'avant du fût (y = 1.62 .. 1.72)
    b.box((-0.275, 1.62, -0.275), (0.275, 1.72, 0.275), "Copper")
    # Durite de pression en cuivre sur le dessus du fût
    b.pipe([(0.16, 0.12, 0.275), (0.16, 1.50, 0.275)], 0.032, "Copper", "IronDark", segments=8)

    b.finish()
    kit.save_and_export("drill_barrel", budget_tris=600, ground=False)


main()
