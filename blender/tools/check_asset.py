"""Contrôles automatiques d'un modèle avant son export (PASS / FAIL), appelés par `prop_kit.save_and_export`.

Un FAIL bloque l'export et dit quoi corriger ; un WARN s'affiche sans bloquer.

    PASS  budget : 812 / 900 triangles
    FAIL  au sol : le bas du modèle est à z = 0.120 m (il doit toucher z = 0 à 5 mm près)

Contrôles :
- budget de triangles ;
- transformations appliquées : échelle 1 partout, pas de rotation sur un objet libre (une pièce accrochée à un os
  peut être tournée) ;
- au sol : le bas du modèle touche z = 0 ; il peut être un peu enfoncé (15 cm au plus : pied ancré, pierres du feu),
  jamais au-dessus (sauf `ground=False` : objet accroché au mur, au plafond, pièce d'un mécanisme) ;
- faces cassées (aire nulle), sommets et arêtes isolés (sans face) ;
- trous (arêtes qui ne bordent qu'une face) : WARN, les faces arrière sont masquées en jeu, un trou se voit ;
- nommage des collisions : suffixes Godot exacts (`-col`, `-colonly`, `-convcolonly`) ;
- UV : obligatoires si un matériau utilise une image ;
- faces superposées de matériaux différents (elles clignotent en jeu, voir `prop_kit.find_z_fighting`).

Utilisation seule (Blender ouvert ou en ligne de commande), sur les objets visibles du fichier :

    blender -b blender/props/barrel.blend --python blender/tools/check_asset.py -- --budget 900 [--no-ground]
"""

import os
import re
import sys

import bmesh
import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

GROUND_TOLERANCE = 0.005      # m, au-dessus du sol
GROUND_SINK = 0.15            # m, enfoncé dans le sol au plus
DEGENERATE_AREA = 1e-8        # m²
COLLISION_SUFFIXES = ("-col", "-colonly", "-convcolonly", "-rigid", "-navmesh")
# Mots qui ressemblent à une collision mais mal écrits (Godot ne les reconnaîtrait pas).
SUSPECT_NAME = re.compile(r"([_.\s]col(only)?|-coll(ision)?|-collider|_collision)$", re.IGNORECASE)


class Report:
    def __init__(self, name: str):
        self.name = name
        self.lines: list = []
        self.failed = 0

    def ok(self, label: str, detail: str = "") -> None:
        self.lines.append(("PASS", label, detail))

    def warn(self, label: str, detail: str) -> None:
        self.lines.append(("WARN", label, detail))

    def fail(self, label: str, detail: str) -> None:
        self.lines.append(("FAIL", label, detail))
        self.failed += 1

    def print(self) -> None:
        print("check_asset : %s" % self.name)
        for level, label, detail in self.lines:
            print("  %s  %s%s" % (level, label, (" : " + detail) if detail else ""))
        print("  => %s" % ("FAIL (%d)" % self.failed if self.failed else "PASS"))


def check(objects, name: str = "", budget_tris: int = 0, ground: bool = True, z_fighting: bool = True) -> Report:
    """Contrôle les objets `objects` (maillages, armatures). Renvoie le rapport (déjà affiché)."""
    meshes = [o for o in objects if o.type == "MESH"]
    report = Report(name or ", ".join(o.name for o in meshes[:3]))
    if not meshes:
        report.fail("contenu", "aucun maillage à exporter")
        report.print()
        return report

    tris = sum(_tris(o) for o in meshes)
    if budget_tris:
        if tris > budget_tris:
            report.fail("budget", "%d triangles pour %d prévus" % (tris, budget_tris))
        else:
            report.ok("budget", "%d / %d triangles" % (tris, budget_tris))

    bad = [o.name for o in objects if any(abs(s - 1.0) > 1e-4 for s in o.scale)
           or (o.parent is None and any(abs(a) > 1e-4 for a in o.rotation_euler))]
    if bad:
        report.fail("transformations", "échelle ou rotation non appliquée (Ctrl+A) : " + ", ".join(bad[:5]))
    else:
        report.ok("transformations")

    low = min(_lowest_z(o) for o in meshes)
    if not ground:
        report.ok("au sol", "non demandé (bas à z = %.3f m)" % low)
    elif low > GROUND_TOLERANCE or low < -GROUND_SINK:
        report.fail("au sol", "le bas du modèle est à z = %.3f m (il doit toucher z = 0 : au plus %d mm au-dessus, "
                              "%d cm enfoncé ; ground=False pour un objet accroché)"
                    % (low, GROUND_TOLERANCE * 1000, GROUND_SINK * 100))
    else:
        report.ok("au sol", "bas à z = %.3f m" % low if abs(low) > GROUND_TOLERANCE else "")

    broken, loose_verts, loose_edges, holes = 0, 0, 0, 0
    for obj in meshes:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        broken += sum(1 for f in bm.faces if f.calc_area() < DEGENERATE_AREA)
        loose_verts += sum(1 for v in bm.verts if not v.link_faces)
        loose_edges += sum(1 for e in bm.edges if not e.link_faces)
        holes += sum(1 for e in bm.edges if len(e.link_faces) == 1)
        bm.free()
    if broken or loose_verts or loose_edges:
        report.fail("géométrie", "%d faces d'aire nulle, %d sommets et %d arêtes sans face"
                    % (broken, loose_verts, loose_edges))
    else:
        report.ok("géométrie")
    if holes:
        report.warn("trous", "%d arêtes ne bordent qu'une face (faces arrière masquées en jeu : le trou se voit)" % holes)

    suspects = [o.name for o in objects if SUSPECT_NAME.search(o.name) and not o.name.endswith(COLLISION_SUFFIXES)]
    if suspects:
        report.fail("nommage", "suffixe de collision mal écrit (Godot attend %s) : %s"
                    % (" / ".join(COLLISION_SUFFIXES[:3]), ", ".join(suspects)))
    else:
        report.ok("nommage")

    no_uv = [o.name for o in meshes if _uses_image(o) and not o.data.uv_layers]
    if no_uv:
        report.fail("UV", "matériau avec image mais pas d'UV : " + ", ".join(no_uv))
    else:
        report.ok("UV")

    if z_fighting:
        import prop_kit
        issues = [i for o in meshes for i in prop_kit.find_z_fighting(o)]
        if issues:
            where = "; ".join("%s / %s vers (%.2f, %.2f, %.2f)" % (ma, mb, *at) for ma, mb, at, *_r in issues[:5])
            report.fail("faces superposées", "%d paires (elles clignotent en jeu, décaler une pièce de 1-2 mm) : %s"
                        % (len(issues), where))
        else:
            report.ok("faces superposées")

    report.print()
    return report


def _tris(obj) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def _lowest_z(obj) -> float:
    matrix = obj.matrix_world
    return min((matrix @ v.co).z for v in obj.data.vertices) if obj.data.vertices else 0.0


def _uses_image(obj) -> bool:
    for mat in obj.data.materials:
        if mat and mat.use_nodes and any(n.type == "TEX_IMAGE" for n in mat.node_tree.nodes):
            return True
    return False


def _parse_args(argv):
    args = argv[argv.index("--") + 1:] if "--" in argv else []
    budget = int(args[args.index("--budget") + 1]) if "--budget" in args else 0
    return budget, "--no-ground" not in args


if __name__ == "__main__":
    budget, ground = _parse_args(sys.argv)
    objects = [o for o in bpy.context.view_layer.objects if o.visible_get() and o.type in {"MESH", "ARMATURE"}]
    result = check(objects, os.path.basename(bpy.data.filepath), budget, ground)
    sys.exit(1 if result.failed else 0)
