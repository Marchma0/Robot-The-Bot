"""Wagonnet de mine plein de minerai (lobby, M12) : posé sur lobby_rails (écartement 0,7 m).

Fiche
- Taille : 1,1 m de long (Y), 0,8 m de large, 0,95 m de haut. Repère : un nain fait 1,2 m.
- Origine : au niveau du dessus des rails (0,14 m), au centre. Avance selon Y.
- Budget : 900 triangles.
- Pièces : caisse évasée (Iron) avec cerclages (Copper) et rivets, châssis (IronDark), 4 roues (IronDark)
  avec moyeux (Copper), attelages, tas de minerai (Ochre, RockDark) avec pépites (Yellow).

    blender -b --factory-startup --python blender/props/mine_cart.py
"""

import os
import random
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

GAUGE = 0.35


def main():
    kit.new_scene()
    rng = random.Random(8)
    b = kit.Builder("MineCart")
    # roues sur les rails (centre des roues à 0,13 m au-dessus du rail)
    for y in (-0.33, 0.33):
        for x in (-GAUGE, GAUGE):
            b.cylinder((x - 0.04, y, 0.13), (x + 0.04, y, 0.13), 0.13, "IronDark", segments=10)
            b.cylinder((x - 0.06 if x < 0 else x + 0.04, y, 0.13), (x - 0.04 if x < 0 else x + 0.06, y, 0.13),
                       0.05, "Copper", segments=6)
        b.cylinder((-GAUGE - 0.055, y, 0.13), (GAUGE + 0.055, y, 0.13), 0.025, "Iron", segments=5)
    # châssis + attelages
    b.box((-0.32, -0.5, 0.2), (0.32, 0.5, 0.27), "IronDark")
    for s in (-1.0, 1.0):
        b.box((-0.05, s * 0.5, 0.21), (0.05, s * 0.62, 0.26), "IronDark")
    # caisse évasée
    b.frustum((0.0, 0.0), 0.27, 0.86, (0.34, 0.48), (0.42, 0.56), "Iron")
    for z in (0.4, 0.75):
        t = (z - 0.27) / 0.59
        hx, hy = 0.34 + 0.08 * t + 0.012, 0.48 + 0.08 * t + 0.012
        b.frustum((0.0, 0.0), z, z + 0.05, (hx, hy), (hx + 0.007, hy + 0.007), "Copper")
    # tas de minerai qui dépasse
    for _ in range(9):
        x, y = rng.uniform(-0.25, 0.25), rng.uniform(-0.38, 0.38)
        s = rng.uniform(0.18, 0.3)
        b.rock((x, y, 0.88 + s * 0.2), (s, s, s * 0.8), rng.choice(("Ochre", "RockDark")), jitter=0.25,
               rng=rng, flat_bottom=False)
    for _ in range(4):
        x, y = rng.uniform(-0.2, 0.2), rng.uniform(-0.3, 0.3)
        b.rock((x, y, 1.0), (0.09, 0.09, 0.08), "Yellow", jitter=0.25, rng=rng, flat_bottom=False)
    b.finish()
    kit.save_and_export("mine_cart", budget_tris=900)


main()
