"""Rotor de l'éolienne du camp (lobby, M12) : tourne au vent dans Godot (autour de son axe Y).

Fiche
- Taille : 2,9 m de diamètre, 0,3 m d'épaisseur. Repère : un nain fait 1,2 m.
- Origine : au centre du moyeu, axe de rotation = Y (devient -Z dans Godot). Se place à (0, 0.45, 8.0)
  dans lobby_windmill.
- Budget : 700 triangles.
- Pièces : moyeu (Copper), 16 pales inclinées (Paint et Cream en alternance), 2 cerclages (Iron).

    blender -b --factory-startup --python blender/props/lobby_windmill_rotor.py
"""

import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

BLADES, R_IN, R_OUT = 16, 0.35, 1.45


def main():
    kit.new_scene()
    b = kit.Builder("LobbyWindmillRotor")
    b.cylinder((0.0, -0.12, 0.0), (0.0, 0.18, 0.0), 0.16, "Copper", segments=10)
    b.cylinder((0.0, 0.18, 0.0), (0.0, 0.28, 0.0), 0.1, "IronDark", segments=8, radius_end=0.03)
    for i in range(BLADES):
        a = i / BLADES * math.tau
        # pale : plaque fine dressée selon Z (de R_IN à R_OUT), élargie vers l'extérieur,
        # vrillée de 25° autour de son axe, puis tournée autour de l'axe du rotor (Y)
        verts_before = len(b.bm.verts)
        b.frustum((0.0, 0.0), R_IN, R_OUT, (0.07, 0.012), (0.17, 0.012), "Paint" if i % 2 == 0 else "Cream")
        b.bm.verts.ensure_lookup_table()
        new = [b.bm.verts[k] for k in range(verts_before, len(b.bm.verts))]
        twist = Matrix.Rotation(math.radians(25.0), 4, "Z")
        spin = Matrix.Rotation(a, 4, "Y")
        for v in new:
            v.co = (spin @ (twist @ v.co.to_4d())).to_3d()
    for r in (0.8, 1.42):
        # cerclage en 16 segments
        pts = [(math.cos(k / 16 * math.tau) * r, 0.02, math.sin(k / 16 * math.tau) * r) for k in range(17)]
        for p0, p1 in zip(pts, pts[1:]):
            b.cylinder(p0, p1, 0.02, "Iron", segments=4)
    b.finish()
    kit.save_and_export("lobby_windmill_rotor", budget_tris=700)


main()
