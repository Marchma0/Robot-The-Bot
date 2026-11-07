"""Établi du poste de la foreuse (tête du mécha, côté droit) : caisson en tôle, moniteur intégré, gyrophare.

Fiche
- Taille : 0,84 m x 0,44 m, plateau à 0,46 m (comme le bureau du grappin), moniteur jusqu'à 0,9 m.
- Origine : au sol, au centre ; le pilote est du côté +Y. Placé tourné de 180° :
  Blender (1.1, 1.55, 5.6) = Godot (1.1, 5.6, -1.55).
- Budget : 2000 triangles.
- Pièces : caisson plein (Patch) sur socle (IronDark), plateau (Iron) avec bande de danger jaune et noire,
  grilles d'aération, boîtier de moniteur (IronDark) avec cadre en cuivre autour de l'écran,
  gyrophare orange (Lamp) et mèche de rechange posée sur le moniteur.
- L'écran lui-même est le quad `Screen` de seat.tscn : centre à (0, -0.065, 0.66) ici, 0,48 x 0,34 m,
  tourné vers le pilote. Le boîtier s'arrête 4 mm derrière. Collision : Hull/DrillDesk dans mecha.tscn.
- Différent du bureau du grappin (bois et peinture verte) : on reconnaît le poste de la foreuse de loin.

    blender -b --factory-startup --python blender/props/drill_desk.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

W, D = 0.84, 0.44
TOP_Z, TOP_T = 0.46, 0.04
SCREEN_Y = -0.065
SCREEN_Z = 0.66
SCREEN_HW, SCREEN_HH = 0.24, 0.17


def main():
    kit.new_scene()
    b = kit.Builder("DrillDesk")
    hw, hd = W / 2, D / 2
    # socle + caisson plein + plateau
    b.box((-hw + 0.02, -hd + 0.02, 0.0), (hw - 0.02, hd - 0.02, 0.04), "IronDark")
    b.box((-hw + 0.03, -hd + 0.03, 0.04), (hw - 0.03, hd - 0.03, TOP_Z - TOP_T), "Patch")
    b.box((-hw, -hd, TOP_Z - TOP_T), (hw, hd, TOP_Z), "Iron")
    # bande de danger jaune et noire sur le chant côté pilote
    n = 14
    for i in range(n):
        x0 = -hw + W * i / n
        x1 = -hw + W * (i + 1) / n
        b.box((x0, hd, TOP_Z - TOP_T + 0.004), (x1, hd + 0.01, TOP_Z - 0.004), "Yellow" if i % 2 == 0 else "DartBlack")
    # grilles d'aération sur la face avant du caisson (côté pilote)
    for k in range(5):
        z = 0.1 + k * 0.05
        b.box((-0.3, hd - 0.03, z), (0.3, hd - 0.012, z + 0.022), "IronDark")
    b.rivet_row((-hw + 0.06, hd - 0.03, 0.37), (hw - 0.06, hd - 0.03, 0.37), (0, 1, 0), spacing=0.12, size=0.014)
    # boîtier du moniteur, posé sur le plateau
    by0, by1 = SCREEN_Y - 0.28, SCREEN_Y - 0.004
    bx = SCREEN_HW + 0.06
    bz0, bz1 = TOP_Z + 0.001, SCREEN_Z + SCREEN_HH + 0.06
    b.box((-bx, by0, bz0), (bx, by1, bz1), "IronDark")
    # cadre en cuivre autour de l'écran (dépasse de 5 mm le boîtier : pas de faces dans le même plan)
    fy0, fy1 = by1 - 0.002, SCREEN_Y + 0.03
    zb, zt = SCREEN_Z - SCREEN_HH, SCREEN_Z + SCREEN_HH
    b.box((-bx - 0.005, fy0, zt), (bx + 0.005, fy1, bz1 + 0.005), "Copper")
    b.box((-bx - 0.005, fy0, bz0 + 0.004), (bx + 0.005, fy1, zb), "Copper")
    b.box((-bx - 0.005, fy0, zb), (-SCREEN_HW, fy1, zt), "Copper")
    b.box((SCREEN_HW, fy0, zb), (bx + 0.005, fy1, zt), "Copper")
    # petits boutons sous l'écran (rouge : moteur, jaune : lumière)
    b.box((-0.05, fy1, zb - 0.025), (-0.02, fy1 + 0.012, zb - 0.008), "ButtonRed")
    b.box((0.02, fy1, zb - 0.025), (0.05, fy1 + 0.012, zb - 0.008), "Yellow")
    # gyrophare orange sur le moniteur
    gx, gy = bx - 0.07, (by0 + by1) / 2
    b.cylinder((gx, gy, bz1), (gx, gy, bz1 + 0.03), 0.045, "IronDark", segments=10)
    b.cylinder((gx, gy, bz1 + 0.03), (gx, gy, bz1 + 0.1), 0.035, "Lamp", segments=10, radius_end=0.02)
    # mèche de rechange couchée sur le moniteur
    my = (by0 + by1) / 2
    b.cylinder((-bx + 0.04, my, bz1 + 0.025), (-0.05, my, bz1 + 0.025), 0.022, "Iron", segments=8)
    b.cylinder((-0.05, my, bz1 + 0.025), (0.07, my, bz1 + 0.025), 0.03, "Copper", segments=8, radius_end=0.0)
    b.box((-bx + 0.06, my - 0.03, bz1 + 0.001), (-bx + 0.09, my + 0.03, bz1 + 0.006), "IronDark")
    # câble qui descend du moniteur derrière l'établi
    b.pipe([(0.2, by0 + 0.02, bz0 + 0.1), (0.2, -hd - 0.03, bz0 + 0.06), (0.2, -hd - 0.03, 0.05)], 0.012, "DartBlack")
    b.finish()
    kit.save_and_export("drill_desk", budget_tris=2000)


main()
