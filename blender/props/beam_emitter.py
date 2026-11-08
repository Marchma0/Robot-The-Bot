"""Émetteur du rayon tracteur : disque lumineux au sol du ventre (et le même, retourné, au plafond de la tête).

Fiche
- Taille : 0,84 m de diamètre, 0,10 m de haut.
- Origine : au sol, au centre ; symétrique (le câble part vers -X, vers le mur).
  Fait partie de scenes/mecha/tractor_beam.tscn : un en bas (origine du rayon), un en haut retourné.
- Budget : 900 triangles.
- Pièces : socle (IronDark) à 8 pattes boulonnées, anneau (Copper), verre lumineux (Lamp), grille radiale (Iron),
  gaine de câble vers le mur.

    blender -b --factory-startup --python blender/props/beam_emitter.py
"""

import math
import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

SEG = 20


def main():
    kit.new_scene()
    b = kit.Builder("BeamEmitter")
    b.cylinder((0, 0, 0.0), (0, 0, 0.05), 0.42, "IronDark", SEG, radius_end=0.4)
    b.cylinder((0, 0, 0.045), (0, 0, 0.075), 0.36, "Copper", SEG)
    b.cylinder((0, 0, 0.075), (0, 0, 0.09), 0.3, "Lamp", SEG)
    # grille radiale au-dessus du verre
    for k in range(6):
        a = k * math.pi / 6
        p0 = (math.cos(a) * 0.29, math.sin(a) * 0.29, 0.093)
        p1 = (-math.cos(a) * 0.29, -math.sin(a) * 0.29, 0.093)
        b.cylinder(p0, p1, 0.006, "Iron", 4)
    b.cylinder((0, 0, 0.088), (0, 0, 0.1), 0.05, "IronDark", 10)
    # pattes boulonnées autour du socle
    for k in range(8):
        a = k * math.tau / 8 + math.pi / 8
        cx, cy = math.cos(a) * 0.44, math.sin(a) * 0.44
        b.box((cx - 0.035, cy - 0.035, 0.0), (cx + 0.035, cy + 0.035, 0.015), "IronDark")
        b.cylinder((cx, cy, 0.015), (cx, cy, 0.025), 0.012, "Copper", 6)
    # gaine de câble vers le mur (-X)
    b.box((-0.75, -0.05, 0.0), (-0.41, 0.05, 0.03), "IronDark")
    b.box((-0.75, -0.035, 0.03), (-0.41, 0.035, 0.036), "Yellow")
    b.finish()
    kit.save_and_export("beam_emitter", budget_tris=900)


main()
