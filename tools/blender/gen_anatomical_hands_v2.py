"""Original connected quad-cage anatomy, skinned hands and rigid nail plates.
Standalone replacement candidate: no live game assets are overwritten.
Godot metres: wrist at zero, dorsum +Y, fingers -Z, forearm +Z.
"""
from pathlib import Path
import bpy,bmesh,math,json,hashlib,sys
from mathutils import Vector,Euler,Quaternion
from mathutils.bvhtree import BVHTree
sys.path.insert(0,str(Path(__file__).parent))
import gen_hand_rig as existing
from gen_survivor_hands import blender as cv
from hand_anatomy_materials_v2 import paint_skin,make_nail_material
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'tools/blender/generated/anatomical_hands_v2'
for p in [OUT,OUT/'textures',OUT/'previews',OUT/'godot']:p.mkdir(parents=True,exist_ok=True)
DIGITS=['index','middle','ring','little']
LENGTHS=[(.041,.025,.018),(.045,.028,.020),(.043,.027,.019),(.034,.021,.016)]
MCP=[-.085,-.090,-.087,-.075]
XS=[-.043,-.032,-.021,-.0105,0,.0105,.021,.031,.041]
RADII=[.0090,.0096,.0091,.0076]

class Anatomy:
    def __init__(self):
        self.v=[];self.f=[];self.w=[];self.uv=[];self.digits=[]
        self.bones={'forearm':((0,0,.095),(0,0,0),None),'hand':((0,0,0),(0,0,-.055),'forearm')}
    def vertex(self,p,w=None):self.v.append(Vector(p));self.w.append(w or {'hand':1});return len(self.v)-1
    def face(self,indices,uv):self.f.append(tuple(indices));self.uv.append(uv)
    def palm_uv(self,i,back):
        p=self.v[i];return ((.04 if back else .53)+(p.x+.046)/.092*.42,.55+(.095-p.z)/.19*.40)
    def palm_face(self,ids,back):self.face(ids,[self.palm_uv(i,back) for i in ids])
    def palm(self):
        zrows=[.095,.065,.035,.014,0,-.013,-.027,-.043,-.059,-.073,-.080]
        widths=[.73,.70,.67,.64,.64,.71,.82,.94,1,1,1]
        self.top=[];self.bottom=[];self.zrows=zrows
        for row,z in enumerate(zrows):
            top=[];bottom=[]
            for col,x0 in enumerate(XS):
                x=x0*widths[row];zz=z
                if col==8 and row>=len(zrows)-2:x-=.0025
                if row==len(zrows)-1:
                    zz=MCP[min(col//2,3)] if col%2 else MCP[0]+.005 if col==0 else MCP[3]+.005 if col==8 else (MCP[col//2-1]+MCP[col//2])*.5+.009
                cross=math.sqrt(max(0,1-(x0/.050)**2))
                dorsal=.004+.0085*cross
                dorsal+=.0018*math.exp(-((zz+.048)/.033)**2)
                dorsal+=.0037*math.exp(-((zz+.084)/.012)**2)*(.25+.75*(col%2))
                for tendon in [-.032,-.0105,.0105,.031]:dorsal+=.00065*math.exp(-((x0-tendon)/.0055)**2-((zz+.040)/.027)**2)
                pad=.0088*math.exp(-((x+.025)/.019)**2-((zz+.033)/.025)**2)
                pad+=.0045*math.exp(-((x-.028)/.016)**2-((zz+.052)/.027)**2)
                volar=-.0048-.0075*cross-pad
                if z>0:
                    dorsal+=.0025*min(z/.095,1);volar-=.0020*min(z/.095,1)
                hand_weight=max(0,min(1,(.030-z)/.042));weights={'forearm':1-hand_weight,'hand':hand_weight}
                weights={k:v for k,v in weights.items() if v>0}
                if z<.008:
                    thumb_weight=.68*math.exp(-((x+.033)/.035)**2-((zz+.029)/.033)**2)
                    weights['hand']-=thumb_weight;weights['thumb_01']=thumb_weight
                top.append(self.vertex((x,dorsal,zz),weights.copy()));bottom.append(self.vertex((x,volar,zz),weights.copy()))
            self.top.append(top);self.bottom.append(bottom)
        nr=len(zrows)
        for row in range(nr-1):
            for col in range(8):
                self.palm_face([self.top[row][col],self.top[row+1][col],self.top[row+1][col+1],self.top[row][col+1]],True)
                self.palm_face([self.bottom[row][col+1],self.bottom[row+1][col+1],self.bottom[row+1][col],self.bottom[row][col]],False)
        self.side={}
        for col in [0,8]:
            mids=[self.vertex((self.v[self.top[r][col]]+self.v[self.bottom[r][col]])*.5,self.w[self.top[r][col]].copy()) for r in range(nr)]
            self.side[col]=mids
            for r in range(nr-1):
                if col==0 and r in [5,6]:continue
                for ids in [[self.top[r][col],self.top[r+1][col],mids[r+1],mids[r]],[mids[r],mids[r+1],self.bottom[r+1][col],self.bottom[r][col]]]:
                    self.face(ids,[(.04+(.095-self.v[i].z)/.19*.91,.49+(self.v[i].y+.025)/.045*.035) for i in ids])
        ids=self.top[0]+[self.side[8][0]]+list(reversed(self.bottom[0]))+[self.side[0][0]]
        self.face(ids,[(.88+self.v[i].x,.43+self.v[i].y) for i in ids])
        self.endmids=[self.side[0][-1]]+[self.vertex((self.v[self.top[-1][c]]+self.v[self.bottom[-1][c]])*.5) for c in [2,4,6]]+[self.side[8][-1]]
    def radius(self,r,segment,t,lengths):
        along=(sum(lengths[:segment])+lengths[segment]*t)/sum(lengths)
        value=r*(1-.22*along)*(1+.065*math.exp(-(t/.13)**2)+.060*math.exp(-((t-1)/.13)**2)-.045*math.exp(-((t-.50)/.25)**2))
        if segment==2:value*=max(.08,math.sqrt(max(0,1-max(0,(t-.65)/.35)**2)))
        return value
    def digit(self,name,root,centers,lengths,radius,ref=(1,0,0),atlas_column=0):
        centers=[Vector(p) for p in centers];parent='hand'
        for j in range(3):
            bone=name+'_'+str(j+1).zfill(2);self.bones[bone]=(tuple(centers[j]),tuple(centers[j+1]),parent);parent=bone
        self.digits.append((centers,radius))
        for i in root:
            self.w[i]['hand']=self.w[i].get('hand',0)-.20;self.w[i][name+'_01']=self.w[i].get(name+'_01',0)+.20
        prev=root;prev_v=.025
        for segment in range(3):
            a,b=centers[segment:segment+2];tangent=(b-a).normalized();u=Vector(ref);u=(u-tangent*u.dot(tangent)).normalized();v=u.cross(tangent).normalized()
            for t in [.08,.25,.50,.76,.91,1.0]:
                r=self.radius(radius,segment,t,lengths)
                start=a if name!='thumb' or segment else sum((self.v[i] for i in root),Vector())/8+tangent*.019
                center=start.lerp(b,t);bone=name+'_'+str(segment+1).zfill(2);weights={bone:1}
                if t<.20:
                    k=.5*(1-t/.20);previous='hand' if segment==0 else name+'_'+str(segment).zfill(2);weights={previous:k,bone:1-k}
                elif t>.80 and segment<2:
                    k=.5*(t-.80)/.20;weights={bone:1-k,name+'_'+str(segment+2).zfill(2):k}
                ring=[]
                for k in range(8):
                    angle=math.pi/4+math.tau*k/8 if name=='thumb' else math.pi*3/4-math.tau*k/8
                    cs,sn=math.cos(angle),math.sin(angle);flattened=sn*.72 if sn>0 else sn*.96
                    # The distal volar pad stays full while the dorsal nail bed flattens.
                    offset=u*(cs*r)+v*(flattened*r)
                    offset-=v*(.0007*math.sin(t*math.pi)*max(0,-sn))
                    ring.append(self.vertex(center+offset,weights.copy()))
                yy=.025+(sum(lengths[:segment])+lengths[segment]*t)/sum(lengths)*.39
                left=.035+atlas_column*.19;width=.16
                for k in range(8):
                    self.face([prev[k],prev[(k+1)%8],ring[(k+1)%8],ring[k]],[(left+width*k/8,prev_v),(left+width*(k+1)/8,prev_v),(left+width*(k+1)/8,yy),(left+width*k/8,yy)])
                prev=ring;prev_v=yy
        self.face(list(reversed(prev)),[(.11+atlas_column*.19+.015*math.cos(k*math.tau/8),.455+.015*math.sin(k*math.tau/8)) for k in reversed(range(8))])
    def build(self):
        self.palm()
        for j,name in enumerate(DIGITS):
            col=j*2;root=[*self.top[-1][col:col+3],self.endmids[j+1],*reversed(self.bottom[-1][col:col+3]),self.endmids[j]]
            p=Vector((XS[col+1],.001,MCP[j]));centers=[p.copy()]
            for k,length in enumerate(LENGTHS[j]):p+=Vector(([-.055,-.008,.023,.110][j]*length,[-.006,-.006,-.010,-.014][j]*length,-length));centers.append(p.copy())
            self.digit(name,root,centers,LENGTHS[j],RADII[j],atlas_column=j)
        root=[self.top[7][0],self.top[6][0],self.top[5][0],self.side[0][5],self.bottom[5][0],self.bottom[6][0],self.bottom[7][0],self.side[0][7]]
        centers=[(-.038,-.006,-.029),(-.056,-.003,-.044),(-.074,-.001,-.063),(-.088,.001,-.080)]
        lengths=[(Vector(b)-Vector(a)).length for a,b in zip(centers,centers[1:])]
        self.digit('thumb',root,centers,lengths,.0116,ref=(.62,0,-.79),atlas_column=4)
        mesh=bpy.data.meshes.new('AnatomicalQuadCage');mesh.from_pydata([cv(p) for p in self.v],[],self.f);mesh.update()
        bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));assert all(e.is_manifold for e in bm.edges);bm.to_mesh(mesh);bm.free()
        uv=mesh.uv_layers.new(name='AnatomicalAtlas')
        for face,indices,coords in zip(mesh.polygons,self.f,self.uv):
            mapped=dict(zip(indices,coords))
            for li in face.loop_indices:uv.data[li].uv=mapped[mesh.loops[li].vertex_index]
        obj=bpy.data.objects.new('BareHand',mesh);bpy.context.collection.objects.link(obj)
        for name in self.bones:obj.vertex_groups.new(name=name)
        for i,w in enumerate(self.w):
            for name,value in w.items():
                if value>0:obj.vertex_groups[name].add([i],value,'REPLACE')
        cage=obj.copy();cage.data=obj.data.copy();cage.name='EditableQuadCage_Right';bpy.context.collection.objects.link(cage)
        cage.hide_render=True;cage.hide_set(True)
        bpy.context.view_layer.objects.active=obj;obj.select_set(True)
        sub=obj.modifiers.new('Two-level joint-loop subdivision','SUBSURF');sub.levels=2;bpy.ops.object.modifier_apply(modifier=sub.name)
        for vertex in obj.data.vertices:
            groups=sorted([(g.group,g.weight) for g in vertex.groups],key=lambda g:g[1],reverse=True);total=sum(g[1] for g in groups[:4])
            for group,weight in groups[4:]:obj.vertex_groups[group].remove([vertex.index])
            for group,weight in groups[:4]:obj.vertex_groups[group].add([vertex.index],weight/total,'REPLACE')
        for p in obj.data.polygons:p.use_smooth=True
        return obj,cage

