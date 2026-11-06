"""Porte des toilettes : tôle peinte, cadre en fer, rivets, lune découpée, poignée en cuivre.

Fiche
- Taille : 0,84 m de large, 1,38 m de haut, 4 cm d'épaisseur.
- Origine : au sol, sur l'axe des gonds. Porte fermée : elle s'étend vers -Y (Blender), soit +Z dans Godot,
  et sa face extérieure (côté couloir) regarde vers +X. Correspond aux nœuds de scenes/mecha/props/toilet_door.tscn.
- Budget : 1500 triangles.
- Pièces : âme (Paint), cadre (IronDark), rivets (Copper), lune (disque sombre + disque de tôle décalé), poignées.
- Le texte « WC », la collision, l'ouverture animée et la synchro réseau restent dans toilet_door.tscn.

    blender -b --factory-startup --python blender/props/toilet_door.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

W, H, T = 0.84, 1.38, 0.04
F = 0.045     # largeur du cadre
P = 0.005     # relief du cadre


def main():
    kit.new_scene()
    b = kit.Builder("ToiletDoor")
    x0, x1 = -T / 2, T / 2
    y0, y1 = -W, 0.0
    b.box((x0, y0, 0.0), (x1, y1, H), "Paint")
    # cadre des deux côtés
    for (ya, yb, za, zb) in (
        (y0, y1, 0.0, F), (y0, y1, H - F, H),           # traverses basse / haute
        (y0, y0 + F, 0.0, H), (y1 - F, y1, 0.0, H),     # montants
        (y0, y1, 0.62, 0.62 + F * 0.8),                 # traverse du milieu
    ):
        b.box((x0 - P, ya, za), (x1 + P, yb, zb), "IronDark")
    # rivets sur le cadre, côté couloir (+X) et côté cabine (-X)
    for face_x, normal in ((x1 + P, (1, 0, 0)), (x0 - P, (-1, 0, 0))):
        for z in (F / 2, H - F / 2, 0.62 + F * 0.4):
            b.rivet_row((face_x, y0 + 0.07, z), (face_x, y1 - 0.07, z), normal, spacing=0.1, size=0.014)
    # lune : disque sombre + disque de tôle décalé qui en cache une partie (croissant)
    b.cylinder((x1, -0.43, 1.15), (x1 + 0.006, -0.43, 1.15), 0.07, "DartBlack", segments=16)
    b.cylinder((x1, -0.46, 1.17), (x1 + 0.009, -0.46, 1.17), 0.064, "Paint", segments=16)
    # poignées des deux côtés
    for side in (1, -1):
        b.cylinder((side * x1, -0.78, 0.75), (side * (x1 + 0.03), -0.78, 0.75), 0.008, "IronDark", segments=8)
        b.sphere((side * (x1 + 0.04), -0.78, 0.75), 0.025, "Copper", segments=10)
    # gonds
    for z in (0.18, H - 0.18):
        b.cylinder((0.0, 0.012, z - 0.06), (0.0, 0.012, z + 0.06), 0.014, "Iron", segments=8)
    b.finish()
    kit.save_and_export("toilet_door", budget_tris=1500)


main()
