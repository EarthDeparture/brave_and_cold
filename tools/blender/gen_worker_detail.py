"""Original close winter worker; retain baseline, rig weights and editable source.
Run with local Blender --background --python tools/blender/gen_worker_detail.py.
Godot coordinates are metres, Y up, face/boot toes towards -Z.
"""
from pathlib import Path
import bpy, bmesh, math, json, hashlib
from mathutils import Vector
from mathutils.kdtree import KDTree

R=Path(__file__).resolve().parents[2]
OUT=R/'tools/blender/generated/worker_detail'
RT=R/'brave-and-cold/assets/infected/detail'
OUT.mkdir(parents=True,exist_ok=True); RT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(R/'tools/blender/generated/infected_skin/winter_worker_skin.blend'))
bpy.context.preferences.filepaths.save_version=0
rig=bpy.data.objects['WinterWorkerSkeleton']
def cv(v): return Vector((v[0],-v[2],v[1]))
def active(ob):
 bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active=ob
def material(name,col,rough=.88,metal=0):
 m=bpy.data.materials.new(name); m.use_nodes=True; m.diffuse_color=(*col,1)
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*col,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 return m
coat_old=bpy.data.objects['Skin_winter_canvas']
# Transfer existing deliberate shoulder/elbow weights to the new continuous shell.
kd=KDTree(len(coat_old.data.vertices)); saved=[]
for v in coat_old.data.vertices:
 kd.insert(v.co,v.index); saved.append({coat_old.vertex_groups[g.group].name:g.weight for g in v.groups})
kd.balance()
coatmat=coat_old.data.materials[0].copy(); coatmat.name='winter_canvas_detail'
parts=[]
def mesh(name,vs,fs,ma):
 me=bpy.data.meshes.new(name);me.from_pydata([cv(v) for v in vs],[],fs);me.update()
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
 ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);ob.data.materials.append(ma)
 for f in me.polygons:f.use_smooth=True
 return ob
def loft(name,profile,ma,n=32,fold=.002):
 vs=[];fs=[]
 for j,(x,y,z,rx,rz) in enumerate(profile):
  for k in range(n):
   a=k*math.tau/n; wrinkle=fold*math.sin(5*a+j*.9)*math.sin(j*.8)
   vs.append((x+math.cos(a)*(rx+wrinkle),y,z+math.sin(a)*(rz+wrinkle)))
 for j in range(len(profile)-1):
  for k in range(n):fs.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
 fs += [tuple(reversed(range(n))),tuple((len(profile)-1)*n+k for k in range(n))]
 return mesh(name,vs,fs,ma)
parts.append(loft('TailoredJacket',[(0,.968,.006,.177,.119),(0,.989,.006,.183,.121),(0,1.06,.01,.183,.131),(0,1.16,.01,.187,.142),(0,1.28,.007,.190,.144),(0,1.37,.006,.210,.136),(0,1.414,.004,.245,.12),(0,1.45,.002,.221,.105),(0,1.49,0,.086,.073)],coatmat,48,.0035))
for sign in [-1,1]:
 parts.append(loft('SetInSleeve',[(sign*.218,1.445,0,.065,.078),(sign*.274,1.397,0,.080,.084),(sign*.310,1.32,-.002,.072,.079),(sign*.302,1.23,-.004,.066,.075),(sign*.293,1.14,-.004,.062,.068),(sign*.285,1.08,-.006,.062,.063),(sign*.287,1.015,-.006,.068,.07),(sign*.287,.955,-.006,.062,.063),(sign*.286,.88,-.008,.055,.054),(sign*.286,.82,-.01,.05,.05),(sign*.286,.797,-.01,.051,.051)],coatmat,32,.003))
