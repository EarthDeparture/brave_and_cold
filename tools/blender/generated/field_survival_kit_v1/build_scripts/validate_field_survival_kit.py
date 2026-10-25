"""Independently inspect exported glTF geometry, dimensions, UVs and provenance."""
from pathlib import Path
import hashlib,json,struct,math
import numpy as np
OUT=Path(__file__).parent/'generated/field_survival_kit_v1'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read_glb(path):
    raw=path.read_bytes();magic,version,length=struct.unpack_from('<III',raw)
    assert magic==0x46546c67 and version==2 and length==len(raw)
    jl,jt=struct.unpack_from('<II',raw,12);assert jt==0x4e4f534a
    g=json.loads(raw[20:20+jl]);bl,bt=struct.unpack_from('<II',raw,20+jl);assert bt==0x004e4942
    binary=raw[28+jl:28+jl+bl]
    def values(index):
        a=g['accessors'][index];v=g['bufferViews'][a['bufferView']]
        f={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']]
        c={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        fmt='<'+f*c;size=struct.calcsize(fmt);off=v.get('byteOffset',0)+a.get('byteOffset',0)
        return np.array([struct.unpack_from(fmt,binary,off+i*v.get('byteStride',size)) for i in range(a['count'])])
    return raw,g,values
def transform(node):
    if 'matrix' in node:return np.array(node['matrix']).reshape((4,4),order='F')
    x,y,z,w=node.get('rotation',[0,0,0,1]);m=np.eye(4)
    m[:3,:3]=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
              [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
              [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]
    m[:3,:3]=m[:3,:3]@np.diag(node.get('scale',[1,1,1]));m[:3,3]=node.get('translation',[0,0,0]);return m
def validate():
    meta=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'));results={}
    assert len(meta['assets'])==32
    for name,r in meta['assets'].items():
        path=OUT/r['glb'];assert sha(path)==r['glb_sha256'];assert sha(OUT/r['native'])==r['native_sha256']
        raw,g,values=read_glb(path);tri=0;degenerate=0;pts=[];names=set();norms_ok=True
        for im in g.get('images',[]):assert 'bufferView' in im and 'uri' not in im,(name,'non-portable texture')
        def visit(i,parent):
            nonlocal tri,degenerate,norms_ok
            n=g['nodes'][i];names.add(n.get('name',''));m=parent@transform(n)
            if 'mesh' in n:
                for primitive in g['meshes'][n['mesh']]['primitives']:
                    at=primitive['attributes'];assert 'NORMAL' in at and 'TEXCOORD_0' in at
                    p=values(at['POSITION']);norm=values(at['NORMAL']);uv=values(at['TEXCOORD_0'])
                    assert np.isfinite(p).all() and np.isfinite(norm).all() and np.isfinite(uv).all()
                    assert np.max(abs(np.linalg.norm(norm,axis=1)-1))<.005,(name,'bad normals')
                    idx=values(primitive['indices']).astype(int).ravel();assert len(idx)%3==0 and idx.min()>=0 and idx.max()<len(p)
                    t=p[idx].reshape((-1,3,3));cross=np.cross(t[:,1]-t[:,0],t[:,2]-t[:,0]);degenerate+=int((np.linalg.norm(cross,axis=1)<1e-10).sum());tri+=len(t)
                    pp=np.concatenate([p,np.ones((len(p),1))],axis=1)@m.T;pts.extend(pp[:,:3])
            for child in n.get('children',[]):visit(child,m)
        for i in g['scenes'][g.get('scene',0)]['nodes']:visit(i,np.eye(4))
        p=np.array(pts);size=p.max(axis=0)-p.min(axis=0)
        assert np.max(abs(size-np.array(r['measured_size_m'])))<.0005,(name,size,r['measured_size_m'])
        assert p[:,1].min()>=-.002,(name,'below resting plane',p[:,1].min())
        assert tri==r['triangles'] and tri<=24000,(name,tri,r['triangles'])
        assert degenerate==0,(name,'degenerate triangles',degenerate)
        assert all(pivot in names for pivot in r['pivots']),(name,'lost pivot')
        assert len(g.get('materials',[]))<=8,(name,'too many materials')
        results[name]={'triangles':tri,'dimensions_m':list(size),'lowest_y_m':float(p[:,1].min()),'degenerate_triangles':degenerate,'materials':len(g.get('materials',[])),'embedded_images':len(g.get('images',[])),'bytes':len(raw),'pivots_verified':r['pivots']}
    return results
if __name__=='__main__':
    results=validate();(OUT/'validation.json').write_text(json.dumps({'static_glb':'passed','assets':results},indent=2)+'\n',encoding='utf-8')
    print('FIELD_KIT_VALIDATE_PASS',len(results),'assets',sum(r['triangles'] for r in results.values()),'triangles')
