"""Consoles de pilotage en tôle : jambes (ventre, x2) et foreuse (tête). Un script, deux modèles.

Fiche
- Taille : 1,00 m (jambes) ou 0,90 m (foreuse) de large, 0,60 m de profondeur, plateau incliné à 20°
  culminant à 0,69 m. Mêmes cotes que les anciennes consoles : les commandes (joystick, pavé, levier,
  bouton) et les petits éléments posés sur le plateau (socles, cadran, voyant) restent exactement en place.
- Origine : au sol, au centre de l'emprise ; le côté pilote regarde vers +Y (le plateau descend vers lui).
  Placées tournées de 180° (le pilote regarde l'avant du mécha) :
    console_leg   : Blender (-1.0, 1.5, 2.6) et (1.0, 1.5, 2.6)  = Godot (∓1.0, 2.6, -1.5)
    console_drill : Blender (1.1, 1.45, 5.6)                      = Godot (1.1, 5.6, -1.45)
- Budget : 1500 triangles chacune.
- Pièces : socle en retrait pour les pieds, caisson à dessus en pente (Paint), montants d'angle (IronDark),
  panneau avant rivé avec grille, trappes latérales vissées, plateau incliné (Paint), barre d'appui en cuivre.
- Collisions : déjà dans mecha.tscn (Hull/LegConsoleL, LegConsoleR, ArmConsoleR).

    blender -b --factory-startup --python blender/props/console.py
"""

import math
import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

D = 0.60                       # profondeur du caisson
TILT = math.radians(20.0)
SLAB_CENTER = (0.05, 0.56)     # (y, z) du centre du plateau
SLAB_DEPTH, SLAB_T = 0.5501, 0.06
SLOPE = math.tan(TILT)
KICK = 0.08                    # retrait pour les pieds, côté pilote


def slab_bottom_z(y):
    """Hauteur du dessous du plateau au-dessus de la position y (repère local)."""
    cy, cz = SLAB_CENTER
    by = cy - math.sin(TILT) * SLAB_T / 2
    bz = cz - math.cos(TILT) * SLAB_T / 2
    return bz - (y - by) * SLOPE


def build(name, width):
    kit.new_scene()
    b = kit.Builder(name)
    hw = width / 2
    y_front, y_back = D / 2, -D / 2
    # socle sombre, en retrait côté pilote
    b.box((-hw + 0.02, y_back + 0.02, 0.0), (hw - 0.02, y_front - KICK, 0.09), "IronDark")
    # caisson à dessus en pente (suit le dessous du plateau, 3 mm plus bas)
    top_front = slab_bottom_z(y_front) - 0.003
    top_back = slab_bottom_z(y_back) - 0.003
    b.prism_x([(y_front, 0.09), (y_front, top_front), (y_back, top_back), (y_back, 0.09)], -hw, hw, "Paint")
    # montants d'angle
    for sx in (-1, 1):
        x0, x1 = sorted((sx * hw, sx * (hw - 0.035)))
        for (y0, y1, ztop) in ((y_front - 0.035, y_front + 0.004, top_front), (y_back - 0.004, y_back + 0.035, top_back)):
            b.box((x0 - 0.004 * (sx < 0), y0, 0.09), (x1 + 0.004 * (sx > 0), y1, ztop), "IronDark")
    # panneau avant (côté pilote) : plaque rivée + grille d'aération
    fy = y_front + 0.004
    b.box((-hw + 0.08, y_front, 0.14), (hw - 0.08, fy, top_front - 0.05), "Patch")
    for z in (0.17, top_front - 0.08):
        b.rivet_row((-hw + 0.11, fy, z), (hw - 0.11, fy, z), (0, 1, 0), spacing=0.1, size=0.014)
    for i in range(5):
        z = 0.2 + i * 0.03
        b.box((-0.18, fy, z), (0.18, fy + 0.01, z + 0.012), "IronDark")
    # trappes latérales vissées
    for sx in (-1, 1):
        fx = sx * (hw + 0.003)
        x0, x1 = sorted((sx * hw, fx))
        b.box((x0, -0.17, 0.16), (x1, 0.15, 0.36), "Patch")
        for yy in (-0.15, 0.13):
            for zz in (0.18, 0.34):
                c = (fx + sx * 0.003, yy, zz)
                b.box((c[0] - 0.004, c[1] - 0.008, c[2] - 0.008), (c[0] + 0.004, c[1] + 0.008, c[2] + 0.008), "Iron")
    # plateau incliné (mêmes cotes que l'ancien)
    cy, cz = SLAB_CENTER
    b.tilted_box((0.0, cy, cz), (width + 0.04, SLAB_DEPTH, SLAB_T), -TILT, "Paint")
    # liseré sombre sur le bord haut du plateau
    top_back_edge = (cy - math.cos(TILT) * SLAB_DEPTH / 2, cz + math.sin(TILT) * SLAB_DEPTH / 2)
    b.box((-hw - 0.02, top_back_edge[0] - 0.02, top_back_edge[1] - 0.06),
          (hw + 0.02, top_back_edge[0] + 0.01, top_back_edge[1] + 0.012), "IronDark")
    # barre d'appui en cuivre devant le plateau, sur deux supports
    front_edge = (cy + math.cos(TILT) * SLAB_DEPTH / 2, cz - math.sin(TILT) * SLAB_DEPTH / 2)
    bar_y, bar_z = front_edge[0] + 0.05, front_edge[1] - 0.02
    b.cylinder((-hw + 0.04, bar_y, bar_z), (hw - 0.04, bar_y, bar_z), 0.014, "Copper", segments=8)
    for sx in (-1, 1):
        x = sx * (hw - 0.08)
        b.cylinder((x, front_edge[0] - 0.01, bar_z), (x, bar_y, bar_z), 0.01, "IronDark", segments=6)
    b.finish()
    kit.save_and_export(name, budget_tris=1500)


def main():
    build("console_leg", 1.00)
    build("console_drill", 0.90)


main()
