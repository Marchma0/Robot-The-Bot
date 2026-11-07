"""Terminal de mission devant le robot (lobby, M12) : écran + logement du grand levier.

Fiche
- Taille : 1,5 m de large (X), 0,9 m de profondeur (Y), écran jusqu'à 1,6 m, antenne à 2,4 m.
  Repère : un nain fait 1,2 m : l'écran est à hauteur des yeux, le levier à hauteur de main.
- Origine : au sol, au centre. Le joueur se tient côté +Y (le terminal lui fait face).
- Budget : 1600 triangles.
- Pièces : socle (IronDark) et caisson (Paint) à bande de danger (Yellow, DartBlack), pupitre incliné (Iron)
  avec boutons (ButtonRed, ButtonGreen), boîtier d'écran (IronDark) à cadre en cuivre : l'écran est le quad
  `Screen` de mission_terminal.tscn (0,62 x 0,42 m, incliné de 12°, 1,6 cm devant (0, 0.06, 1.28) selon sa normale),
  logement du levier à droite (IronDark, Copper) : le levier est un Lever placé en (0.58, 0.18, 0.95),
  antenne (Iron) avec voyant (Lamp), câbles vers le sol (DartBlack).

    blender -b --factory-startup --python blender/props/mission_terminal.py
"""

import math
import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HX = 0.75


def main():
    kit.new_scene()
    b = kit.Builder("MissionTerminal")
    # socle + caisson
    b.box((-HX, -0.45, 0.0), (HX, 0.45, 0.08), "IronDark")
    b.box((-HX + 0.03, -0.42, 0.08), (HX - 0.03, 0.42, 0.88), "Paint")
    # bande de danger sur la face avant du caisson
    n = 12
    for i in range(n):
        x0 = -HX + 0.03 + (2 * HX - 0.06) * i / n
        x1 = -HX + 0.03 + (2 * HX - 0.06) * (i + 1) / n
        b.box((x0, 0.42, 0.12), (x1, 0.432, 0.24), "Yellow" if i % 2 == 0 else "DartBlack")
    b.rivet_row((-HX + 0.08, 0.42, 0.8), (HX - 0.08, 0.42, 0.8), (0, 1, 0), spacing=0.14, size=0.02)
    # pupitre incliné avec boutons
    b.tilted_box((-0.12, 0.25, 0.9), (1.0, 0.36, 0.06), math.radians(-14.0), "Iron")
    for k, mat in enumerate(("ButtonRed", "ButtonGreen", "ButtonGreen", "Yellow")):
        x = -0.5 + k * 0.17
        b.cylinder((x, 0.3, 0.92), (x, 0.31, 0.965), 0.035, mat, segments=8)
    # boîtier d'écran incliné de 12° vers le joueur (épais, dans le dos de l'écran)
    tilt = math.radians(12.0)
    sc_y, sc_z = 0.06, 1.28
    back = 0.2
    b.tilted_box((0.0, sc_y - back / 2 * math.cos(tilt) - 0.005, sc_z + back / 2 * math.sin(tilt)),
                 (0.82, back, 0.62), tilt, "IronDark")
    # cadre en cuivre autour de l'écran (4 barres, 3 cm devant le boîtier)
    def framed(cx, cz_off, w, h):
        cy = sc_y + 0.012 * math.cos(tilt) - cz_off * math.sin(tilt)
        cz = sc_z + cz_off * math.cos(tilt) + 0.012 * math.sin(tilt)
        b.tilted_box((cx, cy, cz), (w, 0.03, h), tilt, "Copper")
    framed(0.0, 0.25, 0.8, 0.08)
    framed(0.0, -0.25, 0.8, 0.08)
    framed(-0.36, 0.0, 0.08, 0.42)
    framed(0.36, 0.0, 0.08, 0.42)
    # pied de l'écran
    b.box((-0.12, -0.12, 0.88), (0.12, 0.1, 1.0), "IronDark")
    # logement du levier à droite
    b.box((0.48, 0.05, 0.88), (0.7, 0.32, 0.93), "IronDark")
    b.box((0.55, 0.1, 0.93), (0.61, 0.27, 0.935), "DartBlack")
    b.cylinder((0.48, 0.18, 0.9), (0.47, 0.18, 0.9), 0.06, "Copper", segments=8)
    # antenne + voyant
    b.cylinder((-0.6, -0.3, 0.88), (-0.6, -0.3, 2.3), 0.02, "Iron", segments=5)
    b.sphere((-0.6, -0.3, 2.34), 0.06, "Lamp", segments=6)
    for z in (1.4, 1.9):
        b.cylinder((-0.68, -0.3, z), (-0.52, -0.3, z), 0.012, "Copper", segments=4)
    # câbles qui partent dans le sable
    b.pipe([(0.4, -0.42, 0.4), (0.45, -0.7, 0.15), (0.6, -1.2, 0.0)], 0.03, "DartBlack", segments=6)
    b.pipe([(-0.3, -0.42, 0.3), (-0.35, -0.8, 0.08), (-0.6, -1.4, 0.0)], 0.025, "DartBlack", segments=6)
    b.finish()
    kit.save_and_export("mission_terminal", budget_tris=1600)


main()
