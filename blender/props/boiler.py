"""Chauffe-eau étroit (tête du mécha, mur du fond) relié au tuyau en fer du plafond.

Fiche
- Taille : cuve de 0,31 m de diamètre, 1,35 m de haut ; tuyau jusqu'au plafond (2,5 m au-dessus du sol de la tête).
- Origine : au sol, au centre de la cuve ; l'avant (manomètre) regarde vers +Y.
  Placé en Blender (1.11, -1.72, 5.6) = Godot (1.11, 5.6, 1.72), sans rotation.
- Budget : 1800 triangles.
- Pièces : 3 pieds, cuve (Paint) avec cerclages en cuivre et dôme, manomètre, tuyau de sortie vers le plafond
  avec vanne rouge, tuyau d'arrivée qui rentre dans le mur.
- Collision : scenes/mecha/props/boiler.tscn (cylindre).

    blender -b --factory-startup --python blender/props/boiler.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

R = 0.155
Z0, Z1 = 0.12, 1.30
CEILING_PIPE = (-0.12, 2.53)   # tuyau en fer du plafond : y local, z local (rayon 0,035)


def main():
    kit.new_scene()
    b = kit.Builder("Boiler")
    # pieds
    for angle_x, angle_y in ((0.0, 1.0), (0.87, -0.5), (-0.87, -0.5)):
        x, y = angle_x * R * 0.7, angle_y * R * 0.7
        b.cylinder((x, y, 0.0), (x, y, Z0 + 0.02), 0.018, "IronDark", segments=6)
    b.cylinder((0, 0, Z0 - 0.02), (0, 0, Z0), R * 0.95, "IronDark", segments=14)
    # cuve, cerclages, dôme
    b.cylinder((0, 0, Z0), (0, 0, Z1), R, "Paint", segments=16)
    for z in (Z0 + 0.06, (Z0 + Z1) / 2, Z1 - 0.06):
        b.cylinder((0, 0, z - 0.015), (0, 0, z + 0.015), R + 0.008, "Copper", segments=16)
    b.cylinder((0, 0, Z1), (0, 0, Z1 + 0.06), R, "Paint", segments=16, radius_end=R * 0.55)
    b.cylinder((0, 0, Z1 + 0.06), (0, 0, Z1 + 0.09), R * 0.55, "Copper", segments=12)
    # manomètre à l'avant
    b.cylinder((0, R - 0.01, 0.95), (0, R + 0.04, 0.95), 0.012, "Copper", segments=6)
    b.cylinder((0, R + 0.04, 0.95), (0, R + 0.065, 0.95), 0.05, "IronDark", segments=14)
    b.cylinder((0, R + 0.065, 0.95), (0, R + 0.07, 0.95), 0.042, "Paper", segments=14)
    b.box((-0.003, R + 0.07, 0.95), (0.003, R + 0.073, 0.985), "ButtonRed")                 # aiguille
    # sortie vers le plafond, avec une vanne
    y_pipe, z_pipe = CEILING_PIPE
    top = Z1 + 0.09
    b.pipe([(0, 0, top), (0, 0, 1.75), (0, y_pipe, 1.75), (0, y_pipe, z_pipe - 0.03)], 0.025, "Copper", "IronDark")
    b.cylinder((0, 0, 1.55), (0.07, 0, 1.55), 0.008, "IronDark", segments=6)
    b.cylinder((0.07, 0, 1.55), (0.085, 0, 1.55), 0.06, "ButtonRed", segments=12)          # volant de vanne
    b.cylinder((0, y_pipe, z_pipe - 0.07), (0, y_pipe, z_pipe - 0.03), 0.045, "IronDark", segments=10)  # raccord
    # arrivée d'eau qui rentre dans le mur du fond
    b.pipe([(R - 0.02, 0, 0.35), (R + 0.06, 0, 0.35), (R + 0.06, -0.17, 0.35)], 0.02, "Iron", "IronDark")
    b.finish()
    kit.save_and_export("boiler", budget_tris=1800)


main()
