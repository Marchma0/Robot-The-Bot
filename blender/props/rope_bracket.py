"""Potence de la corde de la trappe : platine murale, bras et poulie d'où pend la corde (ventre du mécha).

Fiche
- Taille : 0,62 m de saillie, 0,42 m de haut (platine), 0,24 m de large.
- Origine : sur le mur, à la hauteur du bras ; l'avant (le bras) regarde vers +Y.
  Placée en Godot (-2.2, 4.51, 1.4), tournée vers la droite du mécha. La corde pend sous la poulie
  (à 0,5 m du mur, 0,1 m sous l'origine).
- Budget : 700 triangles.
- Pièces : platine boulonnée (IronDark, vis Copper), bras en caisson avec gousset, poulie (Copper) dans sa chape,
  nœud de corde (Ochre).

    blender -b --factory-startup --python blender/props/rope_bracket.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

PULLEY_Y = 0.5


def main():
    kit.new_scene()
    b = kit.Builder("RopeBracket")
    b.box((-0.12, 0.0, -0.21), (0.12, 0.04, 0.21), "IronDark")
    for x in (-0.08, 0.08):
        for z in (-0.17, 0.17):
            b.cylinder((x, 0.04, z), (x, 0.048, z), 0.012, "Copper", 6)
    b.box((-0.03, 0.04, -0.06), (0.03, 0.62, 0.06), "IronDark")                 # bras
    b.prism_x([(0.04, -0.2), (0.3, -0.06), (0.04, -0.06)], -0.012, 0.012, "IronDark")   # gousset
    # chape et poulie
    for x in (-0.03, 0.022):
        b.box((x, PULLEY_Y - 0.05, -0.16), (x + 0.008, PULLEY_Y + 0.05, -0.06), "IronDark")
    b.cylinder((-0.02, PULLEY_Y, -0.12), (0.02, PULLEY_Y, -0.12), 0.045, "Copper", 12)
    b.cylinder((-0.04, PULLEY_Y, -0.12), (0.04, PULLEY_Y, -0.12), 0.01, "Iron", 6)
    # corde qui passe sur la poulie et nœud
    b.cylinder((0, PULLEY_Y + 0.04, -0.12), (0, PULLEY_Y + 0.04, -0.2), 0.016, "Ochre", 6)
    b.sphere((0, PULLEY_Y + 0.04, -0.21), 0.026, "Ochre", 6)
    b.finish()
    kit.save_and_export("rope_bracket", budget_tris=700, ground=False)


main()
