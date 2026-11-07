"""Feu de camp avec ses bancs en rondins (lobby, M12). Les flammes sont faites dans Godot (animées).

Fiche
- Taille : cercle de 4,6 m de diamètre (bancs compris), foyer de 1,0 m. Repère : un nain fait 1,2 m.
- Origine : au sol, au centre du foyer.
- Budget : 1200 triangles.
- Pièces : cercle de pierres (RockDark, Terracotta), bûches croisées (Wood) et braises (Lamp),
  3 bancs en rondins (Wood) sur cales (RockDark), trépied et marmite (IronDark, Copper).

    blender -b --factory-startup --python blender/props/lobby_campfire.py
"""

import math
import os
import random
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402


def main():
    kit.new_scene()
    rng = random.Random(21)
    b = kit.Builder("LobbyCampfire")
    for i in range(11):
        a = i / 11 * math.tau
        b.rock((math.cos(a) * 0.55, math.sin(a) * 0.55, 0.1), (0.26, 0.22, 0.2),
               rng.choice(("RockDark", "Terracotta")), jitter=0.18, rng=rng)
    b.rock((0.0, 0.0, 0.03), (0.7, 0.7, 0.06), "Lamp", jitter=0.1, rng=rng)
    for i in range(4):
        a = i / 4 * math.pi + 0.3
        dx, dy = math.cos(a) * 0.4, math.sin(a) * 0.4
        b.cylinder((-dx, -dy, 0.07 + i * 0.03), (dx, dy, 0.12 + i * 0.03), 0.06, "Wood", segments=6)
    # bancs en rondins à 1,9 m, tournés vers le feu
    for a in (math.radians(30), math.radians(150), math.radians(270)):
        cx, cy = math.cos(a) * 1.9, math.sin(a) * 1.9
        tx, ty = -math.sin(a) * 0.75, math.cos(a) * 0.75
        b.cylinder((cx - tx, cy - ty, 0.3), (cx + tx, cy + ty, 0.3), 0.18, "Wood", segments=8)
        for s in (-0.6, 0.6):
            b.rock((cx + tx * s, cy + ty * s, 0.08), (0.24, 0.24, 0.16), "RockDark", jitter=0.12, rng=rng)
    # trépied et marmite
    for i in range(3):
        a = i / 3 * math.tau
        b.cylinder((math.cos(a) * 0.75, math.sin(a) * 0.75, 0.0), (0.0, 0.0, 1.2), 0.02, "IronDark", segments=4)
    b.cylinder((0.0, 0.0, 1.2), (0.0, 0.0, 0.78), 0.006, "IronDark", segments=4)
    b.cylinder((0.0, 0.0, 0.52), (0.0, 0.0, 0.76), 0.17, "IronDark", segments=10, radius_end=0.19)
    b.cylinder((0.0, 0.0, 0.76), (0.0, 0.0, 0.79), 0.2, "Copper", segments=10)
    b.finish()
    kit.save_and_export("lobby_campfire", budget_tris=1200)


main()
