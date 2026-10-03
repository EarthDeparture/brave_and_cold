"""Read-only GLB validation for the original lookout asset and its geometry receipt.

python tools/blender/validate_fire_lookout.py MODEL.glb GEOMETRY.json
Checks exported bytes, accessors, triangle budget, vertex colors, normals and dimensions.
"""
import hashlib
import json
import math
import struct
import sys
from pathlib import Path


def inspect(model, receipt):
    raw=Path(model).read_bytes()
    meta=json.loads(Path(receipt).read_text(encoding='utf-8'))
    magic,version,length=struct.unpack_from('<III',raw,0)
    assert magic==0x46546C67 and version==2 and length==len(raw),'Invalid GLB header'
    jlen,jkind=struct.unpack_from('<II',raw,12)
    assert jkind==0x4E4F534A,'Missing JSON chunk'
    gltf=json.loads(raw[20:20+jlen])
    boff=20+jlen
    blen,bkind=struct.unpack_from('<II',raw,boff)
    assert bkind==0x004E4942,'Missing binary chunk'
    buf=raw[boff+8:boff+8+blen]
    assert len(buf)==blen
    assert hashlib.sha256(raw).hexdigest()==meta['sha256'],'Receipt digest differs'
    assert len(raw)==meta['file_bytes'],'Receipt size differs'
    sizes={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
    formats={5120:'b',5121:'B',5122:'h',5123:'H',5125:'I',5126:'f'}

    def values(aid):
        a=gltf['accessors'][aid]
        view=gltf['bufferViews'][a['bufferView']]
        fmt='<'+formats[a['componentType']]*sizes[a['type']]
        stride=view.get('byteStride',struct.calcsize(fmt))
        offset=view.get('byteOffset',0)+a.get('byteOffset',0)
        return [struct.unpack_from(fmt,buf,offset+i*stride) for i in range(a['count'])]

    positions=[];tris=0;degenerate=0
    for mesh in gltf['meshes']:
        for prim in mesh['primitives']:
            assert prim.get('mode',4)==4,'Expected triangle primitives'
            attr=prim['attributes']
            assert 'COLOR_0' in attr and 'NORMAL' in attr,'Missing vertex color/normal'
            p=values(attr['POSITION']);n=values(attr['NORMAL'])
            assert len(p)==len(n)
            assert all(math.isfinite(v) for pt in p for v in pt),'Nonfinite positions'
            assert all(.85<sum(v*v for v in nn)<1.15 for nn in n),'Invalid normals'
            idx=[v[0] for v in values(prim['indices'])]
            assert len(idx)%3==0 and max(idx)<len(p)
            tris+=len(idx)//3
            positions.extend(p)
            for i in range(0,len(idx),3):
                a,b,c=[p[idx[j]] for j in range(i,i+3)]
                u=[b[k]-a[k] for k in range(3)];v=[c[k]-a[k] for k in range(3)]
                cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
                degenerate+=sum(t*t for t in cross)<1e-16
    assert tris==meta['triangles'] and tris<=15000,'Triangle budget/receipt mismatch'
    assert degenerate==0,f'{degenerate} degenerate triangles'
    assert len(gltf['meshes'])==meta['mesh_objects']<=8
    assert len(gltf['materials'])==meta['material_count']<=8
    low=[min(p[i] for p in positions) for i in range(3)]
    high=[max(p[i] for p in positions) for i in range(3)]
    assert -.8<low[1]<0 and 12<high[1]<14,'Wrong up axis or height'
    assert high[0]-low[0]<11 and high[2]-low[2]<8,'Footprint larger than site budget'
    assert abs(meta['stairs']['flights']*meta['stairs']['steps_per_flight']*meta['stairs']['riser']-meta['deck_height'])<1e-6
    return {'ok':True,'triangles':tris,'meshes':len(gltf['meshes']),
            'materials':len(gltf['materials']),'bytes':len(raw),'bounds_godot':[low,high],
            'sha256':meta['sha256'],'degenerate_triangles':degenerate}


if __name__=='__main__':
    print(json.dumps(inspect(sys.argv[1],sys.argv[2]),indent=2))
