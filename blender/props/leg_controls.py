"""Habillage du plateau d'une console des jambes, façon manette : corps de manette, socle rond du joystick,
croix directionnelle, cadran rond de la jauge d'erreur et petit écran du QTE (style « Just Dance »).

Fiche
- Taille : 0,74 m x 0,52 m, posé sur le plateau incliné de la console ; l'écran monte à 0,19 m du plateau.
- Origine : centre du plateau, à sa surface (même repère que le nœud LegDashboard : Blender +Y = s'éloigne
  du pilote, +Z = perpendiculaire au plateau). Placé sans transform comme enfant de
  scenes/mecha/controls/leg_dashboard.tscn (une copie par console).
- Budget : 3000 triangles.
- Pièces (repère Blender) :
  - corps de manette (IronDark) avec ses deux poignées vers le pilote, deux petits boutons « start / select » ;
  - joystick en (-0.22, -0.03) : socle rond, bague en cuivre, cuvette, soufflet en dôme (pivot à 0,05 m) ;
  - croix en (0.22, 0) : socle rond + croix creuse sous les 4 pads (pads à 0,075 m du centre, posés à 0,035 m) ;
  - cadran en (-0.04, 0.1), au centre du plateau (pas caché par l'écran) : boîtier rond, fond crème, bague en cuivre (l'arc de couleur et l'aiguille sont
    dessinés par leg_dashboard.gd, à 0,0215 et 0,026 m) ;
  - voyant « à toi » (marche) en (-0.22, 0.19) : posé par leg_dashboard.tscn ;
  - écran du QTE derrière la croix, centre (0.22, 0.22, 0.09), incliné de 50° vers le pilote ; la dalle
    (quad 0,24 x 0,135 m de leg_dashboard.tscn) est 1,5 mm devant la face du boîtier. Liserés néon (Neon).

    blender -b --factory-startup --python blender/props/leg_controls.py
"""

import math
import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

JOY = (-0.22, -0.03)
JOY_PIVOT_Z = 0.05
DPAD = (0.22, 0.0)
DIAL = (-0.04, 0.1)
SCREEN_C = Vector((0.22, 0.22, 0.09))
SCREEN_TILT = math.radians(-50.0)
SCREEN_W, SCREEN_H = 0.24, 0.135
HOUSING = (0.3, 0.03, 0.19)


def ring(b, center, radius, z, tube, mat, segments=16):
    """Anneau (bague) fait de petits cylindres."""
    cx, cy = center
    for k in range(segments):
        a0, a1 = k * math.tau / segments, (k + 1) * math.tau / segments
        p0 = (cx + math.cos(a0) * radius, cy + math.sin(a0) * radius, z)
        p1 = (cx + math.cos(a1) * radius, cy + math.sin(a1) * radius, z)
        b.cylinder(p0, p1, tube, mat, 6)


def gamepad_outline():
    """Contour du corps de manette (x, y), poignées vers le pilote (-Y)."""
    right = [(0.3, 0.13), (0.35, 0.11), (0.375, 0.06), (0.38, -0.06), (0.37, -0.14), (0.34, -0.19),
             (0.29, -0.215), (0.23, -0.21), (0.19, -0.18), (0.15, -0.13), (0.1, -0.1)]
    left = [(-x, y) for x, y in reversed(right)]
    return right + left


def cross_outline(arm_half_w, arm_len):
    w, l = arm_half_w, arm_len
    return [(w, w), (w, l), (-w, l), (-w, w), (-l, w), (-l, -w), (-w, -w), (-w, -l), (w, -l), (w, -w),
            (l, -w), (l, w)][::-1]


