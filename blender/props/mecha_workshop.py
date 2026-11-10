"""Poste d'atelier du robot (4.5 / 3.8) : console de personnalisation du robot (skins + bras) et râtelier.

Fiche
- Taille : console de 1,5 m de large (X), 0,85 m de profondeur (Y), pupitre à 0,62 m, écran à 0,98 m,
  portique arrière à 1,85 m avec potence et pots de peinture. Repère : un nain fait 1,2 m.
- Origine : au sol, au centre de la console. Le joueur se tient côté +Y (face à lui).
- Budget : 2200 triangles.
- Pièces : socle lourd (IronDark), caisson d'atelier (Paint, Copper), pupitre incliné (Iron) à 4 boutons
  (skin précédent, skin suivant, changer bras gauche, changer bras droit), écran large (IronDark, Copper),
  portique arrière avec 3 bidons de peinture colorés (Paint, DartRed, Yellow) et pince/foreuse miniatures.

    blender -b --factory-startup --python blender/props/mecha_workshop.py
"""

import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HX, HY, BODY_TOP = 0.72, 0.38, 0.56
DESK_TILT = math.radians(-14.0)
DESK_CENTER = Vector((0.0, 0.20, 0.60))
DESK_SIZE = (1.36, 0.36, 0.05)
# 4 boutons sur le pupitre (x le long du pupitre) :
# De gauche à droite pour le joueur (qui est en +Y et regarde vers -Y, donc sa gauche est +X) :
# skin_prev (+0.48), skin_next (+0.20), arm_mode (-0.18), paint_fx (-0.48)
BUTTONS = {"skin_prev": 0.46, "skin_next": 0.18, "arm_prev": -0.18, "arm_next": -0.46}
SCREEN_CENTER = Vector((0.0, -0.06, 0.98))
SCREEN_TILT = math.radians(16.0)
SCREEN_W, SCREEN_H = 0.78, 0.42


def desk_matrix() -> Matrix:
    return Matrix.Translation(DESK_CENTER) @ Matrix.Rotation(DESK_TILT, 4, "X")


def desk_point(x: float, along: float = 0.0, height: float = 0.0) -> Vector:
    return desk_matrix() @ Vector((x, -along, DESK_SIZE[2] / 2 + height))


def desk_normal() -> Vector:
    return (Matrix.Rotation(DESK_TILT, 4, "X") @ Vector((0, 0, 1, 0))).to_3d()


def main():
    kit.new_scene()
    b = kit.Builder("MechaWorkshop")

    # Socle et caisson principal
    b.box((-HX, -HY, 0.0), (HX, HY, 0.06), "IronDark")
    b.box((-HX + 0.03, -HY + 0.03, 0.06), (HX - 0.03, HY - 0.03, BODY_TOP), "Paint")
    b.box((-HX + 0.02, HY - 0.04, 0.10), (HX - 0.02, HY - 0.015, 0.18), "Copper")
    b.rivet_row((-HX + 0.08, HY - 0.03, 0.48), (HX - 0.08, HY - 0.03, 0.48), (0, 1, 0), spacing=0.14, size=0.018)

    # Pupitre incliné et embases des 4 boutons
    b.tilted_box(DESK_CENTER, DESK_SIZE, DESK_TILT, "Iron")
    nrm = desk_normal()
    for key, x in BUTTONS.items():
        p = desk_point(x)
        mat = "Copper" if "skin" in key else "Yellow"
        b.cylinder(p - nrm * 0.004, p + nrm * 0.012, 0.06, mat, segments=10)

    # Boîtier d'écran large et cadre en cuivre
    sn = Vector((0.0, math.cos(SCREEN_TILT), math.sin(SCREEN_TILT)))
    su = Vector((0.0, -math.sin(SCREEN_TILT), math.cos(SCREEN_TILT)))
    back = 0.18
    b.tilted_box(SCREEN_CENTER - sn * (back / 2 + 0.004), (SCREEN_W + 0.14, back, SCREEN_H + 0.14),
                 SCREEN_TILT, "IronDark")

    def bar(dx: float, du: float, w: float, h: float) -> None:
        c = SCREEN_CENTER + Vector((dx, 0, 0)) + su * du + sn * 0.008
        b.tilted_box(c, (w, 0.026, h), SCREEN_TILT, "Copper")

    bar(0.0, SCREEN_H / 2 + 0.03, SCREEN_W + 0.12, 0.06)
    bar(0.0, -SCREEN_H / 2 - 0.03, SCREEN_W + 0.12, 0.06)
    bar(-SCREEN_W / 2 - 0.03, 0.0, 0.06, SCREEN_H)
    bar(SCREEN_W / 2 + 0.03, 0.0, 0.06, SCREEN_H)

    # Pieds de l'écran
    for sx in (-0.26, 0.26):
        b.box((sx - 0.06, -0.22, BODY_TOP), (sx + 0.06, 0.0, 0.74), "IronDark")

    # Portique d'atelier à l'arrière avec 3 pots de peinture et outils
    for sx in (-1.0, 1.0):
        px = sx * (HX - 0.08)
        b.box((px - 0.05, -HY + 0.04, BODY_TOP), (px + 0.05, -HY + 0.14, 1.78), "IronDark")
    b.box((-HX + 0.02, -HY + 0.02, 1.78), (HX - 0.02, -HY + 0.18, 1.88), "Yellow")
    b.box((-0.45, -HY + 0.19, 1.79), (0.45, -HY + 0.24, 1.87), "Bulb")

    # Étagère arrière avec 3 bidons de peinture (Teal, Rouge, Or/Cuivre)
    b.box((-HX + 0.14, -HY - 0.18, 0.35), (HX - 0.14, -HY + 0.02, 0.42), "Wood")
    for bx, mat in ((-0.35, "Paint"), (0.0, "DartRed"), (0.35, "Copper")):
        b.cylinder((bx, -HY - 0.08, 0.42), (bx, -HY - 0.08, 0.72), 0.10, mat, segments=10)
        b.cylinder((bx, -HY - 0.08, 0.72), (bx, -HY - 0.08, 0.75), 0.105, "Iron", segments=10)

    b.finish()
    kit.save_and_export("mecha_workshop", budget_tris=2200)
    for key, x in BUTTONS.items():
        p = desk_point(x, height=0.012)
        print("workshop : bouton %s -> Godot (%.4f, %.4f, %.4f)" % (key, p.x, p.z, -p.y))
    s = SCREEN_CENTER + sn * 0.006
    print("workshop : écran -> Godot (%.4f, %.4f, %.4f)" % (s.x, s.z, -s.y))


main()
