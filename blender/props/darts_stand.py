"""Coin des fléchettes du camp (lobby, M12) : cible sur chevalet, ligne de tir, petite table. Décor (pas jouable).

Fiche
- Taille : 1,6 m de large, 3,6 m de profondeur (cible à y = 0, ligne de tir à y = 3,0), cible à 1,25 m du sol
  (à hauteur de nain). Repère : un nain fait 1,2 m.
- Origine : au sol, sous la cible. La cible regarde vers +Y (vers les joueurs).
- Budget : 1100 triangles.
- Pièces : chevalet (Wood) et panneau de fond (Wood), cible à anneaux (DartBlack, Cream, DartRed, DartGreen),
  3 fléchettes plantées (Copper, DartRed), ligne de tir peinte (Cream), table basse en caisse (Wood)
  avec fléchettes posées, tableau des scores (Board) sur poteau à côté de la cible, face aux joueurs : la craie
  est un Label3D de scenes/props/darts_game.tscn (face avant à y = -0.02, centre (0.9, 1.285), 0,54 x 0,57 m).

    blender -b --factory-startup --python blender/props/darts_stand.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

CZ = 1.25


def dart(b, x, z, y_face):
    b.cylinder((x, y_face, z), (x, y_face + 0.16, z + 0.015), 0.008, "Copper", segments=4)
    b.box((x - 0.035, y_face + 0.15, z - 0.003), (x + 0.035, y_face + 0.2, z + 0.033), "DartRed")


def main():
    kit.new_scene()
    b = kit.Builder("DartsStand")
    # chevalet : deux pieds avant, un arrière, panneau
    for x in (-0.45, 0.45):
        b.cylinder((x, 0.1, 0.0), (x * 0.8, -0.05, 1.9), 0.04, "Wood", segments=5)
    b.cylinder((0.0, -0.75, 0.0), (0.0, -0.1, 1.85), 0.04, "Wood", segments=5)
    b.box((-0.48, -0.1, 0.72), (0.48, -0.04, 1.78), "Wood")
    # cible : disques de rayons décroissants, chacun 3 mm devant le précédent
    rings = ((0.36, "DartBlack"), (0.3, "Cream"), (0.24, "DartRed"), (0.17, "Cream"), (0.1, "DartGreen"),
             (0.04, "DartRed"))
    y = -0.04
    for r, mat in rings:
        b.cylinder((0.0, y, CZ), (0.0, y + 0.03, CZ), r, mat, segments=16)
        y += 0.003
    face = -0.04 + 0.03 + 0.003 * (len(rings) - 1)
    dart(b, 0.05, CZ + 0.06, face)
    dart(b, -0.15, CZ - 0.1, face - 0.003)
    dart(b, 0.2, CZ + 0.18, face - 0.009)
    # ligne de tir peinte au sol
    b.box((-0.7, 2.97, 0.0), (0.7, 3.05, 0.012), "Cream")
    # table basse (caisse) à côté de la ligne, fléchettes posées dessus
    b.box((0.9, 2.7, 0.0), (1.4, 3.2, 0.55), "Wood")
    for k in range(3):
        b.cylinder((1.0 + k * 0.1, 2.85, 0.565), (1.0 + k * 0.1, 3.05, 0.565), 0.01, "Copper", segments=4)
    # tableau des scores sur son poteau, à côté de la cible, face aux joueurs (craie écrite dans Godot)
    b.cylinder((0.9, -0.06, 0.0), (0.9, -0.06, 1.0), 0.035, "Wood", segments=6)
    b.box((0.6, -0.08, 0.97), (1.2, -0.04, 1.6), "Wood")
    b.box((0.63, -0.04, 1.0), (1.17, -0.02, 1.57), "Board")
    b.finish()
    kit.save_and_export("darts_stand", budget_tris=1100)


main()
