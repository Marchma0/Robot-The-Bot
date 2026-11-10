"""Vestiaire des nains (4.5 / 2.4) : casiers d'atelier, miroir éclairé et pupitre de choix de skin.

Fiche
- Taille : 1,5 m de large (X), 0,8 m de profondeur (Y), hauteur 1,95 m. Pupitre à 0,60 m.
- Origine : au sol, au centre. Le joueur se tient côté +Y (face au miroir et aux boutons).
- Budget : 2200 triangles.
- Pièces : socle (IronDark), 2 casiers latéraux de garagiste (Paint, Iron), miroir central encadré de cuivre
  et d'ampoules de loge (Glass, Copper, Bulb), pupitre avant avec 3 boutons (skin précédent, skin suivant,
  couleur / accessoire), étagère supérieure avec casques exposés (Yellow, Copper, IronDark).

    blender -b --factory-startup --python blender/props/dwarf_wardrobe.py
"""

import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HX, HY = 0.75, 0.38
DESK_TILT = math.radians(-14.0)
DESK_CENTER = Vector((0.0, 0.22, 0.58))
DESK_SIZE = (0.92, 0.30, 0.05)
BUTTONS = {"prev": 0.28, "next": 0.0, "color": -0.28}


def desk_matrix() -> Matrix:
    return Matrix.Translation(DESK_CENTER) @ Matrix.Rotation(DESK_TILT, 4, "X")


def desk_point(x: float, height: float = 0.0) -> Vector:
    return desk_matrix() @ Vector((x, 0.0, DESK_SIZE[2] / 2 + height))


def desk_normal() -> Vector:
    return (Matrix.Rotation(DESK_TILT, 4, "X") @ Vector((0, 0, 1, 0))).to_3d()


def main():
    kit.new_scene()
    b = kit.Builder("DwarfWardrobe")

    # Socle bas
    b.box((-HX, -HY, 0.0), (HX, HY, 0.08), "IronDark")

    # Deux colonnes de casiers à gauche et à droite (x: -0.74..-0.44 et 0.44..0.74)
    for sx in (-1.0, 1.0):
        x0, x1 = (sx * 0.44, sx * 0.73) if sx > 0 else (-0.73, -0.44)
        b.box((x0, -HY + 0.02, 0.08), (x1, HY - 0.08, 1.82), "Paint")
        b.box((x0 + 0.03, HY - 0.08, 0.16), (x1 - 0.03, HY - 0.06, 0.90), "WallTeal")
        b.box((x0 + 0.03, HY - 0.08, 0.98), (x1 - 0.03, HY - 0.06, 1.72), "WallTeal")
        # Poignées en cuivre
        hx = x0 + 0.06 if sx > 0 else x1 - 0.06
        b.box((hx - 0.015, HY - 0.055, 0.48), (hx + 0.015, HY - 0.03, 0.60), "Copper")
        b.box((hx - 0.015, HY - 0.055, 1.28), (hx + 0.015, HY - 0.03, 1.40), "Copper")

    # Fond central + console basse sous le miroir
    b.box((-0.44, -HY + 0.02, 0.08), (0.44, HY - 0.04, 0.54), "IronDark")
    b.box((-0.44, -HY + 0.02, 0.54), (0.44, -0.08, 1.82), "IronDark")

    # Miroir éclairé au centre (x: -0.36..0.36, z: 0.76..1.66)
    b.box((-0.38, -0.07, 0.74), (0.38, -0.03, 1.68), "Copper")
    b.box((-0.33, -0.025, 0.79), (0.33, -0.01, 1.63), "Glass")
    # Ampoules chaudes autour du miroir
    for lz in (0.86, 1.12, 1.38, 1.58):
        for sx in (-0.355, 0.355):
            b.sphere((sx, -0.01, lz), 0.028, "Bulb", segments=6)

    # Bandeau supérieur avec enseigne lumineuse et 3 petits casques exposés au sommet
    b.box((-HX, -HY + 0.01, 1.82), (HX, HY - 0.04, 1.92), "IronDark")
    b.box((-0.42, HY - 0.038, 1.835), (0.42, HY - 0.01, 1.905), "Bulb")
    # 3 dômes de casques décoratifs sur le toit (Mineur jaune, Soudeur fer, Baron cuivre)
    b.sphere((-0.45, 0.0, 1.96), 0.11, "Yellow", segments=8)
    b.box((0.0 - 0.10, -0.10, 1.92), (0.0 + 0.10, 0.10, 2.10), "Iron")
    b.cylinder((0.45, 0.0, 1.92), (0.45, 0.0, 2.14), 0.10, "Copper", segments=8)

    # Pupitre avant incliné avec 3 boutons
    b.tilted_box(DESK_CENTER, DESK_SIZE, DESK_TILT, "Iron")
    nrm = desk_normal()
    for key, x in BUTTONS.items():
        p = desk_point(x)
        b.cylinder(p - nrm * 0.004, p + nrm * 0.012, 0.055, "Copper" if key != "color" else "Yellow", segments=10)

    b.finish()
    kit.save_and_export("dwarf_wardrobe", budget_tris=2200)
    for key, x in BUTTONS.items():
        p = desk_point(x, height=0.012)
        print("wardrobe : bouton %s -> Godot (%.4f, %.4f, %.4f)" % (key, p.x, p.z, -p.y))


main()
