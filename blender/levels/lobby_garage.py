"""Lobby Garage (4.7) : grand garage industriel ultra éclairé sous la montagne.

Fiche
- Taille : salle principale de 36 m x 44 m (x : -18..18, y : -20..24), hauteur sous plafond 15 m,
  prolongée par une baie vitrée donnant sur la vallée extérieure (y : 24..75). Repères : nain 1,2 m, robot 8,5 m.
- Budget : 9500 triangles.
- Pièces : dalle d'atelier (FloorPlate) avec marquages de sécurité (Yellow, DartBlack), pont élévateur central
  sous un pont roulant (IronDark, Yellow, Copper) où le robot est garé à l'origine, passerelle métallique avec
  escalier, murs d'atelier en tôle peinte (WallTeal, WallCream, Paint) adossés à la roche (RockDark), charpente
  au plafond avec rampes de néons et projecteurs (Bulb, Lamp, Neon), grande verrière (Glass), coin forge (Copper,
  Rust, Lamp), râtelier de pièces détachées et établis.
- Collisions : boîtes `*-colonly` (sol, murs, piliers, passerelle et marches).

    blender -b --factory-startup --python blender/levels/lobby_garage.py
"""

import os
import random
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import prop_kit as kit  # noqa: E402

HX = 18.0
Y0, Y1 = -20.0, 24.0
CEIL_Z = 15.0


