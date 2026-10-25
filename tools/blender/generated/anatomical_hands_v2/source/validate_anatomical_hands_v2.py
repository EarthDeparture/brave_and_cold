"""Independent GLB geometry, UV, bind matrices, skinning and clip validation."""
from pathlib import Path
from collections import Counter
import json,hashlib,struct,numpy as np
from validate_field_survival_kit import transform
OUT=Path(__file__).parent/'generated/anatomical_hands_v2'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(path):
    raw=path.read_bytes();magic,version,length=struct.unpack_from('<III',raw);assert magic==0x46546c67 and version==2 and length==len(raw)
    jl,jt=struct.unpack_from('<II',raw,12);assert jt==0x4e4f534a;g=json.loads(raw[20:20+jl]);bl,bt=struct.unpack_from('<II',raw,20+jl);assert bt==0x004e4942;binary=raw[28+jl:28+jl+bl]
    def values(index):
        a=g['accessors'][index];view=g['bufferViews'][a['bufferView']];c={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']];dtype=np.dtype({5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']]);offset=view.get('byteOffset',0)+a.get('byteOffset',0)
        return np.ndarray((a['count'],c),dtype=dtype,buffer=binary,offset=offset,strides=(view.get('byteStride',dtype.itemsize*c),dtype.itemsize)).copy()
    return g,values
def validate():
    meta=json.loads((OUT/'manifest.json').read_text());assert sha(OUT/'godot/anatomical_hands.glb')==meta['glb_sha256'];assert sha(OUT/'anatomical_hands.blend')==meta['native_sha256']
    g,v=read(OUT/'godot/anatomical_hands.glb');assert len(g['skins'])==2 and all(len(s['joints'])==17 for s in g['skins'])
    assert {a['name'] for a in g['animations']}==set(meta['clips']);assert all('bufferView' in im and 'uri' not in im for im in g['images'])
    parents={c:i for i,n in enumerate(g['nodes']) for c in n.get('children',[])}
    def world(i):return world(parents[i])@transform(g['nodes'][i]) if i in parents else transform(g['nodes'][i])
    meshes={};bind_error=0
    for index,node in enumerate(g['nodes']):
        if 'mesh' not in node:continue
        name=node['name'];assert name in meta['meshes'],('unwanted mesh',name);assert 'skin' in node
        skin=g['skins'][node['skin']];binds=v(skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
        error=max(np.max(abs(world(joint)@bind-world(index))) for joint,bind in zip(skin['joints'],binds));bind_error=max(bind_error,float(error));assert error<2e-6,(name,'inverse bind',error)
        count=0;worldpts=[]
        for primitive in g['meshes'][node['mesh']]['primitives']:
            at=primitive['attributes'];assert all(k in at for k in ['POSITION','NORMAL','TEXCOORD_0','JOINTS_0','WEIGHTS_0'])
            p=v(at['POSITION']);n=v(at['NORMAL']);uv=v(at['TEXCOORD_0']);j=v(at['JOINTS_0']);w=v(at['WEIGHTS_0']);idx=v(primitive['indices']).ravel().astype(int);tri=idx.reshape(-1,3)
            assert all(np.isfinite(a).all() for a in [p,n,uv,w]);assert np.max(abs(np.linalg.norm(n,axis=1)-1))<.005
            assert j.min()>=0 and j.max()<17 and np.min(w)>=0 and np.max(w)<=1 and np.max(abs(w.sum(1)-1))<1e-5
            assert uv.min()>=-.0001 and uv.max()<=1.0001
            area=np.linalg.norm(np.cross(p[tri[:,1]]-p[tri[:,0]],p[tri[:,2]]-p[tri[:,0]]),axis=1)*.5;assert area.min()>1e-12,(name,'zero area')
            unique,weld=np.unique(p,axis=0,return_inverse=True);faces=weld[tri];edges=Counter(tuple(sorted(e)) for face in faces for e in zip(face,np.roll(face,-1)));assert set(edges.values())=={2},(name,'open topology')
            graph=[set() for _ in unique]
            for a,b in edges:graph[a].add(b);graph[b].add(a)
            pending=set(range(len(unique)));components=0
            while pending:
                components+=1;stack=[pending.pop()]
                while stack:
                    for q in graph[stack.pop()]&pending:pending.remove(q);stack.append(q)
            assert components==(1 if name.startswith('Bare') else 5),(name,'disconnected skin',components)
            volume=float(np.einsum('ij,ij->i',p[tri[:,0]],np.cross(p[tri[:,1]],p[tri[:,2]])).sum()/6);assert volume>0,(name,'inverted winding')
            targets=primitive.get('targets',[])
            if name.startswith('Bare'):
                assert len(targets)==8 and set(g['meshes'][node['mesh']]['extras']['targetNames'])=={'corrective_'+s for s in meta['poses'] if s!='Open'}
                for target in targets:assert np.isfinite(v(target['POSITION'])).all() and np.linalg.norm(v(target['POSITION']),axis=1).max()<.035
            else:assert not targets
            count+=len(tri);pp=np.concatenate([p,np.ones((len(p),1))],1)@world(index).T;worldpts.extend(pp[:,:3])
        assert count==meta['meshes'][name]['triangles'];p=np.array(worldpts)
        meshes[name]={'triangles':count,'connected_components':1 if name.startswith('Bare') else 5,'dimensions_m':(p.max(0)-p.min(0)).tolist(),'bounds_min':p.min(0).tolist(),'bounds_max':p.max(0).tolist(),'closed':True,'skinned':True}
    assert set(meshes)==set(meta['meshes'])
    assert np.max(abs(np.array(meshes['BareHand']['dimensions_m'])-meshes['BareHandLeft']['dimensions_m']))<1e-5
    clips={}
    for a in g['animations']:
        end=max(float(v(s['input']).max()) for s in a['samplers']);expected=2.6 if a['name']=='FlexCycle' else 1
        assert abs(end-expected)<.018,(a['name'],end)
        paths=Counter(c['target']['path'] for c in a['channels']);assert paths['weights']==2,(a['name'],'lost corrective animation')
        for s in a['samplers']:
            times=v(s['input']).ravel();assert np.all(np.diff(times)>0) and np.isfinite(v(s['output'])).all()
        for c in a['channels']:
            if c['target']['path']!='weights':continue
            sampler=a['samplers'][c['sampler']];weights=v(sampler['output']).reshape(-1,8)
            if a['name']=='FlexCycle':
                assert len(weights)==79 and abs(weights[0]).max()<1e-6 and abs(weights[-1]).max()<1e-6
                assert weights[40].max()>.999 and weights[56].max()>.999 and np.max(np.ptp(weights,axis=0))>.999
        clips[a['name']]={'duration_s':end,'channels':dict(paths),'tracks':len(a['channels'])}
    return {'glb':'passed','skins':2,'bones_per_hand':17,'inverse_bind_max_error':bind_error,'embedded_images':len(g['images']),'meshes':meshes,'animations':clips}
if __name__=='__main__':
    report=validate();(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n');print('ANATOMICAL_GLB_PASS',len(report['meshes']),len(report['animations']))
