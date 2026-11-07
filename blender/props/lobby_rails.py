"""Tronçon droit de rails de wagonnets (lobby, M12) : se met bout à bout.

Fiche
- Taille : 6,0 m de long (Y, de -3 à 3), écartement 0,7 m, 0,14 m de haut. Repère : un nain fait 1,2 m.
- Origine : au sol, au centre. On en aligne plusieurs tous les 6 m.
- Budget : 400 triangles.
- Pièces : 10 traverses en bois (Wood) légèrement irrégulières, 2 rails (Iron) sur semelles (IronDark),
  quelques tire-fonds (Copper).

    blender -b --factory-startup --python blender/props/lobby_rails.py
"""

import os
import random
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HALF, GAUGE = 3.0, 0.35


def main():
    kit.new_scene()
    rng = random.Random(5)
    b = kit.Builder("LobbyRails")
    for i in range(10):
        y = -HALF + 0.3 + i * 0.6
        w = rng.uniform(0.62, 0.7)
        b.box((-w, y - 0.09, 0.0), (w, y + 0.09, 0.06 + rng.uniform(0.0, 0.01)), "Wood")
    for x in (-GAUGE, GAUGE):
        b.box((x - 0.06, -HALF, 0.075), (x + 0.06, HALF, 0.09), "IronDark")
        b.box((x - 0.025, -HALF, 0.09), (x + 0.025, HALF, 0.14), "Iron")
        for i in range(0, 10, 3):
            y = -HALF + 0.3 + i * 0.6
            b.box((x + 0.07, y - 0.02, 0.07), (x + 0.11, y + 0.02, 0.1), "Copper")
    b.finish()
    kit.save_and_export("lobby_rails", budget_tris=400)


main()
