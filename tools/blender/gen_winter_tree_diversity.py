"""Original snow-capped tree library, near/far meshes and editable Blender source.
Run Blender --background --factory-startup --python-exit-code 1 --python FILE.
Exports into a staging package; admission happens only after binary validation.
"""
from pathlib import Path
import math, random, json, hashlib
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tools/blender/generated/winter_tree_diversity_v1"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = "METRIC"
bpy.context.scene.unit_settings.scale_length = 1.0
bpy.context.preferences.filepaths.save_version = 0
atlas = bpy.data.images.load(str(OUT / "winter_twigs.png"), check_existing=True)
atlas.pack()
far_atlas = bpy.data.images.load(str(OUT / "winter_boughs_far.png")); far_atlas.pack()
mat = bpy.data.materials.new("WinterTree_VertexBark_TwigAtlas_Snow")
mat.use_nodes = True
mat.surface_render_method = "DITHERED"
nodes, links = mat.node_tree.nodes, mat.node_tree.links
bsdf = nodes.get("Principled BSDF")
bsdf.inputs["Roughness"].default_value = .93
bsdf.inputs["Specular IOR Level"].default_value = .13
vertex = nodes.new("ShaderNodeVertexColor")
vertex.layer_name = "Surface"
tex = nodes.new("ShaderNodeTexImage")
tex.image = atlas
far_tex = nodes.new("ShaderNodeTexImage"); far_tex.image = far_atlas
far_mask = nodes.new("ShaderNodeMath"); far_mask.operation = "GREATER_THAN"; far_mask.inputs[1].default_value = .70
links.new(vertex.outputs["Alpha"], far_mask.inputs[0])
leaf_color = nodes.new("ShaderNodeMixRGB"); links.new(far_mask.outputs[0], leaf_color.inputs[0]); links.new(tex.outputs["Color"], leaf_color.inputs[1]); links.new(far_tex.outputs["Color"], leaf_color.inputs[2])
leaf_alpha = nodes.new("ShaderNodeMixRGB"); links.new(far_mask.outputs[0], leaf_alpha.inputs[0]); links.new(tex.outputs["Alpha"], leaf_alpha.inputs[1]); links.new(far_tex.outputs["Alpha"], leaf_alpha.inputs[2])
greater = nodes.new("ShaderNodeMath"); greater.operation = "GREATER_THAN"
greater.inputs[1].default_value = .55; links.new(vertex.outputs["Alpha"], greater.inputs[0])
less = nodes.new("ShaderNodeMath"); less.operation = "LESS_THAN"
less.inputs[1].default_value = .8; links.new(vertex.outputs["Alpha"], less.inputs[0])
mask = nodes.new("ShaderNodeMath"); mask.operation = "MULTIPLY"
links.new(greater.outputs[0], mask.inputs[0]); links.new(less.outputs[0], mask.inputs[1])
color = nodes.new("ShaderNodeMixRGB")
links.new(mask.outputs[0], color.inputs[0]); links.new(vertex.outputs["Color"], color.inputs[1]); links.new(leaf_color.outputs[0], color.inputs[2])
links.new(color.outputs[0], bsdf.inputs["Base Color"])
alpha = nodes.new("ShaderNodeMixRGB"); alpha.inputs[1].default_value = (1, 1, 1, 1)
links.new(mask.outputs[0], alpha.inputs[0]); links.new(leaf_alpha.outputs[0], alpha.inputs[2]); links.new(alpha.outputs[0], bsdf.inputs["Alpha"])
# Native preview uses the same two-family bark/normal contract as Godot.
bark_image = bpy.data.images.load(str(OUT / "winter_bark.png")); bark_image.pack()
normal_image = bpy.data.images.load(str(OUT / "winter_bark_normal.png")); normal_image.colorspace_settings.name = "Non-Color"; normal_image.pack()
coords = nodes.new("ShaderNodeTexCoord")
mapping = nodes.new("ShaderNodeMapping"); mapping.inputs["Scale"].default_value = (.46, 1, 1); mapping.inputs["Location"].default_value = (.02, 0, 0)
links.new(coords.outputs["UV"], mapping.inputs["Vector"])
pale = nodes.new("ShaderNodeMath"); pale.operation = "GREATER_THAN"; pale.inputs[1].default_value = .15
links.new(vertex.outputs["Alpha"], pale.inputs[0])
offset = nodes.new("ShaderNodeMath"); offset.operation = "MULTIPLY"; offset.inputs[1].default_value = .5; links.new(pale.outputs[0], offset.inputs[0])
offset_vec = nodes.new("ShaderNodeCombineXYZ"); links.new(offset.outputs[0], offset_vec.inputs["X"])
bark_uv = nodes.new("ShaderNodeVectorMath"); bark_uv.operation = "ADD"
links.new(mapping.outputs["Vector"], bark_uv.inputs[0]); links.new(offset_vec.outputs[0], bark_uv.inputs[1])
bark_tex = nodes.new("ShaderNodeTexImage"); bark_tex.image = bark_image; links.new(bark_uv.outputs[0], bark_tex.inputs["Vector"])
normal_tex = nodes.new("ShaderNodeTexImage"); normal_tex.image = normal_image; links.new(bark_uv.outputs[0], normal_tex.inputs["Vector"])
bark_greater = nodes.new("ShaderNodeMath"); bark_greater.operation = "GREATER_THAN"; bark_greater.inputs[1].default_value = .05
bark_less = nodes.new("ShaderNodeMath"); bark_less.operation = "LESS_THAN"; bark_less.inputs[1].default_value = .25
links.new(vertex.outputs["Alpha"], bark_greater.inputs[0]); links.new(vertex.outputs["Alpha"], bark_less.inputs[0])
bark_mask = nodes.new("ShaderNodeMath"); bark_mask.operation = "MULTIPLY"
links.new(bark_greater.outputs[0], bark_mask.inputs[0]); links.new(bark_less.outputs[0], bark_mask.inputs[1])
bark_color = nodes.new("ShaderNodeMixRGB"); bark_color.blend_type = "MULTIPLY"; bark_color.inputs[0].default_value = 1
links.new(vertex.outputs["Color"], bark_color.inputs[1]); links.new(bark_tex.outputs["Color"], bark_color.inputs[2])
solid = nodes.new("ShaderNodeMixRGB"); links.new(bark_mask.outputs[0], solid.inputs[0]); links.new(vertex.outputs["Color"], solid.inputs[1]); links.new(bark_color.outputs[0], solid.inputs[2])
links.new(solid.outputs[0], color.inputs[1])
strength = nodes.new("ShaderNodeMath"); strength.operation = "MULTIPLY"; strength.inputs[1].default_value = .6; links.new(bark_mask.outputs[0], strength.inputs[0])
normal_node = nodes.new("ShaderNodeNormalMap"); links.new(normal_tex.outputs["Color"], normal_node.inputs["Color"]); links.new(strength.outputs[0], normal_node.inputs["Strength"]); links.new(normal_node.outputs["Normal"], bsdf.inputs["Normal"])
# Engine overrides this one surface using the same vertex-alpha contract. Native
# materials support honest Blender inspection; glTF need not reproduce node math.
export_collection = bpy.data.collections.new("Export_UnitHeight")
bpy.context.scene.collection.children.link(export_collection)
display_collection = bpy.data.collections.new("Preview_18m_RealScale")
bpy.context.scene.collection.children.link(display_collection)

