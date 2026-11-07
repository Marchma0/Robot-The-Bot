"""Poteau de bois du camp (lobby, M12) : porte les guirlandes d'ampoules (lobby_string_lights).

Fiche
- Taille : 4,0 m de haut, traverse de 0,9 m. Repère : un nain fait 1,2 m.
- Origine : au pied du poteau. Les guirlandes s'accrochent au crochet en haut, à (0, 0, 3.75).
- Budget : 300 triangles.
- Pièces : poteau (Wood) sur socle de pierres (RockDark), traverse et jambe de force (Wood),
  crochet et isolateurs (IronDark, Copper), petite lampe à abat-jour (Lamp, IronDark).

    blender -b --factory-startup --python blender/props/lobby_light_post.py
"""

import os
import random
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402


def main():
    kit.new_scene()
    rng = random.Random(3)
    b = kit.Builder("LobbyLightPost")
    for i in range(4):
        x, y = ((0.22, 0.0), (-0.22, 0.05), (0.03, 0.22), (0.0, -0.2))[i]
        b.rock((x, y, 0.12), (0.3, 0.26, 0.24), "RockDark", jitter=0.15, rng=rng)
    b.cylinder((0.0, 0.0, 0.0), (0.0, 0.0, 4.0), 0.07, "Wood", segments=6)
    b.box((-0.45, -0.045, 3.62), (0.45, 0.045, 3.7), "Wood")
    b.cylinder((0.0, 0.0, 3.2), (0.32, 0.0, 3.62), 0.03, "Wood", segments=5)
    for x in (-0.38, 0.38):
        b.cylinder((x, 0.0, 3.7), (x, 0.0, 3.78), 0.025, "Copper", segments=6)
    b.cylinder((0.0, 0.0, 3.75), (0.0, 0.12, 3.75), 0.015, "IronDark", segments=4)
    # petite lampe sous la traverse, côté -X
    b.cylinder((-0.38, 0.0, 3.62), (-0.38, 0.0, 3.45), 0.008, "IronDark", segments=4)
    b.cylinder((-0.38, 0.0, 3.45), (-0.38, 0.0, 3.36), 0.03, "IronDark", segments=8, radius_end=0.11)
    b.sphere((-0.38, 0.0, 3.33), 0.045, "Lamp", segments=6)
    b.finish()
    kit.save_and_export("lobby_light_post", budget_tris=300)


main()
