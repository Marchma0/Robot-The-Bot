"""Siège du pilote de la foreuse (tête du mécha, côté droit) : siège de tracteur en tôle jaune.

Fiche
- Taille : 0,48 m de large, 0,46 m de profondeur, assise à 0,39 m (comme le fauteuil du grappin), dossier à 0,8 m.
- Origine : au sol, sous le centre de l'assise ; le pilote regarde vers +Y (vers l'établi et l'écran).
  Placé sans rotation : Blender (1.1, 0.85, 5.6) = Godot (1.1, 5.6, -0.85) (même endroit que Controls/Drill_Seat).
- Budget : 1500 triangles.
- Pièces : platine ronde boulonnée au sol (IronDark), colonne (Iron) avec ressort (Copper), repose-pieds
  en anneau, coque d'assise et dossier incliné en tôle jaune (Yellow), coussins noirs (DartBlack).
- Pas de collision solide (comme le fauteuil du grappin) : l'interaction est dans Controls/Drill_Seat.
- Volontairement très différent du fauteuil de bureau du grappin.

    blender -b --factory-startup --python blender/props/drill_chair.py
"""

import math
import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

SEAT_Z = 0.39
SEAT_HW, SEAT_HD = 0.24, 0.23


def main():
    kit.new_scene()
    b = kit.Builder("DrillChair")
    # platine au sol + boulons
    b.cylinder((0, 0, 0), (0, 0, 0.03), 0.22, "IronDark", segments=12)
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        x, y = math.cos(a) * 0.17, math.sin(a) * 0.17
        b.cylinder((x, y, 0.03), (x, y, 0.045), 0.018, "Iron", segments=6)
    # colonne + ressort
    b.cylinder((0, 0, 0.03), (0, 0, SEAT_Z - 0.06), 0.035, "Iron", segments=10)
    for k in range(4):
        z = 0.14 + k * 0.035
        b.cylinder((0, 0, z), (0, 0, z + 0.015), 0.06, "Copper", segments=10)
    # repose-pieds en anneau (6 barres) relié à la colonne
    ring_z, ring_r = 0.14, 0.2
    pts = [(math.cos(i * math.pi / 3) * ring_r, math.sin(i * math.pi / 3) * ring_r) for i in range(6)]
    for i in range(6):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % 6]
        b.cylinder((x0, y0, ring_z), (x1, y1, ring_z), 0.012, "IronDark", segments=6)
    b.cylinder((0, 0.04, ring_z), (0, ring_r - 0.01, ring_z), 0.012, "IronDark", segments=6)
    b.cylinder((0, -0.04, ring_z), (0, -ring_r + 0.01, ring_z), 0.012, "IronDark", segments=6)
    # support sous l'assise
    b.box((-0.12, -0.12, SEAT_Z - 0.065), (0.12, 0.12, SEAT_Z - 0.04), "IronDark")
    # coque d'assise jaune (fond + rebords) et coussin noir
    b.box((-SEAT_HW, -SEAT_HD, SEAT_Z - 0.04), (SEAT_HW, SEAT_HD, SEAT_Z - 0.01), "Yellow")
    b.box((-SEAT_HW, -SEAT_HD, SEAT_Z - 0.01), (-SEAT_HW + 0.025, SEAT_HD, SEAT_Z + 0.06), "Yellow")
    b.box((SEAT_HW - 0.025, -SEAT_HD, SEAT_Z - 0.01), (SEAT_HW, SEAT_HD, SEAT_Z + 0.06), "Yellow")
    b.box((-SEAT_HW + 0.03, -SEAT_HD + 0.02, SEAT_Z - 0.01), (SEAT_HW - 0.03, SEAT_HD - 0.02, SEAT_Z + 0.03), "DartBlack")
    # dossier incliné en tôle jaune + coussin
    back_y = -SEAT_HD + 0.02
    b.tilted_box((0, back_y, SEAT_Z + 0.2), (SEAT_HW * 2, 0.03, 0.4), -0.18, "Yellow")
    b.tilted_box((0, back_y + 0.035, SEAT_Z + 0.18), (SEAT_HW * 2 - 0.08, 0.04, 0.26), -0.18, "DartBlack")
    b.finish()
    kit.save_and_export("drill_chair", budget_tris=1500)


main()
