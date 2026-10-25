"""Original connected winter crowns. Blender 5.2; staged exports, no scatter edits."""
from pathlib import Path
import bpy, math, random, json, hashlib
from mathutils import Vector

R=Path(__file__).resolve().parents[2]
OUT=R/'tools/blender/generated/forest_quality'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
bpy.context.scene.unit_settings.system='METRIC'
mat=bpy.data.materials.new('OriginalWinterPalette');mat.use_nodes=True
nodes=mat.node_tree.nodes;links=mat.node_tree.links
color=nodes.new('ShaderNodeVertexColor');color.layer_name='Surface'
links.new(color.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
nodes.get('Principled BSDF').inputs['Roughness'].default_value=.92
tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(OUT/'needle_spray.png'));tex.image.pack()
snow_tex=nodes.new('ShaderNodeTexImage');snow_tex.image=bpy.data.images.load(str(OUT/'needle_spray_snow.png'));snow_tex.image.pack()
is_snow=nodes.new('ShaderNodeMath');is_snow.operation='GREATER_THAN';is_snow.inputs[1].default_value=.51;links.new(color.outputs['Alpha'],is_snow.inputs[0])
spray=nodes.new('ShaderNodeMixRGB');links.new(is_snow.outputs[0],spray.inputs[0]);links.new(tex.outputs['Color'],spray.inputs[1]);links.new(snow_tex.outputs['Color'],spray.inputs[2])
lo=nodes.new('ShaderNodeMath');lo.operation='GREATER_THAN';lo.inputs[1].default_value=.3;links.new(color.outputs['Alpha'],lo.inputs[0])
hi=nodes.new('ShaderNodeMath');hi.operation='LESS_THAN';hi.inputs[1].default_value=.8;links.new(color.outputs['Alpha'],hi.inputs[0])
mask=nodes.new('ShaderNodeMath');mask.operation='MULTIPLY';links.new(lo.outputs[0],mask.inputs[0]);links.new(hi.outputs[0],mask.inputs[1])
mix=nodes.new('ShaderNodeMixRGB');links.new(mask.outputs[0],mix.inputs[0]);links.new(color.outputs['Color'],mix.inputs[1]);links.new(spray.outputs[0],mix.inputs[2]);links.new(mix.outputs[0],nodes.get('Principled BSDF').inputs['Base Color'])
alpha=nodes.new('ShaderNodeMixRGB');alpha.inputs[1].default_value=(1,1,1,1);links.new(mask.outputs[0],alpha.inputs[0]);links.new(tex.outputs['Alpha'],alpha.inputs[2]);links.new(alpha.outputs[0],nodes.get('Principled BSDF').inputs['Alpha']);mat.surface_render_method='DITHERED'
SPEC={
 'spruce_a':(211,12,.162,.20,.18,.78),
 'spruce_b':(317,12,.133,.28,.24,.62),
 'spruce_c':(419,11,.185,.22,.20,.86),
 'snow_pine_open':(1031,10,.144,.22,.38,.54),
 'snow_fir_full':(2053,12,.153,.34,.16,.90),
 'snow_spruce_wind':(3079,12,.132,.40,.22,.68),
}
SNOW=(.64,.71,.77);LEAF=(.075,.135,.103);BARK=(.72,.75,.68)

class Mesh:
 def __init__(self,name):self.name=name;self.v=[];self.f=[];self.c=[];self.uv=[]
 def vert(self,p,c,uv=(0,0)):
  self.v.append(tuple(p));self.c.append(c);self.uv.append(uv);return len(self.v)-1
 def loft(self,centers,radii,c,sides,up=False):
  rings=[];travel=0
  for j,(p,r) in enumerate(zip(centers,radii)):
   p=Vector(p)
   if j:travel+=(p-Vector(centers[j-1])).length
   axis=(Vector(centers[min(j+1,len(centers)-1)])-Vector(centers[max(0,j-1)])).normalized()
   ref=Vector((0,0,1)) if abs(axis.z)<.95 else Vector((1,0,0))
   u=axis.cross(ref).normalized();v=axis.cross(u).normalized()
   rings.append([self.vert(p+(u*math.cos(k*math.tau/sides)+v*math.sin(k*math.tau/sides))*r,c,(k/sides,travel*12)) for k in range(sides)])
  self.bridge(rings)
 def bridge(self,rings):
  n=len(rings[0]);self.f.append(tuple(reversed(rings[0])));self.f.append(tuple(rings[-1]))
  for a,b in zip(rings,rings[1:]):
   for k in range(n):self.f.append((a[k],a[(k+1)%n],b[(k+1)%n],b[k]))
 def snow(self,a,b,width,depth,far,seed):
  a,b=Vector(a),Vector(b);axis=(b-a).normalized();cross=Vector((-axis.y,axis.x,0)).normalized()
  if far:
   # At >130m retain the loaded branch silhouette with four shaded facets,
   # leaving high-density drift cross-sections to the near resource.
   points=[a-cross*width*.72,a+cross*width*.72,b-cross*width*.52,b+cross*width*.52,a.lerp(b,.5)+Vector((0,0,depth))]
   ids=[self.vert(p,(*SNOW,1),uv) for p,uv in zip(points,[(0,0),(0,1),(1,0),(1,1),(.5,.5)])]
   for face in [(0,1,4),(1,3,4),(3,2,4),(2,0,4)]:self.f.append(tuple(ids[i] for i in face))
   return
  # Cross-section follows a rounded drift, not a horizontal polygon fan.
  # Both LODs retain the same supported underside and full width/depth.
  section=[(-1,0),(0,1),(1,0)] if far else [(-1,0),(-.72,.72),(0,1),(.72,.72),(1,0)]
  rings=[]
  for t,s in [(0,.48),(.28,.95),(.60,.84),(1,.28)]:
   ring=[]
   for k,(side,level) in enumerate(section):
    p=a.lerp(b,t)+cross*side*width*s*(1+.18*math.sin(seed+t*8.7+side*1.3))
    p.z+=depth*level*s
    tone=.91+.09*level
    ring.append(self.vert(p,tuple(x*tone for x in SNOW)+(1,), (t,(side+1)*.5)))
   rings.append(ring)
  self.bridge(rings)
 def needles(self,a,b,width,tilt,far=False,loaded=False):
  a,b=Vector(a),Vector(b);axis=(b-a).normalized();cross=Vector((-axis.y,axis.x,0)).normalized();up=axis.cross(cross).normalized()
  side=cross*math.cos(tilt)+up*math.sin(tilt);rows=[]
  for t in ([0,1] if far else [0,.5,1]):
   center=a.lerp(b,t)+Vector((0,0,-math.sin(t*math.pi)*(b-a).length*.055))
   rows.append([self.vert(center+side*(v-.5)*width,(1,1,1,.52 if loaded else .50),(t,.27+.46*v)) for v in [0,1]])
  for aa,bb in zip(rows,rows[1:]):self.f.append((aa[0],bb[0],bb[1],aa[1]))
 def finish(self):
  me=bpy.data.meshes.new(self.name);me.from_pydata(self.v,[],self.f);me.update()
  col=me.color_attributes.new(name='Surface',type='FLOAT_COLOR',domain='CORNER');uv=me.uv_layers.new(name='SurfaceUV')
  for face in me.polygons:
   face.use_smooth=True
   for li in face.loop_indices:
    i=me.loops[li].vertex_index;col.data[li].color=self.c[i];uv.data[li].uv=self.uv[i]
  me.color_attributes.active_color=col;me.color_attributes.render_color_index=0;me.materials.append(mat)
  ob=bpy.data.objects.new(self.name,me);bpy.context.collection.objects.link(ob);return ob

