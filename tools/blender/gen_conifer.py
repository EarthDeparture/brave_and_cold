"""Procedural stylized conifer (spruce/fir) generator, seedable, Long Dark-like painted silhouette.

Run: blender.exe --background --factory-startup --python gen_conifer.py -- <out_dir>
Outputs spruce_a/b/c.glb (~total height 1.0 unit = scaled at 12 m in game by the scatterer).
Vertex colour: dark cool green base, snow on upward faces, bark brown trunk. Godot material must use vertex colours.
"""
import sys
import math
import random
import bpy
import bmesh
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."

VARIANTS = {
    "spruce_a": dict(seed=11, tiers=17, base_r=0.15, droop=0.16, trunk_h=0.16, snow=0.55),
    "spruce_b": dict(seed=23, tiers=20, base_r=0.13, droop=0.20, trunk_h=0.20, snow=0.45),
    "spruce_c": dict(seed=37, tiers=14, base_r=0.17, droop=0.12, trunk_h=0.13, snow=0.70),
}
GREEN_DARK = (0.05, 0.13, 0.15, 1.0)
GREEN_MID = (0.08, 0.24, 0.22, 1.0)
SNOW = (0.86, 0.90, 0.97, 1.0)
BARK = (0.20, 0.135, 0.095, 1.0)


def bark_color(co):
    a = math.atan2(co.y, co.x)
    k = 0.78 + 0.22 * math.sin(co.z * 70.0 + a * 4.0) * math.sin(a * 7.0 + co.z * 11.0)
    k *= 1.0 - 0.35 * max(0.0, 1.0 - co.z * 6.0) * 0.0
    return (BARK[0] * k, BARK[1] * k, BARK[2] * k, 1.0)


def soft_normals(mesh):
    ns = []
    for i, v in enumerate(mesh.vertices):
        r = math.hypot(v.co.x, v.co.y)
        if i < 16:
            n = Vector((v.co.x, v.co.y, 0.0)) if r > 1e-6 else Vector((0, 0, 1))
        else:
            w = min(1.0, r / 0.03)
            n = Vector((v.co.x / max(r, 1e-6) * 0.8 * w, v.co.y / max(r, 1e-6) * 0.8 * w, 0.6 + 0.4 * (1 - w)))
        ns.append(n.normalized())
    for p in mesh.polygons:
        p.use_smooth = True
    mesh.normals_split_custom_set_from_vertices(ns)


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def add_cone_ring(bm, z0, z1, r, sides, rng, droop):
    """Skirt: apex at z1, ring of radius r at z0 with droop and jitter (a bough tier)."""
    apex = bm.verts.new((0, 0, z1))
    ring = []
    for i in range(sides):
        a = 2 * math.pi * i / sides
        rr = r * (0.85 + 0.3 * rng.random())
        zz = z0 - droop * rr * (0.5 + rng.random()) * (1 if i % 2 else 0.4)
        ring.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, zz)))
    center = bm.verts.new((0, 0, z0 + (z1 - z0) * 0.25))
    for i in range(sides):
        bm.faces.new((apex, ring[i], ring[(i + 1) % sides]))
        bm.faces.new((center, ring[(i + 1) % sides], ring[i]))


