"""Caisse de ravitaillement / minerai ramassable pour le sac à dos (M10 — Inventaire).

Fiche
- Taille : 0,68 m de large, 0,68 m de profondeur, 0,68 m de haut (échelle d'un objet attrapable au grappin).
- Origine : au sol, au centre (0, 0, 0) ; l'avant regarde vers +Y.
- Budget : 600 triangles.
- Pièces : caisse en bois (Wood) creusée sur le dessus, cadre supérieur ouvert et cornières en fer (IronDark),
  poignées et rivets en cuivre (Copper), cristaux / pépites de minerai inclinés (Yellow, Copper, Iron).

    blender -b --factory-startup --python blender/props/cargo_crate.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

S = 0.32          # demi-largeur de la caisse (0,64 m)
H = 0.52          # hauteur de la caisse


def main():
    kit.new_scene()
    b = kit.Builder("CargoCrate")

    t = 0.045
    p = 0.012
    o = S + p         # demi-largeur extérieure du cadre (0,332 m)
    i = S - 0.035     # demi-largeur intérieure de l'ouverture haute (0,285 m)

    # 1. Socle inférieur plein en fer + corps en bois
    b.box((-o, -o, 0.0), (o, o, t), "IronDark")
    b.box((-S, -S, t), (S, S, H - t), "Wood")

    # 2. Cadre supérieur ouvert (4 barres en fer autour du plateau en bois)
    b.box((-o, -o, H - t), (o, -i, H), "IronDark")
    b.box((-o, i, H - t), (o, o, H), "IronDark")
    b.box((-o, -i, H - t), (-i, i, H), "IronDark")
    b.box((i, -i, H - t), (o, i, H), "IronDark")

    # 3. Cornières verticales aux 4 coins
    for sx in (-1, 1):
        for sy in (-1, 1):
            x0 = -o if sx < 0 else (o - t)
            x1 = (-o + t) if sx < 0 else o
            y0 = -o if sy < 0 else (o - t)
            y1 = (-o + t) if sy < 0 else o
            b.box((x0, y0, t + 0.002), (x1, y1, H - t - 0.002), "IronDark")

    # 4. Poignées latérales en cuivre et étiquette avant (+Y)
    for sx in (-1, 1):
        px = sx * o
        b.box((px - 0.016, -0.11, 0.24), (px + 0.016, 0.11, 0.30), "Copper")
    b.box((-0.14, S, 0.20), (0.14, S + 0.010, 0.32), "WallCream")

    # 5. Pépites / cristaux de minerai posés sur le bois en haut (z = H - t = 0.475)
    z_bed = H - t
    b.tilted_box((-0.08, -0.05, z_bed + 0.06), (0.22, 0.20, 0.18), 0.18, "Copper")
    b.tilted_box((0.09, 0.04, z_bed + 0.08), (0.18, 0.18, 0.22), -0.22, "Yellow")
    b.box((-0.16, 0.06, z_bed), (-0.01, 0.21, z_bed + 0.13), "Iron")

    b.finish()
    kit.save_and_export("cargo_crate", budget_tris=600)


main()
