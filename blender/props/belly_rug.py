"""Tapis rectangulaire du salon (ventre du mécha), sous la table basse.

Fiche
- Taille : 1,85 x 1,40 m, 1,6 cm d'épaisseur avec les motifs (plat : pas de collision).
- Origine : au sol, au centre ; long côté selon X. Placé en Blender (-0.33, 0.1, 2.6) = Godot (-0.33, 2.6, -0.1).
- Budget : 700 triangles.
- Pièces : fond (Rug), bordure (RugTrim), losange central en gradins (Cushion, RugTrim),
  motifs dans les coins, franges aux deux bouts. Chaque couche 1 à 2 mm plus haut que la précédente.

    blender -b --factory-startup --python blender/props/belly_rug.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HX, HY = 0.925, 0.70
T = 0.008


def frame(b, hx, hy, w, z0, z1, mat):
    """Cadre rectangulaire (4 bandes) de demi-tailles hx, hy et de largeur w."""
    b.box((-hx, -hy, z0), (hx, -hy + w, z1), mat)
    b.box((-hx, hy - w, z0), (hx, hy, z1), mat)
    b.box((-hx, -hy + w, z0), (-hx + w, hy - w, z1), mat)
    b.box((hx - w, -hy + w, z0), (hx, hy - w, z1), mat)


def main():
    kit.new_scene()
    b = kit.Builder("BellyRug")
    b.box((-HX, -HY, 0.0), (HX, HY, T), "Rug")
    frame(b, HX - 0.07, HY - 0.07, 0.055, T, T + 0.002, "RugTrim")
    frame(b, HX - 0.16, HY - 0.16, 0.02, T, T + 0.002, "RugTrim")
    # losange central en gradins (croix de plus en plus petite)
    for i, (w, h, mat) in enumerate(((0.36, 0.08, "Cushion"), (0.26, 0.16, "Cushion"),
                                     (0.16, 0.26, "Cushion"), (0.08, 0.34, "Cushion"))):
        b.box((-w, -h, T), (w, h, T + 0.002), mat)
    b.box((-0.07, -0.07, T + 0.002), (0.07, 0.07, T + 0.004), "RugTrim")
    b.box((-0.025, -0.025, T + 0.004), (0.025, 0.025, T + 0.006), "Rug")
    # petits carrés dans les coins
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * (HX - 0.26), sy * (HY - 0.26)
            b.box((cx - 0.04, cy - 0.04, T), (cx + 0.04, cy + 0.04, T + 0.002), "Cushion")
    # franges sur les petits côtés
    for sx in (-1, 1):
        x0 = sx * HX
        for i in range(12):
            y = -HY + 0.06 + i * (2 * HY - 0.12) / 11
            b.box((min(x0, x0 + sx * 0.05), y - 0.008, 0.0), (max(x0, x0 + sx * 0.05), y + 0.008, 0.004), "Cream")
    b.finish()
    kit.save_and_export("belly_rug", budget_tris=700)


main()
