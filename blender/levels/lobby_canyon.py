"""Lobby (M12) : fond de canyon du camp minier, au soleil couchant.

Fiche
- Taille : sol de 52 m x 96 m (x : -26..26, y : -32..64) prolongé par un désert (y : 64..170), falaises de 13 à 20 m de haut.
  Repères : un nain fait 1,2 m, le robot ~8,5 m. Le robot est garé à l'origine, face à +Y (la sortie du canyon).
- Budget : 9000 triangles.
- Pièces : sol de sable (Sand) avec sentiers tassés (Terracotta) ; falaises en strates de blocs facettés
  (Terracotta, Ochre, Sand, RockDark), qui se resserrent vers la sortie (+Y) ; fond arrondi derrière le camp (-Y) ;
  arche naturelle au-dessus de la sortie ; mesas lointaines vues par la sortie ; rochers et buissons secs (Scrub).
- Collisions : boîtes `*-colonly` (sol + murs) : Godot en fait des corps statiques invisibles.
- Placé dans scenes/levels/lobby.tscn à l'origine, sans rotation.

    blender -b --factory-startup --python blender/levels/lobby_canyon.py
"""

import math
import os
import random
import sys

import bpy

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

FLOOR_X = 26.0
FLOOR_Y0, FLOOR_Y1 = -32.0, 64.0
STRATA = ["Terracotta", "Ochre", "Sand", "Ochre", "RockDark"]


def half_width(y: float) -> float:
    """Demi-largeur du canyon (bord intérieur des falaises) : large au camp, étroit à la sortie."""
    if y < 26.0:
        return 20.0
    if y < 46.0:
        return 20.0 - (y - 26.0) / 20.0 * 8.5
    if y < 62.0:
        return 11.5
    return 11.5 + (y - 62.0) * 0.9   # à la sortie, les falaises s'écartent sur le désert


def cliff_column(b, rng, x_inner: float, side: float, y: float, step: float, height: float) -> None:
    """Une colonne de falaise : blocs empilés en strates, chaque strate un peu en retrait."""
    z = 0.0
    layer = 0
    while z < height:
        h = rng.uniform(2.6, 4.6)
        recess = layer * rng.uniform(0.5, 1.1)
        depth = rng.uniform(7.0, 10.0)
        x0 = x_inner + side * recess
        cx = x0 + side * depth / 2.0
        b.rock((cx, y, z + h / 2.0), (depth, step * 1.25, h * 1.08), STRATA[layer % len(STRATA)],
               jitter=0.09, rng=rng, flat_bottom=(layer == 0))
        z += h
        layer += 1


