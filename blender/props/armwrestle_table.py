"""Table de bras de fer du camp (lobby, M12) : table massive, deux coussinets, deux tonneaux-tabourets. Décor.

Fiche
- Taille : table 1,1 m (X) x 0,7 m (Y), plateau à 0,72 m (à hauteur de nain), tonneaux à 0,85 m de part
  et d'autre (X). Repère : un nain fait 1,2 m.
- Origine : au sol, au centre de la table. Les deux joueurs s'assoient côté -X et +X.
- Budget : 1100 triangles.
- Pièces : plateau épais (Wood) cerclé de fer (IronDark), 4 pieds trapus (Wood), coussinets de coude
  (Cushion), poignées à empoigner (Iron), ligne centrale (DartRed), 2 tonneaux (Wood, IronDark),
  chope posée (Cream, Copper).

    blender -b --factory-startup --python blender/props/armwrestle_table.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HX, HY, TOP = 0.55, 0.35, 0.72


def main():
    kit.new_scene()
    b = kit.Builder("ArmwrestleTable")
    b.box((-HX, -HY, TOP - 0.1), (HX, HY, TOP), "Wood")
    b.box((-HX - 0.012, -HY - 0.012, TOP - 0.08), (HX + 0.012, HY + 0.012, TOP - 0.05), "IronDark")
    for x in (-HX + 0.1, HX - 0.1):
        for y in (-HY + 0.1, HY - 0.1):
            b.box((x - 0.07, y - 0.07, 0.0), (x + 0.07, y + 0.07, TOP - 0.1), "Wood")
    b.box((-HX + 0.1, -0.03, 0.15), (HX - 0.1, 0.03, 0.22), "Wood")
    # ligne centrale, coussinets de coude et poignées
    b.box((-0.015, -HY + 0.05, TOP), (0.015, HY - 0.05, TOP + 0.004), "DartRed")
    for s in (-1.0, 1.0):
        b.cylinder((s * 0.25, 0.0, TOP), (s * 0.25, 0.0, TOP + 0.04), 0.1, "Cushion", segments=10)
        b.cylinder((s * 0.05, HY - 0.12, TOP), (s * 0.05, HY - 0.12, TOP + 0.16), 0.018, "Iron", segments=6)
    # tonneaux-tabourets
    for s in (-1.0, 1.0):
        x = s * 0.95
        b.cylinder((x, 0.0, 0.0), (x, 0.0, 0.62), 0.24, "Wood", segments=10, radius_end=0.22)
        for z in (0.08, 0.5):
            b.cylinder((x, 0.0, z), (x, 0.0, z + 0.04), 0.245 - z * 0.03, "IronDark", segments=10)
    # chope posée dans un coin
    b.cylinder((HX - 0.12, -HY + 0.12, TOP), (HX - 0.12, -HY + 0.12, TOP + 0.13), 0.04, "Cream", segments=8)
    b.cylinder((HX - 0.12, -HY + 0.12, TOP + 0.13), (HX - 0.12, -HY + 0.12, TOP + 0.15), 0.045, "Copper",
               segments=8)
    b.finish()
    kit.save_and_export("armwrestle_table", budget_tris=1100)


main()
