"""Cabine des toilettes (tête du mécha) : cloisons en tôle peinte, cadre en fer, rivets en cuivre.

Fiche
- Taille : 1,37 x 1,02 m au sol, 1,63 m de haut (un nain fait 1,2 m). Coin du fond à gauche contre les murs de la tête :
  seules la cloison avant (+Y) et la cloison droite (+X, avec l'ouverture de la porte) sont modélisées.
- Origine : au sol, au centre de l'emprise. Placée dans le mécha en Blender (-1.515, -1.39, 5.6) = Godot (-1.515, 5.6, 1.39).
- Budget : 2500 triangles.
- Pièces : âme des cloisons (Paint), plinthe, lisses et poteaux (IronDark), rivets (Copper), grille d'aération,
  corniche en cuivre, voyant vert au-dessus de la porte.
- Collisions : déjà dans mecha.tscn (Hull/ToiletFront, Hull/ToiletSide). La porte est un objet à part (toilet_door).

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


def main():
    kit.new_scene()
    b = kit.Builder("ToiletCabin")
    front_wall(b)
    side_wall(b)
    b.finish()
    kit.save_and_export("toilet_cabin", budget_tris=2500)


main()