def main():
    kit.new_scene()
    rng = random.Random(12)
    b = kit.Builder("LobbyCanyon")

    # Sol + sentiers tassés (0,02 m plus haut : pas dans le plan du sable)
    b.box((-FLOOR_X, FLOOR_Y0, -0.3), (FLOOR_X, FLOOR_Y1, 0.0), "Sand")
    b.box((-70.0, FLOOR_Y1, -0.3), (70.0, 170.0, 0.0), "Sand")           # désert au-delà de la sortie
    b.box((-1.8, -12.0, 0.0), (1.8, 60.0, 0.02), "Terracotta")          # allée centrale vers la sortie
    b.box((-14.0, -3.0, 0.0), (-1.8, 0.4, 0.02), "Terracotta")          # vers les fléchettes / tentes
    b.box((1.8, -3.0, 0.0), (14.0, 0.4, 0.02), "Terracotta")            # vers le bras de fer / feu de camp

    # Falaises gauche et droite, qui se resserrent vers la sortie
    step = 4.0
    y = FLOOR_Y0 + 4.0
    while y <= FLOOR_Y1 + 16.0:
        hw = half_width(y)
        for side in (-1.0, 1.0):
            height = rng.uniform(13.0, 20.0)
            cliff_column(b, rng, side * (hw + rng.uniform(-0.6, 0.6)), side, y, step, height)
        y += step

    # Fond arrondi derrière le camp (demi-cercle de colonnes)
    for i in range(11):
        a = math.pi * (i + 0.5) / 11.0
        r = 20.5
        px, py = math.cos(a) * r, -26.0 - math.sin(a) * 6.0
        height = rng.uniform(15.0, 21.0)
        z = 0.0
        layer = 0
        while z < height:
            h = rng.uniform(2.8, 4.6)
            b.rock((px * (1.0 + layer * 0.04), py - layer * 0.8, z + h / 2.0), (6.5, 8.0, h * 1.08),
                   STRATA[layer % len(STRATA)], jitter=0.09, rng=rng, flat_bottom=(layer == 0))
            z += h
            layer += 1

    # Arche naturelle au-dessus de la sortie (repère qu'on voit depuis le camp)
    for side in (-1.0, 1.0):
        for k in range(4):
            b.rock((side * 9.0, 52.0, 1.8 + k * 3.4), (3.6 - k * 0.3, 3.4, 3.6), STRATA[k % 4], jitter=0.12,
                   rng=rng, flat_bottom=(k == 0))
    for k in range(6):
        t = (k + 0.5) / 6.0
        x = -9.0 + t * 18.0
        z = 14.2 + math.sin(t * math.pi) * 2.2
        b.rock((x, 52.0, z), (3.6, 3.2, 2.6), STRATA[(k + 1) % 4], jitter=0.12, rng=rng, flat_bottom=False)

    # Mesas lointaines, vues par la sortie
    for (mx, my, mw, mh) in ((-18.0, 92.0, 22.0, 16.0), (14.0, 104.0, 26.0, 22.0), (-2.0, 120.0, 18.0, 12.0)):
        b.frustum((mx, my), 0.0, mh * 0.75, (mw / 2, 6.0), (mw / 2 - 2.0, 5.0), "Terracotta")
        b.frustum((mx, my), mh * 0.75, mh, (mw / 2 - 2.0, 5.0), (mw / 2 - 3.0, 4.2), "Ochre")

    # Rochers éboulés au pied des falaises + buissons secs
    for _ in range(26):
        yy = rng.uniform(FLOOR_Y0 + 6.0, 58.0)
        side = rng.choice((-1.0, 1.0))
        xx = side * (half_width(yy) - rng.uniform(0.8, 3.5))
        s = rng.uniform(0.7, 2.2)
        b.rock((xx, yy, s * 0.4), (s * 1.3, s, s * 0.8), rng.choice(("RockDark", "Terracotta", "Ochre")),
               jitter=0.2, rng=rng)
    for _ in range(30):
        yy = rng.uniform(FLOOR_Y0 + 6.0, 60.0)
        xx = rng.uniform(-half_width(yy) + 1.0, half_width(yy) - 1.0)
        if abs(xx) < 3.0 or (abs(xx) < 16.0 and -16.0 < yy < 14.0):
            continue   # pas sur l'allée, ni au milieu du camp
        s = rng.uniform(0.35, 0.7)
        b.rock((xx, yy, s * 0.35), (s * 1.2, s * 1.2, s * 0.7), "Scrub", jitter=0.25, rng=rng)
    b.finish()

    # Collisions (invisibles dans Godot) : sol + murs intérieurs des falaises
    def col_box(name: str, lo, hi) -> None:
        cb = kit.Builder(name + "-colonly")
        cb.box(lo, hi, "RockDark")
        cb.finish()

    col_box("FloorCol", (-FLOOR_X, FLOOR_Y0, -1.0), (FLOOR_X, FLOOR_Y1, 0.0))
    y = FLOOR_Y0
    while y < FLOOR_Y1:
        hw = min(half_width(y), half_width(y + 8.0))
        for side, tag in ((-1.0, "L"), (1.0, "R")):
            x0 = side * (hw - 0.6)
            col_box("Wall%s%d" % (tag, int(y + 40)), (x0, y, 0.0), (x0 + side * 8.0, y + 8.0, 20.0))
        y += 8.0
    col_box("WallBack", (-FLOOR_X, FLOOR_Y0 - 4.0, 0.0), (FLOOR_X, -25.0, 20.0))
    kit.save_and_export("lobby_canyon", budget_tris=9000, folder="levels", ground=False)


main()
