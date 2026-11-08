"""Cabine des toilettes (tête du mécha) : cloisons en tôle peinte, cadre en fer, rivets en cuivre.

Fiche
- Taille : 1,37 x 1,02 m au sol, 1,63 m de haut (un nain fait 1,2 m). Coin du fond à gauche contre les murs de la tête :
  seules la cloison avant (+Y) et la cloison droite (+X, avec l'ouverture de la porte) sont modélisées.
- Origine : au sol, au centre de l'emprise. Placée dans le mécha en Blender (-1.515, -1.39, 5.6) = Godot (-1.515, 5.6, 1.39).
- Budget : 3500 triangles.
- Pièces : âme des cloisons (Paint), plinthe, lisses et poteaux (IronDark), rivets (Copper), grille d'aération,
  corniche en cuivre, voyant vert au-dessus de la porte ; dedans : carrelage en damier (DartBlack / Cream),
  dérouleur de papier, petit cadre au mur du fond, ventouse. La cuvette est un objet à part (toilet_bowl).
- Collisions : scenes/mecha/props/toilet_cabin.tscn (cloison avant, bout de cloison droite). La porte est un objet à part (toilet_door).

    blender -b --factory-startup --python blender/props/toilet_cabin.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

X0, X1 = -0.685, 0.685      # gauche (mur de la tête) -> droite (cloison avec la porte)
Y0, Y1 = -0.51, 0.51        # fond (mur de la tête) -> avant
T = 0.05                    # épaisseur des cloisons
H = 1.6                     # hauteur des cloisons
DOOR_Y0, DOOR_Y1 = -0.39, 0.46   # ouverture de la porte dans la cloison droite
LINTEL_Z = 1.40
P = 0.006                   # relief des lisses


def front_wall(b):
    y0, y1 = Y1 - T, Y1
    b.box((X0 + 0.002, y0 + 0.004, 0.002), (X1 - T - 0.002, y1 - 0.004, H - 0.002), "Paint")   # âme, rentrée de 2 mm sous le cadre
    b.box((X0, y0 - 0.008, 0.0), (X1 - T, y1 + 0.008, 0.12), "IronDark")        # plinthe
    b.box((X0, y0 - P, H - 0.06), (X1 - T, y1 + P, H), "IronDark")              # lisse haute
    b.box((X0, y0 - P, 0.78), (X1 - T, y1 + P, 0.83), "IronDark")               # lisse du milieu
    b.box((X0, y0 - P, 0.0), (X0 + 0.05, y1 + P, H), "IronDark")                # poteau contre le mur
    b.box((-0.03, y0 - P, 0.12), (0.03, y1 + P, H - 0.06), "IronDark")          # raidisseur central
    for face_y, normal in ((y1 + P, (0, 1, 0)), (y0 - P, (0, -1, 0))):
        for z in (0.06, 0.805, H - 0.03):
            b.rivet_row((X0 + 0.09, face_y, z), (X1 - T - 0.05, face_y, z), normal, spacing=0.11)
    # grille d'aération en haut à gauche (lamelles des deux côtés)
    for i in range(4):
        z = 1.28 + i * 0.05
        b.box((-0.45, y0 - 0.012, z), (-0.12, y1 + 0.012, z + 0.018), "IronDark")
    # corniche en cuivre
    b.box((X0, y0 - 0.012, H), (X1, y1 + 0.012, H + 0.025), "Copper")


def side_wall(b):
    x0, x1 = X1 - T, X1
    # poteau d'angle avant-droit
    b.box((x0 - 0.03, Y1 - T - 0.03, 0.0), (x1 + 0.004, Y1 + 0.004, H + 0.028), "IronDark")
    # morceau de cloison au fond, à droite de la porte
    b.box((x0 + 0.004, Y0 + 0.002, 0.002), (x1 - 0.004, DOOR_Y0 - 0.002, LINTEL_Z), "Paint")
    b.box((x0 - 0.008, Y0, 0.0), (x1 + 0.008, DOOR_Y0, 0.12), "IronDark")
    b.box((x0 - P, DOOR_Y0 - 0.04, 0.0), (x1 + P, DOOR_Y0, LINTEL_Z + 0.002), "IronDark")   # montant de la porte (butée)
    # linteau au-dessus de la porte
    b.box((x0 + 0.004, Y0 + 0.002, LINTEL_Z + 0.002), (x1 - 0.004, Y1 - T - 0.002, H - 0.002), "Paint")
    b.box((x0 - P, Y0, LINTEL_Z), (x1 + P, Y1 - T, LINTEL_Z + 0.04), "IronDark")
    b.box((x0 - P, Y0, H - 0.06), (x1 + P, Y1 - T, H), "IronDark")
    b.box((x0 - 0.012, Y0, H), (x1 + 0.012, Y1, H + 0.025), "Copper")
    for face_x, normal in ((x1 + P, (1, 0, 0)), (x0 - P, (-1, 0, 0))):
        b.rivet_row((face_x, Y0 + 0.05, H - 0.03), (face_x, Y1 - T - 0.05, H - 0.03), normal, spacing=0.11)
        b.rivet_row((face_x, Y0 + 0.03, 0.4), (face_x, Y0 + 0.03, 1.2), normal, spacing=0.2)
    # voyant « occupé » au-dessus de la porte, côté couloir
    cy = (DOOR_Y0 + DOOR_Y1) / 2
    b.box((x1, cy - 0.06, LINTEL_Z + 0.07), (x1 + 0.04, cy + 0.06, LINTEL_Z + 0.15), "IronDark")
    b.box((x1 + 0.04, cy - 0.045, LINTEL_Z + 0.085), (x1 + 0.05, cy + 0.045, LINTEL_Z + 0.135), "ButtonGreen")


def interior(b):
    """Dans la cabine : carrelage en damier, dérouleur de papier, cadre au mur du fond, ventouse dans le coin.
    Le mur gauche et le mur du fond sont ceux de la tête (x = X0, y = Y0)."""
    tile = 0.15
    nx = int((X1 - T - 0.01 - X0) / tile)
    ny = int((Y1 - T - 0.01 - Y0) / tile)
    for i in range(nx):
        for j in range(ny):
            x0, y0 = X0 + i * tile, Y0 + j * tile
            b.box((x0 + 0.002, y0 + 0.002, 0.0), (x0 + tile - 0.002, y0 + tile - 0.002, 0.008),
                  "DartBlack" if (i + j) % 2 else "Cream")
    # dérouleur de papier au mur du fond
    px, pz = -0.095, 0.62
    b.box((px - 0.07, Y0, pz + 0.03), (px + 0.07, Y0 + 0.02, pz + 0.05), "Copper")
    for dx in (-0.065, 0.065):
        b.box((dx + px - 0.005, Y0, pz - 0.01), (dx + px + 0.005, Y0 + 0.08, pz + 0.04), "Copper")
    b.cylinder((px - 0.055, Y0 + 0.06, pz), (px + 0.055, Y0 + 0.06, pz), 0.05, "Paper", 10)
    b.box((px - 0.05, Y0 + 0.1, pz - 0.12), (px + 0.05, Y0 + 0.104, pz), "Paper")      # bout de papier qui pend
    # petit cadre au-dessus : canard sur l'eau
    fx, fz = -0.085, 1.15
    b.box((fx - 0.2, Y0, fz - 0.15), (fx + 0.2, Y0 + 0.02, fz + 0.15), "Wood")
    b.box((fx - 0.17, Y0 + 0.02, fz - 0.12), (fx + 0.17, Y0 + 0.022, fz + 0.12), "Paper")
    b.box((fx - 0.17, Y0 + 0.022, fz - 0.12), (fx + 0.17, Y0 + 0.024, fz - 0.04), "Glass")
    b.box((fx - 0.05, Y0 + 0.024, fz - 0.06), (fx + 0.06, Y0 + 0.026, fz), "Yellow")
    b.box((fx + 0.03, Y0 + 0.024, fz), (fx + 0.07, Y0 + 0.026, fz + 0.05), "Yellow")
    b.box((fx + 0.07, Y0 + 0.026, fz + 0.015), (fx + 0.1, Y0 + 0.028, fz + 0.03), "Ochre")
    # ventouse dans le coin du fond, côté porte
    vx, vy = X1 - T - 0.12, Y0 + 0.1
    b.cylinder((vx, vy, 0.008), (vx, vy, 0.07), 0.06, "DartRed", 10, radius_end=0.03)
    b.cylinder((vx, vy, 0.07), (vx - 0.05, vy + 0.02, 0.62), 0.012, "Wood", 6)

def main():
    kit.new_scene()
    b = kit.Builder("ToiletCabin")
    front_wall(b)
    side_wall(b)
    interior(b)
    b.finish()
    kit.save_and_export("toilet_cabin", budget_tris=3500)


main()
