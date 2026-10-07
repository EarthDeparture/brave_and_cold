"""Independent GLB geometry, native source, artwork and audio verification."""
from pathlib import Path
import json,hashlib,struct,wave
import numpy as np
from PIL import Image
from validate_food_assets import geometry_bounds
R=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def validate():
 folder=R/'brave-and-cold/assets/route_detail';manifest=json.loads((folder/'manifest.json').read_text());result={}
 for name in ['compound_gate','service_marker','drain_headwall','shoulder_debris']:
  e=manifest[name];p=folder/(name+'.glb');data=p.read_bytes();magic,version,length=struct.unpack_from('<4sII',data)
  assert magic==b'glTF' and version==2 and length==len(data)
  count,kind=struct.unpack_from('<II',data,12);assert kind==0x4e4f534a
  doc=json.loads(data[20:20+count].decode().rstrip())
  assert sha(p)==e['sha256'] and sha(R/e['source'])==e['source_sha256']
  tris=sum(doc['accessors'][p['indices']]['count']//3 for mesh in doc['meshes'] for p in mesh['primitives'])
  lo,hi=geometry_bounds(doc,data,count)
  assert np.allclose(lo,e['bounds_min_xyz'],atol=1e-5) and np.allclose(hi,e['bounds_max_xyz'],atol=1e-5)
  assert tris==e['triangles'] and tris<6500 and len(doc.get('materials',[]))<=6
  assert all('bufferView' in im for im in doc.get('images',[]))
  blob_start=20+count+8
  for im in doc.get('images',[]):
   view=doc['bufferViews'][im['bufferView']];start=blob_start+view.get('byteOffset',0)
   embedded=data[start:start+view['byteLength']]
   extracted=folder/(name+'_'+im['name']+'.png')
   assert extracted.exists() and extracted.read_bytes()==embedded
  result[name]={'triangles':tris,'materials':len(doc.get('materials',[])),'dimensions_m':list(hi-lo),'source_export_verified':True}
 for file,digest in manifest['generators'].items():assert hashlib.sha256((R/'tools/blender'/file).read_text(encoding='utf8').replace('\r\n','\n').encode()).hexdigest()==digest
 graphics=json.loads((folder/'graphics.json').read_text())
 for file,digest in graphics['files'].items():
  assert sha(R/file)==digest
  im=Image.open(R/file);assert im.width<=1024 and im.height<=1024
 foley_folder=R/'brave-and-cold/assets/audio/sfx';foley=json.loads((foley_folder/'route_foley.json').read_text())
 assert sha(R/'tools/audio/gen_route_foley.py')==foley['generator_sha256']
 for name,e in foley['clips'].items():
  p=foley_folder/(name+'.wav');assert sha(p)==e['sha256']
  with wave.open(str(p),'rb') as wav:
   assert wav.getnchannels()==1 and wav.getsampwidth()==2 and wav.getframerate()==22050
   assert abs(wav.getnframes()/wav.getframerate()-e['seconds'])<1/22050
   samples=np.frombuffer(wav.readframes(wav.getnframes()),dtype='<i2').astype(float)/32768
   assert abs(np.max(np.abs(samples))-e['peak'])<.00005
   assert abs(np.sqrt(np.mean(samples**2))-e['rms'])<.00005
 result['graphics_verified']=len(graphics['files']);result['foley_verified']=list(foley['clips'])
 return result
if __name__=='__main__':print(json.dumps(validate(),indent=2))
