"""Guirlande de fanions tendue sous le plafond, au mur avant de la tête (entre les deux yeux).

Fiche
- Taille : 3,60 m de long, 0,25 m de haut (fanions de 0,14 m de large).
- Origine : au centre de la ficelle (aux clous), contre le mur ; l'avant regarde vers +Y (l'arrière est contre le mur).
  Placée en Godot (0.1, 8.07, -1.88), tournée vers l'arrière du mécha (vers la pièce).
- Budget : 1000 triangles.
- Pièces : ficelle (Cream) qui pend en deux arcs, clous (Iron), 18 fanions triangulaires de couleurs alternées.

    blender -b --factory-startup --python blender/props/bunting.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HALF = 1.8
SAG = 0.07          # creux de chaque arc
Y = 0.03            # distance au mur
COLORS = ["DartRed", "Yellow", "Velvet", "Cream", "Paint", "Ochre"]
FLAGS = 18


def string_z(x: float) -> float:
    """Hauteur de la ficelle : deux arcs, clous aux deux bouts et au milieu."""
    u = abs(x) / HALF                      # 0 au clou du milieu, 1 au clou du bout
    return -SAG * 4 * u * (1 - u)


def main():
    kit.new_scene()
    b = kit.Builder("Bunting")
    pts = [(-HALF + i * (2 * HALF) / 24, Y, 0.0) for i in range(25)]
    pts = [(x, y, string_z(x)) for x, y, _ in pts]
    for a, c in zip(pts, pts[1:]):
        b.cylinder(a, c, 0.004, "Cream", 4)
    for x in (-HALF, 0.0, HALF):
        b.box((x - 0.008, 0.0, -0.008), (x + 0.008, Y + 0.01, 0.008), "Iron")
    for i in range(FLAGS):
        x = -HALF + (i + 0.5) * (2 * HALF) / FLAGS
        if abs(x) < 0.09:
            continue   # pas de fanion sur le clou du milieu
        z = string_z(x)
        # fanion : triangle pointe en bas, 2 mm d'épaisseur, suspendu juste sous la ficelle
        b.frustum((x, Y), z - 0.18, z - 0.004, (0.002, 0.001), (0.07, 0.001), COLORS[i % len(COLORS)])
    b.finish()
    kit.save_and_export("bunting", budget_tris=1000, ground=False)


main()
