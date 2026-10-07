"""Source bytes, engine exports and embedded printwork; actual GPU review is separate."""
from pathlib import Path
import json,hashlib,struct
R=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def source_sha(p):return hashlib.sha256(p.read_text(encoding='utf-8-sig').replace('\r\n','\n').encode()).hexdigest()
def validate():
 folder=R/'brave-and-cold/assets/electrical_fieldwork';manifest=json.loads((folder/'manifest.json').read_text());results={}
 for name,e in manifest.items():
  if name in ['provenance','graphics','dependencies']:continue
  data=(folder/(name+'.glb')).read_bytes();magic,version,length=struct.unpack_from('<4sII',data)
  assert magic==b'glTF' and version==2 and length==len(data)
  count,kind=struct.unpack_from('<II',data,12);assert kind==0x4e4f534a
  doc=json.loads(data[20:20+count].decode().rstrip())
  assert sha(folder/(name+'.glb'))==e['sha256'] and sha(R/e['source'])==e['source_sha256']
  triangles=sum(doc['accessors'][p['indices']]['count']//3 for mesh in doc['meshes'] for p in mesh['primitives'])
  assert triangles==e['triangles'] and triangles<6500 and len(doc.get('materials',[]))<=8
  assert len(doc.get('textures',[]))<=3 and all('bufferView' in im for im in doc.get('images',[]))
  if name=='controller_case':assert 'ControllerStock' in {n.get('name') for n in doc['nodes']}
  if name=='spare_packet':assert max(e['dimensions_m'])<.25
  if name=='controller_case':assert e['dimensions_m'][0]<.41 and e['dimensions_m'][1]<.18
  # Identity printwork must match the original native raster and Godot's extracted copy.
  for im in doc.get('images',[]):
   graphic=im.get('name','')+'.png'
   if graphic in manifest['graphics']:
    runtime=folder/(name+'_'+graphic);assert runtime.exists() and sha(runtime)==manifest['graphics'][graphic]
  results[name]={'triangles':triangles,'materials':len(doc.get('materials',[])),'mesh_nodes':len(doc.get('meshes',[])),'dimensions_m':e['dimensions_m'],'source_export_and_print_hashes_verified':True}
 for name,digest in manifest['graphics'].items():assert sha(R/'tools/blender/generated/electrical_fieldwork'/name)==digest
 p=manifest['provenance']
 assert source_sha(R/'tools/blender/gen_electrical_fieldwork.py')==p['generator_sha256_lf']
 assert source_sha(R/'tools/blender/gen_electrical_graphics.py')==p['graphics_generator_sha256_lf']
 deps=manifest['dependencies']
 assert source_sha(R/deps['helper_source'])==deps['helper_sha256_lf'] and sha(R/deps['timber_texture'])==deps['timber_sha256']
 return results
if __name__=='__main__':print(json.dumps(validate(),indent=2))