# Volume union removes the old overlap seam at each shoulder. Decimate only
# after smoothing, then transfer normalized weights from the accepted rig.
active(parts[0])
for ob in parts:ob.select_set(True)
bpy.ops.object.join();coat=bpy.context.object;coat.name='Skin_winter_canvas_detail'
rem=coat.modifiers.new('Continuous sewn shoulder volume','REMESH');rem.mode='VOXEL';rem.voxel_size=.009;rem.use_smooth_shade=True
bpy.ops.object.modifier_apply(modifier=rem.name)
sm=coat.modifiers.new('Relax fabric volume','SMOOTH');sm.factor=.65;sm.iterations=4;bpy.ops.object.modifier_apply(modifier=sm.name)
dec=coat.modifiers.new('Bounded close topology','DECIMATE');dec.ratio=min(1,6500/max(1,sum(len(p.vertices)-2 for p in coat.data.polygons)));bpy.ops.object.modifier_apply(modifier=dec.name)
groups={n:coat.vertex_groups.new(name=n) for n in rig.data.bones.keys()}
def smooth(a,b,t):
 t=max(0,min(1,(t-a)/(b-a)));return t*t*(3-2*t)
fields=[]
for v in coat.data.vertices:
 # A joined shoulder cannot inherit the hard region boundary of separate
 # source pieces. Paint one continuous field through the sewn shoulder.
 x,y=abs(v.co.x),v.co.z;side='l' if v.co.x<0 else 'r'
 shoulder=smooth(.155,.285,x)*(1-smooth(1.41,1.49,y))
 low=smooth(.200,.215,x)
 blend=smooth(1.31,1.40,y);arm=low*(1-blend)+shoulder*blend
 elbow=1-smooth(1.005,1.135,y)
 pelvis=(1-arm)*(1-smooth(.975,1.09,y))
 ws={'skin_zombie_arm_'+side:arm*(1-elbow),'skin_zombie_elbow_'+side:arm*elbow,'pelvis':pelvis,'spine':1-arm-pelvis}
 fields.append(ws)
# Relax weights along the continuous surface, rather than across the air gap
# between torso and sleeve. This preserves pure cuff weights and spreads the
# shoulder transition without reintroducing the old detached volume boundary.
adj=[set() for v in coat.data.vertices]
for edge in coat.data.edges:
 a,b=edge.vertices;adj[a].add(b);adj[b].add(a)
for iteration in range(44):
 next_fields=[]
 for i,ws in enumerate(fields):
  out={n:w*.35 for n,w in ws.items()}
  for j in adj[i]:
   for n,w in fields[j].items():out[n]=out.get(n,0)+w*.65/max(1,len(adj[i]))
  next_fields.append(out)
 fields=next_fields
for i,ws in enumerate(fields):
 for name,w in ws.items():
  if w>1e-7:groups[name].add([i],w,'REPLACE')
coat.parent=rig;mod=coat.modifiers.new('Continuous joint deformation','ARMATURE');mod.object=rig
bpy.data.objects.remove(coat_old,do_unlink=True)

