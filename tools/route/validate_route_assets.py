"""Verify original route GLB bytes against their Blender export receipt."""
from pathlib import Path
import argparse,hashlib,json,struct
ROOT=Path(__file__).resolve().parents[2]
PALETTE={'painted_steel':(.06,.12,.10),'aged_steel':(.24,.27,.24),'brass':(.31,.25,.12),'rubber':(.017,.021,.02),'paper':(.64,.58,.40),'canvas':(.24,.25,.14),'red_lead':(.25,.032,.017),'cream':(.58,.52,.36)}
def validate():
 receipt=json.loads((ROOT/'tools/blender/generated/route_identity/route_identity.json').read_text(encoding='utf-8'))
 assert receipt['source_hash_encoding']=='utf-8 LF'
 for key,path in [('source_sha256',receipt['source']),('graphics_source_sha256',receipt['graphics'])]:
  assert hashlib.sha256((ROOT/path).read_text(encoding='utf-8').encode('utf-8')).hexdigest()==receipt[key],('source hash',path)
 for name,digest in receipt['graphics_sha256'].items():
  assert hashlib.sha256((ROOT/'tools/blender/generated/route_identity/textures'/name).read_bytes()).hexdigest()==digest,('graphic hash',name)
 results={}
 for name,item in receipt['assets'].items():
  path=ROOT/'brave-and-cold/assets/route_detail'/(name+'.glb');raw=path.read_bytes()
  assert raw[:4]==b'glTF' and struct.unpack_from('<II',raw,4)==(2,len(raw)),('GLB header',name)
  assert hashlib.sha256(raw).hexdigest()==item['sha256'] and len(raw)==item['bytes'],('receipt',name)
  length,chunk=struct.unpack_from('<II',raw,12);assert chunk==0x4e4f534a
  gltf=json.loads(raw[20:20+length]);triangles=0;primitives=0
  for mesh in gltf['meshes']:
   for prim in mesh['primitives']:
    assert prim.get('mode',4)==4 and 'indices' in prim
    triangles+=gltf['accessors'][prim['indices']]['count']//3;primitives+=1
    if name!='store_shell':
     assert 'COLOR_0' in prim['attributes'],('missing patina',name)
     col=gltf['accessors'][prim['attributes']['COLOR_0']]
     assert col['count']==gltf['accessors'][prim['attributes']['POSITION']]['count']
  assert triangles==item['triangles'] and triangles<20000,('triangle budget',name,triangles)
  assert sorted(n['name'] for n in gltf['nodes'] if 'mesh' in n)==sorted(item['mesh_groups']),('stock groups',name)
  if name!='store_shell':
   for mat in gltf['materials']:
    if mat['name'] in PALETTE:
     factor=mat.get('pbrMetallicRoughness',{}).get('baseColorFactor',[1,1,1,1])
     assert max(abs(a-b) for a,b in zip(factor[:3],PALETTE[mat['name']]))<.00001,('palette',name,mat['name'])
  results[name]={'triangles':triangles,'primitives':primitives,'bytes':len(raw),'sha256':item['sha256']}
 return {'source_hashes_valid':True,'graphic_hashes_valid':True,'palette_factors_valid':True,'stock_groups_valid':True,'triangle_budget_per_asset':20000,'total_bytes':sum(r['bytes'] for r in results.values()),'assets':results}
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--report',type=Path);args=parser.parse_args();result=validate()
 if args.report:
  args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
 print('ROUTE_ASSET_VALIDATION',json.dumps(result))