BARK = (.42, .40, .34)
SNOW = (.69, .76, .81)
SPEC = {
    "snow_pine_open": {"seed": 1031, "tiers": 12, "branches": 5, "start": .37, "radius": .138, "droop": .24, "tile": 0, "lean": (.011, -.005), "description": "Open lower trunk, irregular pine crown, long needle sprays"},
    "snow_fir_full": {"seed": 2053, "tiers": 14, "branches": 5, "start": .15, "radius": .151, "droop": .36, "tile": 1, "lean": (-.006, .009), "description": "Full low crown, swept drooping branchlets, layered resting snow"},
    "snow_spruce_wind": {"seed": 3079, "tiers": 14, "branches": 4, "start": .20, "radius": .130, "droop": .40, "tile": 2, "lean": (.06, -.018), "description": "Wind-shaped asymmetric crown, short sparse windward boughs"},
    "snow_snag": {"seed": 4093, "description": "Standing dead conifer with broken taper and snow lodged on surviving limbs"},
    "winter_birch": {"seed": 5107, "description": "Leafless northern birch, pale scarred bark and snow on branching crotches"},
}


class Mesh:
    def __init__(self, name):
        self.name = name; self.v = []; self.f = []; self.col = []; self.uv = []

    def vertex(self, point, color, uv=(0, 0)):
        self.v.append(tuple(point)); self.col.append(color); self.uv.append(uv)
        return len(self.v) - 1

    def tube(self, points, radii, color, sides=6, pale=False):
        rings = []
        distance = 0.0
        for j, (center, radius) in enumerate(zip(points, radii)):
            center = Vector(center)
            if j > 0: distance += (center - Vector(points[j - 1])).length
            axis = (Vector(points[min(j + 1, len(points) - 1)]) - Vector(points[max(j - 1, 0)])).normalized()
            ref = Vector((0, 0, 1)) if abs(axis.z) < .9 else Vector((1, 0, 0))
            u = axis.cross(ref).normalized(); v = axis.cross(u).normalized()
            ring = []
            for i in range(sides):
                angle = i * math.tau / sides
                tone = .90 + .1 * math.sin(j * 2.37 + i * 3.7)
                tint = tuple(c * tone for c in color)
                point = center + radius * (u * math.cos(angle) + v * math.sin(angle))
                if abs(center.z) < 1e-9:
                    point.z = 0.0
                ring.append(self.vertex(point, (*tint, .18 if pale else .10), (i / sides, distance * 14)))
            rings.append(ring)
        self.f.append(tuple(reversed(rings[0]))); self.f.append(tuple(rings[-1]))
        for j in range(len(rings) - 1):
            for i in range(sides):
                self.f.append((rings[j][i], rings[j][(i + 1) % sides], rings[j + 1][(i + 1) % sides], rings[j + 1][i]))

    def card(self, root, tip, width, tilt, tile, far=False):
        axis = (tip - root).normalized()
        cross = Vector((-axis.y, axis.x, 0)).normalized()
        vertical = axis.cross(cross).normalized()
        side = cross * math.cos(tilt) + vertical * math.sin(tilt)
        # The bottom-left GLB UV origin is the inverse of PNG's top-left origin.
        tu, tv = tile % 2, 1 - tile // 2
        ids = []
        for t, v in [(0, 0), (1, 0), (1, 1), (0, 1)]:
            point = root.lerp(tip, t) + side * (v - .5) * width
            ids.append(self.vertex(point, (1, 1, 1, .72 if far else .65), ((tu + t) * .5, (tv + (.05 + v * .90 if far else .15 + v * .70)) * .5)))
        self.f.append(tuple(ids))

    def cap(self, root, tip, width, depth, far):
        axis = (tip - root).normalized()
        cross = Vector((-axis.y, axis.x, 0)).normalized()
        center = root.lerp(tip, .5)
        count = 4 if far else 6
        rings = []
        levels = [(0, 1), (1, .22)] if far else [(0, 1), (.7, .82), (1, .22)]
        for level, scale in levels:
            ring = []
            for i in range(count):
                angle = i * math.tau / count
                # Follow the sloping branch top. All thickness is added upward;
                # snow is not a free-floating sphere detached from its support.
                p = center + axis * math.cos(angle) * (tip - root).length * .5 * scale + cross * math.sin(angle) * width * scale + Vector((0, 0, depth * level))
                shade = .96 + .04 * math.cos(angle)
                ring.append(self.vertex(p, tuple(c * shade for c in SNOW) + (1,)))
            rings.append(ring)
        self.f.append(tuple(reversed(rings[0]))); self.f.append(tuple(rings[-1]))
        for j in range(len(rings) - 1):
            for i in range(count):
                self.f.append((rings[j][i], rings[j][(i + 1) % count], rings[j + 1][(i + 1) % count], rings[j + 1][i]))

    def finish(self):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata(self.v, [], self.f); mesh.update()
        color = mesh.color_attributes.new(name="Surface", type="FLOAT_COLOR", domain="CORNER")
        uv = mesh.uv_layers.new(name="SurfaceUV")
        for face in mesh.polygons:
            face.use_smooth = True
            for li in face.loop_indices:
                vi = mesh.loops[li].vertex_index
                color.data[li].color = self.col[vi]; uv.data[li].uv = self.uv[vi]
        mesh.color_attributes.active_color = color
        mesh.color_attributes.render_color_index = 0
        mesh.materials.append(mat)
        obj = bpy.data.objects.new(self.name, mesh)
        export_collection.objects.link(obj)
        return obj


