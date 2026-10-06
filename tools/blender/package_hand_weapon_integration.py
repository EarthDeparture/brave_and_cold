"""Validate shipped glTF skinning and retain real Godot review frames."""
from pathlib import Path
import json,struct,hashlib,numpy as np
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'tools/blender/generated/live_hand_rig_v2';GAME=ROOT/'brave-and-cold';SHOTS=GAME/'shots/anatomical-weapons'
glb=OUT/'anatomical_hand_rig.glb';data=glb.read_bytes();length=struct.unpack_from('<I',data,12)[0];j=json.loads(data[20:20+length]);binary=data[28+length:]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def accessor(index):
 a=j['accessors'][index];v=j['bufferViews'][a['bufferView']];kind={5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']];columns={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
 result=np.frombuffer(binary,dtype=kind,count=a['count']*columns,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,columns);assert np.isfinite(result).all();return result
assert len(j['skins'])==2 and all(len(s['joints'])==17 for s in j['skins'])
for skin in j['skins']:assert accessor(skin['inverseBindMatrices']).shape==(17,16)
vertices=triangles=0
for mesh in j['meshes']:
 for primitive in mesh['primitives']:
  position=accessor(primitive['attributes']['POSITION']);weights=accessor(primitive['attributes']['WEIGHTS_0']);bones=accessor(primitive['attributes']['JOINTS_0']);indices=accessor(primitive['indices'])
  assert abs(weights.sum(1)-1).max()<.0001 and weights.min()>=0 and bones.max()<17 and indices.max()<len(position)
  vertices+=len(position);triangles+=len(indices)//3
  for target in primitive.get('targets',[]):accessor(target['POSITION'])
assert len(j['meshes'])==6 and len(j['animations'])==16
for clip in j['animations']:
 weights=[c for c in clip['channels'] if c['target']['path']=='weights'];assert len(weights)==4,(clip['name'],'missing bare/glove morph channel')
 for sampler in clip['samplers']:assert np.diff(accessor(sampler['input'])[:,0]).min()>=0;accessor(sampler['output'])
meta=json.loads((OUT/'manifest.json').read_text());assert meta['glb_sha256']==sha(glb) and meta['native_sha256']==sha(OUT/'anatomical_hand_rig.blend')
poses=json.loads((OUT/'pose_audit.json').read_text());assert poses['source_sha256']==meta['native_sha256']
counts=[p['non_neighbour_intersections'] for name,rows in poses.items() if isinstance(rows,dict) for p in rows.values()];assert len(counts)==60 and max(counts)==0
contacts=json.loads((OUT/'contact_fit_audit.json').read_text());assert len(contacts)==25 and max(r['fitted_solid_overlap_m'] for r in contacts.values())<.0035
capture=json.loads((SHOTS/'manifest.json').read_text());assert capture['hands_sha256']==sha(glb) and len(capture['captures'])==82
for frame in capture['captures']:assert sha(SHOTS/(frame['id']+'.png'))==frame['sha256']
previews=OUT/'previews';previews.mkdir(exist_ok=True)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
def sheet(names,name,columns):
 cell=(512,316);sheet=Image.new('RGB',(cell[0]*columns,cell[1]*int(np.ceil(len(names)/columns))),(18,23,28));draw=ImageDraw.Draw(sheet)
 for i,frame in enumerate(names):
  image=Image.open(SHOTS/(frame+'.png')).convert('RGB').resize((512,288),Image.Resampling.LANCZOS);x=i%columns*cell[0];y=i//columns*cell[1];sheet.paste(image,(x,y));draw.text((x+9,y+289),frame.replace('_',' ').replace('-',' / '),font=font,fill=(225,232,239))
 sheet.save(previews/name)
sheet(['empty-bare','guard-bare','punch-bare','axe-bare','timber_bolt_carbine-hip-bare','timber_bolt_carbine-action-bare','empty-glove','axe-glove','watch-bare'],'hands_in_game.png',3)
ids=['ridge_scout_rifle','timber_bolt_carbine','ranger_box_rifle','brush_lever_rifle','frontier_vented_rifle','north_service_rifle','compact_patrol_rifle','expedition_rifle']
sheet([id+'-'+state+'-bare' for id in ids for state in ['hip','aim']],'weapon_stances.png',4)
sheet(['hammer-bare','reach-bare','treat-bare','drink-bare','watch-glove','timber_bolt_carbine-reload-glove'],'survival_actions.png',3)
runtime=GAME/'assets/weapons/north_ridge'
(OUT/'runtime_contact_profiles.json').write_bytes((runtime/'contact_profiles.json').read_bytes())
validation={'bones_per_hand':17,'meshes':6,'animations':16,'all_variant_vertices':vertices,'all_variant_triangles':triangles,'native_poses_checked':60,'native_self_intersections':0,'runtime_contact_cases':25,'maximum_sampled_solid_overlap_m':max(r['fitted_solid_overlap_m'] for r in contacts.values()),'actual_gpu_captures':82,'gpu':capture['gpu'],'renderer':capture['renderer'],'runtime_hand_sha256':sha(glb),'runtime_profiles_sha256':sha(runtime/'contact_profiles.json'),'scope':'New hands live on existing rifle/tools; eight weapon presentations and reload clips, current inventory/ammunition rules retained.'}
(OUT/'validation.json').write_text(json.dumps(validation,indent=2)+'\n',encoding='utf-8',newline='\n')
files=[p for p in OUT.rglob('*') if p.is_file() and p.name!='package_hashes.json' and not p.name.endswith('.blend1') and 'candidate' not in p.name and p.name!='contact_profiles.json']
(OUT/'package_hashes.json').write_text(json.dumps({'files':{p.relative_to(OUT).as_posix():sha(p) for p in sorted(files)}},indent=2)+'\n',encoding='utf-8',newline='\n')
print('HAND_WEAPON_PACKAGE_PASS',validation)
