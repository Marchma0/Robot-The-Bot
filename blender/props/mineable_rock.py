"""Colonne rocheuse minable incrustée de veines de minerai (M8 — Foreuse).

Fiche
- Taille : 1,85 m de large (X), 1,78 m de profondeur (Y), 4,50 m de haut (Z).
  Repère : un nain fait 1,2 m ; la foreuse du mécha est à ~3,4..3,95 m de hauteur.
  Origine au sol, au centre (0, 0, 0) ; l'avant regarde vers +Y.
- Budget : 900 triangles.
- Pièces : socle rocheux massif au sol (IronDark, FloorPlate, Rust), fût rocheux escarpé composé de strates
  et de blocs inclinés jusqu'à 4,5 m de haut (FloorPlate, IronDark, Patch, Rust) pour que la foreuse attaque
  le cœur du filon en hauteur, et riches cristaux de cuivre et d'or incrustés (Copper, Yellow, Bulb).

    blender -b --factory-startup --python blender/props/mineable_rock.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402


def main():
    kit.new_scene()
    b = kit.Builder("MineableRock")

    # 1. Socle rocheux évasé au sol (z = 0.0 .. 1.15)
    b.frustum((0.0, 0.0), 0.0, 1.15, (0.88, 0.84), (0.74, 0.70), "IronDark")
    b.frustum((-0.46, 0.34), 0.004, 1.35, (0.46, 0.40), (0.32, 0.28), "FloorPlate")
    b.frustum((0.48, -0.32), 0.008, 1.25, (0.42, 0.44), (0.30, 0.32), "Rust")
    b.frustum((0.38, 0.38), 0.012, 1.10, (0.38, 0.36), (0.26, 0.24), "Patch")

    # 2. Colonne minérale centrale (z = 1.15 .. 4.45) à hauteur de la foreuse du mécha (z = 3.0 .. 4.1)
    b.frustum((0.03, -0.02), 1.15, 2.65, (0.72, 0.68), (0.60, 0.56), "FloorPlate")
    b.frustum((-0.02, 0.03), 2.65, 3.95, (0.58, 0.54), (0.44, 0.40), "IronDark")
    b.frustum((0.0, 0.0), 3.95, 4.45, (0.40, 0.36), (0.22, 0.20), "FloorPlate")

    # Blocs rocheux obliques sur les flancs pour casser la symétrie
    b.tilted_box((-0.48, -0.16, 1.85), (0.56, 0.62, 1.15), 0.22, "IronDark")
    b.tilted_box((0.44, 0.20, 2.25), (0.54, 0.56, 1.20), -0.24, "Patch")
    b.tilted_box((-0.16, 0.42, 2.95), (0.62, 0.52, 1.10), 0.18, "Rust")
    b.tilted_box((0.18, -0.38, 3.20), (0.56, 0.48, 1.05), -0.20, "IronDark")

    # 3. Veines et cristaux de minerai (surtout concentrés entre z = 2.6 et z = 4.2, face à la foreuse)
    b.tilted_box((0.10, 0.56, 3.35), (0.38, 0.34, 0.58), 0.28, "Copper")
    b.tilted_box((-0.24, 0.50, 3.65), (0.30, 0.28, 0.46), -0.26, "Yellow")
    b.tilted_box((0.0, 0.52, 2.85), (0.28, 0.26, 0.40), 0.18, "Bulb")
    b.tilted_box((0.32, -0.48, 3.40), (0.36, 0.30, 0.52), -0.30, "Copper")
    b.tilted_box((-0.52, 0.08, 3.50), (0.30, 0.28, 0.48), 0.32, "Yellow")
    b.tilted_box((0.48, -0.06, 3.10), (0.28, 0.30, 0.44), -0.25, "Copper")
    b.tilted_box((0.14, 0.12, 1.65), (0.32, 0.28, 0.46), 0.24, "Copper")
    b.tilted_box((-0.28, -0.44, 1.95), (0.26, 0.26, 0.40), -0.22, "Yellow")
    b.tilted_box((0.04, 0.02, 4.38), (0.24, 0.24, 0.32), -0.20, "Bulb")

    b.finish()
    kit.save_and_export("mineable_rock", budget_tris=900)


main()
