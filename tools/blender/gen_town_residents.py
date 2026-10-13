"""Original civilian variants and counter evidence; existing source stays intact."""
from pathlib import Path
import bpy, bmesh, math, json, hashlib
from mathutils import Vector
R=Path(__file__).resolve().parents[2]
OUT=R/'tools/blender/generated/town_residents';RT=R/'brave-and-cold/assets/town_residents'
OUT.mkdir(parents=True,exist_ok=True);RT.mkdir(parents=True,exist_ok=True)
SOURCE=R/'tools/blender/generated/worker_detail/winter_worker_detail.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));bpy.context.preferences.filepaths.save_version=0
rig=bpy.data.objects['WinterWorkerSkeleton']
def cv(v):return Vector((v[0],-v[2],v[1]))
def active(ob):
 bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
def mat(name,col,rough=.88):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*col,1)
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*col,1);p.inputs['Roughness'].default_value=rough
 return m
def mesh(name,vs,faces,ma,bone):
 me=bpy.data.meshes.new(name);me.from_pydata([cv(v) for v in vs],[],faces);me.update()
 ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);me.materials.append(ma)
 for f in me.polygons:f.use_smooth=True
 ob.vertex_groups.new(name=bone).add(list(range(len(vs))),1,'REPLACE');ob.parent=rig
 ob.modifiers.new('Civilian skin','ARMATURE').object=rig
 return ob
# Same metre-scaled thirteen-bone actor, new silhouette without changing anatomy.
def tint_texture(ma,color):
 p=ma.node_tree.nodes.get('Principled BSDF');node=p.inputs['Base Color'].links[0].from_node
 original=node.image
 def apply(name,col):
  image=original.copy();image.name=name;pixels=list(original.pixels[:])
  for i in range(0,len(pixels),4):
   for j in range(3):pixels[i+j]=min(1,pixels[i+j]*col[j])
  image.pixels[:]=pixels;image.pack();node.image=image;p.inputs['Base Color'].default_value=(1,1,1,1)
 apply(ma.name+'_civilian',color)
 return apply
cloth=next(m for m in bpy.data.materials if m.name.startswith('winter_canvas_detail'))
cloth_tint=tint_texture(cloth,(.90,.85,.75))
skin=next(m for m in bpy.data.materials if m.name.startswith('pallid_skin_detail'))
tint_texture(skin,(1.35,1.17,1.08))
apron=mat('shop_canvas',(.32,.24,.15));knit=mat('rust_knit',(.34,.095,.04));trim=mat('apron_binding',(.13,.10,.07))
# Knitted cap follows the head, not the spine. Closed rings, outward winding.
vs=[];fs=[];n=48
profile=[(1.695,.089,.086),(1.716,.093,.088),(1.733,.094,.09),(1.773,.079,.077),(1.804,.047,.047),(1.816,.006,.006)]
for j,(y,rx,rz) in enumerate(profile):
 for k in range(n):
  a=k*math.tau/n; rib=.0009*math.cos(k*math.pi)
  vs.append((math.cos(a)*(rx+rib),y,math.sin(a)*(rz+rib)))
for j in range(len(profile)-1):
 for k in range(n):fs.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
fs.extend([tuple(reversed(range(n))),tuple((len(profile)-1)*n+k for k in range(n))])
mesh('RowanRustCap',vs,fs,knit,'head')
# Apron stays above the hip crease; weight through lower spine/pelvis transition.
vs=[];fs=[];rows=[(.978,.153,-.135),(1.045,.169,-.151),(1.15,.174,-.161),(1.27,.165,-.162),(1.37,.095,-.146)]
for j,(y,width,z) in enumerate(rows):
 for k in range(9):
  u=k/8*2-1;vs.append((width*u,y,z+.026*u*u+.0015*math.sin(k*2+j)))
for j in range(4):
 for k in range(8):fs.append((j*9+k,j*9+k+1,(j+1)*9+k+1,(j+1)*9+k))
ob=mesh('ShopApron',vs,fs,apron,'spine');active(ob)
sol=ob.modifiers.new('Sewn thickness','SOLIDIFY');sol.thickness=.003;bpy.ops.object.modifier_apply(modifier=sol.name)
g=ob.vertex_groups.new(name='pelvis')
for v in ob.data.vertices:
 w=max(0,min(1,(1.11-v.co.z)/.14));ob.vertex_groups['spine'].add([v.index],1-w,'REPLACE');g.add([v.index],w,'REPLACE')
