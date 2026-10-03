"""Bake original painted anatomy/leather into UV atlases, using no reference pixels.

Textures are sampled in model space, so grain, folds and seams cross UV islands
continuously. The runtime packages embed the images; no Blender nodes are needed.
"""
import math
import bpy
import numpy as np

SIZE = 2048
PALM = {'vm_axe_r': (0, 0, -1), 'vm_rifle_r': (0, -1, 0),
        'vm_rifle_l': (0, 1, 0), 'vm_bolt_r': (-1, 0, 0),
        'vm_fist_r': (0, -1, 0), 'vm_fist_l': (0, -1, 0)}


def noise(p, scale):
    q = p * scale
    i = np.floor(q).astype(np.int32)
    f = q - i
    f = f*f*(3-2*f)
    out = np.zeros(len(p), np.float32)
    for x in range(2):
        for y in range(2):
            for z in range(2):
                h = (i[:, 0]+x)*127.1 + (i[:, 1]+y)*311.7 + (i[:, 2]+z)*74.7
                v = np.sin(h) * 43758.5453
                v -= np.floor(v)
                w = (f[:, 0] if x else 1-f[:, 0]) * (f[:, 1] if y else 1-f[:, 1]) * (f[:, 2] if z else 1-f[:, 2])
                out += (v*w).astype(np.float32)
    return out


def painted(points, normals, shape, kind):
    palm = np.clip(normals @ np.array(PALM[shape.name]), -1, 1)
    grain = noise(points, 1900)
    mottle = noise(points, 120)
    broad = noise(points, 37)
    fold = np.zeros(len(points), np.float32)
    blush = np.zeros(len(points), np.float32)
    tips = np.zeros(len(points), np.float32)
    nail = np.zeros(len(points), np.float32)
    stitching = np.zeros(len(points), np.float32)
    nearest_digit = np.full(len(points), 1.0, np.float32)
    for ps, radius in shape.digits:
        path = np.array([tuple(p) for p in ps])
        for j in range(1, len(path)-1):
            center = path[j]
            tangent = path[j+1] - path[j-1]
            tangent /= np.linalg.norm(tangent)
            d = points - center
            plane = d @ tangent
            dist = np.linalg.norm(d, axis=1)
            local = np.exp(-np.square(dist/(radius*1.6)))
            # Fine broken folds around the bend, not large painted rings.
            crease = np.exp(-np.square((plane+(mottle-.5)*.0018)/.00075))
            fold = np.maximum(fold, crease * local * (.45 + .55*np.clip(palm, 0, 1)))
            blush = np.maximum(blush, np.exp(-np.square(dist/(radius*2))) * np.clip(-palm, 0, 1))
        tip_dist = np.linalg.norm(points-path[-1], axis=1)
        tips = np.maximum(tips, np.clip(1-tip_dist/(radius*1.45), 0, 1))
        tip_axis = path[-1]-path[-2]; tip_axis /= np.linalg.norm(tip_axis)
        tip_d = points-path[-1]
        longitudinal = tip_d @ tip_axis
        # A quiet oval nail on the outward terminal segment. Most are hidden by grips.
        nail_mask = np.exp(-np.square((longitudinal+.003)/.004))
        nail_mask *= np.exp(-np.square(tip_dist/(radius*.95))) * np.clip(-palm, 0, 1)
        nail = np.maximum(nail, nail_mask)
        offset = 0.0
        for a, b in zip(path, path[1:]):
            ab = b-a; length = np.linalg.norm(ab); t = np.clip((points-a) @ ab/(length*length), 0, 1)
            nearest = a + t[:, None]*ab
            dist = np.linalg.norm(points-nearest, axis=1)
            side = np.exp(-np.square((palm-.10)/.13))
            stitch = ((np.sin((t*length+offset)*math.tau/.0038) > .45) & (dist < radius*1.3))
            closer = dist < nearest_digit
            stitching[closer] = (side*stitch)[closer]
            nearest_digit = np.minimum(nearest_digit, dist)
            offset += length
    roots = np.array([tuple(ps[0]) for ps, _ in shape.digits])
    forearm = np.array(shape.wrist)-np.mean(roots, axis=0)
    forearm /= np.linalg.norm(forearm)
    wrist_d = points-np.array(shape.wrist)
    along = wrist_d @ forearm
    wrist_fold = np.exp(-np.square((along+.022+(broad-.5)*.008)/.0014))
    wrist_fold += np.exp(-np.square((along+.031+(mottle-.5)*.006)/.0015))*.6
    fold = np.maximum(fold, wrist_fold*.65*np.clip(palm,0,1))
    if shape.name == 'rig_hand':
        # Palm flexion creases and thenar line stay attached to the weighted UVs.
        x, z = points[:, 0], points[:, 2]
        on_palm = np.clip(palm, 0, 1) * ((z < -.016) & (z > -.076))
        distal = z + .063 - x*.18 + (x/.04)**2*.003
        proximal = z + .043 + x*.25
        thenar = np.sqrt(((x+.031)/.024)**2 + ((z+.034)/.030)**2)-1.0
        palm_fold = np.maximum(np.exp(-(distal/.0010)**2),np.exp(-(proximal/.0012)**2)*.7)
        palm_fold = np.maximum(palm_fold,np.exp(-(thenar/.045)**2)*.8)
        fold = np.maximum(fold,palm_fold*on_palm*.8)
    if kind == 'skin':
        col = np.tile((.405, .294, .241), (len(points), 1)).astype(np.float32)
        col *= (0.87 + .21*broad + .10*(mottle-.5) + .023*(grain-.5))[:, None]
        col += blush[:, None]*np.array((.027, -.007, -.012))
        col *= (1-fold*.28)[:, None]
        col = col*(1-nail[:, None]*.55) + np.array((.48, .36, .32))*nail[:, None]*.55
        height = (grain-.5)*.07 - fold*.20
    else:
        # Cream leather backs, brown reinforced palms and fingertips.
        patch = np.clip((palm-.10)*3.5, 0, 1)
        patch = np.maximum(patch, np.clip((tips-.26)*2.5, 0, 1))
        patch = np.maximum(patch, np.clip((along+.007)*220, 0, 1))
        cuff_seam = np.exp(-np.square((along+.010)/.0010))
        angle = np.arctan2(wrist_d[:, 1], wrist_d[:, 0])
        cuff_seam *= (np.sin(angle*35) > .35)
        stitching = np.maximum(stitching*.40, cuff_seam)
        col = (np.array((.32, .285, .225))*(1-patch[:, None]) + np.array((.082, .049, .028))*patch[:, None])
        col *= (0.72 + .40*broad + .22*(mottle-.5) + .065*(grain-.5))[:, None]
        wear = np.clip(blush*.8 + tips*.4, 0, .8) * (.4+.6*mottle)
        col += wear[:, None]*np.array((.036, .028, .018))
        col *= (1-fold*.35)[:, None]
        col = col*(1-stitching[:, None]*.65) + np.array((.51, .43, .30))*stitching[:, None]*.65
        height = (grain-.5)*.14 - fold*.32 + stitching*.17
    return np.clip(col, 0, 1), height