POSES={
 'Open':{'fingers':[0,0,0],'thumb':[0,0,0],'opp':0},
 'Relaxed':{'fingers':[12,18,10],'thumb':[7,8,5],'opp':-10},
 'Fist':{'fingers':[75,88,40],'thumb':[17,25,18],'opp':-20},
 'Shaft':{'fingers':[58,76,45],'thumb':[17,40,28],'opp':-20},
 'Trigger':{'fingers':[58,75,42],'thumb':[17,35,25],'opp':-20,'index':[5,9,5]},
 'Support':{'fingers':[38,55,32],'thumb':[17,38,22],'opp':-20},
 'Bolt':{'fingers':[50,70,45],'thumb':[17,42,22],'opp':-20},
 'PinchReady':{'fingers':[15,23,14],'thumb':[17,40,22],'opp':-20,'index':[42,62,35]},
 'Magazine':{'fingers':[43,57,35],'thumb':[17,35,20],'opp':-20},
}
def set_pose(rig,name,side):
    spec=POSES[name]
    for b in rig.pose.bones:b.rotation_mode='QUATERNION';b.rotation_quaternion=Quaternion()
    for finger in DIGITS:
        values=spec.get(finger,spec['fingers'])
        for j,value in enumerate(values):
            if finger=='little' and name=='Fist':value=[68,93,35][j]
            rig.pose.bones[finger+'_'+str(j+1).zfill(2)].rotation_quaternion=Euler((-math.radians(value),0,0)).to_quaternion()
    for j,value in enumerate(spec['thumb']):rig.pose.bones['thumb_'+str(j+1).zfill(2)].rotation_quaternion=Euler((-math.radians(value),0,math.radians(spec['opp']*side if j==0 else 0))).to_quaternion()
    bpy.context.view_layer.update()