def trunk_point(z, lean):
    return Vector((lean[0] * z * z, lean[1] * z * z, z))


def conifer_skeleton(cfg):
    rng = random.Random(cfg["seed"])
    branches = []
    for tier in range(cfg["tiers"]):
        f = tier / (cfg["tiers"] - 1)
        z = cfg["start"] + (.94 - cfg["start"]) * f
        # Pine is an irregular oval crown; fir retains a conical lower sweep.
        profile = (math.sin((f * .83 + .12) * math.pi) ** .65 if cfg["tile"] == 0 else (1 - f) ** .8)
        reach = cfg["radius"] * profile + .007
        phase = tier * 2.399 + rng.uniform(-.4, .4)
        for index in range(cfg["branches"]):
            angle = phase + index * math.tau / cfg["branches"] + rng.uniform(-.20, .20)
            asymmetry = 1.0 if cfg["tile"] != 2 else .68 + .38 * (1 + math.cos(angle))
            length = reach * rng.uniform(.80, 1.12) * asymmetry
            root = trunk_point(min(.95, z + rng.uniform(-.028, .028)), cfg["lean"])
            direction = Vector((math.cos(angle), math.sin(angle), 0))
            mid = root + direction * length * .46 + Vector((0, 0, -.010 * (1 - f)))
            tip = root + direction * length + Vector((0, 0, -length * cfg["droop"] * (1 - f * .5)))
            branches.append({"root": root, "mid": mid, "tip": tip, "radius": .0025 * (1 - f * .65), "snow": rng.random() < .40, "f": f, "angle": angle})
    return branches


