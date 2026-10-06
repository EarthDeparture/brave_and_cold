"""Eight fictional visual game weapons, rigid animation rigs and reload extras.
Metres; Godot forward -Z. No functioning weapon/internal engineering is modelled.
"""
from pathlib import Path
import bpy,bmesh,math,json,hashlib,sys
from mathutils import Vector

# Reuse our original metre-scale mesh/PBR authoring functions, not existing meshes.
foundation=Path(__file__).with_name('gen_field_survival_kit.py').read_text(encoding='utf-8')
exec(foundation[:foundation.index("\nbpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)")])
OUT=ROOT/'tools/blender/generated/north_ridge_weapon_kit_v1';SRC=OUT/'source';TEX=OUT/'textures';ENGINE=OUT/'godot';SHOTS=OUT/'previews'
for p in (SRC,ENGINE,SHOTS):p.mkdir(parents=True,exist_ok=True)
M={};RECORD={};ASSETS=[];COMPONENTS={};CLIPS={};EVENTS={};MAG_SOURCES=[]
PALETTE={k:(k,(1,1,1),metal) for k,metal in [('beech',0),('walnut',0),('redwood',0),('blued',.55),('steel',.7),('brass',.5),('rubber',0)]}
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1;bpy.context.scene.render.fps=30

def node(name,p,parent=None):
    o=empty('Pivot_'+name,p,parent or current);o['component']=name;return o
def socket(name,p,parent=None):
    o=empty('Socket_'+name,p,parent or current);o['purpose']=name;return o
def bounds(root):
    bpy.context.view_layer.update()
    pts=[gv(o.matrix_world@v.co) for o in root.children_recursive if o.type=='MESH' for v in o.data.vertices]
    lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
    return lo,hi,[hi[i]-lo[i] for i in range(3)]
def mesh(name,vs,faces,key,parent=None,smooth=False):
    me=bpy.data.meshes.new(name);me.from_pydata([cv(p) for p in vs],[],faces);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
    for f in me.polygons:f.use_smooth=smooth and len(f.vertices)==4
    bind(o,key,parent);return o
def tube_z(name,stations,key,parent=None,n=32,cap=True):
    vs=[];faces=[]
    for distance,r,cy in stations:
        for k in range(n):
            a=k*TAU/n;vs.append((math.cos(a)*r,cy+math.sin(a)*r,-distance))
    for j in range(len(stations)-1):
        for k in range(n):faces.append((j*n+k,(j+1)*n+k,(j+1)*n+(k+1)%n,j*n+(k+1)%n))
    if cap:faces.extend([tuple(range(n)),tuple(reversed(range((len(stations)-1)*n,len(stations)*n)))])
    return mesh(name,vs,faces,key,parent,True)
def outline_yz(name,points,width,key,parent=None,edge=.002):
    # Side profile points (Z,Y), extruded across the narrow X axis.
    n=len(points);vs=[(xx,y,z) for xx in [-width/2,width/2] for z,y in points]
    faces=[tuple(range(n)),tuple(reversed(range(n,2*n)))]+[(k,k+n,(k+1)%n+n,(k+1)%n) for k in range(n)]
    o=mesh(name,vs,faces,key,parent);bevel(o,edge);return o