def add_actions(rig,side):
    rig.animation_data_create()
    for name in [*POSES,'FlexCycle']:
        action=bpy.data.actions.new(rig.name+'__'+name);action.use_fake_user=True;rig.animation_data.action=action
        stages=[(0,name),(30,name)] if name!='FlexCycle' else [(0,'Open'),(18,'Relaxed'),(40,'Fist'),(56,'Fist'),(78,'Open')]
        for frame,pose in stages:
            set_pose(rig,pose,side)
            for b in rig.pose.bones:b.keyframe_insert('rotation_quaternion',frame=frame,group=b.name)
        track=rig.animation_data.nla_tracks.new();track.name=name;strip=track.strips.new(name,0,action);strip.extrapolation='NOTHING';track.mute=True
    rig.animation_data.action=None;set_pose(rig,'Open',side)
def choose_pose(rig,name,side):
    if rig.animation_data:
        rig.animation_data.action=None;rig.animation_data.use_nla=False
        for t in rig.animation_data.nla_tracks:t.mute=True
    set_pose(rig,name,side)
def nails(hand,skin,rig,side):
    bpy.context.view_layer.update();tree=BVHTree.FromObject(skin,bpy.context.evaluated_depsgraph_get())
    vs=[];faces=[];weights=[]
    for digit,(path,radius) in zip(DIGITS+['thumb'],hand.digits):
        a,b=path[-2:];tangent=(b-a).normalized();u=Vector((1,0,0)) if digit!='thumb' else Vector((.62,0,-.79));u=(u-tangent*u.dot(tangent)).normalized();v=u.cross(tangent).normalized()
        ring=[];bottom=[];center=a.lerp(b,.53);length=(b-a).length*.30;width=radius*.56
        def project(xx,yy,height):
            base=center+u*xx+tangent*yy
            origin=cv((base.x*side,base.y,base.z))+cv((v.x*side,v.y,v.z))*.025;direction=-cv((v.x*side,v.y,v.z))
            hit,normal,index,distance=tree.ray_cast(origin,direction,.04);assert hit is not None,(digit,'nail projection')
            result=len(vs);vs.append(hit+normal*height);weights.append(digit+'_03');return result
        for k in range(20):
            angle=k*math.tau/20;xx=math.cos(angle)*width;yy=math.sin(angle)*length
            ring.append(project(xx,yy,.00020));bottom.append(project(xx,yy,.000045))
        inner=[project(math.cos(k*math.tau/20)*width*.50,math.sin(k*math.tau/20)*length*.50,.00026) for k in range(20)]
        center_vertex=project(0,0,.00028);faces.append(tuple(reversed(bottom)))
        for k in range(20):faces.append((bottom[k],bottom[(k+1)%20],ring[(k+1)%20],ring[k]))
        for k in range(20):faces.extend([(ring[k],ring[(k+1)%20],inner[(k+1)%20],inner[k]),(inner[k],inner[(k+1)%20],center_vertex)])
    mesh=bpy.data.meshes.new('NailPlates');mesh.from_pydata(vs,[],faces);mesh.update();obj=bpy.data.objects.new('NailsRight' if side==1 else 'NailsLeft',mesh);bpy.context.collection.objects.link(obj)
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    for name in hand.bones:obj.vertex_groups.new(name=name)
    for i,name in enumerate(weights):obj.vertex_groups[name].add([i],1,'REPLACE')
    obj.parent=rig;mod=obj.modifiers.new('Rigid distal nail skinning','ARMATURE');mod.object=rig
    obj.data.materials.append(make_nail_material());bpy.context.view_layer.objects.active=obj;bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT')
    for p in obj.data.polygons:p.use_smooth=True
    return obj