# Replace the primitive face with a single shaped surface, retaining hands.
skin=bpy.data.objects['Skin_pallid_skin'];active(skin);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='DESELECT');bpy.ops.object.mode_set(mode='OBJECT')
for v in skin.data.vertices:v.select=v.co.z>1.43
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.separate(type='SELECTED');bpy.ops.object.mode_set(mode='OBJECT')
old_head=next(o for o in bpy.context.selected_objects if o!=skin);bpy.data.objects.remove(old_head,do_unlink=True)
profile=[(1.44,.046,.046,.006),(1.50,.046,.047,.004),(1.54,.049,.052,.006),(1.565,.058,.062,.004),(1.59,.073,.069,.003),(1.62,.080,.073,.002),(1.65,.086,.080,.003),(1.69,.085,.087,.004),(1.72,.083,.086,.007),(1.75,.072,.075,.009),(1.773,.050,.057,.010),(1.786,.025,.033,.01),(1.792,.001,.001,.01)]
vs=[];fs=[];n=64;rows=89
for j in range(rows):
 y=1.44+j/(rows-1)*.352
 at=next((i for i in range(len(profile)-1) if profile[i][0]<=y<=profile[i+1][0]),len(profile)-2)
 lo,hi=profile[at],profile[at+1];t=(y-lo[0])/(hi[0]-lo[0])
 rx,rz,zc=[lo[k]*(1-t)+hi[k]*t for k in [1,2,3]]
 for k in range(n):
  a=k*math.tau/n;x=math.cos(a)*rx;z=zc+math.sin(a)*rz;front=max(0,-math.sin(a))**8
  def g(cx,cy,sx,sy):return math.exp(-((x-cx)/sx)**2-((y-cy)/sy)**2)
  nose=.025*g(0,1.65,.014,.025)+.008*g(0,1.687,.011,.025)
  nostril=.004*(g(-.015,1.643,.007,.006)+g(.015,1.643,.007,.006))
  socket=.006*(g(-.033,1.689,.020,.013)+g(.033,1.689,.020,.013))
  brow=.005*(g(-.032,1.706,.023,.007)+g(.032,1.706,.023,.007))
  cheek=.004*(g(-.043,1.645,.023,.026)+g(.043,1.645,.023,.026))
  lip=.0025*g(0,1.610,.030,.004)-.003*g(0,1.604,.031,.003)
  z-=front*(nose+nostril+brow+cheek+lip-socket)
  vs.append((x,y,z))
for j in range(rows-1):
 for k in range(n):fs.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
fs += [tuple(reversed(range(n))),tuple((rows-1)*n+k for k in range(n))]
head=mesh('AnatomicalFaceNeck',vs,fs,skin.data.materials[0]);active(head)
dec=head.modifiers.new('Facial surface budget','DECIMATE');dec.ratio=4500/(2*n*(rows-1));bpy.ops.object.modifier_apply(modifier=dec.name)
gh=head.vertex_groups.new(name='head');gs=head.vertex_groups.new(name='spine')
for v in head.data.vertices:
 w=smooth(1.47,1.55,v.co.z)
 if w>0:gh.add([v.index],w,'REPLACE')
 if w<1:gs.add([v.index],1-w,'REPLACE')
head.parent=rig;mod=head.modifiers.new('Facial deformation','ARMATURE');mod.object=rig
active(skin);head.select_set(True);bpy.ops.object.join();skin.name='Skin_pallid_skin'
# Small inset eyes and integrated ears; never floating pale eyeball spheres.
old_eye=bpy.data.objects['Skin_shadowed_eyes'];eyemat=old_eye.data.materials[0].copy();bpy.data.objects.remove(old_eye,do_unlink=True)
bpy.data.objects.remove(bpy.data.objects['Skin_dry_wound'],do_unlink=True)
bs=eyemat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.026,.030,.019,1);bs.inputs['Roughness'].default_value=.95;bs.inputs['Specular IOR Level'].default_value=.05
for sign in [-1,1]:
 for name,p,size,ma in [('InsetEye',(sign*.033,1.689,-.0765),(.0145,.005,.0035),eyemat),('EarRim',(sign*.084,1.65,.013),(.010,.024,.016),skin.data.materials[0])]:
  bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=10,location=cv(p));ob=bpy.context.object;ob.name=name;ob.scale=(size[0],size[2],size[1]);active(ob);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
  ob.data.materials.append(ma)
  for f in ob.data.polygons:f.use_smooth=True
  ob.vertex_groups.new(name='head').add(list(range(len(ob.data.vertices))),1,'REPLACE');ob.parent=rig;mod=ob.modifiers.new('Head attachment','ARMATURE');mod.object=rig