def wood_stock(style,key,butt,variant):
    # Cross-section loft makes a shaped cheek, tapered wrist and flared butt.
    stations=[(butt,.012,.064,.028),(butt-.025,.012,.064,.030),(.29,.012,.051,.026),(.21,.015,.037,.022),(.12,.008,.025,.017),(.018,.014,.029,.020)]
    if style=='pistol':stations=stations[:-1]+[(.076,.023,.027,.020),(.035,.030,.032,.020)]
    drop={1:.027,2:.012,3:.006,4:.019,5:.029,6:.010,8:.004}[variant]
    hh={1:.078,2:.062,3:.071,4:.069,5:.074,6:.066,8:.065}[variant]
    stations[0]=(butt,.012-drop,hh,.028);stations[1]=(butt-.025,.012-drop*.85,hh,.030)
    n=16;vs=[];faces=[]
    for z,cy,hh,ww in stations:
        for k in range(n):
            a=k*TAU/n;c,s=math.cos(a),math.sin(a)
            vs.append((ww*math.copysign(abs(c)**.72,c),cy+hh*math.copysign(abs(s)**.72,s),z))
    for j in range(len(stations)-1):
        for k in range(n):faces.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
    faces.extend([tuple(reversed(range(n))),tuple(range((len(stations)-1)*n,len(stations)*n))])
    o=mesh('SculptedStock',vs,faces,key,smooth=True)
    # Longitudinal grain is aligned along the stock, independently of smart UVs.
    for face in o.data.polygons:
        for li in face.loop_indices:
            p=gv(o.data.vertices[o.data.loops[li].vertex_index].co)
            o.data.uv_layers.active.data[li].uv=(p[1]*4+.5,p[2]*1.8)
    if style=='pistol':
        outline_yz('PistolGrip',[(.042,.017),(.085,.014),(.104,-.125),(.063,-.14),(.014,-.025)],.034,key,edge=.004)
    pad=box('RecoilPad',(0,.012-drop,butt+.006),(.058,hh*2,.012),'rubber',.003)
    for yy in [-.035,-.020,-.005,.010,.025,.040,.055]:box('ButtTexture',(0,yy,butt+.013),(.045,.002,.0018),'blued',.0003)
    torus('RearSlingSwivel',(0,-.052,butt-.068),.011,.002,'blued','X',n=20)
def wire(name,pts,key='blued',r=.003,parent=None):
    for i in range(len(pts)-1):cylinder(name,pts[i],pts[i+1],r,key,10,parent)
def guard():
    pts=[(0,-.012,.056),(0,-.043,.067),(0,-.065,.049),(0,-.071,.006),(0,-.05,-.024),(0,-.013,-.02)]
    wire('OpenTriggerGuard',pts,r=.0032)
    trigger=node('Trigger',(0,-.001,.024));wire('CurvedTrigger',[(0,-.005,.024),(0,-.027,.030),(0,-.045,.018)],'steel',.0023,trigger)
    return trigger
def receiver(length,number):
    # Separate shell panels leave a bottom magazine opening and side ejection recess.
    if number in (3,6,8):
        profile=[(.021,.100),(-.198,.100),(-.219,.073),(-.207,.012),(-.143,.003),(-.069,.008),(-.020,.029),(.021,.038)]
        o=outline_yz('SteppedReceiverSide',profile,.006,'blued',edge=.002);o.location.x=-.022
    else:box('ReceiverLeft',(-.022,.068,-.095),(.006,.068,length),'blued',.002)
    if number==2:
        # Rounded bolt-carbine cover, retaining a separate right-side action port.
        vs=[];faces=[];n=20
        for z,r in [(.012,.026),(-.205,.026),(.012,.024),(-.205,.024)]:
            for k in range(n+1):
                a=k*math.pi/n;vs.append((math.cos(a)*r,.078+math.sin(a)*r,z))
        q=n+1
        for k in range(n):faces.extend([(k,k+1,k+1+q,k+q),(2*q+k,3*q+k,3*q+k+1,2*q+k+1),(k,2*q+k,2*q+k+1,k+1),(q+k,q+k+1,3*q+k+1,3*q+k)])
        faces.extend([(0,q,3*q,2*q),(n,2*q+n,3*q+n,q+n)])
        mesh('RoundedActionCover',vs,faces,'blued',smooth=True)
    else:box('ReceiverTop',(0,.104,-.095),(.047,.005,length),'blued',.001)
    box('ReceiverRear',(0,.068,.012),(.046,.066,.006),'blued',.0015)
    box('TriggerHousing',(0,.014,.021),(.043,.040,.100),'blued',.003)
    box('ReceiverNose',(0,.068,-.205),(.047,.065,.013),'blued',.002)
    # Actual side cutout: wall pieces around the bolt, not a painted rectangle.
    for center,size in [((.022,.045,-.095),(.006,.022,length)),((.022,.093,-.095),(.006,.009,length)),((.022,.077,-.163),(.006,.038,.098)),((.022,.077,-.020),(.006,.038,.074))]:box('PortWall',center,size,'blued',.001)
    for side in [-1,1]:box('MagazineWellRim',(side*.018,.024,-.103),(.008,.023,.091),'blued',.001)
    box('RecessDarkBack',(0,.066,-.097),(.01,.035,.14),'rubber',.001)
    # A serial panel on the left stays clear of the moving ejection side.
    o=label('FieldMarking',(-.0257,.071,-.102),(.080,.020),'marking_'+str(number))
    # Rotate front-facing print to the left receiver side.
    o.rotation_euler.z=-math.pi/2;o.location=cv((-.0257,.071,-.102))-o.rotation_euler.to_matrix()@cv((-.0257,.071,-.102))
    for z in [.008,-.15]:
        cylinder('ReceiverPin',(-.026,.052,z),(.026,.052,z),.0035,'steel',16)
    if number==4:
        for z in [-.025,-.061,-.100,-.145]:
            cylinder('LeverActionScrew',(-.027,.081,z),(-.024,.081,z),.0045,'steel',16)
    if number in (6,7,8):
        for side in [-1,1]:
            for z in [-.175,-.045]:box('StampedReceiverRib',(side*.026,.047,z),(.002,.032,.006),'steel',.0006)
