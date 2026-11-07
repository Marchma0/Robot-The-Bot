"""Tente de toile du camp minier (lobby, M12).

Fiche
- Taille : 2,8 m de long (X), 2,6 m de large (Y), 1,95 m de haut. Repère : un nain fait 1,2 m.
- Origine : au sol, au centre. Le faîtage suit X, l'entrée (ouverte, sombre) est au bout +X.
- Budget : 700 triangles.
- Pièces : toile (Canvas) en prisme, rabat d'entrée sombre (DartBlack), deux mâts et faîtière (Wood),
  tapis de sol (Rug), haubans (cordes fines) et piquets (Wood), lanterne accrochée à l'entrée (Lamp).

    blender -b --factory-startup --python blender/props/lobby_tent.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

L, HW, H = 1.4, 1.3, 1.95


def main():
    kit.new_scene()
    b = kit.Builder("LobbyTent")
    # tapis de sol qui dépasse un peu devant l'entrée
    b.box((-L + 0.1, -HW + 0.15, 0.0), (L + 0.5, HW - 0.15, 0.02), "Rug")
    # toile : prisme triangulaire le long de X
    b.prism_x([(-HW, 0.021), (HW, 0.021), (0.0, H)], -L, L, "Canvas")
    # entrée : triangle sombre qui dépasse de 2 cm du bout +X
    b.prism_x([(-0.55, 0.03), (0.55, 0.03), (0.0, 1.2)], L, L + 0.02, "DartBlack")
    # mâts aux deux bouts + faîtière qui dépasse
    for x in (-L - 0.06, L + 0.06):
        b.cylinder((x, 0.0, 0.021), (x, 0.0, H + 0.12), 0.035, "Wood", segments=6)   # posé sur le tapis
    b.cylinder((-L - 0.2, 0.0, H + 0.03), (L + 0.2, 0.0, H + 0.03), 0.03, "Wood", segments=6)
    # haubans vers des piquets
    for x in (-L - 0.06, L + 0.06):
        sx = -1.0 if x < 0 else 1.0
        for y in (-0.5, 0.5):
            peg = (x + sx * 0.9, y * 1.6, 0.0)
            b.cylinder((x, 0.0, H + 0.08), peg, 0.008, "Canvas", segments=4)
            b.cylinder(peg, (peg[0], peg[1], 0.18), 0.025, "Wood", segments=5)
    # lanterne au mât d'entrée
    b.box((L + 0.08, -0.04, 1.62), (L + 0.12, 0.04, 1.64), "IronDark")
    b.cylinder((L + 0.2, 0.0, 1.38), (L + 0.2, 0.0, 1.55), 0.06, "Lamp", segments=8)
    b.cylinder((L + 0.2, 0.0, 1.55), (L + 0.2, 0.0, 1.6), 0.075, "IronDark", segments=8, radius_end=0.03)
    b.cylinder((L + 0.12, 0.0, 1.63), (L + 0.2, 0.0, 1.6), 0.008, "IronDark", segments=4)
    b.finish()
    kit.save_and_export("lobby_tent", budget_tris=700)


main()
