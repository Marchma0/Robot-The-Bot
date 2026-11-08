"""Horloge murale ronde avec une petite cloche, au mur avant du salon (ventre du mécha).

Fiche
- Taille : 0,34 m de diamètre (0,44 m de haut avec la cloche), 5 cm d'épaisseur.
- Origine : sur le mur, au centre du cadran ; l'avant regarde vers +Y (l'arrière est contre le mur, en y = 0).
  Placée en Godot (0.0, 4.75, -1.9), tournée vers l'arrière du mécha (vers la pièce).
- Budget : 900 triangles.
- Pièces : boîtier (IronDark), lunette (Copper), cadran (Cream), 12 graduations, aiguilles (IronDark)
  à 10 h 10, axe (Copper), cloche et marteau sur le dessus.

    blender -b --factory-startup --python blender/props/wall_clock.py
"""

import math
import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

SEG = 20


def hand(b, angle_deg, length, width, y, mat):
    """Aiguille : fin cylindre aplati du centre vers l'angle donné (0° = midi, sens horaire)."""
    a = math.radians(angle_deg)
    tip = (math.sin(a) * length, y, math.cos(a) * length)
    b.cylinder((0, y, 0), tip, width, mat, 4)


def main():
    kit.new_scene()
    b = kit.Builder("WallClock")
    b.cylinder((0, 0.0, 0), (0, 0.035, 0), 0.17, "IronDark", SEG)
    b.cylinder((0, 0.035, 0), (0, 0.042, 0), 0.17, "Copper", SEG)
    b.cylinder((0, 0.042, 0), (0, 0.045, 0), 0.15, "Cream", SEG)
    for k in range(12):
        a = k * math.tau / 12
        long = k % 3 == 0
        r0, r1 = (0.11 if long else 0.125), 0.14
        b.cylinder((math.sin(a) * r0, 0.045, math.cos(a) * r0), (math.sin(a) * r1, 0.045, math.cos(a) * r1),
                   0.006 if long else 0.004, "IronDark", 4)
    hand(b, 300, 0.08, 0.008, 0.047, "IronDark")    # heures : 10 h
    hand(b, 60, 0.12, 0.005, 0.051, "IronDark")     # minutes : 10
    b.cylinder((0, 0.045, 0), (0, 0.056, 0), 0.012, "Copper", 8)
    # cloche sur le dessus
    b.box((-0.01, 0.01, 0.165), (0.01, 0.03, 0.2), "Copper")
    b.cylinder((0, 0.02, 0.19), (0, 0.02, 0.25), 0.045, "Copper", 12, radius_end=0.02)
    b.sphere((0, 0.02, 0.255), 0.012, "Copper", 6)
    b.box((0.03, 0.015, 0.2), (0.06, 0.025, 0.21), "IronDark")
    b.finish()
    kit.save_and_export("wall_clock", budget_tris=900)


main()