def vent_shroud(start,end,cy=.075,r=.031):
    # Mesh cells omit vents and include a matching inner surface and hole-edge walls.
    nx,na=14,12;vs=[];faces=[];cells=set()
    for i in range(nx):
        for j in range(na):
            if i%3==1 and j in [2,3,5,6,8,9]:continue
            cells.add((i,j))
    def p(i,j,inner=False):
        a=j/na*math.pi;rr=r-(.002 if inner else 0);return (math.cos(a)*rr,cy+math.sin(a)*rr,-(start+(end-start)*i/nx))
    for i,j in cells:
        corners=[(i,j),(i+1,j),(i+1,j+1),(i,j+1)];base=len(vs)
        vs.extend([p(a,b,False) for a,b in corners]+[p(a,b,True) for a,b in corners])
        faces.extend([(base,base+1,base+2,base+3),(base+7,base+6,base+5,base+4)])
        for e,neighbour in enumerate([(i,j-1),(i+1,j),(i,j+1),(i-1,j)]):
            if neighbour not in cells:faces.append((base+e,base+(e+1)%4,base+(e+1)%4+4,base+e+4))
    return mesh('PerforatedHeatShield',vs,faces,'blued')
def magazine(p,height=.115,lean=.012):
    mag=node('Magazine',p);x,y,z=p
    outline_yz('MagazineBody',[(z-.040,y),(z+.029,y),(z+.033+lean,y-height),(z-.030+lean,y-height-.006)],.034,'blued',mag,.003)
    for side in [-1,1]:
        for dz in [-.020,.006]:box('PressedMagRib',(side*.0178,y-height*.52,z+dz+lean*.5),(.002,.093,.004),'steel',.0007,mag)
    box('MagFloorplate',(0,y-height,z+lean),(.039,.010,.071),'blued',.0015,mag)
    box('VisibleFollower',(0,y+.001,z-.005),(.029,.002,.050),'rubber',.0004,mag)
    for side in [-1,1]:box('FeedLip',(side*.0165,y+.004,z-.006),(.0025,.008,.045),'steel',.0005,mag)
    socket('MagazineHand',(0,y-height*.55,z+lean*.5),mag);return mag
def casing(name,p,parent,key='brass',round_tip=False):
    x,y,z=p
    cylinder(name,(x,y,z),(x,y,z-.034),.0044,key,20,parent)
    torus(name+'Rim',(x,y,z),.0047,.0007,key,'Z',parent,n=16,minor=4)
    if round_tip:
        cylinder('VisualRoundTip',(x,y,z-.034),(x,y,z-.049),.0032,'steel',16,parent)
    return parent
def handtargets():
    return socket('HandR',(.041,-.024,.067)),socket('HandL',(-.038,.015,-.38))

def clip(name,duration,tracks,events=None):
    # Named NLA tracks merge matching object actions into one glTF clip.
    for obj,samples in tracks.items():
        obj.animation_data_create();obj.animation_data.action=None
        rest_loc=obj.location.copy();rest_rot=obj.rotation_euler.copy();rest_scale=obj.scale.copy()
        for t,offset,rotation,scale in samples:
            obj.location=rest_loc+cv(offset);obj.rotation_euler=tuple(rest_rot[i]+(rotation[0],-rotation[2],rotation[1])[i] for i in range(3));obj.scale=rest_scale*scale
            frame=round(t*30);obj.keyframe_insert('location',frame=frame);obj.keyframe_insert('rotation_euler',frame=frame);obj.keyframe_insert('scale',frame=frame)
        action=obj.animation_data.action;action.name=current.name+'__'+name+'__'+obj.name
        track=obj.animation_data.nla_tracks.new();track.name=name;track.mute=True
        strip=track.strips.new(name,0,action);strip.extrapolation='NOTHING';strip.blend_type='REPLACE'
        obj.animation_data.action=None;obj.location=rest_loc;obj.rotation_euler=rest_rot;obj.scale=rest_scale
    CLIPS[current.name][name]={'duration_s':round(duration*30)/30,'events':[dict(e,time_s=round(e['time_s']*30)/30) for e in (events or [])],'animated_nodes':[o.name for o in tracks]}