def correctives(obj,rig,side):
    import numpy as np
    mod=next(m for m in obj.modifiers if m.type=='ARMATURE');obj.shape_key_add(name='Basis')
    rest=np.array([tuple(v.co) for v in obj.data.vertices]);names=[g.name for g in obj.vertex_groups]
    ids=np.zeros((len(rest),4),int);weights=np.zeros((len(rest),4))
    for i,v in enumerate(obj.data.vertices):
        for j,g in enumerate(v.groups):ids[i,j]=g.group;weights[i,j]=g.weight
    report={}
    for name in POSES:
        if name=='Open':continue
        choose_pose(rig,name,side)
        matrices=np.array([list(list(row) for row in rig.pose.bones[n].matrix@rig.data.bones[n].matrix_local.inverted()) for n in names])
        blend=np.sum(matrices[ids]*weights[:,:,None,None],axis=1);linear=np.einsum('nij,nj->ni',blend[:,:3,:3],rest)+blend[:,:3,3]
        mod.use_deform_preserve_volume=True;bpy.context.view_layer.update();evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());me=evaluated.to_mesh();target=np.array([tuple(v.co) for v in me.vertices]);evaluated.to_mesh_clear()
        delta=np.linalg.solve(blend[:,:3,:3],(target-linear)[:,:,None])[:,:,0];assert np.isfinite(delta).all() and np.linalg.norm(delta,axis=1).max()<.035,(name,np.linalg.norm(delta,axis=1).max())
        key=obj.shape_key_add(name='corrective_'+name)
        for vertex,co in zip(key.data,rest+delta):vertex.co=co
        key.value=0;mod.use_deform_preserve_volume=False;report[name]=float(np.linalg.norm(delta,axis=1).max())
    choose_pose(rig,'Open',side);return report

