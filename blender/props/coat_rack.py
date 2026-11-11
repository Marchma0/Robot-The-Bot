"""Patère murale avec deux casques de mineur et une lanterne (ventre du mécha, mur gauche).

Fiche
- Taille : planche de 0,60 m x 0,12 m ; casques de 0,24 m de diamètre accrochés dessous (0,40 m de haut en tout),
  0,22 m de saillie.
- Origine : sur le mur, au centre de la planche ; l'avant regarde vers +Y (l'arrière est contre le mur, en y = 0).
  Placée en Godot (-2.2, 4.25, 0.4), tournée vers la droite du mécha (vers la pièce).
- Budget : 1800 triangles.
- Pièces : planche (Wood), 4 crochets (Copper), 2 casques (Yellow) avec visière (IronDark) et lampe (Lamp),
  une lanterne (Copper, Bulb) au dernier crochet.

    blender -b --factory-startup --python blender/props/coat_rack.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HW, HH, D = 0.30, 0.06, 0.025
HOOKS = (-0.21, -0.07, 0.07, 0.21)


def helmet(b, x, top):
    """Casque de mineur suspendu à un crochet par sa jugulaire : dôme en 3 tronçons, bord, crête, lampe frontale.
    `top` : hauteur du sommet du dôme. Le casque est à y = 0.135 du mur (son bord ne touche pas le mur)."""
    y = 0.135
    base = top - 0.11
    b.cylinder((x, y, base - 0.012), (x, y, base), 0.125, "IronDark", 12)                       # bord
    b.cylinder((x, y, base), (x, y, base + 0.05), 0.1, "Yellow", 12, radius_end=0.088)
    b.cylinder((x, y, base + 0.05), (x, y, base + 0.09), 0.088, "Yellow", 12, radius_end=0.055)
    b.cylinder((x, y, base + 0.09), (x, y, top), 0.055, "Yellow", 12, radius_end=0.0)
    b.box((x - 0.012, y - 0.07, base + 0.04), (x + 0.012, y + 0.07, top - 0.006), "IronDark")    # crête
    # lampe frontale (vers la pièce)
    b.cylinder((x, y + 0.085, base + 0.045), (x, y + 0.115, base + 0.045), 0.03, "Copper", 8)
    b.cylinder((x, y + 0.115, base + 0.045), (x, y + 0.12, base + 0.045), 0.022, "Lamp", 8)
    # jugulaire : du crochet au bord du casque
    b.cylinder((x, D + 0.1, 0.03), (x, y - 0.04, base - 0.004), 0.004, "Ochre", 4)


def main():
    kit.new_scene()
    b = kit.Builder("CoatRack")
    b.box((-HW, 0.0, -HH), (HW, D, HH), "Wood")
    for x in (-HW + 0.03, HW - 0.03):
        b.box((x - 0.008, D, -0.008), (x + 0.008, D + 0.006, 0.008), "Copper")       # vis
    for x in HOOKS:
        b.cylinder((x, D, -0.01), (x, D + 0.09, -0.01), 0.008, "Copper", 6)
        b.cylinder((x, D + 0.09, -0.01), (x, D + 0.1, 0.03), 0.008, "Copper", 6)
        b.sphere((x, D + 0.1, 0.035), 0.012, "Copper", 6)
    helmet(b, HOOKS[0], -0.07)
    helmet(b, HOOKS[2], -0.09)
    # lanterne au dernier crochet
    x = HOOKS[3]
    b.box((x - 0.004, D + 0.085, -0.13), (x + 0.004, D + 0.095, -0.01), "Copper")    # anse
    b.cylinder((x, D + 0.09, -0.15), (x, D + 0.09, -0.13), 0.05, "Copper", 8)
    b.cylinder((x, D + 0.09, -0.27), (x, D + 0.09, -0.15), 0.04, "Bulb", 8)
    b.cylinder((x, D + 0.09, -0.29), (x, D + 0.09, -0.27), 0.05, "Copper", 8)
    b.finish()
    kit.save_and_export("coat_rack", budget_tris=1800, ground=False)


main()