def build(name,cfg,far):
 seed,tiers,radius,droop,start,load=cfg;rng=random.Random(seed);m=Mesh(name)
 lean=Vector((.045 if seed==3079 else rng.uniform(-.015,.015),rng.uniform(-.012,.012),0))
 def trunk(z):return Vector((0,0,z))+lean*z*z
 zs=[0,.25,.50,.75,1]
 m.loft([trunk(z) for z in zs],[.016*(1-z*.97) for z in zs],(*BARK,.10),4 if far else 8)
 for tier in range(tiers):
  f=tier/(tiers-1);z=start+(.94-start)*f
  profile=(math.sin((f*.84+.13)*math.pi)**.72 if seed==1031 else (1-f)**.82)
  reach=radius*profile+.005
  for j in range(5):
   angle=tier*2.399+j*math.tau/5+rng.uniform(-.23,.23)
   stretch=(.70+.30*(1+math.cos(angle))) if seed==3079 else 1
   length=reach*rng.uniform(.83,1.13)*stretch
   axis=Vector((math.cos(angle),math.sin(angle),-droop*(1-f*.4))).normalized()
   a=trunk(z+rng.uniform(-.018,.018));b=a+axis*length
   width=length*rng.uniform(.36,.44);height=length*.085
   has_snow=rng.random()<load
   if not far:m.loft([a,a.lerp(b,.55),b],[.0024*(1-f*.65),.0014,.00035],(*BARK,.10),4)
   for tilt in ([-.40] if far else [-.40,.75,1.57]):m.needles(a.lerp(b,.08),b,width*1.9,tilt,far,has_snow)
   if has_snow:
    # The underside sits on the same bough; irregular longitudinal load leaves
    # green tips exposed and cannot become disconnected white disks.
    aa=a.lerp(b,.24)+Vector((0,0,height*.50));bb=a.lerp(b,.88)+Vector((0,0,height*.50))
    m.snow(aa,bb,width*.88,length*.12,far,tier*5+j)
 for j in range(3):
  angle=j*math.tau/3
  a=trunk(.93);b=trunk(1)+Vector((math.cos(angle)*.008,math.sin(angle)*.008,0))
  m.needles(a,b,.03,angle,far)
 return m.finish()

entries=[]
for family,cfg in SPEC.items():
 for far in [False,True]:
  name=family+('_far' if far else '');ob=build(name,cfg,far)
  bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
  ob.data.calc_loop_triangles();n=len(ob.data.loop_triangles)
  assert n<=(1100 if far else 4200),(name,n)
  p=OUT/(name+'.glb')
  bpy.ops.export_scene.gltf(filepath=str(p),export_format='GLB',use_selection=True,export_yup=True,export_vertex_color='ACTIVE',export_materials='NONE')
  entries.append({'name':name,'triangles':n,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
  ob.hide_set(True);ob.hide_render=True
  if not far:
   preview=ob.copy();preview.data=ob.data;bpy.context.collection.objects.link(preview);preview.hide_set(False);preview.hide_render=False
   preview.scale=(18,18,18);preview.location=(list(SPEC).index(family)*9,0,0)
  print('FOREST_QUALITY',name,n,flush=True)
native=OUT/'winter_crowns.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native))
(OUT/'manifest.json').write_text(json.dumps({'schema':1,'origin':'Original project-authored Blender geometry and original botanical paint','units':'1m root-normalized; Godot +Y up; existing canopy scaling retained','surface':'alpha .10 bark, .50 green spray, .52 snow-loaded spray, 1 supported snow; one surface; no collision','budget':{'near':4200,'far':1100},'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'texture_sha256':hashlib.sha256((OUT/'needle_spray.png').read_bytes()).hexdigest(),'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'models':entries},indent=2)+'\n')
