"""Fit wrist offsets to real runtime-skinned gloves and imported prop triangles.
Solid-angle winding in closed components diagnoses contact independently of normals.
"""
from pathlib import Path
import bpy,json,math,sys,numpy as np
from mathutils import Vector,Euler
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
IN=ROOT/'brave-and-cold/shots/anatomical-weapons/contact_geometry.json'
rows=json.loads(IN.read_text());profiles={};audit={}
for key,row in rows.items():
    only=next((arg.split('=',1)[1].split(',') for arg in sys.argv if arg.startswith('--only=')),[])
    if only and key not in only:continue
    if key!='tool' and key.endswith('/bolt') and not key.startswith('timber_bolt_carbine/'):continue
    if key.startswith('brush_lever_rifle/') and key.endswith('/magazine'):continue
    if key=='tool':sides=['right']
    elif key.endswith('/hold'):sides=['right','left']
    elif key.endswith('/bolt'):sides=['right']
    else:sides=['left']
    verts=[];tris=[];solids=[]
    for mesh in row['geometry']:
        start=len(verts);verts.extend(mesh['points']);tri=np.array(mesh['indices']).reshape(-1,3)+start;tris.extend(tri.tolist())
        from collections import Counter
        coordinates=np.array(mesh['points']);faces=np.array(mesh['indices']).reshape(-1,3)
        unique,weld=np.unique(np.round(coordinates,6),axis=0,return_inverse=True);faces=weld[faces]
        parent=list(range(len(unique)))
        def root(i):
            while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
            return i
        for face in faces:
            for i in face[1:]:parent[root(int(i))]=root(int(face[0]))
        components={}
        for face in faces:components.setdefault(root(int(face[0])),[]).append(tuple(int(i) for i in face))
        for component in components.values():
            edges=Counter(tuple(sorted(edge)) for face in component for edge in zip(face,np.roll(face,-1)))
            if set(edges.values())!={2}:continue
            ids=np.unique(component);lo=unique[ids].min(0);hi=unique[ids].max(0)
            solids.append((BVHTree.FromPolygons(unique.tolist(),component,all_triangles=True),lo,hi,unique[np.array(component)]))
    tree=BVHTree.FromPolygons([tuple(v) for v in verts],tris,all_triangles=True)
    for side in sides:
        hand=row[side];points=np.array(hand['points']);names=np.array(hand['regions']);mask=names!='forearm'
        ids=np.flatnonzero(mask);sample=ids[::max(1,len(ids)//600)];p=points[sample];regions=names[sample]
        basis=np.array(hand['basis']).T;origin=np.array(hand['origin'])
        def distances(world):
            values=np.array([tree.find_nearest(Vector(point))[3] for point in world])
            for solid,lo,hi,triangles in solids:
                candidates=np.flatnonzero(np.all((world>lo+1e-7)&(world<hi-1e-7),axis=1))
                for start in range(0,len(candidates),64):
                    ids_=candidates[start:start+64]
                    vectors=triangles[None,:,:,:]-world[ids_,None,None,:]
                    a,b,c=vectors[:,:,0],vectors[:,:,1],vectors[:,:,2]
                    la,lb,lc=np.linalg.norm(a,axis=2),np.linalg.norm(b,axis=2),np.linalg.norm(c,axis=2)
                    determinant=np.einsum('nfi,nfi->nf',a,np.cross(b,c))
                    denominator=la*lb*lc+np.einsum('nfi,nfi->nf',a,b)*lc+np.einsum('nfi,nfi->nf',b,c)*la+np.einsum('nfi,nfi->nf',c,a)*lb
                    inside=abs(np.sum(2*np.arctan2(determinant,denominator),axis=1))>2*math.pi
                    for i in ids_[inside]:
                        distance=solid.find_nearest(Vector(world[i]))[3];values[i]=min(values[i],-distance)
            return values
        def evaluate(delta,full=False):
            target=(points[ids] if full else p)@basis.T+origin+delta
            d=distances(target)
            if full:return d
            penetration=np.maximum(-d-.0012,0)
            cost=100*np.mean(penetration**2)+12*max(penetration)**2
            for digit in ['middle','ring','little','thumb']:
                group=np.char.startswith(regions,digit+'_0') & ~np.char.endswith(regions,'_01')
                if group.any():cost+=.25*np.mean(np.sort(abs(d[group]))[:4]**2)
            cost+=.012*np.dot(delta,delta)
            return float(cost)
        original=evaluate(np.zeros(3),True)
        # Include the actual deepest vertices, which a regular sampling stride
        # can miss around thumb webs and narrow finger creases.
        worst=ids[np.argsort(original)[:100]]
        sample=np.unique(np.r_[sample,worst]);p=points[sample];regions=names[sample]
        delta=np.zeros(3);cost=evaluate(delta)
        for refinement in range(3 if '--audit-only' not in sys.argv and key!='tool' else 0):
            for step in [.008,.004,.002,.001,.0005]:
                for iteration in range(12):
                    best=(cost,delta)
                    for axis in range(3):
                        for sign in [-1,1]:
                            candidate=delta.copy();candidate[axis]+=step*sign
                            if abs(candidate).max()>.055:continue
                            value=evaluate(candidate)
                            if value<best[0]-1e-12:best=(value,candidate)
                    if best[0]>=cost-1e-12:break
                    cost,delta=best
            measured=evaluate(delta,True)
            if measured.min()>-.003:break
            sample=np.unique(np.r_[sample,ids[np.argsort(measured)[:150]]]);p=points[sample];regions=names[sample];cost=evaluate(delta)
        original=evaluate(np.zeros(3),True);fitted=evaluate(delta,True)
        audit[key+'/'+side]={'initial_solid_overlap_m':float(max(0,-original.min())),'fitted_solid_overlap_m':float(max(0,-fitted.min())),'worst_region':str(names[ids[np.argmin(fitted)]]),'near_surface_vertices':int((abs(fitted)<.004).sum()),'wrist_offset_weapon_space_m':delta.tolist(),'closed_components':len(solids),'metric':'solid-angle winding per welded closed component, actual closest-triangle depth; excludes forearm, open surfaces are contact-only'}
        print('CONTACT_FIT',key,side,audit[key+'/'+side],flush=True)
        local=np.linalg.solve(np.array(row.get('anchors',{}).get(side,np.eye(3).tolist())).T,delta)
        audit[key+'/'+side]['wrist_offset_socket_space_m']=local.tolist()
        profiles.setdefault(key.split('/')[0],{})[('tool' if key=='tool' else key.split('/')[1])+'_'+side]=local.tolist()
OUT=ROOT/'tools/blender/generated/live_hand_rig_v2'
if '--audit-only' not in sys.argv:
    (OUT/'contact_fit_candidates.json').write_text(json.dumps(profiles,indent=2)+'\n',encoding='utf-8',newline='\n')
(ROOT/'tools/blender/generated/live_hand_rig_v2/contact_fit_audit.json').write_text(json.dumps(audit,indent=2)+'\n',encoding='utf-8',newline='\n')
if '--strict' in sys.argv:
    assert all(row['fitted_solid_overlap_m']<.0035 and row['near_surface_vertices']>20 for row in audit.values()),'Contact tolerance failed; inspect contact_fit_audit.json'
print('RUNTIME_CONTACT_'+('AUDIT' if '--audit-only' in sys.argv else 'FIT')+'_PASS',len(audit))
