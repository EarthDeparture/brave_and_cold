"""Static original solar-source/runtime/print integrity; GPU review is separate."""
from pathlib import Path
import hashlib,json,struct
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def source_sha(p):return hashlib.sha256(p.read_text(encoding='utf-8-sig').replace('\r\n','\n').encode()).hexdigest()
def validate():
 folder=ROOT/'brave-and-cold/assets/lookout_solar'
 manifest=json.loads((folder/'manifest.json').read_text())
 entry=manifest['relay_solar_array'];glb=folder/'relay_solar_array.glb';data=glb.read_bytes()
 magic,version,length=struct.unpack_from('<4sII',data)
 assert magic==b'glTF' and version==2 and length==len(data)
 chunk_length,chunk_type=struct.unpack_from('<II',data,12)
 assert chunk_type==0x4e4f534a
 doc=json.loads(data[20:20+chunk_length].decode().rstrip())
 assert sha(glb)==entry['sha256'] and sha(ROOT/entry['source'])==entry['source_sha256']
 triangles=sum(doc['accessors'][p['indices']]['count']//3 for mesh in doc['meshes'] for p in mesh['primitives'])
 assert triangles==entry['triangles'] and triangles<12000
 assert len(doc['materials'])<=8 and len(doc.get('textures',[]))<=4
 names={n.get('name','') for n in doc['nodes']}
 assert {'SnowLeft','SnowRight','PVDisconnect'}.issubset(names)
 assert all(t.get('source') is not None for t in doc.get('textures',[]))
 assert all('bufferView' in image for image in doc.get('images',[])), 'No external texture dependencies'
 lo=entry['measured_bounds_min_xyz'];hi=entry['measured_bounds_max_xyz']
 assert -1.28<=lo[0] and hi[0]<=1.28 and -.54<=lo[2] and hi[2]<=.60
 assert hi[1]<2.3 and lo[1]>=0
 assert source_sha(ROOT/'tools/blender/gen_lookout_solar.py')==manifest['provenance']['generator_sha256']
 assert source_sha(ROOT/'tools/blender/gen_solar_graphics.py')==manifest['provenance']['graphics_generator_sha256']
 for name,digest in manifest['graphics'].items():
  assert sha(ROOT/'tools/blender/generated/lookout_solar'/name)==digest
  # Godot extracts embedded image bytes beside the GLB; bind those runtime copies too.
  assert sha(folder/('relay_solar_array_'+name))==digest
 return {'triangles':triangles,'materials':len(doc['materials']),'textures':len(doc.get('textures',[])),'mesh_nodes':len(doc['meshes']),'bounds_min_xyz':lo,'bounds_max_xyz':hi,'bytes':len(data),'native_and_print_hashes_verified':True,'runtime_extracted_textures_verified':True,'embedded_textures':True}
if __name__=='__main__':print(json.dumps(validate(),indent=2))
