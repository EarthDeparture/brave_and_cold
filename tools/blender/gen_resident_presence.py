"""Derive modeled blinks from the preserved original human; no source overwrite."""
from pathlib import Path
import bpy,bmesh,ast,math,json,hashlib
from mathutils import Vector
from mathutils.kdtree import KDTree
R=Path(__file__).resolve().parents[2];SRC=R/'tools/blender/generated/modular_human/human_foundation.blend';GEN=R/'tools/blender/gen_modular_human.py'
OUT=R/'tools/blender/generated/resident_presence';RT=R/'brave-and-cold/assets/resident_presence'
OUT.mkdir(parents=True,exist_ok=True);RT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SRC));bpy.context.preferences.filepaths.save_version=0
def cv(p):return Vector((p[0],-p[2],p[1]))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
# Reuse only the authored pure landmark function, never execute the factory.
tree=ast.parse(GEN.read_text());nodes=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['gauss','face_z'] or isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='profile' for t in n.targets)]
ns={'math':math};exec(compile(ast.Module(body=nodes,type_ignores=[]),str(GEN),'exec'),ns);face_z=ns['face_z']
head=bpy.data.objects['Head'];eyes=bpy.data.objects['Eyes'];rig=bpy.data.objects['HumanFoundationRig']
for module,old in {'Trousers':'ContinuousFittedTrousers','Cap':'KnitCap','Apron':'DrapedShopApron'}.items():bpy.data.objects[old].name=module
eye_bsdf=bpy.data.materials['HumanEye'].node_tree.nodes.get('Principled BSDF')
eye_bsdf.inputs['Roughness'].default_value=.60;eye_bsdf.inputs['Specular IOR Level'].default_value=.25
def lid_landmarks():
 for side in [-1,1]:
  for band in range(5):
   r=.87+band*.095
   for k in range(48):
    a=k*math.tau/48;x=side*.033+r*.015*math.cos(a);y=1.694+r*.0055*math.sin(a)
    yield cv((x,y,face_z(x,y)-.0012-.0014*math.sin(band*math.pi/4))),band
def match_lids():
 kd=KDTree(len(head.data.vertices))
 for v in head.data.vertices:kd.insert(v.co,v.index)
 kd.balance();found=[]
 for p,band in lid_landmarks():
  co,idx,dist=kd.find(p);assert dist<.000001,(idx,dist);found.append((idx,band))
 assert len({i for i,b in found})==480
 return found
landmarks=match_lids();lid_ids={i for i,b in landmarks};normal_repairs=[]
for obj in [eyes,head]:
 bm=bmesh.new();bm.from_mesh(obj.data);bm.verts.ensure_lookup_table()
 faces=list(bm.faces) if obj==eyes else [f for f in bm.faces if all(v.index in lid_ids for v in f.verts)]
 inward=[f for f in faces if f.normal.y<0]
 bmesh.ops.reverse_faces(bm,faces=inward);bm.to_mesh(obj.data);bm.free();obj.data.update();normal_repairs.append({'object':obj.name,'reversed_faces':len(inward)})
# Make the closed lid's inner edge sit in front of the eye cap, not through it.
landmarks=match_lids();basis=head.shape_key_add(name='Basis');blink=head.shape_key_add(name='Blink');blink.slider_min=0;blink.slider_max=1
for idx,band in landmarks:
 v=basis.data[idx].co;x,y,z=v.x,v.z,-v.y;weight=1-band/4
 target_y=1.694+(y-1.694)*(1-weight)
 target_z=z*(1-weight)+(face_z(x,target_y)-.0048)*weight
 blink.data[idx].co=cv((x,target_y,target_z))
blink.value=0
# Organise the editable source for clothing/body variants.
for module in ['Anatomy','Head','Eyes','Hands','Jacket','Trousers','Boots','Cap','Apron']:
 col=bpy.data.collections.new(module);bpy.context.scene.collection.children.link(col)
 obs=[o for o in bpy.context.scene.objects if o.name.startswith('Anatomical') and o not in [head,eyes]] if module=='Anatomy' else ([bpy.data.objects[module]] if module in bpy.data.objects else [])
 for obj in obs:
  for old in list(obj.users_collection):old.objects.unlink(obj)
  col.objects.link(obj)
bpy.ops.file.pack_all();native=OUT/'resident_presence.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native))
cloth=bpy.data.materials['HumanJacket'];clothtex=next(n for n in cloth.node_tree.nodes if n.type=='TEX_IMAGE' and n.image.name=='human_canvas_albedo');clothmap=clothtex.image
skin=bpy.data.materials['HumanSkin'];skintex=next(n for n in skin.node_tree.nodes if n.type=='TEX_IMAGE');skinmap=skintex.image
exports=[];base=['Head','Eyes','Hands','Jacket','Trousers','Boots']
def export(name,modules):
 bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
 for obj in bpy.context.scene.objects:
  if obj.type=='EMPTY':obj.select_set(True)
 selected=[]
 for module in modules:
  obj=bpy.data.objects[module];obj.hide_set(False);obj.select_set(True);selected.append(obj)
 path=RT/(name+'.glb');bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_skins=True,export_morph=True,export_animations=False)
 tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in selected);surfaces=sum(len(o.data.materials) for o in selected)
 assert tris<=40000 and surfaces<=10
 exports.append({'id':name,'triangles':tris,'surfaces':surfaces,'modules':modules,'sha256':sha(path)})
def tint(name,col):
 im=clothmap.copy();im.name=name;pixels=list(clothmap.pixels[:])
 for i in range(0,len(pixels),4):
  for j in range(3):pixels[i+j]=min(1,pixels[i+j]*col[j])
 im.pixels[:]=pixels;im.pack();clothtex.image=im
export('rowan',base+['Cap','Apron']);tint('sam_canvas',(.85,1.12,1.32));export('sam',base);tint('lin_canvas',(1.30,.92,.73));export('lin',base)
tint('infected_canvas',(.75,.83,.75));im=skinmap.copy();im.name='human_infected_skin';p=list(skinmap.pixels[:])
for i in range(0,len(p),4):
 grey=sum(p[i:i+3])/3
 for j,f in enumerate([.84,.96,.86]):p[i+j]=grey*f
im.pixels[:]=p;im.pack();skintex.image=im;export('infected_preview',base)
(RT/'manifest.json').write_text(json.dumps({'license':'Original project human and modeled eyelid animation; original master retained; winding inspected','source_native_sha256':sha(SRC),'source_generator_sha256':sha(GEN),'native_sha256':sha(native),'generator_sha256':sha(Path(__file__)),'blender':bpy.app.version_string,'normal_repairs':normal_repairs,'blink_vertices':480,'exports':exports},indent=2)+'\n')
print('RESIDENT_PRESENCE_EXPORTED',json.dumps(exports),flush=True)