def paint_atlas(objects, shapes, out, kind):
    positions = np.zeros((SIZE, SIZE, 3), np.float32)
    normals = np.zeros_like(positions)
    ids = np.full((SIZE, SIZE), -1, np.int8)
    for oi, obj in enumerate(objects):
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True); bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=.012)
        bpy.ops.object.mode_set(mode='OBJECT')
        uv = obj.data.uv_layers.active.data
        columns = min(3, len(objects))
        rows = math.ceil(len(objects)/columns)
        for loop in uv:
            loop.uv.x = (oi % columns + .025 + loop.uv.x*.95)/columns
            loop.uv.y = (oi // columns + .025 + loop.uv.y*.95)/rows
        obj.data.calc_loop_triangles()
        for tri in obj.data.loop_triangles:
            u = np.array([tuple(uv[li].uv) for li in tri.loops])*SIZE-.5
            lo = np.maximum(np.floor(u.min(axis=0)).astype(int), 0)
            hi = np.minimum(np.ceil(u.max(axis=0)).astype(int), SIZE-1)
            xx, yy = np.meshgrid(np.arange(lo[0], hi[0]+1), np.arange(lo[1], hi[1]+1))
            v0, v1 = u[1]-u[0], u[2]-u[0]
            den = v0[0]*v1[1]-v1[0]*v0[1]
            if abs(den) < 1e-8: continue
            dx, dy = xx-u[0, 0], yy-u[0, 1]
            b = (dx*v1[1]-v1[0]*dy)/den
            c = (v0[0]*dy-dx*v0[1])/den
            weights = np.stack((1-b-c, b, c), axis=-1)
            inside = np.min(weights, axis=-1) >= -1e-5
            xs, ys = xx[inside], yy[inside]
            p = np.array([tuple(obj.data.vertices[vi].co) for vi in tri.vertices])
            n = np.array([tuple(obj.data.vertices[vi].normal) for vi in tri.vertices])
            # Convert to authored Godot coordinates for anatomical paint fields.
            p = p[:, [0, 2, 1]]*np.array((1, 1, -1))
            n = n[:, [0, 2, 1]]*np.array((1, 1, -1))
            positions[ys, xs] = weights[inside] @ p
            normals[ys, xs] = weights[inside] @ n
            ids[ys, xs] = oi
        print('UNWRAPPED', kind, obj.name, flush=True)
    color = np.zeros_like(positions)
    heights = np.zeros((SIZE, SIZE), np.float32)
    for oi, shape in enumerate(shapes):
        mask = ids == oi
        n = normals[mask]; n /= np.maximum(np.linalg.norm(n, axis=1)[:, None], .001)
        color[mask], heights[mask] = painted(positions[mask], n, shape, kind)
    # Extend island margins before normal derivation and mip filtering.
    filled = ids >= 0
    for _ in range(12):
        old = filled.copy()
        for axis, step in [(0, 1), (0, -1), (1, 1), (1, -1)]:
            take = ~filled & np.roll(old, step, axis=axis)
            color[take] = np.roll(color, step, axis=axis)[take]
            heights[take] = np.roll(heights, step, axis=axis)[take]
            filled[take] = True
    gy, gx = np.gradient(heights)
    normal = np.stack((-gx, -gy, np.ones_like(gx)), axis=-1)
    normal /= np.linalg.norm(normal, axis=-1)[:, :, None]
    images = []
    for suffix, pixels in [('albedo', color), ('normal', normal*.5+.5)]:
        img = bpy.data.images.new(kind+'_'+suffix, SIZE, SIZE, alpha=False)
        if suffix == 'normal': img.colorspace_settings.name = 'Non-Color'
        else:
            # PNG samples are sRGB. Painting operates in linear light; storing
            # those values directly makes Godot decode them a second time.
            pixels = np.where(pixels <= .0031308, pixels*12.92, 1.055*np.power(pixels, 1/2.4)-.055)
        rgba = np.concatenate((pixels, np.ones((SIZE, SIZE, 1), np.float32)), axis=-1)
        img.pixels.foreach_set(rgba.ravel())
        img.filepath_raw = str(out/(kind+'_'+suffix+'.png')); img.file_format = 'PNG'
        img.save(); img.pack(); images.append(img)
    mat = bpy.data.materials.new('survivor_'+kind+'_painted'); mat.use_nodes = True
    bs = mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value = .70 if kind == 'skin' else .84
    bs.inputs['Specular IOR Level'].default_value = .25
    base = mat.node_tree.nodes.new('ShaderNodeTexImage'); base.image = images[0]
    mat.node_tree.links.new(base.outputs['Color'], bs.inputs['Base Color'])
    tex = mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image = images[1]
    bump = mat.node_tree.nodes.new('ShaderNodeNormalMap'); bump.inputs['Strength'].default_value = .45
    mat.node_tree.links.new(tex.outputs['Color'], bump.inputs['Color'])
    mat.node_tree.links.new(bump.outputs['Normal'], bs.inputs['Normal'])
    for obj in objects:
        obj.data.materials.clear(); obj.data.materials.append(mat)
        # Painted albedo already includes pigment; keep exported vertex color white.
        for datum in obj.data.color_attributes['Col'].data: datum.color = (1, 1, 1, 1)
    print('PAINTED_ATLAS', kind, SIZE, flush=True)


def fabric_grain(out):
    """Neutral textile modulation for vertex-tinted, triplanar parka sleeves."""
    n = 512
    yy, xx = np.mgrid[:n, :n]
    rng = np.random.default_rng(48)
    grain = rng.random((n, n))
    weave = np.sin(xx*math.tau/4)*np.sin(yy*math.tau/4)
    folds = np.sin(yy*math.tau/128 + np.sin(xx*math.tau/512)*1.8)
    value = .88 + .035*weave + .024*(grain-.5) + .035*folds
    px = np.ones((n, n, 4), np.float32); px[:, :, :3] = value[:, :, None]
    image = bpy.data.images.new('parka_fabric', n, n, alpha=False)
    image.pixels.foreach_set(px.ravel())
    image.filepath_raw = str(out/'parka_fabric.png'); image.file_format = 'PNG'
    image.save(); image.pack()