# Restrained seam/welt geometry and boot construction share existing surfaces.
detailmat=material('canvas_welts',(.12,.16,.13));metalmat=bpy.data.materials['steel']
def tube(name,a,b,r,ma,n=10):
 aa,bb=cv(a),cv(b);d=bb-aa
 bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=d.length,location=(aa+bb)/2)
 ob=bpy.context.object;ob.name=name;ob.rotation_mode='QUATERNION';ob.rotation_quaternion=d.to_track_quat('Z','Y');ob.data.materials.append(ma)
 active(ob);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 for f in ob.data.polygons:f.use_smooth=len(f.vertices)==4
 return ob
def weight(ob,kind='cloth',side=None):
 gs={n:ob.vertex_groups.new(name=n) for n in rig.data.bones.keys()}
 for v in ob.data.vertices:
  if kind=='cloth':
   ws={'spine':1}
  else:ws={'skin_zombie_ankle_'+side:1}
  for name,w in ws.items():gs[name].add([v.index],w,'REPLACE')
 ob.parent=rig;mod=ob.modifiers.new('Deform with garment','ARMATURE');mod.object=rig
for sign in [-1,1]:
 side='l' if sign<0 else 'r'
 for y in [1.067,1.105]:
  ob=tube('PocketWelt',(sign*.065,y,-.132),(sign*.165,y+.009,-.11),.0033,detailmat);weight(ob)
 ob=tube('CollarEdge',(sign*.032,1.447,-.089),(sign*.075,1.488,-.071),.003,detailmat);weight(ob)
 # Ankle bones keep the planted boot upright while the knee articulates.
active(rig);bpy.ops.object.mode_set(mode='EDIT')
for sign,side in [(-1,'l'),(1,'r')]:
 b=rig.data.edit_bones.new('skin_zombie_ankle_'+side);b.head=cv((sign*.1,.09,-.015));b.tail=cv((sign*.1,.09,-.15));b.parent=rig.data.edit_bones['skin_zombie_knee_'+side]
bpy.ops.object.mode_set(mode='OBJECT')
rubber=bpy.data.objects['Skin_rubber']
active(rubber)
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='DESELECT');bpy.ops.object.mode_set(mode='OBJECT')
for v in rubber.data.vertices:v.select=v.co.z<.22
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.delete(type='VERT');bpy.ops.object.mode_set(mode='OBJECT')
for side in ['l','r']:rubber.vertex_groups.new(name='skin_zombie_ankle_'+side)
for v in rubber.data.vertices:
 if v.co.z<.19:
  side='l' if v.co.x<0 else 'r'
  for g in list(v.groups):rubber.vertex_groups[g.group].remove([v.index])
  rubber.vertex_groups['skin_zombie_ankle_'+side].add([v.index],1,'REPLACE')
for sign,side in [(-1,'l'),(1,'r')]:
 vs=[];fs=[];n=24
 # Foot-last profile with a flattened sole, rounded toe and higher ankle.
 for z,rx,center_y,ry in [(-.182,.006,.055,.013),(-.172,.043,.058,.037),(-.145,.071,.066,.049),(-.095,.076,.078,.061),(-.035,.073,.091,.075),(.025,.066,.111,.096),(.073,.058,.103,.088),(.083,.039,.074,.059)]:
  for k in range(n):
   a=math.tau*k/n;vs.append((sign*.1+rx*math.cos(a),max(.0115,center_y+ry*math.sin(a)-.02),z))
 for j in range(7):
  for k in range(n):fs.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
 fs += [tuple(reversed(range(n))),tuple(7*n+k for k in range(n))]
 ob=mesh('LeatherBootLast',vs,fs,rubber.data.materials[0]);weight(ob,'boot',side)
 for y,z in [(.105,-.122),(.128,-.097),(.149,-.072)]:
  ob=tube('BootLacing',(sign*.1-.031,y-.02,z),(sign*.1+.031,y-.02,z),.0026,detailmat,8);weight(ob,'boot',side)

