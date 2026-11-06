"""Chauffe-eau étroit (tête du mécha, mur gauche) dont le tuyau monte dans le plafond.

Fiche
- Taille : cuve de 0,31 m de diamètre, 1,35 m de haut ; tuyau jusqu'au plafond (2,7 m au-dessus du sol de la tête).
- Origine : au sol, au centre de la cuve ; l'avant (manomètre) regarde vers +Y.
  Placé contre le mur gauche, entre le meuble bas et le pot de l'angle, tourné de -90° (manomètre vers la pièce) :
  Blender (-1.975, 0.85, 5.6) = Godot (-1.975, 5.6, -0.85). Hors du passage à la sortie du rayon tracteur.
  Le tuyau se décale de 0,2 m (vers l'arrière du mécha) pour éviter la poutre du plafond.
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
CEILING = 2.70           # hauteur du plafond de la tête au-dessus de son sol
PIPE_SHIFT = 0.20        # décalage du tuyau (x local) pour passer à côté de la poutre


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
    top = Z1 + 0.09
    b.pipe([(0, 0, top), (0, 0, 1.75), (PIPE_SHIFT, 0, 1.75), (PIPE_SHIFT, 0, CEILING)], 0.025, "Copper", "IronDark")
    b.cylinder((0, 0, 1.55), (0, 0.07, 1.55), 0.008, "IronDark", segments=6)
    b.cylinder((0, 0.07, 1.55), (0, 0.085, 1.55), 0.06, "ButtonRed", segments=12)          # volant de vanne
    b.cylinder((PIPE_SHIFT, 0, CEILING - 0.03), (PIPE_SHIFT, 0, CEILING), 0.06, "IronDark", segments=12)  # collerette
    # arrivée d'eau qui rentre dans le mur
    b.pipe([(R - 0.02, 0, 0.35), (R + 0.06, 0, 0.35), (R + 0.06, -0.17, 0.35)], 0.02, "Iron", "IronDark")
    b.finish()
    kit.save_and_export("boiler", budget_tris=1800)


main()
