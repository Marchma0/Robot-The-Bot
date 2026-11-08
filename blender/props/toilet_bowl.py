"""Toilettes à l'ancienne : cuvette en faïence, abattant en bois levé, réservoir en hauteur à chasse à tirer.

Fiche
- Taille : cuvette 0,40 x 0,48 m au sol, 0,37 m de haut ; réservoir en hauteur (jusqu'à 1,25 m) contre le mur.
- Origine : au sol, au centre de la cuvette ; l'avant (on s'y assoit face à lui) regarde vers +Y,
  le mur est derrière, à y = -0.23.
  Placées par scenes/mecha/props/toilet_bowl.tscn (collision) en Godot (-1.97, 5.6, 1.4),
  tournées vers la droite du mécha (la porte de la cabine).
- Budget : 1600 triangles.
- Pièces : pied et cuvette (Cream), eau (Glass), lunette et abattant ovale à bord adouci (Wood), charnières, tuyau de chasse (Copper),
  réservoir (Cream) sur équerres, chaîne et poignée (Copper, Wood).

    blender -b --factory-startup --python blender/props/toilet_bowl.py
"""

import math
import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402
from mathutils import Matrix  # noqa: E402

WALL = -0.23
SEAT_Z = 0.37


def lid_outline(half_w, half_h):
    """Contour de l'abattant (x, hauteur), centré : bas presque droit aux coins arrondis (charnières),
    haut en demi-ellipse un peu pointue, comme une vraie lunette."""
    pts = []
    r = 0.05
    # coins arrondis du bas, de gauche à droite
    for k in range(4):
        a = math.pi + k * (math.pi / 2) / 3
        pts.append((-half_w + r + math.cos(a) * r * 0.9, -half_h + r + math.sin(a) * r))
    for k in range(4):
        a = 1.5 * math.pi + k * (math.pi / 2) / 3
        pts.append((half_w - r + math.cos(a) * r * 0.9, -half_h + r + math.sin(a) * r))
    # côtés puis haut en ellipse (de droite à gauche), un peu plus étroit en haut
    top_c = -half_h + r + 0.06
    for k in range(13):
        a = k * math.pi / 12
        squeeze = 1.0 - 0.12 * math.sin(a)
        pts.append((math.cos(a) * half_w * squeeze, top_c + math.sin(a) * (half_h - (top_c))))
    return pts


def main():
    kit.new_scene()
    b = kit.Builder("ToiletBowl")
    # pied et cuvette, un peu ovale (deux troncs de cône côte à côte vers l'avant)
    b.cylinder((0, -0.02, 0.0), (0, -0.02, 0.18), 0.12, "Cream", 16, radius_end=0.1)
    b.cylinder((0, 0.02, 0.17), (0, 0.02, SEAT_Z - 0.03), 0.13, "Cream", 16, radius_end=0.19)
    b.cylinder((0, 0.02, SEAT_Z - 0.03), (0, 0.02, SEAT_Z - 0.027), 0.15, "Glass", 16)     # eau, juste sous la lunette
    # lunette : anneau en 16 segments de bois autour du trou
    for k in range(16):
        a0, a1 = k * math.tau / 16, (k + 1) * math.tau / 16
        p0 = (math.cos(a0) * 0.16, 0.02 + math.sin(a0) * 0.16, SEAT_Z - 0.015)
        p1 = (math.cos(a1) * 0.16, 0.02 + math.sin(a1) * 0.16, SEAT_Z - 0.015)
        b.cylinder(p0, p1, 0.022, "Wood", 6)
    # abattant levé contre le réservoir : ovale (large aux charnières, arrondi en haut), bord adouci
    # par une 2e épaisseur un peu plus petite côté cuvette ; charnières
    lid = (Matrix.Translation((0, WALL + 0.07, SEAT_Z + 0.2)) @ Matrix.Rotation(math.radians(12), 4, "X")
           @ Matrix.Rotation(math.radians(90), 4, "X"))
    b.extrude(lid_outline(0.17, 0.2), -0.0045, 0.0125, "Wood", lid)
    b.extrude(lid_outline(0.15, 0.18), -0.0125, -0.0045, "Wood", lid)
    for x in (-0.09, 0.09):
        b.box((x - 0.02, WALL + 0.05, SEAT_Z - 0.03), (x + 0.02, WALL + 0.09, SEAT_Z), "Copper")
    b.box((-0.22, WALL, SEAT_Z - 0.05), (0.12, WALL + 0.07, SEAT_Z - 0.01), "Cream")        # raccord au mur
    # tuyau de chasse jusqu'au réservoir en hauteur
    b.pipe([(-0.19, WALL + 0.04, SEAT_Z - 0.03), (-0.19, WALL + 0.04, 1.03)], 0.022, "Copper", "Copper")
    # réservoir sur équerres
    tz = 1.02
    b.box((-0.2, WALL, tz), (0.2, WALL + 0.17, tz + 0.22), "Cream")
    b.box((-0.21, WALL, tz + 0.22), (0.21, WALL + 0.18, tz + 0.24), "Wood")
    for x in (-0.15, 0.15):
        b.box((x - 0.012, WALL, tz - 0.1), (x + 0.012, WALL + 0.02, tz), "IronDark")
        b.box((x - 0.012, WALL, tz - 0.012), (x + 0.012, WALL + 0.15, tz), "IronDark")
    # chaîne et poignée qui pendent
    b.box((0.17, WALL + 0.16, tz + 0.05), (0.19, WALL + 0.22, tz + 0.07), "Copper")
    for k in range(8):
        z = tz + 0.04 - k * 0.045
        b.box((0.205, WALL + 0.21, z - 0.03), (0.215, WALL + 0.22, z), "Copper")
    b.cylinder((0.21, WALL + 0.215, tz - 0.36), (0.21, WALL + 0.215, tz - 0.44), 0.016, "Wood", 8)
    b.finish()
    kit.save_and_export("toilet_bowl", budget_tris=1600)


main()
