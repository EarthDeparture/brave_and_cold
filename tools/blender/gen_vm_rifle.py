"""
Run: blender.exe --background --factory-startup --python gen_vm_rifle.py -- <out_dir>
vm_rifle.glb: bolt-action hunting rifle, ~1.07 m. Origin = wrist of the stock (right-hand grip). Muzzle toward +Y (Godot -Z).
Parts: vm_rifle (stock + metal), vm_bolt (bolt handle, origin on bolt axis, slides along Y). Budget <= 900 tris.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vmlib import *

WOOD = (0.34, 0.20, 0.09)
WOOD_D = (0.20, 0.115, 0.05)
BLUED = (0.09, 0.10, 0.12)
STEEL = (0.20, 0.21, 0.23)
PAD = (0.04, 0.04, 0.04)
BZ = 0.032  # bore axis height


def build_rifle():
    r = Part("vm_rifle")
    Z = Vector
    # stock: butt -> wrist -> forend tip. rings are (half width x, half height z)
    st = [(-0.40, -0.035, 0.016, 0.055), (-0.30, -0.025, 0.017, 0.046), (-0.20, -0.016, 0.016, 0.036), (-0.09, -0.004, 0.015, 0.030),
          (0.0, -0.004, 0.016, 0.034), (0.12, 0.008, 0.016, 0.030), (0.26, 0.016, 0.017, 0.022), (0.40, 0.020, 0.016, 0.017)]
    cols = [WOOD, WOOD, WOOD, WOOD_D, WOOD, WOOD, WOOD, WOOD_D]
    limb(r, [Z((0, y, z)) for (y, z, _, _) in st], [(w, h) for (_, _, w, h) in st], cols, sides=8, ref=Z((0, 0, 1)), cap0=False, cap1=True)
    limb(r, [Z((0, -0.412, -0.035)), Z((0, -0.400, -0.035))], [(0.0165, 0.056), (0.0165, 0.055)], [PAD, PAD], sides=8, ref=Z((0, 0, 1)), cap0=True, cap1=False)
    blob(r, (0, -0.012, -0.034), 0.017, 0.032, 0.042, WOOD_D, sides=8, nrings=4)   # pistol grip swell
    # barrel + band
    limb(r, [Z((0, 0.04, BZ)), Z((0, 0.30, BZ)), Z((0, 0.66, BZ))], [0.0115, 0.0100, 0.0085], [BLUED, BLUED, BLUED], sides=8, ref=Z((0, 0, 1)), cap0=False, cap1=True)
    limb(r, [Z((0, 0.395, BZ)), Z((0, 0.415, BZ))], [0.0125, 0.0125], [STEEL, STEEL], sides=8, ref=Z((0, 0, 1)), cap0=True, cap1=True)
    # receiver
    limb(r, [Z((0, -0.12, BZ)), Z((0, -0.10, BZ)), Z((0, 0.06, BZ)), Z((0, 0.095, BZ))], [0.0125, 0.0148, 0.0148, 0.0125], [STEEL, BLUED, BLUED, STEEL], sides=8, ref=Z((0, 0, 1)), cap0=True, cap1=True)
    # sights
    blob(r, (0, 0.045, BZ + 0.019), 0.0075, 0.012, 0.006, STEEL, sides=6, nrings=3)
    blob(r, (0, 0.64, BZ + 0.013), 0.0035, 0.006, 0.009, STEEL, sides=6, nrings=3)
    # trigger guard + trigger
    limb(r, [Z((0, -0.075, 0.022)), Z((0, -0.06, -0.004)), Z((0, -0.03, -0.012)), Z((0, 0.005, -0.004)), Z((0, 0.015, 0.022))], [0.0045] * 5, [STEEL] * 5, sides=5, ref=Z((1, 0, 0)), cap0=True, cap1=True)
    limb(r, [Z((0, -0.035, 0.022)), Z((0, -0.030, 0.0)), ], [0.004, 0.003], [STEEL, STEEL], sides=4, ref=Z((1, 0, 0)), cap0=False, cap1=True)
    stain(r, mix=0.0, scale=7.0, thresh=2.0, seed=2.0)
    return r.finish()


def build_bolt():
    o = Vector((0.0, -0.06, BZ + 0.004))
    b = Part("vm_bolt", origin=o)
    limb(b, [o + Vector((0.012, 0, 0)), o + Vector((0.052, 0.0, -0.022))], [0.0045, 0.0045], [STEEL, STEEL], sides=5, ref=Vector((0, 1, 0)), cap0=False, cap1=True)
    blob(b, o + Vector((0.058, 0.0, -0.028)), 0.0105, 0.0105, 0.0105, BLUED, sides=7, nrings=4)
    blob(b, o + Vector((0.0, 0.0, 0.0)), 0.011, 0.016, 0.011, STEEL, sides=7, nrings=3)
    return b.finish()


if __name__ == "__main__":
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    objs = [build_rifle(), build_bolt()]
    tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs}
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=f"{OUT}/vm_rifle.glb", export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    print("VMRIFLE tris", sum(tris.values()), tris)
