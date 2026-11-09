"""Animations « porter » du nain, ajoutées à blender/dwarf.blend (le reste du nain est fait à la main).

Fiche
- hold_low / hold_mid / hold_high : un objet léger (caca, fléchettes) tenu dans la main droite, bras tendu
  devant soi. Trois poses selon le regard (bas, droit devant, haut) : Godot les mélange avec l'inclinaison
  du regard, pour que l'objet reste dans le champ (en bas à droite de la vue).
- carry : un objet lourd (caisse de 0,68 m) porté à deux mains, mains de chaque côté de la caisse,
  à hauteur de ventre.
- Poses fixes (2 images identiques, comme `grab`) ; seuls les os des bras sont animés.
- Retire les emotes `emote_clap` et `emote_salute` (retirées du jeu).

Relancer après une modification, puis réimporter dans Godot :

    blender -b blender/dwarf.blend --python blender/dwarf_anims.py

Sauvegarde blender/dwarf.blend et réexporte assets/models/dwarf_body.glb (squelette + corps + actions).
"""

import os

import bpy
from mathutils import Vector

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SHOULDER = {"L": Vector((-0.3, 0.0, 0.78)), "R": Vector((0.3, 0.0, 0.78))}

# Où va la main (repère du nain dans Blender : +Y devant, +Z en haut), par pose.
POSES = {
    "hold_low": {"R": (0.24, 0.38, 0.58)},
    "hold_mid": {"R": (0.18, 0.36, 0.78)},
    "hold_high": {"R": (0.14, 0.24, 1.16)},
    "carry": {"L": (-0.38, 0.34, 0.58), "R": (0.38, 0.34, 0.58)},
}
REMOVED = ("emote_clap", "emote_salute")


def aim(rig, side, target):
    """Tourne l'os arm_<side> pour que la main aille vers `target` (le torse est au repos)."""
    bone = rig.data.bones["arm_" + side]
    rest = (bone.tail_local - bone.head_local).normalized()
    wanted = (Vector(target) - SHOULDER[side]).normalized()
    turn = rest.rotation_difference(wanted)
    rest_rot = bone.matrix_local.to_quaternion()
    pose = rig.pose.bones["arm_" + side]
    pose.rotation_mode = "QUATERNION"
    pose.rotation_quaternion = rest_rot.inverted() @ turn @ rest_rot


def make_pose(rig, name, hands):
    old = bpy.data.actions.get(name)
    if old is not None:
        bpy.data.actions.remove(old)
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = action
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
    for side, target in hands.items():
        aim(rig, side, target)
    for frame in (0, 1):
        for side in hands:
            rig.pose.bones["arm_" + side].keyframe_insert("rotation_quaternion", frame=frame)
    print("dwarf_anims : %s" % name)


def main():
    rig = bpy.data.objects["DwarfRig"]
    for name in REMOVED:
        action = bpy.data.actions.get(name)
        if action is not None:
            bpy.data.actions.remove(action)
    for name, hands in POSES.items():
        make_pose(rig, name, hands)
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "blender", "dwarf.blend"))
    body = bpy.data.objects["DwarfBody"]
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(ROOT, "assets", "models", "dwarf_body.glb"),
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_cameras=False,
        export_lights=False,
        export_yup=True,
        export_animations=True,
    )


main()
