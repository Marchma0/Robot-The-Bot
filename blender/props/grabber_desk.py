"""Bureau du poste du grappin (tête du mécha) : plateau sur pieds, caisson à tiroirs, une tasse.

Fiche
- Taille : 0,84 m x 0,44 m, plateau à 0,46 m (même hauteur que l'ancien : le cadre de l'écran reste posé dessus).
- Origine : au sol, au centre ; le pilote est du côté +Y. Placé tourné de 180° :
  Blender (-1.1, 1.55, 5.6) = Godot (-1.1, 5.6, -1.55).
- Budget : 1500 triangles.
- Pièces : plateau (Paint) avec chant en cuivre, 2 pieds et une traverse (IronDark), caisson à 2 tiroirs à gauche
  du pilote (poignées en cuivre), panneau de fond, tasse (Cream).
- Le cadre de l'écran et l'écran restent dans mecha.blend / seat.tscn. Collision : Hull/GrabberDesk (inchangée).

    blender -b --factory-startup --python blender/props/grabber_desk.py
"""

import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

W, D = 0.84, 0.44
TOP_Z, TOP_T = 0.46, 0.04


def main():
    kit.new_scene()
    b = kit.Builder("GrabberDesk")
    hw, hd = W / 2, D / 2
    # plateau + chant en cuivre côté pilote
    b.box((-hw, -hd, TOP_Z - TOP_T), (hw, hd, TOP_Z), "Paint")
    b.box((-hw, hd, TOP_Z - TOP_T), (hw, hd + 0.008, TOP_Z - 0.005), "Copper")
    # caisson à tiroirs : à gauche du pilote. Le pilote regarde vers -Y local (bureau tourné de 180°),
    # sa gauche est donc en +X local.
    cx0, cx1 = hw - 0.3, hw - 0.02
    b.box((cx0, -hd + 0.02, 0.03), (cx1, hd - 0.02, TOP_Z - TOP_T), "Paint")
    b.box((cx0 - 0.005, -hd + 0.02, 0.0), (cx1 + 0.005, hd - 0.02, 0.03), "IronDark")
    for z0, z1 in ((0.05, 0.2), (0.22, 0.39)):
        b.box((cx0 + 0.02, hd - 0.02, z0), (cx1 - 0.02, hd - 0.005, z1), "Patch")
        b.box(((cx0 + cx1) / 2 - 0.05, hd - 0.005, (z0 + z1) / 2 - 0.008),
              ((cx0 + cx1) / 2 + 0.05, hd + 0.015, (z0 + z1) / 2 + 0.008), "Copper")
    # pieds de l'autre côté + traverse + panneau de fond
    for y in (-hd + 0.04, hd - 0.04):
        b.box((-hw + 0.03, y - 0.02, 0.0), (-hw + 0.07, y + 0.02, TOP_Z - TOP_T), "IronDark")
    b.box((-hw + 0.03, -hd + 0.04, 0.08), (-hw + 0.07, hd - 0.04, 0.11), "IronDark")
    b.box((-hw + 0.07, -hd + 0.01, 0.12), (cx0, -hd + 0.03, TOP_Z - TOP_T), "IronDark")
    b.rivet_row((-hw + 0.1, -hd + 0.01, 0.15), (cx0 - 0.03, -hd + 0.01, 0.15), (0, -1, 0), spacing=0.1, size=0.012)
    # tasse posée à droite du pilote (-X local), loin de l'écran
    mx, my = -hw + 0.12, hd - 0.12
    b.cylinder((mx, my, TOP_Z), (mx, my, TOP_Z + 0.08), 0.035, "Cream", segments=10)
    b.cylinder((mx - 0.05, my, TOP_Z + 0.04), (mx - 0.035, my, TOP_Z + 0.04), 0.018, "Cream", segments=6)
    b.finish()
    kit.save_and_export("grabber_desk", budget_tris=1500)


main()
