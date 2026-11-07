"""Terminal de mission devant le robot (lobby, M12.1) : petit écran + pupitre à 3 boutons.

Fiche
- Taille : 1,1 m de large (X), 0,7 m de profondeur (Y), pupitre à 0,62 m, écran centré à 0,92 m
  (les yeux d'un nain sont à 0,95 m), antenne à 1,5 m. Repère : un nain fait 1,2 m.
- Origine : au sol, au centre. Le joueur se tient côté +Y (le terminal lui fait face).
- Budget : 1600 triangles.
- Pièces : socle (IronDark) et caisson (Paint) à bande de danger (Yellow, DartBlack), pupitre incliné (Iron)
  avec 2 logements de flèches (IronDark) et leurs triangles peints (Yellow), logement du bouton de lancement
  cerclé de danger (DartBlack, Yellow), boîtier d'écran (IronDark) à cadre en cuivre, antenne (Iron)
  avec voyant (Lamp), câbles (DartBlack).
- Les boutons eux-mêmes (PushButton) et l'écran (quad `Screen`) sont dans scenes/props/mission_terminal.tscn :
  voir BUTTONS et SCREEN ci-dessous pour leurs places exactes.

    blender -b --factory-startup --python blender/props/mission_terminal.py
"""

import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HX, HY, BODY_TOP = 0.55, 0.35, 0.56
# Pupitre : boîte inclinée de -14° (dessus tourné vers le joueur).
DESK_TILT = math.radians(-14.0)
DESK_CENTER = Vector((0.0, 0.2, 0.6))
DESK_SIZE = (1.0, 0.34, 0.05)
# Boutons (x le long du pupitre). Le joueur est côté +Y : sa gauche est en +X. De gauche à droite
# pour lui : flèche « précédent » (pointe vers sa gauche), flèche « suivant », bouton de lancement.
BUTTONS = {"prev": 0.38, "next": 0.16, "launch": -0.26}
# Écran : centre, inclinaison (vers le haut), taille du quad dans Godot.
SCREEN_CENTER = Vector((0.0, -0.05, 0.92))
SCREEN_TILT = math.radians(18.0)
SCREEN_W, SCREEN_H = 0.52, 0.34


def desk_matrix() -> Matrix:
    return Matrix.Translation(DESK_CENTER) @ Matrix.Rotation(DESK_TILT, 4, "X")


def desk_point(x: float, along: float = 0.0, height: float = 0.0) -> Vector:
    """Point sur le dessus du pupitre : x le long, `along` vers le haut de la pente, `height` au-dessus."""
    return desk_matrix() @ Vector((x, -along, DESK_SIZE[2] / 2 + height))


def desk_normal() -> Vector:
    return (Matrix.Rotation(DESK_TILT, 4, "X") @ Vector((0, 0, 1, 0))).to_3d()


def flat_triangle(b, x: float, along: float, size: float, pointing: float, mat: str) -> None:
    """Triangle peint posé sur le pupitre (épaisseur 4 mm), pointe vers +X (pointing=1) ou -X (-1)."""
    m = desk_matrix()
    z0, z1 = DESK_SIZE[2] / 2 + 0.001, DESK_SIZE[2] / 2 + 0.005
    pts = [(x + pointing * size, -along), (x - pointing * size * 0.6, -along - size * 0.8),
           (x - pointing * size * 0.6, -along + size * 0.8)]
    bottom = [b.bm.verts.new(m @ Vector((px, py, z0))) for px, py in pts]
    top = [b.bm.verts.new(m @ Vector((px, py, z1))) for px, py in pts]
    faces = [b.bm.faces.new(bottom[::-1]), b.bm.faces.new(top)]
    for i in range(3):
        j = (i + 1) % 3
        faces.append(b.bm.faces.new((bottom[i], bottom[j], top[j], top[i])))
    import bmesh
    bmesh.ops.recalc_face_normals(b.bm, faces=faces)
    index = b._index(mat)
    for f in faces:
        f.material_index = index


