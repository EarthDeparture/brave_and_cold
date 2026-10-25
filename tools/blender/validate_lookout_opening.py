"""Validate original mesh package integrity, native sources and embedded textures."""
from pathlib import Path
import hashlib,json,struct,math
R=Path(__file__).resolve().parents[2];A=R/'brave-and-cold/assets/lookout_opening';manifest=json.loads((A/'manifest.json').read_text(encoding='utf-8'))
source=manifest['source'];text=(R/source['generator']).read_text(encoding='utf-8').replace('\r\n','\n')
assert hashlib.sha256(text.encode()).hexdigest()==source['generator_sha256']
for name,sha in source['graphics_sha256'].items():assert hashlib.sha256((R/'tools/blender/generated/lookout_opening/textures'/name).read_bytes()).hexdigest()==sha
rows=[]
for name,entry in manifest.items():
 if name=='source':continue
 path=A/(name+'.glb');raw=path.read_bytes();assert hashlib.sha256(raw).hexdigest()==entry['sha256']
 magic,version,length=struct.unpack_from('<III',raw);assert magic==0x46546c67 and version==2 and length==len(raw)
 count,kind=struct.unpack_from('<II',raw,12);g=json.loads(raw[20:20+count]);triangles=0
 for mesh in g['meshes']:
  for prim in mesh['primitives']:
   assert prim.get('mode',4)==4 and 'NORMAL' in prim['attributes']
   pos=g['accessors'][prim['attributes']['POSITION']];assert all(math.isfinite(v) for v in pos['min']+pos['max'])
   triangles+=g['accessors'][prim['indices']]['count']//3
 assert triangles==entry['triangles'] and triangles<20000,(name,triangles)
 assert all('uri' not in image and 'bufferView' in image for image in g.get('images',[]))
 native=R/entry['native_source'];assert native.is_file() and native.stat().st_size>100000
 rows.append({'asset':name,'triangles':triangles,'surfaces':sum(len(m['primitives']) for m in g['meshes']),'native_bytes':native.stat().st_size,'runtime_bytes':len(raw)})
print('LOOKOUT_ASSET_PACKAGE_VALID',json.dumps(rows))
