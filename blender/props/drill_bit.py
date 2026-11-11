"""Mèche rotative conique de la foreuse (M8 — Foreuse).

Fiche
- Taille : 0,74 m de diamètre à la base, 1,35 m de longueur (Y : de 0,0 à +1,35 m).
- Origine : à la base de la mèche (0, 0, 0), dans l'axe de rotation Y (devient -Z dans Godot).
  Tourne autour de son axe longitudinal quand le bouton « miner » est enclenché.
- Budget : 900 triangles.
- Pièces : tambour d'entraînement cranté (IronDark), 4 étages coniques en acier (Iron) séparés par des bagues
  de coupe en cuivre (Copper), 4 nervures de forage croisées en fer sombre (IronDark) décalées en hélice,
  et trépan de pointe en carbure doré (Yellow).

    blender -b --factory-startup --python blender/props/drill_bit.py
"""

import math
import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402


def main():
    kit.new_scene()
    b = kit.Builder("DrillBit")

    # 1. Tambour d'entraînement à la base (y = 0.0 .. 0.14)
    b.cylinder((0.0, 0.0, 0.0), (0.0, 0.14, 0.0), 0.35, "IronDark", segments=12)

    # 2. Étages coniques successifs + bagues hélicoïdales en cuivre + dents d'attaque
    stages = [
        (0.14, 0.46, 0.33, 0.26, 0.0),
        (0.49, 0.78, 0.25, 0.18, 0.42),
        (0.81, 1.08, 0.17, 0.10, 0.84),
    ]
    for y0, y1, r0, r1, twist in stages:
        b.cylinder((0.0, y0, 0.0), (0.0, y1, 0.0), r0, "Iron", segments=12, radius_end=r1)
        # Bague de coupe en cuivre entre les étages
        b.cylinder((0.0, y1, 0.0), (0.0, y1 + 0.03, 0.0), r1 + 0.022, "Copper", segments=12)
        # 4 dents / ailettes de coupe réparties à 90° avec décalage angulaire (effet spirale)
        ym = (y0 + y1) * 0.5
        rm = (r0 + r1) * 0.5
        for k in range(4):
            ang = twist + k * (math.pi * 0.5)
            cx = math.cos(ang) * (rm + 0.02)
            cz = math.sin(ang) * (rm + 0.02)
            b.box((cx - 0.042, y0 + 0.03, cz - 0.042), (cx + 0.042, y1 - 0.03, cz + 0.042), "IronDark")

    # 3. Pointe de trépan terminale (y = 1.11 .. 1.35)
    b.cylinder((0.0, 1.11, 0.0), (0.0, 1.35, 0.0), 0.095, "Yellow", segments=10, radius_end=0.012)

    b.finish()
    kit.save_and_export("drill_bit", budget_tris=900, ground=False)


main()