def sample(t,offset=(0,0,0),rot=(0,0,0),scale=1):return (t,offset,rot,scale)
def make_clips(parts,mode):
    root=current;mag=parts.get('mag');bolt=parts['bolt'];handle=parts['handle'];trigger=parts['trigger'];hr,hl=parts['hr'],parts['hl'];case=parts['case'];charge=parts['charge']
    CLIPS[root.name]={}
    clip('idle',1.2,{root:[sample(0),sample(.6,(0,.001,0)),sample(1.2)]})
    case.scale=Vector((1,1,1))
    fire_tracks={root:[sample(0),sample(.04,(0,.003,.015),(.016,0,0)),sample(.30)],trigger:[sample(0),sample(.04,rot=(.18,0,0)),sample(.18),sample(.30)]}
    fire_events=[{'time_s':0,'event':'muzzle_effect'},{'time_s':.04,'event':'shot_recoil'}]
    if mode=='semi':
        fire_tracks[bolt]=[sample(0),sample(.067,(0,0,.045)),sample(.18),sample(.30)]
        fire_tracks[charge]=[sample(0),sample(.067,(0,0,.045)),sample(.18),sample(.30)]
        fire_tracks[case]=[sample(0,scale=.0001),sample(.033,scale=.0001),sample(.067,scale=1),sample(.17,(.12,.035,.025),(.5,.5,.3)),sample(.267,(.24,-.015,.045),(1,.8,.6),.0001),sample(.30,scale=.0001)]
        fire_events.append({'time_s':.067,'event':'case_eject'})
    clip('fire',.30,fire_tracks,fire_events)
    case_track=[sample(0,scale=.0001),sample(.14,scale=.0001),sample(.16,scale=1),sample(.34,(.16,.06,.04),(.7,.6,.4)),sample(.55,(.30,.02,.08),(1.3,1,.7),.0001),sample(.9,scale=.0001)]
    if mode=='bolt':
        clip('cycle',.9,{handle:[sample(0),sample(.16,rot=(0,0,-1.05)),sample(.58,rot=(0,0,-1.05)),sample(.78),sample(.9)],bolt:[sample(0),sample(.16),sample(.36,(0,0,.079)),sample(.60,(0,0,.079)),sample(.78),sample(.9)],hr:[sample(0),sample(.16,(.015,.077,-.105)),sample(.4,(.015,.077,-.03)),sample(.65,(.015,.077,-.10)),sample(.9)],case:case_track},[{'time_s':.16,'event':'case_eject'},{'time_s':.78,'event':'action_closed'}])
    elif mode=='lever':
        lever=parts['lever']
        clip('cycle',.9,{lever:[sample(0),sample(.25,rot=(.75,0,0)),sample(.5,rot=(.75,0,0)),sample(.9)],bolt:[sample(0),sample(.30,(0,0,.073)),sample(.55,(0,0,.073)),sample(.9)],hr:[sample(0),sample(.28,(0,-.05,.018),(.32,0,0)),sample(.55,(0,-.05,.018),(.32,0,0)),sample(.9)],case:case_track},[{'time_s':.16,'event':'case_eject'},{'time_s':.9,'event':'action_closed'}])
    else:
        clip('cycle',.9,{bolt:[sample(0),sample(.25,(0,0,.068)),sample(.54,(0,0,.068)),sample(.78),sample(.9)],charge:[sample(0),sample(.25,(0,0,.065)),sample(.54,(0,0,.065)),sample(.78),sample(.9)],case:case_track},[{'time_s':.16,'event':'case_eject'},{'time_s':.78,'event':'action_closed'}])
    case.scale=Vector((.0001,.0001,.0001))
    if mag:
        release=parts['release']
        for name,dur in [('reload_tactical',2.4),('reload_empty',3.0)]:
            tracks={mag:[sample(0),sample(.35),sample(.68,(0,-.17,.055),(.18,0,0)),sample(1.0,(.19,-.28,.14),(.42,.16,0)),sample(1.25,(.19,-.28,.14),(.42,.16,0)),sample(1.60,(0,-.16,.028)),sample(1.83),sample(dur)],release:[sample(0),sample(.30,rot=(0,.28,0)),sample(.52),sample(dur)],hl:[sample(0),sample(.28,(.03,-.115,.28)),sample(.68,(.03,-.27,.34)),sample(1.05,(.20,-.35,.40)),sample(1.6,(.03,-.28,.31)),sample(1.83,(.03,-.11,.28)),sample(dur)]}
            events=[{'time_s':.68,'event':'magazine_removed'},{'time_s':1.20,'event':'magazine_exchange_out_of_view'},{'time_s':1.83,'event':'magazine_seated'},{'time_s':dur,'event':'reload_complete'}]
            if name=='reload_empty':
                tracks[bolt]=[sample(0),sample(1.85),sample(2.17,(0,0,.068)),sample(2.38,(0,0,.068)),sample(2.63),sample(dur)]
                tracks[charge]=[sample(0),sample(1.85),sample(2.17,(0,0,.065)),sample(2.38,(0,0,.065)),sample(2.63),sample(dur)]
                tracks[hr]=[sample(0),sample(1.90),sample(2.17,(.02,.085,-.12)),sample(2.38,(.02,.085,-.12)),sample(dur)]
                if mode=='bolt':tracks[handle]=[sample(0),sample(1.90),sample(2.12,rot=(0,0,-1.05)),sample(2.51,rot=(0,0,-1.05)),sample(2.78),sample(dur)]
                events.insert(-1,{'time_s':2.63,'event':'action_closed'})
            clip(name,dur,tracks,events)
    else:
        gate=parts['gate'];round_=parts['round'];round_.scale=Vector((1,1,1))
        clip('reload_start',.45,{root:[sample(0),sample(.45,rot=(0,0,.25))],hl:[sample(0),sample(.45,(.09,-.055,.24))]})
        clip('reload_insert',.9,{root:[sample(0,rot=(0,0,.25)),sample(.9,rot=(0,0,.25))],round_:[sample(0,scale=.0001),sample(.1,(.045,0,.025),scale=1),sample(.58),sample(.68,scale=.0001),sample(.9,scale=.0001)],gate:[sample(0),sample(.3,rot=(0,.55,0)),sample(.65,rot=(0,.55,0)),sample(.9)],hl:[sample(0,(.09,-.055,.24)),sample(.12,(.10,-.05,.25)),sample(.58,(.06,-.06,.25)),sample(.9,(.09,-.055,.24))]},[{'time_s':.68,'event':'round_inserted'}])
        round_.scale=Vector((.0001,.0001,.0001))
        clip('reload_end',.45,{root:[sample(0,rot=(0,0,.25)),sample(.45)],hl:[sample(0,(.09,-.055,.24)),sample(.45)]},[{'time_s':.45,'event':'reload_complete'}])
    clip('inspect',2.0,{root:[sample(0),sample(.45,(0,.015,0),(.02,.28,-.23)),sample(1.3,(0,.015,0),(.02,.28,-.23)),sample(2.0)]})
    clip('equip',.55,{root:[sample(0,(0,-.28,.06),(-.55,0,0)),sample(.55)]})
    clip('unequip',.55,{root:[sample(0),sample(.55,(0,-.28,.06),(-.55,0,0))]})
    if parts.get('fold'):
        clip('stock_fold',.6,{parts['fold']:[sample(0),sample(.6,rot=(0,-math.pi,0))]},[{'time_s':.6,'event':'stock_locked_folded'}])
        clip('stock_unfold',.6,{parts['fold']:[sample(0,rot=(0,-math.pi,0)),sample(.6)]},[{'time_s':.6,'event':'stock_locked_extended'}])
    bpy.context.scene.frame_set(0)