# Original periodic woven canvas: albedo, roughness and OpenGL tangent normal.
# Full image pixels are saved, embedded in GLB and packed in the native source.
N=512
def image(name,fn,noncolor=False):
 im=bpy.data.images.new(name,width=N,height=N,alpha=True);pixels=[]
 for y in range(N):
  for x in range(N):pixels.extend((*fn(x,y),1))
 if noncolor:im.colorspace_settings.name='Non-Color'
 im.pixels.foreach_set(pixels);im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG'
 im.save();im.pack();return im
def tex(x,y):
 broad=.012*math.sin(x*math.tau/N*3)*math.cos(y*math.tau/N*5)
 weave=.008*math.sin(x*math.pi/2)*math.sin(y*math.pi/2)
 return tuple(c+broad+weave for c in (.36,.40,.32))
alb=image('worker_canvas_albedo',tex)
rough=image('worker_canvas_roughness',lambda x,y:(.87+.045*math.sin(x*math.tau/N*4)*math.cos(y*math.tau/N*3),)*3,True)
normal=image('worker_canvas_normal',lambda x,y:(.5+.04*math.cos(x*math.pi/2),.5+.04*math.cos(y*math.pi/2),.997),True)
nodes=coatmat.node_tree.nodes;links=coatmat.node_tree.links;bs=nodes.get('Principled BSDF')
for n in list(nodes):
 if n.type=='TEX_IMAGE':nodes.remove(n)
bs.inputs['Base Color'].default_value=(1,1,1,1)
for im,socket in [(alb,'Base Color'),(rough,'Roughness')]:
 n=nodes.new('ShaderNodeTexImage');n.image=im;links.new(n.outputs['Color'],bs.inputs[socket])
n=nodes.new('ShaderNodeTexImage');n.image=normal;nm=nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.4;links.new(n.outputs['Color'],nm.inputs['Color']);links.new(nm.outputs['Normal'],bs.inputs['Normal'])
# Cylindrical UVs: textile runs vertically; split the angular seam explicitly.
uv=coat.data.uv_layers.new(name='TailoredUV')
for face in coat.data.polygons:
 coords=[]
 for li in face.loop_indices:
  v=coat.data.vertices[coat.data.loops[li].vertex_index].co
  center=.283*(1 if v.x>0 else -1) if abs(v.x)>.22 and v.z<1.40 else 0
  coords.append([math.atan2(v.x-center,-v.y)/math.tau+.5,v.z*3])
 if max(p[0] for p in coords)-min(p[0] for p in coords)>.5:
  for p in coords:
   if p[0]<.5:p[0]+=1
for li,p in zip(face.loop_indices,coords):uv.data[li].uv=p

# Original face paint anchored to actual facial coordinates: subdued sockets,
# lip crease, cheek/temple shading and small mottling instead of a white mask.
def face_tex(px,py):
 x=(px/(N-1)-.5)*.24;y=1.43+py/(N-1)*.39
 def g(cx,cy,sx,sy):return math.exp(-((x-cx)/sx)**2-((y-cy)/sy)**2)
 sockets=g(-.033,1.684,.026,.024)+g(.033,1.684,.026,.024)
 cheek=g(-.061,1.634,.027,.033)+g(.061,1.634,.027,.033)
 mouth=g(0,1.607,.036,.006)
 stubble=g(0,1.59,.069,.027)*(.008+.004*math.sin(px*2.9)*math.cos(py*3.7))
 mottling=.009*math.sin(px*.08)*math.cos(py*.12)
 return tuple(max(.06,c-mottling-sockets*.085-cheek*.045-mouth*.12-stubble) for c in (.38,.35,.30))
face=image('worker_skin_albedo',face_tex)
old_skinmat=skin.data.materials[0];skinmat=old_skinmat.copy();skinmat.name='pallid_skin_detail'
bs=skinmat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(1,1,1,1)
n=skinmat.node_tree.nodes.new('ShaderNodeTexImage');n.image=face;skinmat.node_tree.links.new(n.outputs['Color'],bs.inputs['Base Color'])
for ob in bpy.context.scene.objects:
 if ob.type!='MESH' or ob.data.materials[0]!=old_skinmat:continue
 ob.data.materials[0]=skinmat
 uv=ob.data.uv_layers.active or ob.data.uv_layers.new(name='FaceCoordinates')
 for f in ob.data.polygons:
  for li in f.loop_indices:
   v=ob.data.vertices[ob.data.loops[li].vertex_index].co
   uv.data[li].uv=(v.x/.24+.5,(v.z-1.43)/.39) if v.z>1.43 and v.y>.015 else (.03,.90)

