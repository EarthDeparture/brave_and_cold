"""Seeded original winter lookout, generated without modifying the open Blender session.

blender --background --factory-startup --python tools/blender/gen_fire_lookout.py --
    --output-dir PATH --preview-dir PATH [--render]

Blender metres, +Z up. Export converts to Godot +Y up; front (-Y) becomes +Z.
Geometry metadata describes the same stairs/deck used by the game traversal adapter.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

SEED = 2103
ORIGINAL_ROOF_HEIGHT = 12.77
ROOM_ROOF_HEIGHT = 4.13
ROOF_HEIGHT = ORIGINAL_ROOF_HEIGHT * 2
FLOOR = ROOF_HEIGHT - ROOM_ROOF_HEIGHT
FLIGHTS = 10
STEPS_PER_FLIGHT = 12
FLIGHT_RISE = FLOOR / FLIGHTS
RISER = FLIGHT_RISE / STEPS_PER_FLIGHT
STAIR_POST_X = (3.40, 6.80)
STAIR_POST_Y = (-2.90, 2.90)
RNG = random.Random(SEED)
PALETTE = {
    "timber": (0.27, 0.19, 0.125, 1),
    "boards": (0.39, 0.29, 0.19, 1),
    "trim": (0.16, 0.23, 0.22, 1),
    "metal": (0.085, 0.105, 0.12, 1),
    "snow": (0.78, 0.85, 0.91, 1),
    "glass": (0.37, 0.58, 0.67, 0.20),
    "interior": (0.36, 0.28, 0.20, 1),
    "door": (0.25, 0.32, 0.28, 1),
}


class Batch:
    def __init__(self, name: str, color: tuple):
        self.name, self.color = name, color
        self.verts, self.faces, self.colors = [], [], []

    def poly(self, points, color=None, variation=0.045):
        start = len(self.verts)
        self.verts.extend(tuple(p) for p in points)
        self.faces.append(tuple(range(start, len(self.verts))))
        c = color or self.color
        k = 1 + RNG.uniform(-variation, variation)
        self.colors.append(tuple(min(1, v * k) for v in c[:3]) + (c[3],))

    def box(self, center, size, color=None):
        x, y, z = center
        a, b, c = [s * .5 for s in size]
        pts = [(x-a,y-b,z-c),(x+a,y-b,z-c),(x+a,y+b,z-c),(x-a,y+b,z-c),
               (x-a,y-b,z+c),(x+a,y-b,z+c),(x+a,y+b,z+c),(x-a,y+b,z+c)]
        for ids in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:
            self.poly([pts[i] for i in ids], color)

    def beam(self, a, b, width=.16, depth=None, color=None):
        a, b = Vector(a), Vector(b)
        d = (b-a).normalized()
        ref = Vector((0,0,1)) if abs(d.z) < .95 else Vector((0,1,0))
        u = d.cross(ref).normalized() * width * .5
        v = d.cross(u).normalized() * (depth or width) * .5
        corners = [a-u-v,a+u-v,a+u+v,a-u+v,b-u-v,b+u-v,b+u+v,b-u+v]
        for ids in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:
            self.poly([corners[i] for i in ids], color)

    def cylinder(self, center, radius, height, color=None, sides=8):
        x,y,z = center
        low = [(x+radius*math.cos(i*math.tau/sides),y+radius*math.sin(i*math.tau/sides),z-height*.5) for i in range(sides)]
        high = [(p[0],p[1],p[2]+height) for p in low]
        self.poly(list(reversed(low)), color)
        self.poly(high, color)
        for i in range(sides):
            j=(i+1)%sides
            self.poly([low[i],low[j],high[j],high[i]], color)

    def finish(self, mat):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata(self.verts, [], self.faces)
        mesh.update()
        attr = mesh.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
        for face, col in zip(mesh.polygons, self.colors):
            for loop in face.loop_indices:
                attr.data[loop].color = col
            face.use_smooth = False
        mesh.color_attributes.active_color = attr
        obj=bpy.data.objects.new(self.name,mesh)
        bpy.context.collection.objects.link(obj)
        obj.data.materials.append(mat)
        return obj


def material(name, glass=False):
    mat=bpy.data.materials.new(name)
    mat.use_nodes=True
    nt=mat.node_tree
    bs=nt.nodes.get("Principled BSDF")
    vc=nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name="Col"
    nt.links.new(vc.outputs["Color"],bs.inputs["Base Color"])
    bs.inputs["Roughness"].default_value=.88 if not glass else .24
    if glass:
        nt.links.new(vc.outputs["Alpha"],bs.inputs["Alpha"])
        mat.surface_render_method="DITHERED"
        mat.use_transparent_shadow=False
    return mat


def structure(b):
    t, wood, trim, metal, snow, glass, inside=[b[k] for k in ["timber","boards","trim","metal","snow","glass","interior"]]
    # Four splayed square posts sit on concrete shoes. Diagonal braces form readable bays.
    for sx in [-1,1]:
        for sy in [-1,1]:
            foot=(sx*2.95,sy*2.45,-.28)
            top=(sx*2.6,sy*2.1,FLOOR-.12)
            t.beam(foot,top,.44)
            metal.box((foot[0],foot[1],-.20),(.72,.72,.55),(0.26,.29,.32,1))
            metal.box((foot[0],foot[1],.15),(.43,.43,.24))
    bay_height = (FLOOR - .50) / 8
    for z in [(.25 + i * bay_height) for i in range(1, 9)]:
        for sy in [-1,1]:
            t.beam((-2.9,sy*2.38,z),(2.9,sy*2.38,z),.22)
        for sx in [-1,1]:
            t.beam((sx*2.88,-2.4,z),(sx*2.88,2.4,z),.22)
    for i in range(8):
        z0 = .30 + i * bay_height
        z1 = min(z0 + bay_height - .12, FLOOR - .35)
        for sy in [-1,1]:
            t.beam((-2.8,sy*2.37,z0),(2.8,sy*2.37,z1),.16)
            t.beam((2.8,sy*2.37,z0),(-2.8,sy*2.37,z1),.16)
        for sx in [-1,1]:
            t.beam((sx*2.78,-2.3,z0),(sx*2.78,2.3,z1),.16)
            t.beam((sx*2.78,2.3,z0),(sx*2.78,-2.3,z1),.16)
    # Solid top floor; planks carry subtle per-board values rather than a noisy texture.
    # A 14cm deck with inset joists leaves 2m of headroom over the ninth landing.
    wood.box((0,0,FLOOR-.07),(7.6,6.6,.14))
    for i in range(42):
        x=-3.7+i*(7.4/41)
        wood.box((x,0,FLOOR+.006),(.174,6.50,.012))
    for y in [-2.45,0,2.45]:
        # Keep underside joists clear of the adjacent staircase's standing aisle.
        t.box(((-3.85 + 3.42)*.5,y,FLOOR-.32),(3.42 + 3.85,.24,.24))
    # Continuous perimeter rails, except the stair connector on the right/front corner.
    for y in [-3.25,3.25]:
        for x in [-3.7,-1.85,0,1.85,3.7]:
            trim.box((x,y,FLOOR+.54),(.115,.115,1.08))
        for z in [FLOOR+.45,FLOOR+1.06]:
            trim.box((0,y,z),(7.5,.10,.10))
        snow.box((0,y,FLOOR+1.13),(7.52,.12,.045))
    for x in [-3.72,3.72]:
        ymax=3.20 if x<0 else -1.80  # Blender -Y is Godot +Z: opening at front right.
        for y in [-3.20,-1.65,0,1.65,3.20]:
            if x>0 and y< -1.8:
                continue
            trim.box((x,y,FLOOR+.54),(.115,.115,1.08))
        # Right rail runs from rear to the connector at Blender y=-1.8.
        y0,y1=(-3.2,3.2) if x<0 else (-1.8,3.2)
        for z in [FLOOR+.45,FLOOR+1.06]:
            trim.box((x,(y0+y1)*.5,z),(.10,y1-y0,.10))
        snow.box((x,(y0+y1)*.5,FLOOR+1.13),(.12,y1-y0,.045))


def stairs(b):
    t, wood, trim, metal, snow=[b[k] for k in ["timber","boards","trim","metal","snow"]]
    for f in range(FLIGHTS):
        x=4.45 if f%2==0 else 5.8
        direction=1 if f%2==0 else -1
        ys=-1.8*direction
        base=f*FLIGHT_RISE
        for i in range(STEPS_PER_FLIGHT):
            y=ys+direction*(i+.5)*.30
            z=base+(i+1)*RISER
            wood.box((x,y,z-.075),(1.1,.32,.15))
            wood.box((x,y-direction*.155,z-RISER*.5),(1.08,.025,RISER))
            # Thin quiet frost at tread edges; leave the walking lane readable.
            for xx in [x-.48,x+.48]:
                snow.box((xx,y,z+.015),(.10,.28,.025))
        for xx in [x-.56,x+.56]:
            t.beam((xx,ys,base-.12),(xx,-ys,base+FLIGHT_RISE-.12),.16)
            # Retract rail ends from the turn so shoulders can pass the corner posts.
            rail_inset = .12 / 3.60
            trim.beam((xx,ys+direction*.12,base+FLIGHT_RISE*rail_inset+1.02),
                      (xx,-ys-direction*.12,base+FLIGHT_RISE*(1-rail_inset)+1.02),.075)
            for u in [rail_inset,.333,.666,1-rail_inset]:
                yy=ys+direction*3.6*u
                zz=base+FLIGHT_RISE*u
                trim.box((xx,yy,zz+.48),(.075,.075,.96))
    # Ten broad landings join flights; posts/braces stay outside their walking volume.
    for f in range(FLIGHTS):
        y=2.20 if f%2==0 else -2.20
        z=(f+1)*FLIGHT_RISE
        # Small edge aprons support rails outside the 2.8m x .8m usable aisle.
        wood.box((5.10,y,z-.09),(2.92,.84,.18))
        for yy in [y-.44,y+.44]:
            # opening toward flights is left clear; fence the outer edge.
            if (y>0 and yy<y) or (y<0 and yy>y):
                continue
            trim.box((5.1,yy,z+1.0),(2.94,.08,.10))
            # The turn aisle stays clear: no centre post above the landing floor.
            for xx in [3.63,6.57]:
                trim.box((xx,yy,z+.50),(.09,.09,1.0))
        # Close the outer landing sides; leave the final connection to the deck open.
        for xx in [3.63,6.57]:
            if f==FLIGHTS-1 and xx<4:
                continue
            for zz in [z+.45,z+1.0]:
                trim.box((xx,y,zz),(.08,.88,.08))
            for yy in [y-.44,y+.44]:
                trim.box((xx,yy,z+.50),(.09,.09,1.0))
        # Landing joists sit beneath the floor and cantilever from exterior columns.
        t.beam((STAIR_POST_X[0],y,z-.25),(STAIR_POST_X[1],y,z-.25),.22)
        for x in STAIR_POST_X:
            outer_y = math.copysign(2.90, y)
            inner_y = math.copysign(1.90, y)
            t.beam((x,outer_y,z-.25),(x,inner_y,z-.25),.22)
    wood.box((4.20,-2.30,FLOOR-.08),(1.30,1.0,.16))
    # Four continuous columns replace repeated overlapping posts. All X-bracing
    # is in exterior planes, beyond the outer landing rails and the player's body.
    for y in STAIR_POST_Y:
        for x in STAIR_POST_X:
            t.beam((x,y,-.25),(x,y,FLOOR-.22),.28)
            metal.box((x,y,-.12),(.5,.5,.35),(0.26,.29,.32,1))
        for f in range(FLIGHTS):
            low=f*FLIGHT_RISE+.15
            high=(f+1)*FLIGHT_RISE-.35
            t.beam((STAIR_POST_X[0],y,low),(STAIR_POST_X[1],y,high),.14)
            t.beam((STAIR_POST_X[1],y,low),(STAIR_POST_X[0],y,high),.14)


def cabin(b):
    t,wood,trim,metal,snow,glass,inside=[b[k] for k in ["timber","boards","trim","metal","snow","glass","interior"]]
    sill=FLOOR+1.02
    top=FLOOR+2.46
    # Horizontal timber cladding beneath panoramic windows, actual cut-out doorway.
    for i in range(6):
        z=FLOOR+.085+i*.17
        for x in [-2.70,2.70]:
            wood.box((x,0,z),(.14,4.4,.162))
        wood.box((0,2.20,z),(5.4,.14,.162))
        for x in [-1.65,1.65]:
            wood.box((x,-2.20,z),(2.10,.14,.162))
    # Corner and window mullions; continuous windows broken into bays.
    for x in [-2.70,2.70]:
        for y in [-2.2,-.73,.73,2.2]:
            trim.box((x,y,FLOOR+1.45),(.14,.14,2.90))
        for z in [sill,top]:
            trim.box((x,0,z),(.18,4.5,.13))
        for y in [-1.47,0,1.47]:
            # Separate corner vertices, flat panes, inexpensive alpha material.
            glass.poly([(x,y-.65,sill+.07),(x,y+.65,sill+.07),(x,y+.65,top-.07),(x,y-.65,top-.07)],variation=0)
    for y in [-2.2,2.2]:
        for x in [-2.70,-.9,.9,2.70]:
            trim.box((x,y,FLOOR+1.5),(.14,.14,3.0))
        trim.box((0,y,top),(5.5,.18,.13))
        if y>0:
            trim.box((0,y,sill),(5.5,.18,.13))
        for x in [-1.8,0,1.8]:
            if y<0 and x==0:
                continue
            glass.poly([(x-.82,y,sill+.07),(x+.82,y,sill+.07),(x+.82,y,top-.07),(x-.82,y,top-.07)],variation=0)
    # Door jambs, lintel, and an open inward leaf. No invisible barrier in the threshold.
    for x in [-.59,.59]:
        trim.box((x,-2.21,FLOOR+1.03),(.11,.20,2.06))
    trim.box((0,-2.21,FLOOR+2.10),(1.28,.20,.12))
    # Separate closed leaf: runtime hinge is Godot (-.55, FLOOR, 2.19).
    leaf=b["door"]
    leaf.box((0,-2.19,FLOOR+1.025),(1.10,.075,2.05))
    for x in [-.49,.49]: leaf.box((x,-2.238,FLOOR+1.025),(.075,.025,1.97))
    for z in [FLOOR+.08,FLOOR+1.96]: leaf.box((0,-2.238,z),(.94,.025,.07))
    for y in [-2.255,-2.125]: leaf.box((.40,y,FLOOR+1.02),(.05,.07,.12),(.52,.47,.32,1))
    # Header, exposed under-eave rafters.
    for y in [-2.2,2.2]:
        t.box((0,y,FLOOR+2.73),(5.65,.18,.45))
    for x in [-2.7,2.7]:
        t.box((x,0,FLOOR+2.73),(.18,4.5,.45))
    eave=FLOOR+2.90
    ridge=FLOOR+4.02
    corners=[(-3.5,-3.0,eave),(3.5,-3.0,eave),(3.5,3.0,eave),(-3.5,3.0,eave)]
    r0=(0,-.80,ridge);r1=(0,.80,ridge)
    faces=[[corners[0],corners[1],r0],[corners[1],corners[2],r1,r0],
           [corners[2],corners[3],r1],[corners[3],corners[0],r0,r1]]
    for points in faces:
        metal.poly(points)
        snow.poly([(x,y,z+.11) for x,y,z in points])
    # Fascia hides open roof edges and gives a chunky snow silhouette.
    for y in [-3,3]:
        trim.box((0,y,eave-.07),(7.1,.18,.22))
        snow.box((0,y,eave+.08),(7.14,.21,.13))
    for x in [-3.5,3.5]:
        trim.box((x,0,eave-.07),(.18,6.0,.22))
        snow.box((x,0,eave+.08),(.21,6.04,.13))
    for y in [-2.7,-1.35,0,1.35,2.7]:
        t.box((0,y,eave-.14),(6.8,.09,.12))
    # Stove and safe flue placement away from the entrance and sleeping berth.
    metal.box((-1.65,-1.2,FLOOR+.04),(.95,1.05,.06))
    stove_start=len(metal.verts)
    metal.box((-1.65,-1.2,FLOOR+.40),(.58,.52,.65))
    metal.box((-1.65,-1.47,FLOOR+.42),(.38,.035,.36),(0.17,.13,.10,1))
    metal.cylinder((-1.65,-1.2,FLOOR+2.25),.105,3.1)
    metal.box((-1.65,-1.2,FLOOR+3.90),(.44,.44,.09))
    # Front points from the left/front corner toward the room center.
    yaw=math.atan2(1.65,-1.20);cs,sn=math.cos(yaw),math.sin(yaw)
    for i in range(stove_start,len(metal.verts)):
        x,y,z=metal.verts[i];dx,dy=x+1.65,y+1.20
        metal.verts[i]=(-1.65+cs*dx-sn*dy,-1.20+sn*dx+cs*dy,z)
    snow.box((-1.65,-1.2,FLOOR+3.96),(.45,.45,.05))
    # Bunk, two-tone blanket and pillow.
    inside.box((-1.60,1.00,FLOOR+.42),(1.25,2.0,.22))
    inside.box((-1.60,1.00,FLOOR+.60),(1.20,1.95,.18),(0.57,.53,.40,1))
    inside.box((-1.60,.77,FLOOR+.71),(1.18,1.45,.08),(0.22,.31,.36,1))
    inside.box((-1.60,1.70,FLOOR+.74),(.82,.35,.14),(0.78,.76,.63,1))
    for x in [-2.1,-1.1]:
        for y in [.2,1.8]:
            inside.box((x,y,FLOOR+.19),(.10,.10,.38))
    # Work desk with radio transceiver, task lamp, paper chart and log book.
    inside.box((1.40,1.35,FLOOR+.83),(1.80,.70,.09))
    for x in [.6,2.2]:
        for y in [1.07,1.63]:
            inside.box((x,y,FLOOR+.39),(.085,.085,.78))
    metal.box((1.78,1.33,FLOOR+1.03),(.45,.30,.30),(0.23,.30,.27,1))
    metal.box((1.78,1.17,FLOOR+1.04),(.34,.015,.14),(0.045,.065,.07,1))
    metal.box((1.70,1.16,FLOOR+1.05),(.13,.012,.065),(0.53,.64,.40,1))
    metal.cylinder((1.96,1.33,FLOOR+1.42),.012,.50,sides=6)
    inside.box((.97,1.25,FLOOR+.886),(.47,.37,.008),(0.73,.72,.60,1))
    for i in range(3):
        inside.box((.97,1.17+i*.065,FLOOR+.892),(.35,.008,.002),(0.25,.38,.35,1))
    metal.cylinder((.60,1.50,FLOOR+1.16),.025,.54)
    metal.box((.68,1.50,FLOOR+1.45),(.30,.22,.08),(0.52,.45,.26,1))
    inside.box((1.35,.60,FLOOR+.45),(.46,.44,.07))
    for x in [1.16,1.54]:
        for y in [.42,.78]:
            inside.box((x,y,FLOOR+.22),(.05,.05,.44))
    inside.box((1.35,.83,FLOOR+.72),(.46,.06,.48))
    # Provisions shelf and exterior numbered plaque, limited discrete meshes.
    for z in [FLOOR+.20,FLOOR+.65,FLOOR+1.1]:
        inside.box((1.90,-1.65,z),(1.05,.36,.055))
    for x in [1.39,2.41]:
        inside.box((x,-1.65,FLOOR+.62),(.055,.37,1.25))
    for i in range(5):
        inside.cylinder((1.5+i*.18,-1.65,FLOOR+.77),.055,.20,(.35,.43,.37,1),sides=8)
    inside.box((1.82,-1.65,FLOOR+.32),(.50,.27,.22),(.57,.45,.27,1))
    trim.box((1.65,-2.29,FLOOR+.61),(.72,.04,.27))
    for x in [1.48,1.62,1.80]:
        wood.box((x,-2.315,FLOOR+.62),(.045,.015,.15),(.77,.72,.54,1))


def point_camera(camera, at):
    camera.rotation_euler=(Vector(at)-camera.location).to_track_quat('-Z','Y').to_euler()


def render_previews(out):
    out.mkdir(parents=True,exist_ok=True)
    scene=bpy.context.scene
    scene.render.engine='CYCLES'
    scene.cycles.device='CPU'
    scene.cycles.samples=24
    scene.cycles.use_denoising=True
    scene.render.resolution_x=1100
    scene.render.resolution_y=1100
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.world.color=(.18,.22,.30)
    scene.world.use_nodes=True
    background=scene.world.node_tree.nodes.get('Background')
    background.inputs['Color'].default_value=(.40,.52,.70,1)
    background.inputs['Strength'].default_value=.45
    scene.view_settings.view_transform='AgX'
    scene.view_settings.look='AgX - Medium High Contrast'
    # Ground is preview-only and excluded from the GLB.
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.46))
    ground=bpy.context.object
    ground.name='preview_ground'
    m=bpy.data.materials.new('preview_snow')
    m.diffuse_color=(.60,.70,.81,1)
    ground.data.materials.append(m)
    bpy.ops.object.light_add(type='AREA',location=(6,-10,ROOF_HEIGHT+7))
    light=bpy.context.object
    light.data.energy=2300
    light.data.shape='DISK'
    light.data.size=10
    point_camera(light,(0,0,6))
    bpy.ops.object.light_add(type='SUN',location=(-8,-6,14))
    sun=bpy.context.object
    sun.data.energy=2
    sun.data.angle=.15
    sun.rotation_euler=(.35,-.50,-.5)
    bpy.ops.object.camera_add()
    cam=bpy.context.object
    scene.camera=cam
    cam.data.type='ORTHO'
    cam.data.ortho_scale=ROOF_HEIGHT+4.0
    for name,pos in [('exterior',(32,-42,34)),('rear',(-30,38,31))]:
        cam.location=pos
        point_camera(cam,(1,0,ROOF_HEIGHT*.5))
        scene.render.filepath=str(out/f'{name}.png')
        bpy.ops.render.render(write_still=True)
    cam.data.type='PERSP'
    cam.data.lens=20
    cam.location=(0,-2.80,FLOOR+1.65)
    point_camera(cam,(0,1.0,FLOOR+1.10))
    bpy.ops.object.light_add(type='AREA',location=(.60,1.3,FLOOR+2.3))
    room_light=bpy.context.object
    room_light.data.energy=90
    room_light.data.color=(1.0,.75,.44)
    room_light.data.size=1.4
    point_camera(room_light,(0,0,FLOOR+.6))
    scene.render.filepath=str(out/'interior.png')
    bpy.ops.render.render(write_still=True)


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--output-dir',required=True)
    ap.add_argument('--preview-dir',required=True)
    ap.add_argument('--render',action='store_true')
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:])
    out=Path(args.output_dir).resolve();out.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    batches={name:Batch('lookout_'+name,col) for name,col in PALETTE.items()}
    structure(batches);stairs(batches);cabin(batches)
    objs=[b.finish(material(b.name,'glass' in b.name)) for b in batches.values()]
    for obj in objs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
    blend=out/'fire_lookout.blend'
    if hasattr(bpy.context.preferences.filepaths,'save_preview_images'):
        bpy.context.preferences.filepaths.save_preview_images=False
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    glb=out/'fire_lookout.glb'
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,
                              export_yup=True,export_apply=True,export_normals=True,
                              export_materials='EXPORT')
    triangles=sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in objs)
    vertices=sum(len(ob.data.vertices) for ob in objs)
    if triangles>15000:
        raise RuntimeError(f'Triangle budget exceeded: {triangles}')
    spec={
        'schema':2,'name':'fire_lookout','seed':SEED,'units':'metres','up_axis':'Godot +Y',
        'roof_height':ROOF_HEIGHT,'original_roof_height':ORIGINAL_ROOF_HEIGHT,
        'floor_y':FLOOR,'deck_half':[3.8,3.3],'cabin_half':[2.7,2.2],
        'deck_height':FLOOR,'deck_bounds':[-3.8,-3.3,3.8,3.3],
        'room_bounds':[-2.7,-2.2,2.7,2.2],'door_width':1.1,
        'supports':[[x,z,.30] for x in [-2.95,2.95] for z in [-2.45,2.45]]+[[x,z,.20] for x in STAIR_POST_X for z in STAIR_POST_Y],
        'door':{'x':0,'z':2.19,'width':1.1,'hinge_x':-.55,'leaf_mesh':'lookout_door','open_degrees':105},
        'stove':{'center':[-1.65,FLOOR,1.20],'yaw_degrees':math.degrees(math.atan2(1.65,-1.20))},
        'stairs':{'flights':FLIGHTS,'steps_per_flight':STEPS_PER_FLIGHT,'riser':RISER,'run':.30,'width':1.1,
                  'lane_x':[4.45 if f%2==0 else 5.8 for f in range(FLIGHTS)],
                  'z_start':[1.8 if f%2==0 else -1.8 for f in range(FLIGHTS)],
                  'z_end':[-1.8 if f%2==0 else 1.8 for f in range(FLIGHTS)],'landing_x':[3.7,6.5],
                  'landing_depth':.8,'landing_z':[-2.2 if f%2==0 else 2.2 for f in range(FLIGHTS)],
                  'standing_clearance_m':2.0,'support_planes_z':[-2.90,2.90],
                  'rail_end_inset_m':.12,'visual_landing_x':[3.64,6.56],'visual_landing_depth':.84},
        'mesh_objects':len(objs),'triangles':triangles,'vertices':vertices,
        'material_count':len(objs),'file_bytes':glb.stat().st_size,
        'sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),
        'source':'Original procedural geometry: tools/blender/gen_fire_lookout.py',
        'generator_sha256':hashlib.sha256(Path(__file__).read_text(encoding='utf-8').replace('\r\n','\n').encode('utf-8')).hexdigest(),
        'license':'Project-authored original asset; same ownership as repository',
        'blender_version':bpy.app.version_string,
        'design':'Winter forestry lookout on timber stilts, glazed elevated room, snow hip roof, continuous switchback access, muted wood/green/blue palette',
        'negative_constraints':'No copied meshes/textures, no terrain edits, no external paid generation, no more than 15000 triangles',
    }
    (out/'fire_lookout_geometry.json').write_text(json.dumps(spec,indent=2)+'\n',encoding='utf-8')
    print('LOOKOUT_ASSET',json.dumps(spec))
    if args.render:
        render_previews(Path(args.preview_dir).resolve())


if __name__=='__main__':
    main()