def export_asset(weapon=True):
    bpy.context.scene.frame_set(0);groups={}
    hidden=[o for o in current.children_recursive if o.type=='EMPTY' and max(o.scale)<.001]
    for o in hidden:o.scale=(1,1,1)
    bpy.context.view_layer.update()
    for o in list(current.children_recursive):
        if o.type=='MESH':groups.setdefault((o.parent,o.data.materials[0]),[]).append(o)
    for (parent,mat_),arr in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in arr:o.select_set(True)
        bpy.context.view_layer.objects.active=arr[0]
        if len(arr)>1:bpy.ops.object.join()
        bpy.context.object.name=parent.name+'__'+mat_.name
    for o in hidden:o.scale=(.0001,.0001,.0001)
    bpy.context.view_layer.update();lo,hi,size=bounds(current);meshes=[o for o in current.children_recursive if o.type=='MESH']
    tri=sum(len(f.vertices)-2 for o in meshes for f in o.data.polygons);assert tri<24000,(current.name,tri)
    bpy.ops.object.select_all(action='DESELECT');current.select_set(True)
    for o in current.children_recursive:o.select_set(True)
    path=ENGINE/(current.name+'.glb')
    rest={o:o.matrix_basis.copy() for o in [current]+list(current.children_recursive)}
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_extras=True,export_materials='EXPORT',export_cameras=False,export_lights=False,export_animations=weapon,export_animation_mode='NLA_TRACKS',export_merge_animation='NLA_TRACK',export_force_sampling=True)
    # Export samples object NLA actions. Restore the native authoring rest pose explicitly.
    for o,matrix in rest.items():
        if o.animation_data:
            for track in o.animation_data.nla_tracks:track.mute=True
        o.matrix_basis=matrix
    bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
    for o in meshes:
        for m in o.data.materials:
            for n in m.node_tree.nodes:
                if n.type=='TEX_IMAGE':n.image.pack()
    coll=bpy.data.collections.new(current.name+'_Editable');bpy.context.scene.collection.children.link(coll)
    for o in [current]+list(current.children_recursive):
        for c in list(o.users_collection):c.objects.unlink(o)
        coll.objects.link(o)
    native=SRC/(current.name+'.blend');bpy.data.libraries.write(str(native),{coll},fake_user=True,compress=True)
    RECORD[current.name]={'kind':'weapon' if weapon else 'reload_extra','description':current['description'],'dimensions_m':size,'bounds_min':lo,'bounds_max':hi,'triangles':tri,'mesh_nodes':len(meshes),'materials':len({m.name for o in meshes for m in o.data.materials}),'glb':'godot/'+path.name,'native':'source/'+native.name,'glb_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'nodes':[o.name for o in current.children_recursive if o.type=='EMPTY'],'animations':CLIPS.get(current.name,{})}
    print('WEAPON_ASSET',current.name,tri,len(CLIPS.get(current.name,{})),flush=True)

SPECS=[
 ('ridge_scout_rifle','Straight-stock semi-automatic field rifle',.40,.68,'classic','beech','semi',False,False,.10),
 ('timber_bolt_carbine','Short timber-stock bolt carbine',.36,.59,'classic','redwood','bolt',False,False,.085),
 ('ranger_box_rifle','Deep receiver box rifle',.38,.63,'classic','walnut','semi',False,False,.13),
 ('brush_lever_rifle','Lever-action brush rifle with tubular fore-end',.36,.60,'classic','redwood','lever',True,False,0),
 ('frontier_vented_rifle','Traditional stock with vented upper handguard',.39,.65,'classic','beech','semi',True,False,.10),
 ('north_service_rifle','Wood pistol-grip service rifle',.39,.66,'pistol','beech','semi',False,False,.12),
 ('compact_patrol_rifle','Wire folding-stock patrol rifle',.30,.57,'folding','redwood','semi',True,True,.15),
 ('expedition_rifle','Full-size wooden pistol-grip expedition rifle',.40,.70,'pistol','walnut','semi',False,False,.15),
]
for i,(name,description,butt,muzzle,style,wood,mode,vented,folding,magheight) in enumerate(SPECS,1):
    start(name,description,[.09,.23,butt+muzzle]);current['forward_axis']='-Z';current['origin']='trigger-hand reference';current['reload_style']='individual_round' if mode=='lever' else 'detachable_magazine'
    if folding:
        fold=node('FoldingStock',(.034,.04,.03))
        for side in [-1,1]:wire('WireStock',[(side*.022,.04,.02),(side*.027,-.05,butt),(side*.027,.063,butt),(side*.022,.04,.02)],r=.006,parent=fold)
        box('StockShoulderPad',(0,.01,butt),(.058,.12,.014),'rubber',.003,fold)
        outline_yz('WoodPistolGrip',[(.046,.018),(.089,.012),(.092,-.14),(.05,-.15),(.014,-.034)],.033,wood,edge=.004)
    else:wood_stock(style,wood,butt,i)
    receiver(.23 if i!=3 else .265,i);trigger=guard()
    # Fore-end is separate from the stock; long barrel and handguard silhouettes vary.
    fore_end=.48 if muzzle>.64 else .43
    box('LowerHandguard',(0,.039,-.35),(.052,.048,fore_end-.23),wood,.010)
    if i==8:
        for k in range(4):box('SlottedWoodUpper',(0,.092,-.25-k*.060),(.050,.034,.044),wood,.006)
        cylinder('UpperGasTube',(0,.097,-.22),(0,.097,-.52),.006,'blued',24)
    elif not vented:box('UpperHandguard',(0,.092,-.35),(.050,.034,fore_end-.23),wood,.009)
    else:vent_shroud(.235,fore_end)
    tube_z('Barrel',[(.205,.011,.075),(muzzle-.055,.010,.075),(muzzle-.032,.013,.075),(muzzle,.013,.075),(muzzle,.004,.075),(muzzle-.025,.004,.075)],'blued',n=40,cap=False)
    for d in [.225,fore_end+.009]:tube_z('BarrelBand',[(d,.025,.075),(d+.013,.025,.075)],'blued',n=28)
    if i in [1,5,6,7,8]:
        # Stylised slotted muzzle cage: visible gap, not a closed cylinder cap.
        for side in [-1,1]:box('MuzzleCageRail',(side*.014,.075,-muzzle+.025),(.006,.020,.041),'blued',.002)
    tube_z('FrontSightCollar',[(muzzle-.095,.015,.075),(muzzle-.083,.015,.075)],'blued',n=24)
    box('FrontSightPost',(0,.109,-muzzle+.09),(.003,.036,.012),'steel',.001)
    for side in [-1,1]:box('SightProtection',(side*.010,.117,-muzzle+.09),(.003,.052,.017),'blued',.001)
    box('RearSightBase',(0,.112,-.026),(.027,.016,.027),'blued',.002)
    for side in [-1,1]:box('RearNotch',(side*.009,.127,-.026),(.009,.013,.012),'steel',.001)
    torus('ForwardSlingSwivel',(0,.045,-fore_end),.010,.0016,'blued','X',n=20)
    bolt=node('Bolt',(0,.079,-.068));box('SlidingBolt',(0,.079,-.068),(.032,.025,.128),'steel',.004,bolt)
    handle=node('BoltHandle',(.026,.081,-.022),bolt)
    if mode=='bolt':
        wire('BoltHandleArm',[(.024,.081,-.022),(.047,.068,-.013),(.054,.051,-.008)],'blued',.004,handle)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=.010,location=cv((.054,.051,-.008)));o=bpy.context.object;o.name='BoltKnob';bind(o,'blued',handle)
    charge=node('ChargingHandle',(.027,.085,-.053))
    if mode=='semi':box('ChargingTab',(.036,.085,-.053),(.027,.010,.017),'blued',.002,charge)
    release=node('MagazineRelease',(.027,.019,-.095));box('ReleasePaddle',(.027,.014,-.095),(.006,.018,.020),'steel',.001,release)
    safety=node('Safety',(.026,.094,.015));box('SafetyLever',(.026,.096,.017),(.005,.009,.023),'blued',.001,safety)
    mag=magazine((0,.026,-.103),magheight,.009 if i<6 else .019) if mode!='lever' else None
    hr,hl=handtargets()
    socket('Muzzle',(0,.075,-muzzle));socket('Aim',(0,.127,.052));socket('Ejection',(.029,.079,-.065));socket('MagazineInsert',(0,.026,-.103));socket('TriggerFinger',(.021,-.026,.023));socket('BoltHand',(.054,.051,-.008),handle)
    case=node('SpentCase',(.037,.079,-.056));casing('VisualCase',(.037,.079,-.056),case);case.scale=Vector((.0001,.0001,.0001))
    parts={'bolt':bolt,'handle':handle,'charge':charge,'trigger':trigger,'release':release,'mag':mag,'hr':hr,'hl':hl,'case':case}
    if folding:parts['fold']=fold
    if mode=='lever':
        tube_z('VisualTube',[(.18,.009,.037),(muzzle-.08,.009,.037)],'blued',n=24)
        lever=node('Lever',(0,-.008,.006));wire('LeverLoop',[(0,-.012,.04),(0,-.036,.11),(0,-.102,.105),(0,-.122,.03),(0,-.060,-.033),(0,-.015,-.018)],r=.004,parent=lever)
        gate=node('LoadingGate',(.026,.052,-.086));box('GatePlate',(.026,.052,-.086),(.003,.018,.045),'steel',.001,gate)
        round_=node('InsertRound',(.041,.044,-.072));casing('InsertionRound',(.041,.044,-.072),round_,round_tip=True);round_.scale=Vector((.0001,.0001,.0001));socket('LoadingGate',(.028,.046,-.082));parts.update({'lever':lever,'gate':gate,'round':round_})
    make_clips(parts,mode);export_asset()
    if mag:MAG_SOURCES.append((name,mag))