def build_conifer(name, cfg, far):
    m = Mesh(name); lean = cfg["lean"]
    steps = 4 if far else 9
    zs = [i / steps for i in range(steps + 1)]
    m.tube([trunk_point(z, lean) for z in zs], [.017 * (1 - z * .96) for z in zs], BARK, 4 if far else 8)
    for i, b in enumerate(conifer_skeleton(cfg)):
        root, mid, tip = b["root"], b["mid"], b["tip"]
        width = (tip - root).length * (.59 if cfg["tile"] == 0 else .70)
        if not far:
            m.tube([root, mid, tip], [b["radius"], b["radius"] * .7, .00035], BARK, 4)
        # Keep the same branch/crown/spray positions at both distances. Near
        # crosses each spray; far retains the outer sprays with fewer planes.
        if far:
            for tilt in [-.48, .67]:
                m.card(root, root.lerp(tip, 1.13), (tip - root).length * 1.12, tilt, cfg["tile"], True)
        else:
            for tilt in [-.48, .67]:
                m.card(root.lerp(tip, .16), tip, width, tilt, cfg["tile"])
            for fraction in [.30, .63]:
                for side in [-1, 1]:
                    a = root.lerp(tip, fraction)
                    direction = Vector((math.cos(b["angle"] + side * (.75 - fraction * .2)), math.sin(b["angle"] + side * (.75 - fraction * .2)), -.30))
                    twig_tip = a + direction * (tip - root).length * (.84 - fraction * .45)
                    for tilt in [-.32, .90]:
                        m.card(a, twig_tip, width * .72, tilt, cfg["tile"])
        if b["snow"] and (not far or i % 4 == 0):
            a = root.lerp(tip, .35) + Vector((0, 0, .0022))
            c = root.lerp(tip, .86) + Vector((0, 0, .0022))
            m.cap(a, c, width * .13, .0035, far)
    # Fine upward needles at the apex; no flat cap at the end of the leader.
    a = trunk_point(.94, lean); b = trunk_point(1, lean)
    for tilt in [0, 1.05, 2.1]:
        m.card(a, b + Vector((.003, 0, 0)), .025, tilt, cfg["tile"])
    return m.finish()


