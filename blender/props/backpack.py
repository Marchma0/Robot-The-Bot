"""Gros sac à dos du mécha (M10 — Inventaire), fixé sur la paroi arrière du ventre (Ext_Body, y = -2.10).

Fiche
- Taille : 3,86 m de large hors-tout (caisson 3,20 m + poches latérales), 1,48 m de profondeur, 3,15 m de haut hors-tout.
  Repère : un nain fait 1,2 m ; le dos extérieur du ventre (Ext_Body) fait 4,8 m de large sur 3,2 m de haut (z = 2,3..5,5)
  avec la collerette (Ext_Collar) qui déborde de 0,30 m entre z = 5,3 et 5,7.
- Origine : face avant (plaquée contre Ext_Body) à y = 0, base du caisson à z = 0.
  Le sac s'étend vers -Y dans Blender, soit +Z dans Godot (vers l'arrière du mécha).
  Placé dans mecha.tscn à (0, 2.55, 2.10) sans rotation.
- Budget : 2500 triangles.
- Pièces : cadre dorsal boulonné et bretelles épaulées qui contournent la collerette (IronDark, Copper, Wood),
  gros caisson principal creux en haut (Paint, IronDark, intérieur DartBlack), panneau cargo nervuré en bas
  (WallCream, IronDark), 2 poches latérales à rabat (WallTeal, Wood, Copper), gros rouleau de bâche centré sous le sac
  (Cushion, Wood, Copper), cadre de jauge arrière (Copper, DartBlack).
- Le couvercle articulé est dans blender/props/backpack_lid.py (charnière à y = -0.34, z = 2.52).

    blender -b --factory-startup --python blender/props/backpack.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

W = 3.20          # largeur du caisson principal
D = 1.45          # profondeur du caisson (vers -Y)
H = 2.52          # hauteur du bord supérieur du caisson (ouverture, sous la collerette à z_monde = 5.3)
Y_BACK = -0.26    # décalage par rapport à la coque pour dégager l'ouverture devant la collerette (qui déborde de 0.30 m)
WALL = 0.12       # épaisseur des parois du puits supérieur
WELL_Z = 1.65     # fond du puits visible quand le couvercle s'ouvre


def main():
    kit.new_scene()
    b = kit.Builder("Backpack")

    x0, x1 = -W / 2, W / 2
    y_back = Y_BACK
    y_front = -D            # face arrière extérieure du sac (côté -Y)

    # 1. Pattes d'ancrage contre Ext_Body (y = 0) et bretelles qui montent s'accrocher sur la collerette
    for sx in (-1, 1):
        px = sx * 1.08
        # Entretoises dorsales (de y = 0 contre la coque jusqu'au dos du caisson y = y_back)
        b.box((px - 0.13, y_back - 0.01, 0.08), (px + 0.13, 0.0, H - 0.05), "IronDark")
        for pz in (0.24, 1.25, 2.22):
            b.box((px - 0.20, -0.05, pz - 0.12), (px + 0.20, 0.002, pz + 0.12), "Iron")
            for dx in (-0.15, 0.15):
                b.box((px + dx - 0.022, -0.06, pz - 0.022), (px + dx + 0.022, -0.01, pz + 0.022), "Copper")
        # Bretelles d'épaule qui contournent la collerette (y = -0.30..0 entre z_local = 2.75..3.15)
        b.box((px - 0.11, -0.42, H - 0.08), (px + 0.11, -0.305, H + 0.62), "Wood")
        b.box((px - 0.11, -0.305, H + 0.48), (px + 0.11, -0.02, H + 0.62), "Wood")
        b.box((px - 0.125, -0.435, H + 0.16), (px + 0.125, -0.295, H + 0.26), "Copper")

    # 2. Socle blindé en fer sous le caisson
    b.box((x0 - 0.035, y_front - 0.025, 0.0), (x1 + 0.035, y_back + 0.02, 0.22), "IronDark")
    b.rivet_row((x0 + 0.16, y_front - 0.025, 0.11), (x1 - 0.16, y_front - 0.025, 0.11),
                (0, -1, 0), spacing=0.26, size=0.030)

    # 3. Caisson principal (partie basse pleine + puits creux en haut pour accueillir les objets)
    b.box((x0 + 0.002, y_front + 0.002, 0.22), (x1 - 0.002, y_back - 0.002, WELL_Z), "Paint")
    # Parois du puits supérieur (de WELL_Z à H)
    b.box((x0 + 0.002, y_back - WALL, WELL_Z), (x1 - 0.002, y_back - 0.002, H - 0.03), "Paint")       # paroi côté coque
    b.box((x0 + 0.002, y_front + 0.002, WELL_Z), (x1 - 0.002, y_front + WALL, H - 0.03), "Paint")     # paroi arrière
    b.box((x0 + 0.002, y_front + WALL, WELL_Z), (x0 + WALL, y_back - WALL, H - 0.03), "Paint")        # paroi gauche
    b.box((x1 - WALL, y_front + WALL, WELL_Z), (x1 - 0.002, y_back - WALL, H - 0.03), "Paint")        # paroi droite
    # Fond sombre du puits
    b.box((x0 + WALL + 0.002, y_front + WALL + 0.002, WELL_Z + 0.002),
          (x1 - WALL - 0.002, y_back - WALL - 0.002, WELL_Z + 0.04), "DartBlack")

    # 4. Cornières, ceinture métallique et col d'ouverture en fer + rivets cuivre
    b.box((x0 - 0.025, y_back - WALL - 0.01, H - 0.05), (x1 + 0.025, y_back + 0.015, H), "IronDark")
    b.box((x0 - 0.025, y_front - 0.02, H - 0.05), (x1 + 0.025, y_front + WALL + 0.01, H), "IronDark")
    b.box((x0 - 0.025, y_front + WALL + 0.01, H - 0.05), (x0 + WALL + 0.01, y_back - WALL - 0.01, H), "IronDark")
    b.box((x1 - WALL - 0.01, y_front + WALL + 0.01, H - 0.05), (x1 + 0.025, y_back - WALL - 0.01, H), "IronDark")

    # Montants verticaux d'angle (face arrière -Y)
    for sx in (x0, x1 - 0.09):
        b.box((sx - 0.012, y_front - 0.015, 0.222), (sx + 0.102, y_front + 0.07, H - 0.052), "IronDark")
        b.rivet_row((sx + 0.045, y_front - 0.015, 0.34), (sx + 0.045, y_front - 0.015, H - 0.16),
                    (0, -1, 0), spacing=0.26, size=0.026)

    # Ceinture horizontale à mi-hauteur
    belt_z0, belt_z1 = 1.28, 1.40
    b.box((x0 - 0.018, y_front - 0.018, belt_z0), (x1 + 0.018, y_back + 0.008, belt_z1), "IronDark")
    b.rivet_row((x0 + 0.16, y_front - 0.018, (belt_z0 + belt_z1) / 2),
                (x1 - 0.16, y_front - 0.018, (belt_z0 + belt_z1) / 2),
                (0, -1, 0), spacing=0.24, size=0.026)

    # Panneau cargo inférieur encadré de fer avec nervures (face arrière -Y)
    px0, px1, pz0, pz1 = -1.06, 1.06, 0.32, 1.18
    b.box((px0, y_front - 0.012, pz0), (px1, y_front - 0.001, pz1), "IronDark")
    b.box((px0 + 0.05, y_front - 0.019, pz0 + 0.05), (px1 - 0.05, y_front - 0.005, pz1 - 0.05), "WallCream")
    for rz in (0.54, 0.75, 0.96):
        b.box((px0 + 0.10, y_front - 0.025, rz - 0.018), (px1 - 0.10, y_front - 0.014, rz + 0.018), "Iron")

    # 2 sangles verticales en cuir (Wood) qui passent par-dessus le panneau et la ceinture
    for sx in (-0.82, 0.82):
        b.box((sx - 0.085, y_front - 0.034, 0.26), (sx + 0.085, y_front - 0.004, H - 0.052), "Wood")
        # Boucle en cuivre sur la sangle
        b.box((sx - 0.105, y_front - 0.046, 1.66), (sx + 0.105, y_front - 0.014, 1.86), "Copper")
        b.box((sx - 0.06, y_front - 0.050, 1.70), (sx + 0.06, y_front - 0.026, 1.82), "IronDark")

    # 5. Cadre de la jauge de remplissage au centre de la face arrière (-Y)
    gx0, gx1, gz0, gz1 = -0.28, 0.28, 1.54, 2.30
    b.box((gx0, y_front - 0.026, gz0), (gx1, y_front - 0.002, gz1), "Copper")
    b.box((gx0 + 0.045, y_front - 0.032, gz0 + 0.045), (gx1 - 0.045, y_front - 0.014, gz1 - 0.045), "DartBlack")
    for i in range(1, 5):
        gz = gz0 + 0.045 + (gz1 - gz0 - 0.09) * (i / 5.0)
        b.box((gx0 + 0.012, y_front - 0.035, gz - 0.010), (gx0 + 0.075, y_front - 0.022, gz + 0.010), "Copper")
        b.box((gx1 - 0.075, y_front - 0.035, gz - 0.010), (gx1 - 0.012, y_front - 0.022, gz + 0.010), "Copper")

    # 6. Deux grosses poches latérales (gauche et droite)
    for side in (-1, 1):
        p_x0 = (x0 - 0.35) if side < 0 else (x1 + 0.002)
        p_x1 = (x0 - 0.002) if side < 0 else (x1 + 0.35)
        py0, py1 = -1.24, -0.44
        pz0, pz1 = 0.38, 1.86
        b.box((p_x0, py0, pz0), (p_x1, py1, pz1 - 0.18), "WallTeal")
        # Rabat supérieur de la poche
        flap_x0 = p_x0 - (0.018 if side < 0 else 0.004)
        flap_x1 = p_x1 + (0.004 if side < 0 else 0.018)
        b.box((flap_x0, py0 - 0.015, pz1 - 0.28), (flap_x1, py1 + 0.015, pz1), "Wood")
        # Sangle + boucle en cuivre sur le côté extérieur de la poche
        out_x = flap_x0 if side < 0 else flap_x1
        s_lo = (out_x - 0.022, -0.90, pz1 - 0.50) if side < 0 else (out_x - 0.002, -0.90, pz1 - 0.50)
        s_hi = (out_x + 0.002, -0.78, pz1 - 0.08) if side < 0 else (out_x + 0.022, -0.78, pz1 - 0.08)
        b.box(s_lo, s_hi, "Copper")

    # 7. Gros rouleau de bâche / paquetage centré sous le socle
    roll_y, roll_z = (y_front + y_back) / 2, -0.22
    for sx in (-0.88, 0.88):
        b.box((sx - 0.07, roll_y - 0.25, roll_z - 0.25), (sx + 0.07, roll_y + 0.25, 0.02), "Wood")
        b.box((sx - 0.085, roll_y - 0.27, roll_z - 0.06), (sx + 0.085, roll_y - 0.23, roll_z + 0.06), "Copper")
    b.cylinder((-1.26, roll_y, roll_z), (1.26, roll_y, roll_z), 0.23, "Cushion", segments=12)
    b.cylinder((-1.30, roll_y, roll_z), (-1.26, roll_y, roll_z), 0.185, "WallCream", segments=12)
    b.cylinder((1.26, roll_y, roll_z), (1.30, roll_y, roll_z), 0.185, "WallCream", segments=12)

    # 8. Charnières fixes en haut côté coque (autour de y = Y_BACK - 0.06, z = H)
    hinge_y = y_back - 0.06
    for hx in (-0.98, 0.0, 0.98):
        b.cylinder((hx - 0.15, hinge_y, H), (hx + 0.15, hinge_y, H), 0.052, "IronDark", segments=10)

    b.finish()
    kit.save_and_export("backpack", budget_tris=2500)


main()
