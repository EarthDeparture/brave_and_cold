"""Original technician power-distribution panel; metres, 4 draw surfaces.
Blender -Y front becomes Godot +Z. Source remains separate from lookout GLB.
"""
import bpy,bmesh,math,json,hashlib,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'brave-and-cold/assets/route_detail';OUT.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'tools/blender/generated/route_detail';SOURCE.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
texture=OUT/'panel_face.png'
def material(name,color,rough=.8,metal=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*color,1);b.inputs['Roughness'].default_value=rough;b.inputs['Metallic'].default_value=metal;return m
paint=material('aged_powder_coat',(.22,.28,.26),.79,.2)
steel=material('brushed_fasteners',(.31,.34,.34),.48,.75)
rubber=material('switches_gaskets_and_recesses',(.035,.043,.04),.88,.04)
face=material('authored_service_graphics',(.7,.7,.7),.82,.02)
img=bpy.data.images.load(str(texture));img.pack();tex=face.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img;face.node_tree.links.new(tex.outputs['Color'],face.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
def box(name,p,size,mat,bevel=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.name=name;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
 if bevel:
  mod=o.modifiers.new('manufactured_edges','BEVEL');mod.width=bevel;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o
box('weatherproof_enclosure',(0,0,.35),(.48,.145,.70),paint,.008)
box('door_gasket',(0,-.078,.35),(.462,.008,.677),rubber,.004)
box('pressed_front_door',(0,-.088,.35),(.450,.015,.665),paint,.006)
verts=[(-.212,-.098,.033),(.212,-.098,.033),(.212,-.098,.669),(-.212,-.098,.669)]
me=bpy.data.meshes.new('panel_graphics');me.from_pydata(verts,[],[(0,1,2,3)]);me.materials.append(face);me.update();o=bpy.data.objects.new('printed_face',me);bpy.context.collection.objects.link(o);uv=me.uv_layers.new()
for loop in me.loops:uv.data[loop.index].uv=[(0,0),(1,0),(1,1),(0,1)][loop.vertex_index]
for x in [-.19,.19]:
 for z in [.052,.648]:
  bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=.006,depth=.005,location=(x,-.103,z),rotation=(math.pi/2,0,0));bpy.context.object.data.materials.append(steel)
for z in [.48,.14]:box('hinge',(-.235,0,z),(.023,.051,.07),steel,.003)
box('latch',(.198,-.112,.35),(.023,.022,.06),steel,.003)
# Breaker rails, recessed toggles and strain reliefs are actual geometry.
for i in range(4):
 z=.278-i*.058
 box('breaker_recess',(.116,-.110,z),(.080,.015,.035),rubber,.003)
 box('toggle',(.116,-.129,z+.004),(.016,.025,.025),steel,.002)
for x in [-.13,0,.13]:
 bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.014,depth=.028,location=(x,0,-.008));bpy.context.object.data.materials.append(rubber)
for z in [.36,.395,.43,.465]:box('vent',(.120,-.012,z),(.09,.01,.007),rubber)
# Real edges, bounded material groups, no per-screw draw calls.
objects=[]
for m in [paint,steel,rubber,face]:
 group=[o for o in bpy.data.objects if o.type=='MESH' and o.data.materials[0]==m]
 bpy.ops.object.select_all(action='DESELECT')
 for o in group:o.select_set(True)
 bpy.context.view_layer.objects.active=group[0]
 if len(group)>1:bpy.ops.object.join()
 o=bpy.context.object;o.name=m.name;objects.append(o)
 for poly in o.data.polygons:poly.use_smooth=False
triangles=0
for o in objects:o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
assert triangles<2500
bpy.ops.object.select_all(action='SELECT')
model=OUT/'field_power_panel.glb'
bpy.ops.export_scene.gltf(filepath=str(model),export_format='GLB',use_selection=True,export_yup=True,export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'field_power_panel.blend'))
receipt={'origin':'Project-authored original Blender geometry and painted graphics','units':'metres','triangles':triangles,'draw_surfaces':4,'dimensions_m':[.48,.70,.19],'generator':'tools/blender/gen_field_panel.py','sha256':hashlib.sha256(model.read_bytes()).hexdigest(),'texture_sha256':hashlib.sha256(texture.read_bytes()).hexdigest(),'license':'Original project-owned asset; system font is rasterized, not redistributed'}
(OUT/'provenance.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('FIELD_PANEL_COMPLETE',json.dumps(receipt))