def main():
    kit.new_scene()
    b = kit.Builder("MissionTerminal")
    # socle + caisson + bande de danger (côté joueur)
    b.box((-HX, -HY, 0.0), (HX, HY, 0.06), "IronDark")
    b.box((-HX + 0.03, -HY + 0.03, 0.06), (HX - 0.03, HY - 0.03, BODY_TOP), "Paint")
    n = 10
    for i in range(n):
        x0 = -HX + 0.03 + (2 * HX - 0.06) * i / n
        x1 = -HX + 0.03 + (2 * HX - 0.06) * (i + 1) / n
        b.box((x0, HY - 0.03, 0.09), (x1, HY - 0.018, 0.18), "Yellow" if i % 2 == 0 else "DartBlack")
    b.rivet_row((-HX + 0.08, HY - 0.03, 0.5), (HX - 0.08, HY - 0.03, 0.5), (0, 1, 0), spacing=0.13, size=0.018)
    # pupitre incliné
    b.tilted_box(DESK_CENTER, DESK_SIZE, DESK_TILT, "Iron")
    nrm = desk_normal()
    for key in ("prev", "next"):
        x = BUTTONS[key]
        p = desk_point(x)
        b.cylinder(p - nrm * 0.004, p + nrm * 0.012, 0.055, "IronDark", segments=10)
        flat_triangle(b, x, 0.105, 0.035, 1.0 if key == "prev" else -1.0, "Yellow")
    p = desk_point(BUTTONS["launch"])
    b.cylinder(p - nrm * 0.004, p + nrm * 0.008, 0.115, "Yellow", segments=16)
    b.cylinder(p - nrm * 0.003, p + nrm * 0.012, 0.09, "DartBlack", segments=16)
    # boîtier d'écran : sa face avant passe 4 mm derrière le centre de l'écran
    sn = Vector((0.0, math.cos(SCREEN_TILT), math.sin(SCREEN_TILT)))
    su = Vector((0.0, -math.sin(SCREEN_TILT), math.cos(SCREEN_TILT)))
    back = 0.18
    b.tilted_box(SCREEN_CENTER - sn * (back / 2 + 0.004), (SCREEN_W + 0.14, back, SCREEN_H + 0.14),
                 SCREEN_TILT, "IronDark")
    # cadre en cuivre (4 barres, de 4 mm derrière à 2 cm devant le centre de l'écran)
    def bar(dx: float, du: float, w: float, h: float) -> None:
        c = SCREEN_CENTER + Vector((dx, 0, 0)) + su * du + sn * 0.008
        b.tilted_box(c, (w, 0.024, h), SCREEN_TILT, "Copper")
    bar(0.0, SCREEN_H / 2 + 0.03, SCREEN_W + 0.12, 0.06)
    bar(0.0, -SCREEN_H / 2 - 0.03, SCREEN_W + 0.12, 0.06)
    bar(-SCREEN_W / 2 - 0.03, 0.0, 0.06, SCREEN_H)
    bar(SCREEN_W / 2 + 0.03, 0.0, 0.06, SCREEN_H)
    # pied de l'écran
    b.box((-0.1, -0.2, BODY_TOP), (0.1, 0.02, 0.69), "IronDark")
    # antenne + voyant
    b.cylinder((0.42, -0.22, BODY_TOP), (0.42, -0.22, 1.46), 0.018, "Iron", segments=5)
    b.sphere((0.42, -0.22, 1.5), 0.05, "Lamp", segments=6)
    b.cylinder((0.35, -0.22, 1.2), (0.49, -0.22, 1.2), 0.01, "Copper", segments=4)
    # câbles qui partent dans le sable
    b.pipe([(0.3, -HY + 0.03, 0.3), (0.35, -0.6, 0.12), (0.5, -1.0, 0.0)], 0.025, "DartBlack", segments=6)
    b.pipe([(-0.25, -HY + 0.03, 0.25), (-0.3, -0.65, 0.07), (-0.5, -1.1, 0.0)], 0.02, "DartBlack", segments=6)
    b.finish()
    kit.save_and_export("mission_terminal", budget_tris=1600)
    # Places pour la scène Godot (Godot = Blender (x, z, -y)).
    for key, x in BUTTONS.items():
        p = desk_point(x, height=0.012)
        print("terminal : bouton %s -> Godot (%.4f, %.4f, %.4f)" % (key, p.x, p.z, -p.y))
    s = SCREEN_CENTER + sn * 0.006
    print("terminal : écran -> Godot (%.4f, %.4f, %.4f), normale Godot (0, %.4f, %.4f)"
          % (s.x, s.z, -s.y, sn.z, -sn.y))


main()