def ribbon(name,a,b,width,ma,bone):
 a,b=Vector(a),Vector(b);d=b-a;side=Vector((d.y,-d.x,0)).normalized()*width/2
 o=mesh(name,[a-side,a+side,b+side,b-side],[(0,1,2,3)],ma,bone);active(o)
 sol=o.modifiers.new('Binding thickness','SOLIDIFY');sol.thickness=.002;bpy.ops.object.modifier_apply(modifier=sol.name)
for sign in [-1,1]:ribbon('NeckStrap',(sign*.085,1.36,-.15),(sign*.085,1.485,-.071),.018,trim,'spine')
ribbon('ApronPocketTop',(-.085,1.12,-.164),(.085,1.12,-.164),.009,trim,'spine')
# Merge by material so the three actors do not acquire separate detail draws.
by={}
for o in list(bpy.context.scene.objects):
 if o.type=='MESH':by.setdefault(o.data.materials[0].name,[]).append(o)
for ma,obs in by.items():
 active(obs[0])
 for o in obs:o.select_set(True)
 if len(obs)>1:bpy.ops.object.join()
 bpy.context.object.name='Skin_'+ma
for o in bpy.context.scene.objects:
 if o.type=='MESH':
  bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
for pb in rig.pose.bones:pb.rotation_euler=(0,0,0)
rig.animation_data_clear()
bpy.context.view_layer.update()
native=OUT/'north_ridge_residents.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native))
rows=[]
def export(id):
 p=RT/(id+'.glb');bpy.ops.export_scene.gltf(filepath=str(p),export_format='GLB',export_yup=True,export_skins=True,export_animations=False)
 tris=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
 surfaces=sum(len(o.data.materials) for o in bpy.context.scene.objects if o.type=='MESH')
 assert tris<=22000 and surfaces<=10,(tris,surfaces)
 rows.append({'id':id,'triangles':tris,'surfaces':surfaces,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
export('rowan_shopkeeper')
# Supporting staff share anatomy but do not wear Rowan's apron or cap.
for o in list(bpy.context.scene.objects):
 if o.type=='MESH' and o.data.materials[0] in [apron,knit,trim]:bpy.data.objects.remove(o,do_unlink=True)
cloth_tint('sam_blue_canvas',(1.0,1.3,1.55));export('sam_clinic')
cloth_tint('lin_tan_canvas',(1.4,.95,.65));export('lin_runner')
# Original small counter ledger, modelled in metres in a separate source.
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def box(name,p,size,ma,bevel=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=cv(p));o=bpy.context.object;o.name=name;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(ma)
 if bevel:
  mod=o.modifiers.new('Worn edges','BEVEL');mod.width=bevel;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o
board=mat('ledger_board',(.23,.15,.075));paper=mat('ledger_paper',(.73,.70,.57));ink=mat('ledger_ink',(.035,.05,.055));steel=mat('ledger_clip',(.30,.33,.34))
box('IssueClipboard',(0,0,0),(.19,.012,.27),board,.003)
box('CountedIssuePage',(0,.007,0),(.17,.001,.23),paper,.001)
box('LedgerClip',(0,.013,-.108),(.07,.009,.019),steel,.002)
for i,line in enumerate(['NORTH RIDGE SUPPLY','RESERVED ISSUE','KESTREL 07','TRANSFER RELAY','WINTER CONTROLLER','COLLECT MARKED CASES','R. BELL']):
 bpy.ops.object.text_add(location=cv((-.076,.008,-.078+i*.021)));o=bpy.context.object;o.name='LedgerWriting';o.rotation_euler=(0,0,0);o.data.body=line;o.data.size=.008;o.data.extrude=0;o.data.materials.append(ink);bpy.ops.object.convert(target='MESH')
props_native=OUT/'issue_ledger.blend';bpy.ops.wm.save_as_mainfile(filepath=str(props_native))
ledger=RT/'issue_ledger.glb';bpy.ops.export_scene.gltf(filepath=str(ledger),export_format='GLB',export_yup=True,export_animations=False)
report={'license':'Original project source, geometry and procedural maps; no external inputs','units':'metres','source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'blender':bpy.app.version_string,'models':rows,'ledger_sha256':hashlib.sha256(ledger.read_bytes()).hexdigest(),'ledger_native_sha256':hashlib.sha256(props_native.read_bytes()).hexdigest()}
(RT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print('TOWN_RESIDENTS_EXPORTED',json.dumps(report),flush=True)
