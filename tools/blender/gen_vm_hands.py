"""
Run: blender.exe --background --factory-startup --python gen_vm_hands.py -- <out_dir>
vm_hands.glb: first-person gloved hands + parka sleeves. Budget <= 1400 tris.
Hand = fist whose grip axis is local Z (handle passes through origin). Palm on -Y side (toward camera),
fingers wrap round via -X (right hand), thumb over +X. Wrist sits at (sx*0.075,-0.05,0).
Parts: vm_hand_r, vm_hand_l, vm_sleeve_r, vm_sleeve_l (sleeve origin = wrist, extends along -Y = Godot +Z).
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vmlib import *

LEATHER = (0.44, 0.31, 0.17)
LEATHER_D = (0.27, 0.18, 0.10)
WOOL = (0.17, 0.155, 0.13)
PARKA = (0.22, 0.26, 0.20)
PARKA_D = (0.13, 0.16, 0.12)
WRIST = Vector((0.075, -0.05, -0.005))


def mir(sx, p):
    return Vector((p[0] * sx * -1.0 if False else p[0] * sx, p[1], p[2]))


def build_hand(sx, name):
    h = Part(name)
    # palm / back of hand
    blob(h, (sx * 0.012, -0.031, 0.0), 0.036, 0.019, 0.042, LEATHER, sides=10, nrings=5, col2=LEATHER)
    R = 0.030
    angs = [-70, -105, -145, -185, -225]
    for z in (0.030, 0.010, -0.010, -0.030):
        pts, rad, cols = [], [], []
        for i, a in enumerate(angs):
            t = math.radians(a)
            pts.append(Vector((sx * R * math.cos(t), R * math.sin(t), z)))
            rad.append(0.0105 - i * 0.0013)
            cols.append(LEATHER if i < 3 else LEATHER_D)
        limb(h, pts, rad, cols, sides=6, ref=Vector((0, 0, 1)), cap0=False, cap1=True)
    # thumb along the +X side, wrapping toward the far side
    th = [Vector((sx * 0.03, -0.034, 0.040)), Vector((sx * 0.036, -0.008, 0.050)), Vector((sx * 0.026, 0.026, 0.052)),
          Vector((sx * 0.010, 0.040, 0.050))]
    limb(h, th, [0.014, 0.0125, 0.011, 0.009], [LEATHER, LEATHER, LEATHER, LEATHER_D], sides=6, ref=Vector((0, 0, 1)), cap0=False, cap1=True)
    # wrist cuff stub
    wr = Vector((sx * WRIST.x, WRIST.y, WRIST.z))
    limb(h, [Vector((sx * 0.03, -0.04, 0.0)), wr], [(0.034, 0.040), (0.036, 0.040)], [LEATHER, WOOL], sides=8, ref=Vector((0, 0, 1)), cap0=False, cap1=False)
    stain(h, mix=0.0, scale=4.0, thresh=2.0, seed=3.0 + sx)
    return h.finish()


def build_sleeve(sx, name):
    wr = Vector((sx * WRIST.x, WRIST.y, WRIST.z))
    s = Part(name, origin=wr)
    d = Vector((sx * 0.25, -1.0, -0.12)).normalized()
    pts = [wr + d * t for t in (0.0, 0.05, 0.2, 0.45, 0.8)]
    rad = [0.034, 0.038, 0.043, 0.048, 0.052]
    cols = [WOOL, PARKA_D, PARKA, PARKA, PARKA]
    limb(s, pts, rad, cols, sides=9, ref=Vector((0, 0, 1)), cap0=False, cap1=True)
    stain(s, mix=0.0, scale=3.0, thresh=2.0, seed=5.0 + sx)
    return s.finish()


if __name__ == "__main__":
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    objs = []
    for nm, sx in (("r", 1), ("l", -1)):
        objs.append(build_hand(sx, "vm_hand_" + nm))
        objs.append(build_sleeve(sx, "vm_sleeve_" + nm))
    tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs}
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=f"{OUT}/vm_hands.glb", export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    print("VMHANDS tris", sum(tris.values()), tris)
