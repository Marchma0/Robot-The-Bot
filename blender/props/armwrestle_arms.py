"""Machine de bras de fer (lobby, M12.1) : deux avant-bras mécaniques aux poings serrés, posés sur la table.
Les joueurs, assis sur les tonneaux, martèlent leur bouton : la machine bascule vers le gagnant (animée dans Godot).

Fiche
- Taille : 0,62 m d'un coude à l'autre (X), 0,42 m de haut au-dessus de la table. Repère : un nain fait 1,2 m.
- Origine : sur le plateau, au centre de la table = pivot de bascule. L'axe de bascule est X (la ligne entre
  les deux joueurs) : les coudes sont sur cet axe et ne bougent pas, les poings partent vers ±Y.
- Budget : 700 triangles.
- Pièces : socles de coude en cuivre (Copper) sur les coussinets, articulations (IronDark), avant-bras
  mécaniques (Iron) avec vérins (Copper), poings serrés (Paint et Cream : une couleur par joueur), boulon central.

    blender -b --factory-startup --python blender/props/armwrestle_arms.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

ELBOW_X, PAD_TOP = 0.25, 0.042
FIST_Z = 0.34


def main():
    kit.new_scene()
    b = kit.Builder("ArmwrestleArms")
    for s, fist_mat in ((-1.0, "Paint"), (1.0, "Cream")):
        ex = s * ELBOW_X
        # socle de coude et articulation (axe X)
        b.cylinder((ex - 0.05, 0.0, PAD_TOP + 0.03), (ex + 0.05, 0.0, PAD_TOP + 0.03), 0.045, "IronDark", segments=10)
        b.cylinder((ex - 0.058, 0.0, PAD_TOP + 0.03), (ex - 0.05, 0.0, PAD_TOP + 0.03), 0.03, "Copper", segments=8)
        b.cylinder((ex + 0.05, 0.0, PAD_TOP + 0.03), (ex + 0.058, 0.0, PAD_TOP + 0.03), 0.03, "Copper", segments=8)
        # avant-bras : du coude vers les poings, au centre
        fx = s * 0.052
        b.cylinder((ex, 0.0, PAD_TOP + 0.03), (fx, 0.0, FIST_Z - 0.03), 0.032, "Iron", segments=8)
        b.cylinder((ex * 0.75, 0.03, PAD_TOP + 0.08), (fx * 1.4, 0.03, FIST_Z - 0.09), 0.012, "Copper", segments=5)
        # poing serré (boîte + jointures)
        b.box((fx - 0.05, -0.05, FIST_Z - 0.05), (fx + 0.05, 0.05, FIST_Z + 0.05), fist_mat)
        # jointures : 3 barrettes qui dépassent du dessus du poing
        for k in range(3):
            y = -0.03 + k * 0.03
            b.box((fx - 0.045, y - 0.011, FIST_Z + 0.05), (fx + 0.045, y + 0.011, FIST_Z + 0.062), "IronDark")
    # boulon central qui serre les deux poings
    b.cylinder((0.0, -0.07, FIST_Z), (0.0, 0.07, FIST_Z), 0.022, "Copper", segments=8)
    b.finish()
    kit.save_and_export("armwrestle_arms", budget_tris=700)


main()