def snag_skeleton(cfg):
    rng = random.Random(cfg["seed"]); branches = []
    for tier in range(10):
        z = .17 + tier * .075
        for index in range(3):
            angle = tier * 2.4 + index * math.tau / 3 + rng.uniform(-.25, .25)
            length = (.13 * (1 - z) + .022) * rng.uniform(.65, 1.30)
            direction = Vector((math.cos(angle), math.sin(angle), -.14))
            root = Vector((.020 * z * z, -.009 * z, z))
            mid = root + direction * length * .55 + Vector((0, 0, -.004))
            tip = root + direction * length
            # A few limbs point upward rather than a perfect whorl comb.
            tip.z += .026 if index == 1 and tier % 3 == 0 else 0
            branches.append((root, mid, tip, angle, rng.random() < .55))
    return branches


def build_snag(name, cfg, far):
    m = Mesh(name); bark = (.50, .49, .46)
    steps = 6 if far else 15
    zs = [i / steps for i in range(steps + 1)]
    m.tube([(.020 * z * z, -.009 * z, z) for z in zs], [.016 * (1 - .94 * z) for z in zs], bark, 4 if far else 8)
    for i, (root, mid, tip, angle, snow) in enumerate(snag_skeleton(cfg)):
        radius = .0028 * (1 - root.z * .6)
        m.tube([root, mid, tip], [radius, radius * .72, .0008], bark, 3 if far else 5)
        if not far:
            fork = root.lerp(tip, .64)
            for side in [-1, 1]:
                end = fork + Vector((math.cos(angle + side * .75), math.sin(angle + side * .75), .15)) * (tip - root).length * .34
                m.tube([fork, end], [.0010, .0003], bark, 3)
        if snow:
            offset = Vector((0, 0, radius))
            m.cap(root.lerp(tip, .20) + offset, root.lerp(tip, .83) + offset, .004, .0026, far)
    return m.finish()


def birch_skeleton(cfg):
    rng = random.Random(cfg["seed"])
    limbs = []
    # One rooted trunk; the crown divides above walking/head height.
    for index in range(7):
        z = .42 + index * .067
        angle = index * 2.399 + .3
        reach = .21 * (1 - (z - .4) * .65) * rng.uniform(.82, 1.14)
        a = Vector((.028 * z * z, 0, z))
        d = Vector((math.cos(angle), math.sin(angle), 0))
        b = a + d * reach * .40 + Vector((0, 0, .04))
        c = a + d * reach * .74 + Vector((0, 0, .10))
        e = a + d * reach + Vector((0, 0, min(.13, .985 - z)))
        limbs.append(([a, b, c, e], angle, rng.random() < .75))
    return limbs


def build_birch(name, cfg, far):
    m = Mesh(name); bark = (.93, .95, .94)
    steps = 7 if far else 18
    zs = [i / steps for i in range(steps + 1)]
    m.tube([(.028 * z * z, 0, z) for z in zs], [.0155 * (1 - z * .96) for z in zs], bark, 5 if far else 9, True)
    for index, (points, angle, snow) in enumerate(birch_skeleton(cfg)):
        m.tube(points, [.005, .0035, .0021, .0008], bark, 4 if far else 6, True)
        for j in range(4):
            t = .30 + j * .17
            a = points[0].lerp(points[-1], t)
            side = 1 if j % 2 else -1
            direction = Vector((math.cos(angle + side * .8), math.sin(angle + side * .8), .7)).normalized()
            b = a + direction * .065
            c = b + direction * .042 + Vector((0, 0, .01))
            m.tube([a, b, c], [.0014, .0008, .00025], bark, 3 if far else 4, True)
            if not far:
                m.tube([b, b + Vector((-.02 * side, .025, .034))], [.00065, .00020], bark, 3, True)
        if snow:
            for j in range(2):
                offset = Vector((0, 0, .0035))
                m.cap(points[j] + offset, points[j].lerp(points[j + 1], .92) + offset, .006 if j == 0 else .004, .003, far)
    return m.finish()


