"""Inspect exported bytes rather than trusting generator logs.
python validate_survival_props.py PROJECT_ROOT
"""
import sys,json,struct,math,hashlib
from pathlib import Path
root=Path(sys.argv[1]);folder=root/'brave-and-cold/assets/survival_props'
meta=json.loads((folder/'provenance.json').read_text(encoding='utf8'))
def digest(path):
    raw=path.read_text(encoding='utf8').replace('\r\n','\n').encode('utf8') if path.suffix=='.py' else path.read_bytes()
    return hashlib.sha256(raw).hexdigest()
assert digest(root/meta['source'])==meta['source_sha256']
for source,expected in meta['source_dependencies'].items():
    assert digest(root/source)==expected
formats={5126:'f',5125:'I',5123:'H',5121:'B'}
components={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}
results={}
for name,receipt in meta['assets'].items():
    raw=(folder/(name+'.glb')).read_bytes()
    assert hashlib.sha256(raw).hexdigest()==receipt['sha256']
    assert len(raw)==receipt['bytes'] and len(raw)<3000000
    magic,version,size=struct.unpack_from('<III',raw)
    assert magic==0x46546c67 and version==2 and size==len(raw)
    jl=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+jl]);binary=raw[28+jl:]
    def values(index):
        a=g['accessors'][index];v=g['bufferViews'][a['bufferView']]
        fmt='<'+formats[a['componentType']]*components[a['type']];step=struct.calcsize(fmt)
        off=v.get('byteOffset',0)+a.get('byteOffset',0)
        return [struct.unpack_from(fmt,binary,off+i*v.get('byteStride',step)) for i in range(a['count'])]
    count=0;degenerate=0;verts=[]
    for mesh in g['meshes']:
        for part in mesh['primitives']:
            a=part['attributes'];assert 'NORMAL' in a and 'TEXCOORD_0' in a
            pos=values(a['POSITION']);norm=values(a['NORMAL']);idx=[t[0] for t in values(part['indices'])]
            assert all(math.isfinite(v) for point in pos for v in point)
            assert all(.9<sum(v*v for v in point)<1.1 for point in norm)
            assert len(idx)%3==0 and min(idx)>=0 and max(idx)<len(pos)
            count+=len(idx)//3;verts+=pos
            for i in range(0,len(idx),3):
                aa,bb,cc=[pos[idx[i+j]] for j in range(3)]
                u=[bb[k]-aa[k] for k in range(3)];v=[cc[k]-aa[k] for k in range(3)]
                cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
                degenerate+=sum(x*x for x in cross)<1e-16
            mat=g['materials'][part['material']]
            if mat['name']=='vm_ration':
                uv=values(a['TEXCOORD_0'])
                assert max(v[0] for v in uv)-min(v[0] for v in uv)>.9,'Collapsed label UV'
    assert count==receipt['triangles'] and count<=2000 and degenerate==0
    low=[min(p[k] for p in verts) for k in range(3)];high=[max(p[k] for p in verts) for k in range(3)]
    if name!='work_hammer':assert -.001<=low[1]<=.004,'Unit must rest on ground'
    assert len(g['meshes'])==1 and len(g.get('materials',[]))<=3
    assert all('uri' not in image for image in g.get('images',[])),'Nonportable external texture'
    results[name]={'triangles':count,'bytes':len(raw),'degenerate':degenerate,'bounds_godot':[low,high],'materials':len(g.get('materials',[]))}
print(json.dumps({'ok':True,'assets':results},indent=2))