# Detached magazines are native props, not glued geometry in the weapon model.
for weapon_name,oldmag in MAG_SOURCES:
    name=weapon_name+'_spare_magazine';start(name,'Matching detachable visual magazine / '+weapon_name,[.04,.14,.085])
    bpy.context.view_layer.update();inverse=oldmag.matrix_world.inverted()
    for old in oldmag.children_recursive:
        if old.type!='MESH':continue
        o=old.copy();o.data=old.data.copy();bpy.context.collection.objects.link(o);o.parent=current;o.matrix_world=inverse@old.matrix_world
    socket('Insertion',(0,0,0));socket('Hand',(0,-.07,0));export_asset(False)
for name,tip in [('visual_rifle_round',True),('visual_spent_case',False)]:
    start(name,'Fictional visual animation prop; not a real ammunition specification',[.010,.010,.05])
    casing('AnimationAmmo',(0,0,0),current,round_tip=tip);socket('Pickup',(0,0,-.02));export_asset(False)
start('round_loading_strip','Fictional visual round carrier for handling/loot animations',[.058,.012,.052])
box('CarrierStrip',(0,0,0),(.057,.006,.009),'steel',.001)
for x in [-.023,-.0115,0,.0115,.023]:casing('VisualRound',(x,0,0),current,round_tip=True)
socket('Hand',(0,0,0));export_asset(False)

