"""Fléchette du jeu de fléchettes du robot (cible du salon) : on la ramasse, on la lance, elle se plante.

Fiche
- Taille : 0,21 m de long, empennage de 6 cm (fléchette de dessin animé, lisible plantée dans un casque).
  Repère d'un nain : 1,2 m.
- Origine : à la pointe. La fléchette pointe vers +Y (devient -Z dans Godot, comme un Basis.looking_at) :
  plantée, la pointe est enfoncée de 2 cm là où elle a touché.
- Budget : 300 triangles.
- Pièces : pointe (Iron), corps en cuivre (Copper), tige (DartBlack), empennage en croix (DartRed).
- Scène : scenes/mecha/props/dart.tscn (zone pour la ramasser ou la retirer d'un nain), placée par DartsGame.

    blender -b --factory-startup --python blender/props/dart.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

S = 1.4   # tout est dessiné à 0,15 m puis agrandi


def main():
    kit.new_scene()
    b = kit.Builder("Dart")
    b.cylinder((0, 0, 0), (0, -0.03 * S, 0), 0.0015 * S, "Iron", 6, radius_end=0.003 * S)          # pointe
    b.cylinder((0, -0.03 * S, 0), (0, -0.075 * S, 0), 0.0065 * S, "Copper", 8)                     # corps
    b.cylinder((0, -0.075 * S, 0), (0, -0.082 * S, 0), 0.0065 * S, "Copper", 8, radius_end=0.0035 * S)
    b.cylinder((0, -0.082 * S, 0), (0, -0.13 * S, 0), 0.0025 * S, "DartBlack", 6)                  # tige
    # empennage en croix (les deux ailettes se croisent, pas de faces dans le même plan)
    b.box((-0.022 * S, -0.15 * S, -0.0012 * S), (0.022 * S, -0.11 * S, 0.0012 * S), "DartRed")
    b.box((-0.0011 * S, -0.149 * S, -0.022 * S), (0.0011 * S, -0.111 * S, 0.022 * S), "DartRed")
    b.finish()
    kit.save_and_export("dart", budget_tris=300, ground=False)


main()
