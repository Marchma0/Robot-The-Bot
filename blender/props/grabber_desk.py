"""Bureau du poste du grappin (tête du mécha) : plateau sur pieds, caisson à tiroirs, une tasse.

Fiche
- Taille : 0,84 m x 0,44 m, plateau à 0,46 m (même hauteur que l'ancien : le cadre de l'écran reste posé dessus).
- Origine : au sol, au centre ; le pilote est du côté +Y. Placé tourné de 180° :
  Blender (-1.1, 1.55, 5.6) = Godot (-1.1, 5.6, -1.55).
- Budget : 1500 triangles.
- Pièces : plateau (Paint) avec chant en cuivre, 2 pieds et une traverse (IronDark), caisson à 2 tiroirs à gauche
  du pilote (poignées en cuivre), panneau de fond, tasse (Cream).
- Moniteur posé au fond du plateau (Paint, cadre Copper, molettes, antenne) : l'écran lui-même est le quad
  `Screen` de seat.tscn, centre à (0, -0.065, 0.66) ici, 0,48 x 0,34 m, tourné vers le pilote ; le boîtier
  s'arrête 4 mm derrière. Collision : scenes/mecha/props/grabber_desk.tscn.

    blender -b --factory-startup --python blender/props/grabber_desk.py
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


def monitor(b):
    """Moniteur à l'ancienne : boîtier vert posé sur le plateau, cadre en cuivre, molettes et antenne."""
    hd = D / 2
    by0, by1 = SCREEN_Y - 0.24, SCREEN_Y - 0.004
    bx = SCREEN_HW + 0.05
    zb, zt = SCREEN_Z - SCREEN_HH, SCREEN_Z + SCREEN_HH
    bz0, bz1 = TOP_Z + 0.002, zt + 0.045
    # boîtier : face avant + arrière plus étroit (forme de tube cathodique)
    b.box((-bx, by0 + 0.1, bz0), (bx, by1, bz1), "Paint")
    b.frustum((0, (by0 + by0 + 0.1) / 2), bz0 + 0.03, bz1 - 0.03, (bx - 0.06, 0.05), (bx - 0.09, 0.05), "Paint")
    # cadre en cuivre autour de l'écran (dépasse le boîtier : pas de faces dans le même plan)
    fy0, fy1 = by1 - 0.002, SCREEN_Y + 0.02
    b.box((-bx - 0.005, fy0, zt), (bx + 0.005, fy1, bz1 + 0.005), "Copper")
    b.box((-bx - 0.005, fy0, bz0 - 0.005), (bx + 0.005, fy1, zb), "Copper")
    b.box((-bx - 0.005, fy0, zb), (-SCREEN_HW, fy1, zt), "Copper")
    b.box((SCREEN_HW, fy0, zb), (bx + 0.005, fy1, zt), "Copper")
    # molettes sur le côté droit du cadre, rivets aux coins
    mx = (SCREEN_HW + bx) / 2
    for z in (SCREEN_Z + 0.02, SCREEN_Z - 0.06):
        b.cylinder((mx, fy1, z), (mx, fy1 + 0.015, z), 0.016, "IronDark", segments=10)
    for x in (-bx + 0.015, bx - 0.015):
        for z in (bz0 + 0.012, bz1 - 0.008):
            b.box((x - 0.007, fy1, z - 0.007), (x + 0.007, fy1 + 0.005, z + 0.007), "Iron")
    # antenne en V sur le dessus
    ay = (by0 + 0.1 + by1) / 2
    b.cylinder((0.12, ay, bz1), (0.12, ay, bz1 + 0.02), 0.03, "IronDark", segments=8)
    for sx in (-1, 1):
        tip = (0.12 + sx * 0.08, ay - 0.02, bz1 + 0.2)
        b.cylinder((0.12, ay, bz1 + 0.02), tip, 0.004, "Iron", segments=5)
        b.sphere(tip, 0.01, "Copper", segments=6)
    # câble qui descend derrière le bureau
    b.pipe([(-0.27, by0 + 0.12, bz0 + 0.05), (-0.27, -hd - 0.03, bz0 + 0.02), (-0.27, -hd - 0.03, 0.05)],
           0.01, "DartBlack")


def main():
    kit.new_scene()
    b = kit.Builder("GrabberDesk")
    hw, hd = W / 2, D / 2
    # plateau + chant en cuivre côté pilote
    b.box((-hw, -hd, TOP_Z - TOP_T), (hw, hd, TOP_Z), "Paint")
    b.box((-hw, hd, TOP_Z - TOP_T), (hw, hd + 0.008, TOP_Z - 0.005), "Copper")
    # caisson à tiroirs : à gauche du pilote. Le pilote regarde vers -Y local (bureau tourné de 180°),
    # sa gauche est donc en +X local.
    cx0, cx1 = hw - 0.3, hw - 0.02
    b.box((cx0, -hd + 0.02, 0.03), (cx1, hd - 0.02, TOP_Z - TOP_T), "Paint")
    b.box((cx0 - 0.005, -hd + 0.02, 0.0), (cx1 + 0.005, hd - 0.02, 0.03), "IronDark")
    for z0, z1 in ((0.05, 0.2), (0.22, 0.39)):
        b.box((cx0 + 0.02, hd - 0.02, z0), (cx1 - 0.02, hd - 0.005, z1), "Patch")
        b.box(((cx0 + cx1) / 2 - 0.05, hd - 0.005, (z0 + z1) / 2 - 0.008),
              ((cx0 + cx1) / 2 + 0.05, hd + 0.015, (z0 + z1) / 2 + 0.008), "Copper")
    # pieds de l'autre côté + traverse + panneau de fond
    for y in (-hd + 0.04, hd - 0.04):
        b.box((-hw + 0.03, y - 0.02, 0.0), (-hw + 0.07, y + 0.02, TOP_Z - TOP_T), "IronDark")
    b.box((-hw + 0.03, -hd + 0.04, 0.08), (-hw + 0.07, hd - 0.04, 0.11), "IronDark")
    b.box((-hw + 0.07, -hd + 0.01, 0.12), (cx0, -hd + 0.03, TOP_Z - TOP_T), "IronDark")
    b.rivet_row((-hw + 0.1, -hd + 0.01, 0.15), (cx0 - 0.03, -hd + 0.01, 0.15), (0, -1, 0), spacing=0.1, size=0.012)
    # tasse posée à droite du pilote (-X local), loin de l'écran
    mx, my = -hw + 0.12, hd - 0.12
    b.cylinder((mx, my, TOP_Z), (mx, my, TOP_Z + 0.08), 0.035, "Cream", segments=10)
    b.cylinder((mx - 0.05, my, TOP_Z + 0.04), (mx - 0.035, my, TOP_Z + 0.04), 0.018, "Cream", segments=6)
    monitor(b)
    b.finish()
    kit.save_and_export("grabber_desk", budget_tris=2200)


main()
