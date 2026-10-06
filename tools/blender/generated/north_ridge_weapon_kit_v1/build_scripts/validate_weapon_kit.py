"""Independent geometry, portability and animation-contract checks of final GLBs."""
from pathlib import Path
import json,hashlib,numpy as np
from validate_field_survival_kit import read_glb,transform
OUT=Path(__file__).parent/'generated/north_ridge_weapon_kit_v1'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def validate():
    meta=json.loads((OUT/'manifest.json').read_text());results={}
    assert len(meta['assets'])==18
    for name,r in meta['assets'].items():
        assert sha(OUT/r['glb'])==r['glb_sha256'];assert sha(OUT/r['native'])==r['native_sha256']
        raw,g,v=read_glb(OUT/r['glb']);tri=0;degenerate=0;pts=[];names=set();world={}
        def visit(i,parent):
            nonlocal tri,degenerate
            n=g['nodes'][i];names.add(n.get('name'));m=parent@transform(n);world[i]=m
            if 'mesh' in n:
                for primitive in g['meshes'][n['mesh']]['primitives']:
                    at=primitive['attributes'];assert 'TEXCOORD_0' in at and 'NORMAL' in at
                    p=v(at['POSITION']);norm=v(at['NORMAL']);uv=v(at['TEXCOORD_0'])
                    assert all(np.isfinite(a).all() for a in (p,norm,uv));assert np.max(abs(np.linalg.norm(norm,axis=1)-1))<.005
                    idx=v(primitive['indices']).astype(int).ravel();assert len(idx)%3==0 and idx.min()>=0 and idx.max()<len(p)
                    t=p[idx].reshape((-1,3,3));degenerate+=int((np.linalg.norm(np.cross(t[:,1]-t[:,0],t[:,2]-t[:,0]),axis=1)<1e-10).sum());tri+=len(t)
                    pp=np.concatenate([p,np.ones((len(p),1))],axis=1)@m.T;pts.extend(pp[:,:3])
            for child in n.get('children',[]):visit(child,m)
        for i in g['scenes'][g.get('scene',0)]['nodes']:visit(i,np.eye(4))
        p=np.array(pts);size=p.max(axis=0)-p.min(axis=0)
        assert np.max(abs(size-r['dimensions_m']))<.0005,(name,size,r['dimensions_m'])
        assert np.max(abs(p.min(axis=0)-r['bounds_min']))<.0005
        assert np.max(abs(p.max(axis=0)-r['bounds_max']))<.0005
        assert tri==r['triangles'] and tri<24000,(name,tri,r['triangles']);assert degenerate==0,(name,'degenerate',degenerate)
        assert set(r['nodes'])<=names,(name,'missing attachment');assert len(g.get('materials',[]))<=8
        for im in g.get('images',[]):assert 'bufferView' in im and 'uri' not in im
        animations={a['name']:a for a in g.get('animations',[])};assert set(animations)==set(r['animations']),(name,set(animations),set(r['animations']))
        clips={}
        for clip,contract in r['animations'].items():
            a=animations[clip];end=max(float(v(s['input']).max()) for s in a['samplers'])
            assert abs(end-contract['duration_s'])<.018,(name,clip,end,contract['duration_s'])
            channel_names=set();changes=0
            for channel in a['channels']:
                node=g['nodes'][channel['target']['node']]['name'];channel_names.add(node)
                s=a['samplers'][channel['sampler']];times=v(s['input']).ravel();data=v(s['output'])
                assert np.isfinite(data).all() and np.all(np.diff(times)>0),(name,clip,'invalid keys')
                changes+=int(np.max(abs(data-data[0]))>1e-6)
            assert changes>0,(name,clip,'empty animation')
            if clip.startswith('reload') and 'Magazine' in ''.join(contract['animated_nodes']):assert name+'__Pivot_Magazine' in channel_names
            assert all(0<=e['time_s']<=end+.018 for e in contract['events'])
            clips[clip]={'duration_s':end,'channels':len(a['channels']),'changed_channels':changes,'animated_nodes':sorted(channel_names)}
        results[name]={'triangles':tri,'dimensions_m':size.tolist(),'materials':len(g.get('materials',[])),'embedded_images':len(g.get('images',[])),'bytes':len(raw),'degenerate_triangles':degenerate,'nodes':r['nodes'],'animations':clips}
    return results
if __name__=='__main__':
    results=validate();(OUT/'validation.json').write_text(json.dumps({'glb_geometry_and_animation':'passed','assets':results},indent=2)+'\n',encoding='utf-8',newline='\n')
    print('WEAPON_GLB_PASS',len(results),sum(len(r['animations']) for r in results.values()),'clips',sum(r['triangles'] for r in results.values()),'triangles')
