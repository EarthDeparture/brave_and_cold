"""Original, reusable first-person hand poses. Blender 5.x, no external assets.

blender --background --factory-startup --python gen_survivor_hands.py -- --output-dir PATH
Authored in Godot metres (+Y up, -Z forward); converted at mesh construction.
Closed skin volumes are fused before decimation: no separate tendon/knuckle tubes.
Grip poses use tool coordinates; fists use a wrist origin. Sleeve origin is its cuff.
"""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector
sys.path.insert(0, str(Path(__file__).resolve().parent))
from hand_materials import paint_atlas, fabric_grain

# Linear-light palette, so Godot does not wash the skin/fabric out to white.
SKIN = (0.40, 0.29, 0.235, 1.0)
WRISTS = {
    'vm_axe_r': [0.075, -0.005, 0.050],
    'vm_rifle_r': [0.105, -0.007, 0.230],
    'vm_rifle_l': [-0.082, -0.096, -0.203],
    'vm_bolt_r': [0.140, -0.058, 0.155],
    'vm_fist_r': [0, 0, 0],
    'vm_fist_l': [0, 0, 0],
}
FOREARM_AXIS = Vector((0, 0, 1))


def blender(v):
    return Vector((v[0], -v[2], v[1]))


def material(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value = 0.86
    bs.inputs['Specular IOR Level'].default_value = 0.22
    col = m.node_tree.nodes.new('ShaderNodeVertexColor')
    col.layer_name = 'Col'
    m.node_tree.links.new(col.outputs['Color'], bs.inputs['Base Color'])
    return m


class Shape:
    def __init__(self, name):
        self.name, self.vertices, self.faces, self.colors = name, [], [], []
        self.digits = []

    def loft(self, pts, radii, sides=12, ref=(0, 1, 0), color=SKIN):
        pts = [Vector(p) for p in pts]
        rows = []
        for i, p in enumerate(pts):
            tangent = (pts[min(i+1, len(pts)-1)] - pts[max(0, i-1)]).normalized()
            axis = Vector(ref)
            if abs(axis.dot(tangent)) > 0.94:
                axis = Vector((1, 0, 0))
            u = tangent.cross(axis).normalized()
            v = u.cross(tangent).normalized()
            r = radii[i]
            ru, rv = r if isinstance(r, tuple) else (r, r)
            row = []
            for k in range(sides):
                a = math.tau * k / sides
                row.append(len(self.vertices))
                self.vertices.append(p + u * ru * math.cos(a) + v * rv * math.sin(a))
            rows.append(row)
        for a, b in zip(rows, rows[1:]):
            for k in range(sides):
                self.faces.append((a[k], a[(k+1)%sides], b[(k+1)%sides], b[k]))
                self.colors.append(color)
        for row, flip in [(rows[0], True), (rows[-1], False)]:
            self.faces.append(tuple(reversed(row)) if flip else tuple(row))
            self.colors.append(color)

    def ellipsoid(self, c, r, color=SKIN):
        c = Vector(c)
        # Tiny closed end rings avoid degenerate pole triangles.
        pts, radii = [], []
        for k in range(9):
            t = math.pi * k / 8
            pts.append(c + Vector((0, 0, math.cos(t) * r[2])))
            scale = max(0.025, math.sin(t))
            radii.append((r[0]*scale, r[1]*scale))
        self.loft(pts, radii, ref=(0, 1, 0), color=color)

    def finger(self, pts, radius=0.010):
        pts = [Vector(p) for p in pts]
        self.digits.append((pts, radius))
        radii = [radius * (1.0 - 0.27*i/(len(pts)-1)) for i in range(len(pts))]
        # Dorsal knuckles belong to the volume, rather than floating decoration.
        self.loft(pts, radii, sides=12, ref=(0, 0, 1))
        for p, rad in zip(pts, radii):
            self.ellipsoid(p, (rad, rad, rad))

    def finish(self, mat, fuse=False, budget=2700):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata([blender(p) for p in self.vertices], [], self.faces)
        mesh.update()
        # The voxel union needs consistently outward raw volumes, including
        # overlapping joint/palm components, before computing their inside.
        raw_bm = bmesh.new()
        raw_bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(raw_bm, faces=raw_bm.faces)
        raw_bm.to_mesh(mesh)
        raw_bm.free()
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.collection.objects.link(obj)
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        if fuse:
            remesh = obj.modifiers.new('Fuse anatomical skin', 'REMESH')
            remesh.mode = 'VOXEL'
            remesh.voxel_size = 0.0011
            remesh.use_smooth_shade = True
            bpy.ops.object.modifier_apply(modifier=remesh.name)
            smooth = obj.modifiers.new('Soften joint transitions', 'SMOOTH')
            smooth.factor, smooth.iterations = 0.45, 3
            bpy.ops.object.modifier_apply(modifier=smooth.name)
            dec = obj.modifiers.new('Game silhouette budget', 'DECIMATE')
            tri_count = sum(len(p.vertices)-2 for p in obj.data.polygons)
            dec.ratio = min(1.0, budget / tri_count)
            bpy.ops.object.modifier_apply(modifier=dec.name)
            # One subdivision pass removes the pinched polygon silhouette left
            # by decimation while preserving fused, closed grip topology.
            sub = obj.modifiers.new('Smooth first-person silhouette', 'SUBSURF')
            sub.levels = 1
            bpy.ops.object.modifier_apply(modifier=sub.name)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        if fuse:
            remaining = set(bm.verts)
            parts = []
            while remaining:
                group = [remaining.pop()]
                stack = list(group)
                while stack:
                    ve = stack.pop()
                    for edge in ve.link_edges:
                        other = edge.other_vert(ve)
                        if other in remaining:
                            remaining.remove(other); group.append(other); stack.append(other)
                parts.append(group)
            # Decimation can leave microscopic double-sided specks inside tight
            # finger/palm contacts. Remove only sub-2 mm debris, never a digit.
            largest = max(parts, key=len)
            for part in parts:
                if part is largest:
                    continue
                diameter = max((a.co-b.co).length for a in part for b in part)
                assert len(part) <= 12 and diameter < 0.002, (self.name, 'Lost anatomical component', len(part), diameter)
                bmesh.ops.delete(bm, geom=part, context='VERTS')
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.materials.append(mat)
        cols = obj.data.color_attributes.new(name='Col', type='FLOAT_COLOR', domain='CORNER')
        for poly in obj.data.polygons:
            # Broad painted planes, no high-frequency photorealistic noise.
            if fuse:
                n = poly.normal
                tone = 0.93 + 0.07 * max(0.0, n.z)
                col = tuple(c * tone for c in SKIN[:3]) + (1.0,)
            else:
                col = self.colors[poly.index]
            for li in poly.loop_indices:
                cols.data[li].color = col
            poly.use_smooth = True
        obj.data.color_attributes.active_color = cols
        obj.data.color_attributes.render_color_index = 0
        obj.select_set(False)
        return obj


def shaft_grip(name, fist=False, side=1):
    s = Shape(name)
    wrist = Vector((0.075, -0.005, 0.050))
    # The handle axis is +Y. Dorsum is behind the handle, palm is a flat wedge.
    s.loft([wrist, (0.052, -0.004, 0.043),
            (0.026, 0.000, 0.035), (0.003, 0.000, 0.027)],
           [(0.021, 0.026), (0.019, 0.033), (0.017, 0.042), (0.013, 0.041)], ref=(0, 1, 0))
    for j, y in enumerate([0.033, 0.011, -0.011, -0.030]):
        xz = [(-0.006, 0.030), (-0.026, 0.020), (-0.030, -0.005),
              (-0.018, -0.026), (0.006, -0.029), (0.022, -0.018)]
        if fist:
            xz = [(0.000, 0.027), (-0.016, 0.018), (-0.018, -0.004),
                  (0.000, -0.014), (0.027, -0.009), (0.031, 0.007)]
        pts = [(x, y*(1.0-0.05*k), z) for k, (x, z) in enumerate(xz)]
        s.finger(pts, [0.0098, 0.0104, 0.0097, 0.0088][j])
    # Opposing thumb crosses the index, with a broad thenar root.
    s.ellipsoid((0.040, 0.021, 0.032), (0.024, 0.023, 0.019))
    thumb = [(0.047, 0.023, 0.034), (0.038, 0.043, 0.016),
             (0.020, 0.050, -0.004), (-0.004, 0.045, -0.018)]
    if fist:
        thumb = [(0.045, 0.018, 0.030), (0.026, 0.040, 0.018),
                 (0.000, 0.042, 0.002), (-0.015, 0.030, -0.004)]
    s.finger(thumb, 0.012)
    if fist:
        # Wrist-origin variant; future poses can reuse the same palm/finger builder.
        s.vertices = [Vector((side*(v.x-wrist.x), v.y-wrist.y, v.z-wrist.z)) for v in s.vertices]
    return s


def closed_fist(name, side):
    s = Shape(name)
    s.loft([(0, 0, 0.006), (0, 0, 0), (0, 0.001, -0.034),
            (0, 0.006, -0.060), (0, 0.007, -0.077)],
           [(0.022, 0.018), (0.025, 0.020), (0.036, 0.022), (0.041, 0.023), (0.039, 0.020)], ref=(0, 1, 0))
    for i, x in enumerate([0.031, 0.011, -0.010, -0.029]):
        # MCP -> PIP -> DIP -> pad: fingertips fold back onto the palm.
        z = -0.100 + 0.008 * (i == 3)
        s.finger([(x, 0.004, -0.076), (x, -0.010, z), (x, -0.033, z),
                  (x, -0.044, -0.081), (x, -0.033, -0.063), (x, -0.022, -0.065)],
                 [0.0101, 0.0105, 0.0097, 0.0087][i])
    # Compressed palm tissue fills the inside of a closed fist. This prevents
    # the curled digits becoming four hollow-looking hoops from the camera.
    s.ellipsoid((0.000, -0.023, -0.083), (0.034, 0.023, 0.020))
    s.ellipsoid((0.030, -0.008, -0.047), (0.021, 0.020, 0.026))
    s.finger([(0.033, -0.009, -0.042), (0.047, -0.015, -0.065),
              (0.039, -0.038, -0.090), (0.018, -0.047, -0.095), (0.003, -0.040, -0.090)], 0.012)
    s.vertices = [Vector((side*v.x, v.y, v.z)) for v in s.vertices]
    s.digits = [([Vector((side*p.x, p.y, p.z)) for p in ps], r) for ps, r in s.digits]
    return s


def rifle_trigger():
    s = Shape('vm_rifle_r')
    w = WRISTS[s.name]
    # Dorsum approaches from the right. Four fingers curl underneath; only the
    # opposing thumb crosses the visible top/left of the stock wrist.
    s.loft([w, (0.075, 0.015, 0.202), (0.057, 0.013, 0.171), (0.048, -0.002, 0.134)],
           [(0.021, 0.026), (0.020, 0.031), (0.025, 0.038), (0.023, 0.039)], ref=(0, 0, 1))
    s.ellipsoid((0.047, -0.006, 0.149), (0.023, 0.029, 0.042))
    for j, z in enumerate([0.123, 0.145, 0.166]):
        s.finger([(0.048, -0.018, z), (0.043, -0.037, z), (0.020, -0.056, z),
                  (-0.006, -0.054, z), (-0.026, -0.033, z)], [0.0100, 0.0095, 0.0086][j])
    s.finger([(0.046, -0.017, 0.105), (0.036, -0.038, 0.083),
              (0.020, -0.047, 0.054), (0.001, -0.040, 0.030)], 0.0095)
    s.ellipsoid((0.044, 0.020, 0.187), (0.026, 0.024, 0.029))
    s.finger([(0.045, 0.029, 0.194), (0.025, 0.044, 0.170),
              (-0.001, 0.033, 0.145), (-0.023, 0.003, 0.124), (-0.026, -0.018, 0.111)], 0.012)
    return s


def rifle_support():
    s = Shape('vm_rifle_l')
    w = WRISTS[s.name]
    s.loft([w, (-0.051, -0.069, -0.235), (-0.022, -0.047, -0.269)],
           [(0.021, 0.027), (0.022, 0.033), (0.020, 0.040)], ref=(0, 0, 1))
    for j, z in enumerate([-0.296, -0.275, -0.254, -0.234]):
        s.finger([(-0.027, -0.043, z), (0.003, -0.045, z), (0.026, -0.036, z),
                  (0.033, -0.012, z), (0.029, 0.011, z)],
                 [0.0096, 0.0100, 0.0094, 0.0084][j])
    s.ellipsoid((-0.020, -0.052, -0.232), (0.021, 0.020, 0.025))
    s.finger([(-0.027, -0.052, -0.218), (-0.036, -0.023, -0.226),
              (-0.032, 0.007, -0.243), (-0.027, 0.019, -0.253)], 0.012)
    return s


def bolt_grip():
    s = Shape('vm_bolt_r')
    s.loft([WRISTS[s.name], (0.116, -0.033, 0.120), (0.097, -0.012, 0.088)],
           [(0.021, 0.027), (0.023, 0.034), (0.020, 0.038)], ref=(0, 0, 1))
    for j, z in enumerate([0.054, 0.075, 0.096, 0.115]):
        s.finger([(0.096, -0.008, z), (0.086, 0.019, z), (0.061, 0.026, z),
                  (0.043, 0.006, z), (0.053, -0.014, z)], 0.0095-j*0.0003)
    s.ellipsoid((0.107, -0.014, 0.112), (0.020, 0.022, 0.023))
    s.finger([(0.110, -0.018, 0.120), (0.091, -0.028, 0.099),
              (0.069, -0.024, 0.080), (0.050, -0.010, 0.064)], 0.012)
    return s


def sleeve(name):
    s = Shape(name)
    # +Z native forearm, 0.52 m long. Runtime aims it at the hidden elbow.
    wool = (0.035, 0.041, 0.027, 1)
    cloth = (0.064, 0.083, 0.048, 1)
    cuff = [0.0, 0.008, 0.016, 0.032, 0.042, 0.051]
    cr = [0.029, 0.030, 0.028, 0.030, 0.030, 0.035]
    s.loft([(0, 0, t) for t in cuff], [(r, r*0.83) for r in cr], sides=12, color=wool)
    ts = [0.037, 0.052, 0.070, 0.095, 0.13, 0.19, 0.26, 0.33, 0.41, 0.52]
    rs = [0.038, 0.045, 0.046, 0.044, 0.051, 0.054, 0.056, 0.064, 0.065, 0.074]
    start = len(s.colors)
    s.loft([(0, 0, t) for t in ts], [(r, r*0.92) for r in rs], sides=12, color=cloth)
    for i in range(len(ts)-1):
        k = [0.85, 1.02, 0.96, 0.90, 1.03, 0.97, 1.02, 0.94, 1.0][i]
        for f in range(12):
            s.colors[start + i*12 + f] = tuple(c*k for c in cloth[:3]) + (1,)
    return s


def validate(objs):
    report = {}
    for o in objs:
        bm = bmesh.new(); bm.from_mesh(o.data)
        tris = sum(len(f.verts)-2 for f in bm.faces)
        bad_area = sum(f.calc_area() < 1e-12 for f in bm.faces)
        bad_coords = sum(not all(math.isfinite(v) for v in ve.co) for ve in bm.verts)
        skin = not 'sleeve' in o.name
        manifold = sum(not e.is_manifold for e in bm.edges)
        # Connected components: the skin must be one fused anatomical surface.
        remaining = set(bm.verts); comps = 0
        while remaining:
            comps += 1; stack = [remaining.pop()]
            while stack:
                v = stack.pop()
                for e in v.link_edges:
                    q = e.other_vert(v)
                    if q in remaining:
                        remaining.remove(q); stack.append(q)
        assert bad_area == 0 and bad_coords == 0, o.name
        if skin:
            assert manifold == 0 and comps == 1, (o.name, manifold, comps)
        report[o.name] = {'triangles': tris, 'vertices': len(bm.verts), 'components': comps,
                          'nonmanifold_edges': manifold, 'zero_area_faces': bad_area,
                          'bounds_godot': [[min(v[i] for v in [Vector((ve.co.x,ve.co.z,-ve.co.y)) for ve in bm.verts]),
                                            max(v[i] for v in [Vector((ve.co.x,ve.co.z,-ve.co.y)) for ve in bm.verts])] for i in range(3)]}
        bm.free()
    assert sum(r['triangles'] for r in report.values()) <= 100000
    return report


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--output-dir', required=True)
    args = ap.parse_args(sys.argv[sys.argv.index('--')+1:])
    out = Path(args.output_dir).resolve(); out.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    skin, cloth = material('survivor_skin'), material('survivor_cloth')
    shapes = [shaft_grip('vm_axe_r'), rifle_trigger(), rifle_support(), bolt_grip(),
              closed_fist('vm_fist_r', 1), closed_fist('vm_fist_l', -1)]
    for s in shapes: s.wrist = WRISTS[s.name]
    bare = [s.finish(skin, fuse=True) for s in shapes]
    sleeves = [sleeve(n).finish(cloth) for n in ['vm_sleeve_r', 'vm_sleeve_l']]
    gloves = []
    for obj in bare:
        glove = obj.copy(); glove.data = obj.data.copy()
        glove.name = obj.name + '_glove'
        bpy.context.collection.objects.link(glove)
        # A fitted leather shell; fingers stay fitted to the same tool pose.
        for v in glove.data.vertices:
            v.co += v.normal * 0.0008
        glove.data.update()
        gloves.append(glove)
    paint_atlas(bare, shapes, out, 'skin')
    paint_atlas(gloves, shapes, out, 'leather')
    fabric_grain(out)
    objs = bare + sleeves
    bpy.context.view_layer.objects.active = objs[0]
    if hasattr(bpy.context.preferences.filepaths, 'save_preview_images'):
        bpy.context.preferences.filepaths.save_preview_images = False
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'survivor_hands.blend'))
    for asset, group in [('survivor_hands', objs), ('survivor_gloves', gloves)]:
        report = validate(group)
        bpy.ops.object.select_all(action='DESELECT')
        for o in group: o.select_set(True)
        # Both packages use identical semantic names for runtime interchange.
        if asset == 'survivor_gloves':
            for o in bare:
                o.name += '_bare'; o.data.name += '_bare'
            for o, s in zip(gloves, shapes):
                o.name = s.name; o.data.name = s.name
        glb = out/(asset + '.glb')
        bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', use_selection=True,
                              export_yup=True, export_apply=True, export_normals=True,
                              export_vertex_color='ACTIVE', export_all_vertex_colors=False,
                              export_materials='EXPORT')
        if asset == 'survivor_gloves':
            report = {k.removesuffix('_glove'): v for k, v in report.items()}
        receipt = {'name': asset, 'version': 2, 'units': 'metres', 'wrists_godot': WRISTS,
               'native_fist_forearm': list(FOREARM_AXIS), 'sleeve_axis': [0,0,1], 'sleeve_length': 0.52,
               'source': 'tools/blender/gen_survivor_hands.py', 'blender': bpy.app.version_string,
               'sha256': hashlib.sha256(glb.read_bytes()).hexdigest(),
               'generator_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
               'material_source': 'tools/blender/hand_materials.py',
               'material_source_sha256': hashlib.sha256(Path(__file__).with_name('hand_materials.py').read_bytes()).hexdigest(),
               'license': 'Project-authored original geometry and procedural painted textures; repository ownership',
               'design': 'Smooth fused anatomy, fitted grips, weathered skin or stitched two-tone leather gloves, olive parka cuffs',
               'negative_constraints': 'No extracted game assets, no external texture dependencies, no paid providers, no floating knuckle decorations',
               'validation': report, 'total_triangles': sum(r['triangles'] for r in report.values())}
        (out/(asset+'.json')).write_text(json.dumps(receipt, indent=2)+'\n', encoding='utf-8')
        print('HAND_ASSET', asset, receipt['total_triangles'], flush=True)


if __name__ == '__main__':
    main()
