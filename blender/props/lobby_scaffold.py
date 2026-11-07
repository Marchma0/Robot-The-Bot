"""Échafaudage de mineurs adossé à la falaise (lobby, M12), avec sa petite grue à seau.

Fiche
- Taille : 3,0 m (X) x 2,2 m (Y) x 5,2 m de haut, potence de grue jusqu'à 6,4 m. Repère : un nain fait 1,2 m.
- Origine : au sol, au centre. La falaise est côté -Y, l'échelle et la grue côté +Y.
- Budget : 1800 triangles.
- Pièces : 6 montants et contreventements (Wood), plancher à 2,4 m et à 4,6 m (Wood) avec garde-corps,
  échelle (Wood), potence (Wood) avec poulie (Copper), corde et seau (Iron) rempli de minerai (Ochre, Yellow).
- Décor seulement (pas de collision pour l'instant).

    blender -b --factory-startup --python blender/props/lobby_scaffold.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HX, HY = 1.5, 1.1
FLOORS = (2.4, 4.6)


def main():
    kit.new_scene()
    b = kit.Builder("LobbyScaffold")
    xs = (-HX, 0.0, HX)
    ys = (-HY, HY)
    top = FLOORS[-1] + 0.6
    for x in xs:
        for y in ys:
            b.box((x - 0.06, y - 0.06, 0.0), (x + 0.06, y + 0.06, top), "Wood")
    # contreventements en croix sur les côtés et l'arrière
    for z0, z1 in ((0.2, FLOORS[0]), (FLOORS[0], FLOORS[1])):
        for y in ys:
            b.cylinder((-HX, y, z0), (0.0, y, z1), 0.035, "Wood", segments=5)
            b.cylinder((0.0, y, z0), (HX, y, z1), 0.035, "Wood", segments=5)
        b.cylinder((-HX, -HY, z1), (-HX, HY, z0), 0.035, "Wood", segments=5)
        b.cylinder((HX, -HY, z0), (HX, HY, z1), 0.035, "Wood", segments=5)
    # planchers (planches séparées) + garde-corps
    for z in FLOORS:
        for i in range(7):
            x0 = -HX - 0.1 + i * 0.47
            b.box((x0, -HY - 0.1, z - 0.06), (x0 + 0.44, HY + 0.1, z), "Wood")
        for y in ys:
            b.box((-HX, y - 0.035, z + 0.9), (HX, y + 0.035, z + 0.97), "Wood")
        b.box((HX - 0.035, -HY, z + 0.9), (HX + 0.035, HY, z + 0.97), "Wood")
    # échelle côté +Y, à gauche
    lx, ly = -0.9, HY + 0.25
    for dx in (-0.22, 0.22):
        b.box((lx + dx - 0.03, ly - 0.03, 0.0), (lx + dx + 0.03, ly + 0.03, FLOORS[-1] + 0.9), "Wood")
    k = 0
    while 0.3 + k * 0.35 < FLOORS[-1] + 0.6:
        z = 0.3 + k * 0.35
        b.cylinder((lx - 0.19, ly, z), (lx + 0.19, ly, z), 0.02, "Wood", segments=5)
        k += 1
    # potence de grue au sommet, avec poulie, corde et seau de minerai
    b.box((HX - 0.06, HY - 0.06, top), (HX + 0.06, HY + 0.06, top + 1.2), "Wood")
    b.box((HX - 0.05, HY - 0.05, top + 1.1), (HX + 0.05, HY + 1.6, top + 1.2), "Wood")
    b.cylinder((HX, HY + 0.6, top + 0.6), (HX, HY + 0.05, top + 1.1), 0.03, "Wood", segments=5)
    py = HY + 1.45
    b.cylinder((HX - 0.08, py, top + 1.0), (HX + 0.08, py, top + 1.0), 0.09, "Copper", segments=10)
    b.cylinder((HX, py, top + 0.92), (HX, py, 1.6), 0.012, "Canvas", segments=4)
    b.cylinder((HX, py, 1.15), (HX, py, 1.58), 0.22, "Iron", segments=10, radius_end=0.26)
    b.box((HX - 0.27, py - 0.012, 1.58), (HX + 0.27, py + 0.012, 1.62), "IronDark")
    b.sphere((HX - 0.05, py + 0.04, 1.58), 0.12, "Ochre", segments=6)
    b.sphere((HX + 0.09, py - 0.05, 1.57), 0.09, "Yellow", segments=6)
    b.finish()
    kit.save_and_export("lobby_scaffold", budget_tris=1800)


main()