# Merge added details by material so close rendering remains bounded.
by={}
for ob in list(bpy.context.scene.objects):
 if ob.type=='MESH':by.setdefault(ob.data.materials[0].name,[]).append(ob)
for ma,obs in by.items():
 active(obs[0])
 for ob in obs:ob.select_set(True)
 if len(obs)>1:bpy.ops.object.join()
 bpy.context.object.name='Skin_'+ma
for pb in rig.pose.bones:pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0)
bpy.context.view_layer.update()
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
tris=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in meshes)
assert tris<=22000,(tris,'near budget');assert len(meshes)<=8,len(meshes)
native=OUT/'winter_worker_detail.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native))
near=RT/'winter_worker_detail.glb';bpy.ops.export_scene.gltf(filepath=str(near),export_format='GLB',export_yup=True,export_skins=True,export_animations=True,export_animation_mode='ACTIONS',export_all_influences=False)
# Matching low-detail silhouette; retain vertex palette rather than texture draws.
copies=[]
for ob in meshes:
 cp=ob.copy();cp.data=ob.data.copy();bpy.context.collection.objects.link(cp);cp.parent=None;cp.matrix_world=ob.matrix_world.copy()
 for m in list(cp.modifiers):cp.modifiers.remove(m)
 for g in list(cp.vertex_groups):cp.vertex_groups.remove(g)
 color=cp.data.color_attributes.new(name='Color',type='BYTE_COLOR',domain='CORNER')
 col=(.25,.32,.26,1) if ob==coat else cp.data.materials[0].diffuse_color
 for v in color.data:v.color=col
 copies.append(cp)
active(copies[0])
for cp in copies:cp.select_set(True)
bpy.ops.object.join();proxy=bpy.context.object;proxy.name='WinterInfectedProxy'
dec=proxy.modifiers.new('Distant silhouette budget','DECIMATE');dec.ratio=2200/tris;bpy.ops.object.modifier_apply(modifier=dec.name)
proxy.data.validate(verbose=True,clean_customdata=True)
proxy.data.materials.clear();pm=material('baked_vertex_palette',(1,1,1));n=pm.node_tree.nodes.new('ShaderNodeVertexColor');n.layer_name='Color';pm.node_tree.links.new(n.outputs['Color'],pm.node_tree.nodes.get('Principled BSDF').inputs['Base Color']);proxy.data.materials.append(pm)
for p in proxy.data.polygons:p.material_index=0
far=RT/'winter_worker_proxy.glb';bpy.ops.export_scene.gltf(filepath=str(far),export_format='GLB',use_selection=True,export_yup=True,export_skins=False,export_animations=False)
ptris=sum(len(f.vertices)-2 for f in proxy.data.polygons);assert ptris<=2500,ptris
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
report={'license':'Original project-authored geometry and procedural textures; no external sources','blender':bpy.app.version_string,'units':'metres','near_triangles':tris,'far_triangles':ptris,'surfaces':len(meshes),'bones':list(rig.data.bones.keys()),'rig_migration':'11 to 13: ankle children keep boots upright; eight logical joint drivers unchanged','native':str(native.relative_to(R)),'native_sha256':digest(native),'glb_sha256':digest(near),'proxy_sha256':digest(far),'generator_sha256':digest(Path(__file__)),'textures':{p.name:digest(p) for p in OUT.glob('*.png')}}
(RT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print('WORKER_DETAIL_EXPORTED',json.dumps(report),flush=True)
