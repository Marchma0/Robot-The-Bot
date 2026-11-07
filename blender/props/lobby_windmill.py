"""Éolienne de ferme du camp (lobby, M12) : pylône en treillis et queue. Le rotor est lobby_windmill_rotor.py.

Fiche
- Taille : pied de 2,4 m de côté, 8,0 m de haut jusqu'à l'axe du rotor, queue de 2,2 m. Repère : un nain fait 1,2 m.
- Origine : au sol, au centre. Le rotor regarde vers +Y ; son axe est à (0, 0.45, 8.0) (lobby_windmill_rotor
  s'y place, et tourne autour de son axe Y local).
- Budget : 900 triangles.
- Pièces : 4 pieds en treillis (Iron) avec entretoises (IronDark), plateforme (Wood), nacelle (Paint),
  queue et dérive (Paint, Copper), réservoir en bois au pied (Wood, IronDark) et pompe (Copper).

    blender -b --factory-startup --python blender/props/lobby_windmill.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

BASE, TOP, HUB_Z = 1.2, 0.3, 8.0


def main():
    kit.new_scene()
    b = kit.Builder("LobbyWindmill")
    top_z = HUB_Z - 0.35
    corners = ((-1, -1), (1, -1), (1, 1), (-1, 1))
    for sx, sy in corners:
        b.cylinder((sx * BASE, sy * BASE, 0.0), (sx * TOP, sy * TOP, top_z), 0.05, "Iron", segments=5)
        b.box((sx * BASE - 0.12, sy * BASE - 0.12, 0.0), (sx * BASE + 0.12, sy * BASE + 0.12, 0.1), "RockDark")
    # entretoises horizontales et diagonales
    for k, z in enumerate((1.2, 3.2, 5.2)):
        t = z / top_z
        h = BASE + (TOP - BASE) * t
        t2 = min(1.0, (z + 2.0) / top_z)
        h2 = BASE + (TOP - BASE) * t2
        for i in range(4):
            ax, ay = corners[i]
            bx, by = corners[(i + 1) % 4]
            b.cylinder((ax * h, ay * h, z), (bx * h, by * h, z), 0.025, "IronDark", segments=4)
            if k < 2:
                b.cylinder((ax * h, ay * h, z), (bx * h2, by * h2, z + 2.0), 0.02, "IronDark", segments=4)
    # plateforme et nacelle
    b.box((-0.55, -0.55, top_z - 0.06), (0.55, 0.55, top_z), "Wood")
    b.cylinder((0.0, -0.6, HUB_Z), (0.0, 0.35, HUB_Z), 0.16, "Paint", segments=8)
    b.cylinder((0.0, 0.0, top_z), (0.0, 0.0, HUB_Z - 0.12), 0.08, "IronDark", segments=6)
    # queue + dérive
    b.cylinder((0.0, -0.6, HUB_Z), (0.0, -2.2, HUB_Z + 0.1), 0.04, "Iron", segments=5)
    b.box((-0.015, -2.9, HUB_Z - 0.35), (0.015, -2.05, HUB_Z + 0.55), "Paint")
    b.box((-0.02, -2.95, HUB_Z + 0.5), (0.02, -2.0, HUB_Z + 0.58), "Copper")
    # réservoir au pied et pompe
    b.cylinder((1.9, 0.6, 0.0), (1.9, 0.6, 1.1), 0.7, "Wood", segments=12)
    for z in (0.15, 0.95):
        b.cylinder((1.9, 0.6, z), (1.9, 0.6, z + 0.06), 0.72, "IronDark", segments=12)
    b.cylinder((0.0, 0.0, 0.0), (0.0, 0.0, 1.4), 0.05, "Copper", segments=6)
    b.pipe([(0.0, 0.0, 1.0), (1.2, 0.6, 1.0), (1.7, 0.6, 1.25)], 0.035, "Copper", "IronDark", segments=6)
    b.finish()
    kit.save_and_export("lobby_windmill", budget_tris=900)


main()