def main():
    kit.new_scene()
    rng = random.Random(42)
    b = kit.Builder("LobbyGarage")

    # --- 1. Sol principal de l'atelier (FloorPlate) ---
    b.box((-HX, Y0, -0.4), (HX, Y1, 0.0), "FloorPlate")

    # Tapis / allées de circulation en tôle sombre (+4 mm..+12 mm)
    b.box((-2.2, -16.0, 0.004), (2.2, 22.0, 0.012), "IronDark")
    b.box((-15.0, -6.0, 0.004), (-2.25, 6.0, 0.012), "IronDark")
    b.box((2.25, -6.0, 0.004), (15.0, 6.0, 0.012), "IronDark")

    # Bandes jaunes de guidage au sol (+6 mm..+16 mm)
    for sx in (-1.0, 1.0):
        b.box((sx * 2.35 - 0.08, -14.0, 0.006), (sx * 2.35 + 0.08, 20.0, 0.016), "Yellow")
    for sy in (-6.15, 6.15):
        b.box((-14.8, sy - 0.08, 0.006), (-2.5, sy + 0.08, 0.016), "Yellow")
        b.box((2.5, sy - 0.08, 0.006), (14.8, sy + 0.08, 0.016), "Yellow")

    # --- 2. Pont élévateur central du Robot (autour de l'origine, 0,0,0 libre pour les pieds) ---
    for sx in (-1.0, 1.0):
        b.box((sx * 3.9 - 0.25, -3.6, 0.005), (sx * 3.9 + 0.25, 3.6, 0.06), "Yellow")
        for k in range(6):
            yk = -3.0 + k * 1.1
            b.box((sx * 3.9 - 0.26, yk, 0.008), (sx * 3.9 + 0.26, yk + 0.45, 0.065), "DartBlack")
    for sy in (-1.0, 1.0):
        b.box((-3.6, sy * 3.7 - 0.25, 0.005), (3.6, sy * 3.7 + 0.25, 0.06), "Yellow")

    # 4 colonnes hydrauliques du pont élévateur aux coins (x = ±4.8, y = ±3.8)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx, cy = sx * 4.8, sy * 3.8
            b.box((cx - 0.45, cy - 0.45, 0.002), (cx + 0.45, cy + 0.45, 0.35), "IronDark")
            b.box((cx - 0.32, cy - 0.32, 0.35), (cx + 0.32, cy + 0.32, 12.2), "Paint")
            for hz in (1.2, 4.0, 7.5, 10.5):
                b.box((cx - 0.36, cy - 0.36, hz), (cx + 0.36, cy + 0.36, hz + 0.22), "Copper")
            # Projecteur orienté vers le robot sur chaque colonne
            b.box((cx - sx * 0.44, cy - 0.18, 5.2), (cx - sx * 0.33, cy + 0.18, 5.65), "IronDark")
            b.box((cx - sx * 0.47, cy - 0.14, 5.25), (cx - sx * 0.445, cy + 0.14, 5.60), "Bulb")

    # Pont roulant (grue supérieure) à z = 12.2..13.4 m au-dessus du robot
    for sy in (-3.8, 3.8):
        b.box((-5.4, sy - 0.35, 12.2), (5.4, sy + 0.35, 13.0), "Yellow")
        b.box((-5.3, sy - 0.38, 12.35), (5.3, sy + 0.38, 12.55), "IronDark")
    b.box((-1.6, -4.1, 13.02), (1.6, 4.1, 13.5), "Copper")
    b.cylinder((0.0, -0.8, 11.2), (0.0, -0.8, 13.0), 0.12, "IronDark", segments=8)
    b.box((-0.45, -1.25, 10.85), (0.45, -0.35, 11.18), "Yellow")

    # --- 3. Passerelle métallique d'accès (côté arrière-gauche du robot : x = -8.2..-4.6, y = -8.5..-2.0) ---
    cat_z = 2.4
    b.box((-8.2, -8.5, cat_z - 0.16), (-4.6, -2.0, cat_z), "FloorPlate")
    b.box((-8.25, -8.55, cat_z - 0.22), (-4.55, -2.02, cat_z - 0.165), "IronDark")
    for px in (-8.0, -4.8):
        for py in (-8.2, -5.2, -2.2):
            b.box((px - 0.14, py - 0.14, 0.002), (px + 0.14, py + 0.14, cat_z - 0.225), "IronDark")
    for gz in (cat_z + 0.45, cat_z + 0.9):
        b.box((-8.18, -8.33, gz), (-8.10, -2.18, gz + 0.07), "Yellow")
        b.box((-8.03, -8.48, gz), (-4.65, -8.40, gz + 0.07), "Yellow")
    for py in (-8.4, -6.2, -4.0, -2.1):
        b.box((-8.24, py - 0.05, cat_z + 0.005), (-8.06, py + 0.05, cat_z + 0.98), "IronDark")
    steps = 12
    for i in range(steps):
        sy0 = 1.6 - (i + 1) * (3.6 / steps)
        sy1 = 1.6 - i * (3.6 / steps) - 0.01
        sz1 = (i + 1) * (cat_z / steps)
        sz0 = max(0.005, sz1 - 0.19)
        b.box((-7.8, sy0, sz0), (-5.2, sy1, sz1), "Iron")
    for sx in (-7.9, -5.1):
        b.box((sx - 0.06, -1.95, 0.002), (sx + 0.06, 1.6, 0.35), "IronDark")

    # --- 4. Murs du Garage (tôle d'atelier + soubassement + piliers) ---
    for side in (-1.0, 1.0):
        wx0 = side * HX
        wx1 = side * (HX + 1.2)
        b.box((wx0, Y0, 0.002), (wx1, Y1, 2.2), "IronDark")
        b.box((wx0 + side * 0.02, Y0, 2.202), (wx1, Y1, 8.5), "WallTeal")
        b.box((wx0 + side * 0.04, Y0, 8.502), (wx1, Y1, CEIL_Z - 0.01), "WallCream")
        # Bandes décoratives cuivre devant le mur (sans pénétrer le mur)
        b.box((wx0 - side * 0.08, Y0 + 0.6, 2.15), (wx0 - side * 0.005, Y1 - 0.6, 2.32), "Copper")
        b.box((wx0 - side * 0.08, Y0 + 0.6, 8.42), (wx0 - side * 0.005, Y1 - 0.6, 8.58), "Copper")

        # Piliers métalliques devant le mur + enseignes lumineuses verticales (Bulb)
        for py in range(-16, 22, 8):
            b.box((wx0 - side * 0.45, py - 0.35, 0.005), (wx0 - side * 0.09, py + 0.35, CEIL_Z - 0.02), "Iron")
            b.box((wx0 - side * 0.54, py - 0.12, 3.02), (wx0 - side * 0.455, py + 0.12, 11.48), "Bulb")
            b.box((wx0 - side * 0.52, py - 0.22, 2.85), (wx0 - side * 0.455, py + 0.22, 3.0), "Copper")
            b.box((wx0 - side * 0.52, py - 0.22, 11.5), (wx0 - side * 0.455, py + 0.22, 11.65), "Copper")

        # Tuyaux de cuivre le long des murs
        b.cylinder((wx0 - side * 0.25, Y0 + 1.0, 3.6), (wx0 - side * 0.25, Y1 - 1.0, 3.6), 0.08, "Copper", segments=8)

    # Mur du fond (Y = Y0 = -20.0) : grande porte de monte-charge industriel
    b.box((-HX + 0.05, Y0 - 1.2, 0.003), (HX - 0.05, Y0, 2.2), "IronDark")
    b.box((-HX + 0.05, Y0 - 1.2, 2.203), (HX - 0.05, Y0 - 0.02, 8.5), "WallTeal")
    b.box((-HX + 0.05, Y0 - 1.2, 8.503), (HX - 0.05, Y0 - 0.04, CEIL_Z - 0.01), "WallCream")
    # Grande porte blindée d'atelier au fond (devant le mur, y > Y0 + 0.01)
    b.box((-5.8, Y0 + 0.01, 0.006), (5.8, Y0 + 0.35, 10.8), "IronDark")
    b.box((-5.2, Y0 + 0.36, 0.01), (5.2, Y0 + 0.48, 10.2), "Paint")
    for pz in (2.5, 5.0, 7.5):
        b.box((-5.1, Y0 + 0.485, pz), (5.1, Y0 + 0.56, pz + 0.18), "Iron")
    b.box((-5.6, Y0 + 0.36, 10.3), (5.6, Y0 + 0.58, 10.65), "Yellow")
    b.box((-3.5, Y0 + 0.38, 11.2), (3.5, Y0 + 0.65, 12.0), "Bulb")

    # Mur avant (Y = Y1 = +24.0) : grande baie vitrée / ouverture lumineuse sur l'extérieur
    for sx in (-1.0, 1.0):
        x_in, x_out = sx * 10.35, sx * (HX - 0.05)
        b.box((x_in, Y1, 0.003), (x_out, Y1 + 1.2, CEIL_Z - 0.01), "WallTeal")
        b.box((sx * 9.8, Y1 - 0.25, 0.006), (sx * 10.3, Y1 + 1.25, 11.45), "IronDark")
    b.box((-10.3, Y1, 11.5), (10.3, Y1 + 1.2, CEIL_Z - 0.01), "WallCream")
    b.box((-9.75, Y1 - 0.2, 0.006), (9.75, Y1 + 0.5, 0.94), "IronDark")
    b.box((-9.70, Y1 - 0.24, 0.95), (9.70, Y1 + 0.54, 1.18), "Yellow")
    for vx in (-6.5, -3.2, 0.0, 3.2, 6.5):
        b.box((vx - 0.14, Y1 + 0.1, 1.19), (vx + 0.14, Y1 + 0.4, 11.48), "IronDark")
    for hz in (4.5, 8.0):
        b.box((-9.7, Y1 + 0.08, hz - 0.12), (9.7, Y1 + 0.42, hz + 0.12), "IronDark")
    b.box((-9.65, Y1 + 0.2, 1.22), (9.65, Y1 + 0.28, 11.44), "Glass")

    # Paysage extérieur derrière la verrière
    b.box((-45.0, Y1 + 1.3, -0.5), (45.0, 80.0, -0.05), "Sand")
    b.box((-12.0, Y1 + 1.3, -0.04), (12.0, 46.0, 0.02), "FloorPlate")
    for (rx, ry, rw, rh) in ((-22.0, 52.0, 16.0, 18.0), (24.0, 56.0, 18.0, 21.0), (0.0, 68.0, 26.0, 16.0)):
        b.rock((rx, ry, rh * 0.45), (rw, 12.0, rh), "Terracotta", jitter=0.14, rng=rng)

    # --- 5. Plafond ultra éclairé (fermes métalliques + grandes rampes de néons) ---
    b.box((-HX - 1.0, Y0 - 1.0, CEIL_Z), (HX + 1.0, Y1 + 1.0, CEIL_Z + 0.6), "Ceiling")
    for py in range(-16, 22, 8):
        b.box((-HX + 0.5, py - 0.3, CEIL_Z - 0.9), (HX - 0.5, py + 0.3, CEIL_Z - 0.005), "IronDark")
        for lx in (-11.0, 0.0, 11.0):
            b.box((lx - 2.6, py + 2.0, CEIL_Z - 0.25), (lx + 2.6, py + 5.6, CEIL_Z - 0.005), "Iron")
            b.box((lx - 2.3, py + 2.3, CEIL_Z - 0.34), (lx + 2.3, py + 5.3, CEIL_Z - 0.255), "Bulb")

    # --- 6. Décor d'atelier dans les coins (Forge, Établis) ---
    b.box((14.2, -12.5, 0.004), (17.4, -5.5, 0.28), "IronDark")
    b.box((15.2, -11.5, 0.285), (17.35, -6.5, 2.58), "RockDark")
    b.box((14.95, -10.8, 0.285), (15.18, -7.2, 1.05), "Copper")
    b.box((15.12, -10.2, 1.08), (15.19, -7.8, 1.95), "Bulb")
    b.box((14.9, -11.6, 2.60), (17.38, -6.4, 3.4), "IronDark")
    b.cylinder((16.2, -9.0, 3.42), (16.2, -9.0, CEIL_Z - 0.02), 0.55, "IronDark", segments=10)

    # Établis au fond à gauche et à droite
    for sx in (-1.0, 1.0):
        bx = sx * 13.5
        b.box((bx - 2.2, -18.8, 0.004), (bx + 2.2, -17.2, 0.82), "Wood")
        b.box((bx - 2.25, -18.85, 0.825), (bx + 2.25, -17.15, 0.92), "Iron")
        b.box((bx - 2.0, -18.9, 1.3), (bx + 2.0, -18.7, 2.8), "Board")

    b.finish()

    # --- 7. Collisions invisibles (-colonly) ---
    def col_box(name: str, lo, hi) -> None:
        cb = kit.Builder(name + "-colonly")
        cb.box(lo, hi, "RockDark")
        cb.finish()

    col_box("FloorCol", (-HX - 2.0, Y0 - 2.0, -1.0), (HX + 2.0, Y1 + 2.0, 0.0))
    col_box("WallLeft", (-HX - 2.0, Y0 - 2.0, 0.0), (-HX, Y1 + 2.0, CEIL_Z))
    col_box("WallRight", (HX, Y0 - 2.0, 0.0), (HX + 2.0, Y1 + 2.0, CEIL_Z))
    col_box("WallBack", (-HX - 2.0, Y0 - 2.0, 0.0), (HX + 2.0, Y0 + 0.4, CEIL_Z))
    col_box("WallFront", (-HX - 2.0, Y1 - 0.1, 0.0), (HX + 2.0, Y1 + 2.0, CEIL_Z))
    for i, (sx, sy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1))):
        cx, cy = sx * 4.8, sy * 3.8
        col_box("LiftCol%d" % i, (cx - 0.45, cy - 0.45, 0.0), (cx + 0.45, cy + 0.45, 6.0))
    col_box("CatwalkFloor", (-8.2, -8.5, cat_z - 0.2), (-4.6, -2.0, cat_z))
    col_box("CatwalkRailL", (-8.25, -8.5, cat_z), (-8.05, -2.0, cat_z + 1.1))
    col_box("CatwalkRailB", (-8.2, -8.55, cat_z), (-4.6, -8.35, cat_z + 1.1))
    for i in range(steps):
        sy0 = 1.6 - (i + 1) * (3.6 / steps)
        sy1 = 1.6 - i * (3.6 / steps)
        sz1 = (i + 1) * (cat_z / steps)
        col_box("Stair%d" % i, (-7.8, sy0, 0.0), (-5.2, sy1, sz1))
    col_box("ForgeCol", (14.2, -12.5, 0.0), (17.9, -5.5, 3.0))

    kit.save_and_export("lobby_garage", budget_tris=9500, folder="levels")


main()
