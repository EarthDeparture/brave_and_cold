"""Validate exported bytes, skin weights, bind matrices and welded topology.
Usage: python validate_hand_rig.py MODEL.glb RECEIPT.json
"""
import hashlib
import json
import struct
import sys
from collections import Counter
from pathlib import Path

import numpy as np
from scipy.spatial.transform import Rotation

raw=Path(sys.argv[1]).read_bytes()
receipt=json.loads(Path(sys.argv[2]).read_text())
magic,version,length=struct.unpack_from('<III',raw)
assert magic==0x46546c67 and version==2 and length==len(raw)
jlen,_=struct.unpack_from('<II',raw,12)
j=json.loads(raw[20:20+jlen]); binary=raw[28+jlen:]
assert hashlib.sha256(raw).hexdigest()==receipt['sha256']
assert len(j['skins'])==2 and all(len(s['joints'])==16 for s in j['skins'])
assert {a['name'] for a in j['animations']}=={'Open','Fist','Shaft','Trigger','Support','Bolt'}
assert len(j['images'])==4 and all('bufferView' in a and 'uri' not in a for a in j['images'])
types={5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}
components={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def values(i):
    a=j['accessors'][i];v=j['bufferViews'][a['bufferView']];c=components[a['type']]
    dtype=np.dtype(types[a['componentType']]);offset=v.get('byteOffset',0)+a.get('byteOffset',0)
    return np.ndarray((a['count'],c),dtype=dtype,buffer=binary,offset=offset,
                      strides=(v.get('byteStride',dtype.itemsize*c),dtype.itemsize)).copy()
parents={child:i for i,node in enumerate(j['nodes']) for child in node.get('children',[])}
def world(i):
    node=j['nodes'][i];m=np.eye(4)
    m[:3,:3]=Rotation.from_quat(node.get('rotation',[0,0,0,1])).as_matrix()@np.diag(node.get('scale',[1,1,1]))
    m[:3,3]=node.get('translation',[0,0,0])
    if 'matrix' in node:m=np.array(node['matrix']).reshape(4,4).T
    return world(parents[i])@m if i in parents else m
bind_error=0
for skin in j['skins']:
    binds=values(skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
    bind_error=max(bind_error,max(np.abs(world(node)@bind-np.eye(4)).max() for node,bind in zip(skin['joints'],binds)))
assert bind_error<1e-6,bind_error
report={}
for node in j['nodes']:
    if node['name'] not in ['BareHand','LeatherGlove','BareHandLeft','LeatherGloveLeft']:continue
    primitive=j['meshes'][node['mesh']]['primitives'][0];attrs=primitive['attributes']
    assert all(k in attrs for k in ['POSITION','NORMAL','TEXCOORD_0','JOINTS_0','WEIGHTS_0'])
    pos=values(attrs['POSITION']);normal=values(attrs['NORMAL']);weights=values(attrs['WEIGHTS_0']);bones=values(attrs['JOINTS_0'])
    assert np.isfinite(pos).all() and np.isfinite(normal).all()
    assert np.all((weights>=0)&(weights<=1)) and np.max(np.abs(weights.sum(axis=1)-1))<1e-5
    assert bones.max()<16 and np.max(np.abs(np.linalg.norm(normal,axis=1)-1))<1e-5
    idx=values(primitive['indices']).ravel();tri=idx.reshape(-1,3)
    assert len(tri)==receipt['validation'][node['name']]['triangles']
    if receipt.get('version',0)>=5:
        targets=primitive.get('targets',[])
        assert len(targets)==5 and set(j['meshes'][node['mesh']]['extras']['targetNames'])=={'corrective_'+g for g in ['Fist','Shaft','Trigger','Support','Bolt']}
        for target in targets:
            offsets=values(target['POSITION'])
            assert offsets.shape==pos.shape and np.isfinite(offsets).all()
            assert np.linalg.norm(offsets,axis=1).max()<.035
        assert sum(np.linalg.norm(values(t['POSITION']),axis=1).max() for t in targets)>.005
    unique,weld=np.unique(pos,axis=0,return_inverse=True);faces=weld[tri]
    edges=Counter(tuple(sorted(e)) for face in faces for e in zip(face,np.roll(face,-1)))
    assert set(edges.values())=={2},'Open skin surface'
    neighbours=[set() for _ in unique]
    for a,b in edges:neighbours[a].add(b);neighbours[b].add(a)
    visited={0};stack=[0]
    while stack:
        for q in neighbours[stack.pop()]-visited:visited.add(q);stack.append(q)
    assert len(visited)==len(unique),'Detached skin component'
    a,b,c=pos[tri[:,0]],pos[tri[:,1]],pos[tri[:,2]]
    area=np.linalg.norm(np.cross(b-a,c-a),axis=1)*.5
    assert area.min()>1e-12
    volume=np.einsum('ij,ij->i',a,np.cross(b,c)).sum()/6
    assert volume>0,'Inverted skin winding'
    report[node['name']]={'triangles':len(tri),'components':1,'closed':True,
        'weight_sum_error':float(np.max(np.abs(weights.sum(axis=1)-1))),
        'minimum_triangle_area_m2':float(area.min())}
print(json.dumps({'ok':True,'bones_per_hand':16,'skeletons':2,'grips':6,'bind_error':float(bind_error),'bytes':len(raw),'meshes':report},indent=2))