def morph_actions(obj):
    keys=obj.data.shape_keys;keys.animation_data_create()
    for name in [*POSES,'FlexCycle']:
        action=bpy.data.actions.new(obj.name+'__'+name);keys.animation_data.action=action
        stages=[(0,name),(30,name)] if name!='FlexCycle' else [(0,'Open'),(18,'Relaxed'),(40,'Fist'),(56,'Fist'),(78,'Open')]
        for frame,pose in stages:
            for key in keys.key_blocks:
                if key.name=='Basis':continue
                key.value=float(key.name=='corrective_'+pose);key.keyframe_insert('value',frame=frame)
        track=keys.animation_data.nla_tracks.new();track.name=name;strip=track.strips.new(name,0,action);strip.extrapolation='NOTHING';track.mute=True
    keys.animation_data.action=None
    for key in keys.key_blocks:key.value=0

bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1;scene.render.fps=30
hand=Anatomy();right,cage=hand.build();rig=existing.make_rig(hand,right)
if '--geometry-only' not in sys.argv:paint_skin(right,hand,OUT/'textures')
left=right.copy();left.data=right.data.copy();left.name='BareHandLeft';left.parent=None;left.modifiers.clear();bpy.context.collection.objects.link(left)
for vertex in left.data.vertices:vertex.co.x=-vertex.co.x
bm=bmesh.new();bm.from_mesh(left.data);bmesh.ops.reverse_faces(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(left.data);bm.free();left.data.update()
left_rig=existing.make_rig(hand,left,-1)
left_cage=cage.copy();left_cage.data=cage.data.copy();left_cage.name='EditableQuadCage_Left';bpy.context.collection.objects.link(left_cage)
for vertex in left_cage.data.vertices:vertex.co.x=-vertex.co.x
bm=bmesh.new();bm.from_mesh(left_cage.data);bmesh.ops.reverse_faces(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(left_cage.data);bm.free()
left_cage.hide_render=True;left_cage.hide_set(True)
nails_r=nails(hand,right,rig,1);nails_l=nails(hand,left,left_rig,-1)
add_actions(rig,1);add_actions(left_rig,-1)
corrections={right.name:correctives(right,rig,1),left.name:correctives(left,left_rig,-1)}
for obj in [right,left]:morph_actions(obj)
for which,side in [(rig,1),(left_rig,-1)]:
    choose_pose(which,'Open',side);which.animation_data.use_nla=True
report={}
for obj in [right,left,nails_r,nails_l]:
    bm=bmesh.new();bm.from_mesh(obj.data);assert all(e.is_manifold for e in bm.edges);assert all(f.calc_area()>1e-12 for f in bm.faces)
    assert all(1<=len(v.groups)<=4 and abs(sum(g.weight for g in v.groups)-1)<1e-5 for v in obj.data.vertices)
    report[obj.name]={'vertices':len(bm.verts),'triangles':sum(len(f.verts)-2 for f in bm.faces),'closed':True};bm.free()
print('HAND_ANATOMY_BUILT',json.dumps(report),flush=True)
bpy.ops.object.select_all(action='DESELECT')
for o in [rig,left_rig,right,left,nails_r,nails_l]:o.select_set(True)
rest={o:o.matrix_basis.copy() for o in [rig,left_rig,right,left,nails_r,nails_l]}
glb=OUT/'godot/anatomical_hands.glb'
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_yup=True,export_apply=False,export_normals=True,export_materials='EXPORT',export_skins=True,export_def_bones=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_merge_animation='NLA_TRACK',export_morph=True)
from export_hand_morph_tracks_v2 import bake_morph_tracks
bake_morph_tracks(glb)
for o,matrix in rest.items():o.matrix_basis=matrix
for which,side in [(rig,1),(left_rig,-1)]:choose_pose(which,'Open',side)
for obj in [right,left]:
    obj.data.shape_keys.animation_data.action=None;obj.data.shape_keys.animation_data.use_nla=False
    for track in obj.data.shape_keys.animation_data.nla_tracks:track.mute=True
    for key in obj.data.shape_keys.key_blocks:key.value=0
scene.frame_set(0);bpy.context.view_layer.update()
for which in [rig,left_rig]:which.show_in_front=True
rig.location.x=.11;left_rig.location.x=-.11
cage.location.x=.11;left_cage.location.x=-.11
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'anatomical_hands.blend'),compress=True)
receipt={'name':'North Ridge / Anatomical Hands v2','units':'metres','wrist_origin':[0,0,0],'fingers_forward':'-Z','dorsum':'+Y','forearm':'+Z','blender':bpy.app.version_string,'reference_sha256':hashlib.sha256(Path('C:/Users/parst/AppData/Local/Temp/codex-clipboard-daeca6a5-398a-401c-9684-d240f9f58d22.png').read_bytes()).hexdigest(),'reference_use':'Topology and anatomical guidance; source pixels are not copied or redistributed.','source':'Original new quad cage, anatomical lofts and original baked skin fields. Existing project coordinate/armature helpers reused.','bones':list(hand.bones),'poses':list(POSES),'clips':[*POSES,'FlexCycle'],'volume_correctives':corrections,'meshes':report,'control_cage':{'vertices':len(hand.v),'faces':len(hand.f),'connected':True},'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'native_sha256':hashlib.sha256((OUT/'anatomical_hands.blend').read_bytes()).hexdigest(),'runtime_replacement':False}
(OUT/'manifest.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8',newline='\n')
if '--render' in sys.argv:
    from render_anatomical_hands_v2 import render_all
    render_all(OUT,right,left,nails_r,nails_l,rig,left_rig,POSES,choose_pose,cage)
print('ANATOMICAL_HANDS_EXPORTED',flush=True)
