"""Guirlande d'ampoules entre deux poteaux du camp (lobby, M12).

Fiche
- Taille : 8,0 m de long (Y, de 0 à 8), flèche de 0,6 m au milieu. Repère : un nain fait 1,2 m.
- Origine : au premier crochet. Se pose entre deux lobby_light_post espacés de 8 m
  (origine au crochet du premier, à 3,75 m du sol).
- Budget : 900 triangles.
- Pièces : câble noir en chaînette (DartBlack), 11 douilles (IronDark) et ampoules allumées (Bulb).

    blender -b --factory-startup --python blender/props/lobby_string_lights.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

LENGTH, SAG, SEGMENTS, BULBS = 8.0, 0.6, 12, 11


def point(t: float):
    return (0.0, t * LENGTH, -SAG * 4.0 * t * (1.0 - t))


def main():
    kit.new_scene()
    b = kit.Builder("LobbyStringLights")
    pts = [point(i / SEGMENTS) for i in range(SEGMENTS + 1)]
    for a, c in zip(pts, pts[1:]):
        b.cylinder(a, c, 0.008, "DartBlack", segments=4)
    for i in range(BULBS):
        t = (i + 1) / (BULBS + 1)
        x, y, z = point(t)
        b.cylinder((x, y, z), (x, y, z - 0.07), 0.016, "IronDark", segments=6)
        b.sphere((x, y, z - 0.11), 0.045, "Bulb", segments=6)
    b.finish()
    kit.save_and_export("lobby_string_lights", budget_tris=900)


main()