def main():
    kit.new_scene()
    b = kit.Builder("LegControls")
    # corps de manette, un peu enfoncé dans le plateau (pas de faces dans le plan du plateau)
    b.extrude(gamepad_outline(), -0.004, 0.012, "IronDark")
    for sx in (-1, 1):   # petits boutons start / select
        b.cylinder((sx * 0.05, -0.06, 0.012), (sx * 0.05, -0.06, 0.018), 0.012, "Iron", segments=8)

    # joystick : socle rond, bague en cuivre, cuvette noire, soufflet en dôme qui cache le pied du manche
    jx, jy = JOY
    b.cylinder((jx, jy, 0.0), (jx, jy, 0.022), 0.105, "Patch", segments=20)
    ring(b, JOY, 0.102, 0.022, 0.007, "Copper", segments=20)
    b.cylinder((jx, jy, 0.02), (jx, jy, 0.03), 0.085, "DartBlack", segments=20)
    b.sphere((jx, jy, JOY_PIVOT_Z), 0.064, "DartBlack", segments=14)
    for k in range(4):   # vis du socle
        a = math.pi / 4 + k * math.pi / 2
        x, y = jx + math.cos(a) * 0.093, jy + math.sin(a) * 0.093
        b.cylinder((x, y, 0.022), (x, y, 0.026), 0.006, "Iron", segments=6)

    # croix : socle rond + croix creuse sous les pads (les pads eux-mêmes sont des PushButton en flèche)
    dx, dy = DPAD
    b.cylinder((dx, dy, -0.002), (dx, dy, 0.016), 0.13, "Patch", segments=20)
    ring(b, DPAD, 0.127, 0.016, 0.006, "Copper", segments=20)
    b.extrude([(dx + x, dy + y) for x, y in cross_outline(0.032, 0.118)], 0.01, 0.033, "DartBlack")
    b.cylinder((dx, dy, 0.033), (dx, dy, 0.037), 0.022, "IronDark", segments=10)   # pivot au centre de la croix

    # cadran rond de la jauge d'erreur
    cx, cy = DIAL
    b.cylinder((cx, cy, -0.006), (cx, cy, 0.018), 0.1, "IronDark", segments=24)
    b.cylinder((cx, cy, 0.018), (cx, cy, 0.0195), 0.088, "Cream", segments=24)
    ring(b, DIAL, 0.094, 0.021, 0.008, "Copper", segments=24)
    for k in range(3):
        a = math.pi / 2 + k * math.tau / 3
        x, y = cx + math.cos(a) * 0.094, cy + math.sin(a) * 0.094
        b.sphere((x, y, 0.03), 0.006, "Iron", segments=6)

    # socle du voyant « à toi » (le voyant est dans leg_dashboard.tscn)
    b.cylinder((-0.22, 0.19, -0.003), (-0.22, 0.19, 0.008), 0.045, "Patch", segments=12)

    # écran du QTE : boîtier incliné, liserés néon, pied et petite antenne
    rot = Matrix.Rotation(SCREEN_TILT, 4, "X")
    hx, hy, hz = HOUSING

    def tilted(local, size, mat):
        b.tilted_box(SCREEN_C + (rot @ Vector(local)), size, SCREEN_TILT, mat)

    tilted((0, 0, 0), HOUSING, "IronDark")
    front = -hy / 2 - 0.002
    bx, bz = SCREEN_W / 2 + 0.012, SCREEN_H / 2 + 0.012
    tilted((0, front, bz), (2 * bx + 0.008, 0.004, 0.006), "Neon")
    tilted((0, front, -bz), (2 * bx + 0.008, 0.004, 0.006), "Neon")
    tilted((bx, front, 0), (0.006, 0.004, 2 * bz - 0.006), "Copper")
    tilted((-bx, front, 0), (0.006, 0.004, 2 * bz - 0.006), "Copper")
    tilted((0, 0, hz / 2 + 0.006), (hx - 0.03, hy - 0.008, 0.012), "Patch")          # visière
    # pied : de la face arrière jusqu'au plateau
    back = SCREEN_C + rot @ Vector((0, hy / 2, 0))
    b.box((SCREEN_C.x - 0.07, back.y - 0.02, -0.004), (SCREEN_C.x + 0.07, back.y + 0.02, back.z), "Iron")
    b.box((SCREEN_C.x - 0.09, back.y - 0.045, -0.006), (SCREEN_C.x + 0.09, back.y + 0.035, 0.01), "IronDark")
    # antenne avec boule néon
    top = SCREEN_C + rot @ Vector((hx / 2 - 0.03, 0.0, hz / 2 + 0.012))
    b.cylinder(top, top + Vector((0, 0.02, 0.07)), 0.003, "Iron", segments=5)
    b.sphere(top + Vector((0, 0.02, 0.075)), 0.009, "Neon", segments=8)
    b.finish()
    kit.save_and_export("leg_controls", budget_tris=3000)


main()