def build(name, seed, tiers, base_r, droop, snow, trunk_h=0.1):
    rng = random.Random(seed)
    bm = bmesh.new()
    # trunk
    sides = 8
    bot = [bm.verts.new((math.cos(2 * math.pi * i / sides) * 0.010, math.sin(2 * math.pi * i / sides) * 0.010, 0)) for i in range(sides)]
    top = [bm.verts.new((math.cos(2 * math.pi * i / sides) * 0.005, math.sin(2 * math.pi * i / sides) * 0.005, 0.95)) for i in range(sides)]
    for i in range(sides):
        bm.faces.new((bot[i], bot[(i + 1) % sides], top[(i + 1) % sides], top[i]))
    trunk_faces = set(f.index for f in bm.faces)
    bm.faces.ensure_lookup_table()
    n_trunk = len(bm.faces)
    for t in range(tiers):
        f = t / max(tiers - 1, 1)
        z0 = trunk_h + f * (0.93 - trunk_h) * 0.92
        h = 0.16 - 0.06 * f
        r = base_r * (1.0 - f) ** 0.8 + 0.02
        add_cone_ring(bm, z0, z0 + h, r, 12 if f < 0.5 else 8, rng, droop)
    # top spike
    add_cone_ring(bm, 0.86, 1.0, 0.035, 5, rng, 0.0)
    bm.normal_update()
    bm.faces.ensure_lookup_table()
    col = bm.loops.layers.color.new("Color")
    for fi, f in enumerate(bm.faces):
        n = f.normal
        for loop in f.loops:
            if fi < n_trunk:
                c = bark_color(loop.vert.co)
            else:
                h = min(max(loop.vert.co.z, 0.0), 1.0)
                base = tuple(GREEN_DARK[k] * (1 - h) + GREEN_MID[k] * h for k in range(4))
                up = max(n.z, 0.0)
                s = min(1.0, (up ** 1.5) * snow * 2.2 + (0.12 * snow if n.z > 0 else 0))
                c = tuple(base[k] * (1 - s) + SNOW[k] * s for k in range(4))
            loop[col] = c
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    if mesh.color_attributes:
        mesh.color_attributes.active_color = mesh.color_attributes[0]
        mesh.color_attributes.render_color_index = 0
    soft_normals(mesh)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def build_near(name, seed, tiers, base_r, droop, snow, trunk_h=0.1):
    """Near LOD: drooping bough wedges per tier -> irregular silhouette, visible trunk between boughs."""
    rng = random.Random(seed + 1000)
    bm = bmesh.new()
    sides = 8
    bot = [bm.verts.new((math.cos(2 * math.pi * i / sides) * 0.011, math.sin(2 * math.pi * i / sides) * 0.011, 0)) for i in range(sides)]
    top = [bm.verts.new((math.cos(2 * math.pi * i / sides) * 0.004, math.sin(2 * math.pi * i / sides) * 0.004, 0.97)) for i in range(sides)]
    for i in range(sides):
        bm.faces.new((bot[i], bot[(i + 1) % sides], top[(i + 1) % sides], top[i]))
    n_trunk = len(bm.faces)
    for t in range(tiers):
        f = t / max(tiers - 1, 1)
        z = trunk_h + f * (0.94 - trunk_h)
        reach = base_r * 1.0 * (1.0 - f) ** 0.85 + 0.015
        nb = 11 if f < 0.5 else 8
        phase = rng.random() * 6.283
        for b in range(nb):
            a = phase + 2 * math.pi * b / nb + rng.uniform(-0.25, 0.25)
            L = reach * rng.uniform(0.7, 1.15)
            wd = max(0.012, L * rng.uniform(0.2, 0.3))
            dz = -droop * L * rng.uniform(0.7, 1.4)
            ca, sa = math.cos(a), math.sin(a)
            px, py = -sa, ca
            root = Vector((ca * 0.01, sa * 0.01, z + 0.012))
            tip = Vector((ca * L, sa * L, z + dz))
            mid_l = Vector((ca * L * 0.55 + px * wd, sa * L * 0.55 + py * wd, z + dz * 0.25 + 0.01))
            mid_r = Vector((ca * L * 0.55 - px * wd, sa * L * 0.55 - py * wd, z + dz * 0.25 + 0.01))
            under = Vector((ca * L * 0.5, sa * L * 0.5, z + dz * 0.15 - 0.03))
            v = [bm.verts.new(p) for p in (root, mid_l, tip, mid_r, under)]
            bm.faces.new((v[0], v[3], v[2], v[1]))      # top surface (quad, may be non planar)
            bm.faces.new((v[0], v[1], v[2], v[3]))[0:0] if False else None
            bm.faces.new((v[0], v[1], v[4]))
            nt = 5
            for k in range(nt):
                u = (k + 0.5) / nt
                base_p = root.lerp(tip, u * 0.95) + Vector((0, 0, dz * 0.12 * math.sin(u * 3.14159)))
                tl = L * (0.55 * (1.0 - u * 0.7)) * rng.uniform(0.8, 1.2)
                for side in (-1, 1):
                    ang = math.radians(rng.uniform(35, 65))
                    dirv = Vector((ca * math.cos(ang) * 0.7 + px * side * math.sin(ang),
                                   sa * math.cos(ang) * 0.7 + py * side * math.sin(ang),
                                   -0.30 - 0.25 * rng.random()))
                    dirv.normalize()
                    tp = base_p + dirv * tl
                    hw = tl * 0.30
                    a0 = base_p + Vector((ca, sa, 0)) * hw
                    a1 = base_p - Vector((ca, sa, 0)) * hw
                    bm.faces.new([bm.verts.new(q) for q in (a0, a1, tp)])
    spike_v = [bm.verts.new(p) for p in ((0.02, 0, 0.90), (-0.01, 0.017, 0.90), (-0.01, -0.017, 0.90), (0, 0, 1.0))]
    bm.faces.new((spike_v[0], spike_v[1], spike_v[3]))
    bm.faces.new((spike_v[1], spike_v[2], spike_v[3]))
    bm.faces.new((spike_v[2], spike_v[0], spike_v[3]))
    bm.normal_update()
    bm.faces.ensure_lookup_table()
    col = bm.loops.layers.color.new("Color")
    for fi, f in enumerate(bm.faces):
        n = f.normal
        for loop in f.loops:
            if fi < n_trunk:
                c = bark_color(loop.vert.co)
            else:
                hh = min(max(loop.vert.co.z, 0.0), 1.0)
                base = tuple(GREEN_DARK[k] * (1 - hh) + GREEN_MID[k] * hh for k in range(4))
                jitter = 0.85 + 0.3 * rng.random()
                base = tuple(min(1.0, base[k] * jitter) if k < 3 else 1.0 for k in range(4))
                s = min(1.0, (max(n.z, 0.0) ** 1.2) * snow * 1.8)
                c = tuple(base[k] * (1 - s) + SNOW[k] * s for k in range(4))
            loop[col] = c
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    if mesh.color_attributes:
        mesh.color_attributes.active_color = mesh.color_attributes[0]
        mesh.color_attributes.render_color_index = 0
    soft_normals(mesh)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj

def export(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False)


if __name__ == "__main__":
    clear()
    for name, cfg in VARIANTS.items():
        clear()
        far = build(name + "_far", **cfg)
        export(far, f"{OUT}/{name}_far.glb")
        clear()
        near = build_near(name, **cfg)
        tris = sum(len(p.vertices) - 2 for p in near.data.polygons)
        export(near, f"{OUT}/{name}.glb")
        print("TREE", name, "near tris", tris)
