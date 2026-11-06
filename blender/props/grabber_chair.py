"""Fauteuil du pilote du grappin (tête du mécha).

Fiche
- Taille : 0,56 m de large, 0,55 m de profondeur, assise à 0,39 m (comme l'ancien siège), dossier à 0,95 m.
- Origine : au sol, sous le centre de l'assise ; le pilote regarde vers +Y (vers le bureau et l'écran).
  Placé sans rotation : Blender (-1.1, 0.85, 5.6) = Godot (-1.1, 5.6, -0.85) (même endroit que Controls/Grabber_Seat).
- Budget : 2500 triangles.
- Pièces : piètement étoile à 5 branches avec patins, colonne, assise et dossier rembourrés (Cushion) avec coutures,
  cadre de dossier (IronDark), appui-tête, accoudoirs (Wood) sur supports, petit manche en cuivre à droite.
- Pas de collision solide (comme l'ancien siège) : l'interaction est dans Controls/Grabber_Seat.

    blender -b --factory-startup --python blender/props/grabber_chair.py
"""

import math
import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

SEAT_Z = 0.39
SEAT_W, SEAT_D = 0.46, 0.44


def main():
    kit.new_scene()
    b = kit.Builder("GrabberChair")
    # piètement étoile
    for i in range(5):
        a = math.radians(90 + i * 72)
        tip = (0.25 * math.cos(a), 0.25 * math.sin(a), 0.05)
        b.cylinder((0, 0, 0.07), tip, 0.018, "IronDark", segments=6)
        b.cylinder((tip[0], tip[1], 0.0), (tip[0], tip[1], 0.04), 0.025, "DartBlack", segments=8)
    b.cylinder((0, 0, 0.04), (0, 0, 0.1), 0.05, "IronDark", segments=10)
    b.cylinder((0, 0, 0.1), (0, 0, SEAT_Z - 0.09), 0.025, "Iron", segments=10)              # colonne
    b.box((-0.15, -0.15, SEAT_Z - 0.1), (0.15, 0.15, SEAT_Z - 0.07), "IronDark")             # platine
    # assise rembourrée + coutures
    y0, y1 = -SEAT_D / 2, SEAT_D / 2
    b.box((-SEAT_W / 2, y0, SEAT_Z - 0.07), (SEAT_W / 2, y1, SEAT_Z), "Cushion")
    b.box((-SEAT_W / 2 + 0.03, y1 - 0.01, SEAT_Z - 0.065), (SEAT_W / 2 - 0.03, y1 + 0.02, SEAT_Z - 0.01), "Cushion")  # bourrelet avant
    for x in (-0.08, 0.08):
        b.box((x - 0.004, y0 + 0.04, SEAT_Z), (x + 0.004, y1 - 0.04, SEAT_Z + 0.003), "Rust")
    # dossier : cadre + coussin + appui-tête
    by = y0 - 0.02
    b.box((-0.02, by - 0.04, SEAT_Z - 0.09), (0.02, by - 0.01, SEAT_Z + 0.08), "IronDark")   # support
    b.box((-SEAT_W / 2, by - 0.06, SEAT_Z + 0.06), (SEAT_W / 2, by - 0.03, SEAT_Z + 0.5), "IronDark")
    b.box((-SEAT_W / 2 + 0.025, by - 0.03, SEAT_Z + 0.08), (SEAT_W / 2 - 0.025, by + 0.03, SEAT_Z + 0.48), "Cushion")
    for z in (SEAT_Z + 0.21, SEAT_Z + 0.35):
        b.box((-SEAT_W / 2 + 0.04, by + 0.03, z - 0.004), (SEAT_W / 2 - 0.04, by + 0.033, z + 0.004), "Rust")
    b.box((-0.12, by - 0.05, SEAT_Z + 0.5), (0.12, by + 0.02, SEAT_Z + 0.58), "Cushion")       # appui-tête
    b.rivet_row((-SEAT_W / 2 + 0.012, by - 0.06, SEAT_Z + 0.1), (-SEAT_W / 2 + 0.012, by - 0.06, SEAT_Z + 0.46),
                (0, -1, 0), spacing=0.09, size=0.012)
    b.rivet_row((SEAT_W / 2 - 0.012, by - 0.06, SEAT_Z + 0.1), (SEAT_W / 2 - 0.012, by - 0.06, SEAT_Z + 0.46),
                (0, -1, 0), spacing=0.09, size=0.012)
    # accoudoirs
    for sx in (-1, 1):
        x = sx * (SEAT_W / 2 + 0.03)
        b.box((x - 0.015, -0.02, SEAT_Z - 0.07), (x + 0.015, 0.01, SEAT_Z + 0.17), "IronDark")
        b.box((sx * SEAT_W / 2 - 0.0, -0.02, SEAT_Z - 0.07), (x, 0.01, SEAT_Z - 0.04), "IronDark")
        b.box((x - 0.035, -0.17, SEAT_Z + 0.17), (x + 0.035, 0.15, SEAT_Z + 0.2), "Wood")
    # petit manche sur l'accoudoir droit (+X)
    x = SEAT_W / 2 + 0.03
    b.cylinder((x, 0.09, SEAT_Z + 0.2), (x, 0.09, SEAT_Z + 0.215), 0.03, "IronDark", segments=10)
    b.cylinder((x, 0.09, SEAT_Z + 0.215), (x, 0.1, SEAT_Z + 0.3), 0.008, "Iron", segments=6)
    b.sphere((x, 0.1, SEAT_Z + 0.31), 0.022, "Copper", segments=10)
    b.finish()
    kit.save_and_export("grabber_chair", budget_tris=2500)


main()
