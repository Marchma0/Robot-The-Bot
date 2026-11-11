"""Carte de la région épinglée sur un panneau de liège, au mur droit de la tête (au-dessus de l'armoire).

Fiche
- Taille : 0,85 m de large, 0,60 m de haut, 3 cm de saillie avec les punaises.
- Origine : sur le mur, au centre ; l'avant regarde vers +Y (l'arrière est contre le mur, en y = 0).
  Placée en Godot (2.2, 7.05, -0.57), tournée vers la gauche du mécha (vers la pièce).
- Budget : 900 triangles.
- Pièces : panneau (Wood) et cadre (Copper), carte (Paper) avec forêts (Plant), lac (Glass), montagnes (Ochre),
  canyon (Terracotta), itinéraire en pointillés (DartRed), punaises, petite note (Yellow).

    blender -b --factory-startup --python blender/props/wall_map.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HW, HH = 0.425, 0.30


def main():
    kit.new_scene()
    b = kit.Builder("WallMap")
    b.box((-HW + 0.01, 0.002, -HH + 0.01), (HW - 0.01, 0.015, HH - 0.01), "Wood")
    for z0, z1 in ((HH - 0.02, HH), (-HH, -HH + 0.02)):
        b.box((-HW, 0.0, z0), (HW, 0.02, z1), "Copper")
    for x0, x1 in ((-HW, -HW + 0.02), (HW - 0.02, HW)):
        b.box((x0, 0.0, -HH + 0.02), (x1, 0.02, HH - 0.02), "Copper")
    f = 0.017
    b.box((-0.36, 0.015, -0.24), (0.32, f, 0.24), "Paper")
    # terrains (2 mm au-dessus du papier)
    for x0, z0, x1, z1 in ((-0.33, 0.06, -0.15, 0.2), (-0.12, 0.12, -0.02, 0.21), (0.14, -0.2, 0.28, -0.08)):
        b.box((x0, f, z0), (x1, f + 0.002, z1), "Plant")
    b.box((0.02, f, 0.02), (0.15, f + 0.002, 0.11), "Glass")
    for x, h in ((-0.29, 0.09), (-0.235, 0.12), (-0.18, 0.08)):
        # montagne : triangle pointe en haut, 2 mm d'épaisseur
        b.frustum((x, f + 0.001), -0.2, -0.2 + h, (0.035, 0.001), (0.002, 0.001), "Ochre")
    b.box((-0.1, f, -0.22), (0.05, f + 0.002, -0.14), "Terracotta")
    # itinéraire en pointillés
    route = [(-0.3, 0.0), (-0.2, -0.04), (-0.1, -0.06), (0.0, -0.05), (0.08, -0.02), (0.18, 0.04), (0.24, 0.13)]
    for x, z in route:
        b.box((x - 0.02, f + 0.002, z - 0.006), (x + 0.02, f + 0.004, z + 0.006), "DartRed")
    # punaises aux étapes
    for x, z in (route[0], route[3], route[-1]):
        b.cylinder((x, f + 0.004, z + 0.02), (x, f + 0.02, z + 0.02), 0.003, "Iron", 4)
        b.sphere((x, f + 0.022, z + 0.02), 0.012, "DartRed", 6)
    # petite note jaune épinglée
    b.box((0.18, f, 0.14), (0.3, f + 0.003, 0.23), "Yellow")
    b.sphere((0.24, f + 0.01, 0.22), 0.01, "Velvet", 6)
    b.finish()
    kit.save_and_export("wall_map", budget_tris=900, ground=False)


main()