# Native library uses a spaced actual-scale grid. Exported weapon roots remain identity.
display_parents=[]
for i,asset in enumerate(ASSETS):
    display=empty('Display_'+asset.name,((i%4)*.60,0,(i//4)*1.55));asset.parent=display;asset.location=(0,0,0);display_parents.append(display)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'north_ridge_weapon_library.blend'),compress=True)
for asset in ASSETS:
    asset.parent=None;asset.location=(0,0,0);bpy.data.collections[asset.name+'_Editable'].hide_render=True
meta={'name':'North Ridge / Original Weapon Art Kit','version':'1.0.0','units':'metres','forward_axis':'-Z','origin':'Weapon trigger-hand reference; extras insertion/pickup reference','provenance':'Fictional game-art geometry and original printwork; user sheet is visual guidance only. No live weapon internals or real ammunition engineering.','generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'assets':RECORD}
(OUT/'manifest.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8',newline='\n')
print('WEAPON_KIT_EXPORT_DONE',len(RECORD),flush=True)
if '--render' in sys.argv:
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True;scene.render.resolution_x=900;scene.render.resolution_y=450;scene.render.resolution_percentage=100;scene.world.color=(.055,.055,.055);scene.view_settings.view_transform='AgX'
    for loc,energy,size in [((3,-4,5),520,4),((-3,-2,2),260,3),((1,3,4),400,3)]:
        bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=energy;o.data.size=size;o.rotation_euler=(Vector((0,0,0))-o.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO'
    for asset in ASSETS:
        bpy.data.collections[asset.name+'_Editable'].hide_render=False
        scene.frame_set(0);lo,hi,size=bounds(asset);center=cv(((lo[0]+hi[0])/2,(lo[1]+hi[1])/2,(lo[2]+hi[2])/2));length=max(size)
        cam.data.ortho_scale=length*1.12;cam.location=center+Vector((2.9,-.5,1.0))*length;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(SHOTS/(asset.name+'.png'));bpy.ops.render.render(write_still=True)
        bpy.data.collections[asset.name+'_Editable'].hide_render=True
    print('WEAPON_KIT_RENDER_DONE',flush=True)