models = []
for index, (family, cfg) in enumerate(SPEC.items()):
    for far in [False, True]:
        name = family + ("_far" if far else "")
        obj = (build_snag if family == "snow_snag" else build_birch if family == "winter_birch" else build_conifer)(name, cfg, far)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True); bpy.context.view_layer.objects.active = obj
        obj.data.calc_loop_triangles()
        count = len(obj.data.loop_triangles)
        assert count <= (1100 if far else 4200), (name, count)
        coords = [v.co for v in obj.data.vertices]
        bounds = [[min(v[i] for v in coords), max(v[i] for v in coords)] for i in range(3)]
        assert all(math.isfinite(c) for v in coords for c in v)
        assert bounds[2][0] >= -1e-6 and .99 <= bounds[2][1] <= 1.03, (name, bounds)
        path = OUT / (name + ".glb")
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True, export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_normals=True, export_materials="NONE")
        models.append({"name": name, "family": family, "lod": 1 if far else 0, "seed": cfg["seed"], "triangles": count, "vertices": len(coords), "bounds_blender": bounds, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "description": cfg["description"]})
        obj.hide_set(True); obj.hide_render = True
        if not far:
            preview = bpy.data.objects.new(family + "_18m_preview", obj.data)
            display_collection.objects.link(preview)
            preview.scale = (18, 18, 18); preview.location = (index * 9, 0, 0)
        print("WINTER_TREE", name, count, flush=True)

bpy.ops.object.select_all(action="DESELECT")
for obj in display_collection.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = next(iter(display_collection.objects))
for area in bpy.context.screen.areas:
    if area.type == "VIEW_3D":
        area.spaces.active.clip_end = 500
        area.spaces.active.shading.type = "MATERIAL"
        area.spaces.active.region_3d.view_distance = 45
        area.spaces.active.region_3d.view_location = Vector((18, 0, 8))
source = OUT / "winter_tree_library.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(source))
reference = Path("C:/Users/parst/AppData/Local/Temp/codex-clipboard-4ec4ab40-7aa1-42b5-8cc4-ef462a5b8af8.png")
manifest = {"schema": 1, "origin": "Original project-authored Blender/Python geometry and original Pillow twig/bark atlases", "reference_use": "Winter silhouette, age, crown openness and deadwood guidance only; no extracted pixels or downloaded meshes", "reference_sha256": hashlib.sha256(reference.read_bytes()).hexdigest() if reference.exists() else None, "units": "Metres. Export meshes normalised to 1 m upright height. Existing canopy scales to 6-26 m; linked native preview instances are 18 m high.", "axes": "Blender +Z up; exported Godot +Y up. Origin is ground-root centre, all GLB node transforms identity.", "collision": "No physics in exports. Runtime existing trunk circles are retained; foliage/twigs never block walking.", "surface_contract": "One mesh/surface per GLB. Vertex alpha .10=dark bark, .18=birch bark, .65=new atlas needles, 1=snow; UV selects a padded twig tile or repeating bark.", "lod_contract": "Identical deterministic trunk/crown skeleton and resting-snow positions. Far simplifies branch cylinders, crossed twig sprays and snow caps.", "negative_spec": "No autumn leaf crowns, enormous snow pillows, copy of proprietary trees, foliage collision, moved scatter roots, changed height RNG or changed save keys", "budget": {"near_triangles_max": 4200, "far_triangles_max": 1100, "atlas_px": [1024, 1024]}, "native_sha256": hashlib.sha256(source.read_bytes()).hexdigest(), "models": models}
manifest["surface_contract"] = "One mesh/surface per GLB. Vertex alpha .10=dark bark, .18=birch bark, .65=near twig atlas, .72=far full-bough atlas, 1=solid snow. UV selects a padded tile or repeating bark. GLBs deliberately use the supplied Godot shader; native materials and four packed textures support Blender editing."
manifest["lod_contract"] = "Shared trunk and primary crown skeleton. Near has crossed individual branchlet sprays and all resting snow caps; far uses composed full-bough coverage on two planes per limb, reduced branch cylinders and selected major caps. Far conifers <=500 triangles; bare trees <=1100."
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", newline="\n")
