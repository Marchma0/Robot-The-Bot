"""Mâchoire articulée de la pince du grappin (M9 — Grappin).

Fiche
- Taille : 0,38 m de large (X), 0,92 m de long (Y : de -0,08 à +0,86 m), 0,56 m de haut (Z).
- Origine : sur l'axe de pivot de la mâchoire (0, 0, 0). Instanciée deux fois sur le poignet du grappin
  (mâchoire gauche à x = -0,24 m, mâchoire droite symétrique par scale.x = -1 à x = +0,24 m).
- Budget : 600 triangles.
- Pièces : chape de pivot avec cabochons en cuivre (IronDark, Copper), 2 doigts coudés à trois phalanges
  (Iron, Copper), traverse blindée rivetée (Paint, Copper), et patins de préhension crantés orange (Cushion)
  avec griffes intérieures en acier.

    blender -b --factory-startup --python blender/props/grabber_claw.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402


def main():
    kit.new_scene()
    b = kit.Builder("GrabberClaw")

    # Modélisé pour la mâchoire GAUCHE (située en -X, qui se referme vers +X).
    # 1. Moyeu d'articulation autour de (0, 0, 0) + cabochons d'axe en cuivre
    b.box((-0.09, -0.08, -0.25), (0.09, 0.12, 0.25), "IronDark")
    b.cylinder((0.0, 0.0, -0.275), (0.0, 0.0, 0.275), 0.055, "Copper", segments=10)

    # 2. Deux doigts parallèles (z = -0.18 et z = +0.18) en arc de pince (3 segments progressifs)
    for sz in (-0.18, 0.18):
        # Segment proximal (s'écarte vers -X : y = 0.08 .. 0.36)
        b.box((-0.15, 0.08, sz - 0.055), (0.03, 0.36, sz + 0.055), "Iron")
        # Phalange intermédiaire (y = 0.32 .. 0.58)
        b.box((-0.12, 0.32, sz - 0.050), (0.08, 0.58, sz + 0.050), "Iron")
        # Articulation médiane en cuivre (y = 0.44 .. 0.54)
        b.box((-0.14, 0.44, sz - 0.062), (0.09, 0.54, sz + 0.062), "Copper")
        # Phalange distale refermée vers l'intérieur (+X) pour saisir (y = 0.54 .. 0.85)
        b.box((-0.04, 0.54, sz - 0.046), (0.16, 0.85, sz + 0.046), "Iron")
        # Patin de préhension intérieur cranté haute visibilité (Cushion)
        b.box((0.13, 0.58, sz - 0.056), (0.21, 0.86, sz + 0.056), "Cushion")

    # 3. Traverse verticale extérieure reliant les deux doigts (y = 0.16 .. 0.42)
    b.box((-0.168, 0.16, -0.22), (-0.09, 0.42, 0.22), "Paint")
    b.rivet_row((-0.168, 0.22, -0.14), (-0.168, 0.22, 0.14), (-1, 0, 0), spacing=0.14, size=0.022)
    b.rivet_row((-0.168, 0.36, -0.14), (-0.168, 0.36, 0.14), (-1, 0, 0), spacing=0.14, size=0.022)

    b.finish()
    kit.save_and_export("grabber_claw", budget_tris=600)


main()
