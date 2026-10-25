"""Original editable survival equipment. Blender 5.2; metre scale, Godot Y up.
Reference is visual guidance only. All geometry/printwork is authored locally.
Outputs are a standalone asset package, not replacements for live game items.
"""
from pathlib import Path
import bpy, math, json, hashlib, sys
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'tools/blender/generated/field_survival_kit_v1'
SRC=OUT/'source'; TEX=OUT/'textures'; ENGINE=OUT/'godot'; SHOTS=OUT/'previews'
for p in (SRC,ENGINE,SHOTS):p.mkdir(parents=True,exist_ok=True)
TAU=math.tau
M={}; RECORD={}; ASSETS=[]; current=None

def cv(p):return Vector((p[0],-p[2],p[1]))
def gv(p):return [p.x,p.z,-p.y]
def image(path,noncolor=False):
    im=bpy.data.images.load(str(path),check_existing=True)
    if noncolor:im.colorspace_settings.name='Non-Color'
    return im
PALETTE={
 'steel':('steel',(1,1,1),.7), 'dark_steel':('steel',(.30,.34,.32),.7),
 'red':('enamel',(.64,.12,.075),.15), 'ochre':('enamel',(.8,.53,.08),.1),
 'green':('enamel',(.13,.24,.19),.15), 'blue':('enamel',(.23,.48,.65),0),
 'canvas':('canvas',(1,1,1),0), 'leather':('leather',(1,1,1),0),
 'wood':('wood',(1,1,1),0), 'rubber':('rubber',(1,1,1),0),
 'cotton':('cotton',(1,1,1),0), 'white':('enamel',(1,1,1),0),
 'gold':('steel',(.85,.62,.12),.7), 'rust':('enamel',(.41,.19,.09),.15),
 'glass':('steel',(.28,.34,.30),.2), 'stone':('stone',(1,1,1),0)}
def material(key):
    if key in M:return M[key]
    m=bpy.data.materials.new('FieldKit_'+key);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    if key.startswith('print:'):
        n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=image(TEX/(key[6:]+'.png'))
        m.node_tree.links.new(n.outputs['Color'],bs.inputs['Base Color'])
        bs.inputs['Roughness'].default_value=.8
        m.diffuse_color=(.7,.65,.5,1)
    else:
        family,color,metal=PALETTE[key];m.diffuse_color=(*color,1)
        bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Metallic'].default_value=metal
        for channel,socket in [('base','Base Color'),('rough','Roughness')]:
            n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=image(TEX/((key if channel=='base' else family)+'_'+channel+'.png'),channel!='base')
            if channel=='base':
                m.node_tree.links.new(n.outputs['Color'],bs.inputs[socket])
            else:m.node_tree.links.new(n.outputs['Color'],bs.inputs[socket])
        bs.inputs['Base Color'].default_value=(1,1,1,1)
        n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=image(TEX/(family+'_normal.png'),True)
        nm=m.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.4
        m.node_tree.links.new(n.outputs['Color'],nm.inputs['Color']);m.node_tree.links.new(nm.outputs[0],bs.inputs['Normal'])
    M[key]=m;return m

def empty(name,p=(0,0,0),parent=None):
    if current and name.startswith(('Pivot_','Socket_')):name=current.name+'__'+name
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=cv(p)
    if parent:
        bpy.context.view_layer.update();matrix=o.matrix_world.copy();o.parent=parent;o.matrix_world=matrix
    return o
def bind(o,key,parent=None,uv=True):
    o.data.materials.append(material(key))
    if not o.data.uv_layers and uv:
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.1,island_margin=.025);bpy.ops.object.mode_set(mode='OBJECT')
    if uv and not key.startswith('print:'):
        scale=max(o.dimensions)/.3
        for loop in o.data.uv_layers.active.data:loop.uv*=max(.5,scale)
    parent=parent or current
    if parent:
        bpy.context.view_layer.update();matrix=o.matrix_world.copy();o.parent=parent;o.matrix_world=matrix
    return o
def bevel(o,width=.004,segments=2):
    if width:
        mod=o.modifiers.new('Manufactured edge radius','BEVEL');mod.width=width;mod.segments=segments
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=o.modifiers.new('Face-weighted normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
    return o
def box(name,p,size,key,rounding=.003,parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=cv(p));o=bpy.context.object;o.name=name;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bevel(o,min(rounding,min(size)*.3));return bind(o,key,parent)
def cylinder(name,a,b,r,key,n=24,parent=None):
    aa,bb=cv(a),cv(b);d=bb-aa
    bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=d.length,location=(aa+bb)*.5)
    o=bpy.context.object;o.name=name;o.rotation_mode='QUATERNION';o.rotation_quaternion=d.to_track_quat('Z','Y')
    for f in o.data.polygons:f.use_smooth=len(f.vertices)==4
    return bind(o,key,parent)
def torus(name,p,r,t,key,axis='Y',parent=None,n=32,minor=8):
    bpy.ops.mesh.primitive_torus_add(major_segments=n,minor_segments=minor,location=cv(p),major_radius=r,minor_radius=t)
    o=bpy.context.object;o.name=name
    if axis=='Z':o.rotation_euler.x=math.pi/2
    if axis=='X':o.rotation_euler.y=math.pi/2
    for f in o.data.polygons:f.use_smooth=True
    return bind(o,key,parent)
def lathe(name,profile,key,n=32,p=(0,0,0),parent=None,cap=True):
    vs=[];fs=[]
    for y,r in profile:
        for k in range(n):vs.append(cv((p[0]+math.cos(k*TAU/n)*r,p[1]+y,p[2]+math.sin(k*TAU/n)*r)))
    for j in range(len(profile)-1):
        for k in range(n):fs.append((j*n+k,(j+1)*n+k,(j+1)*n+(k+1)%n,j*n+(k+1)%n))
    if cap:fs.extend([tuple(range(n)),tuple(reversed([(len(profile)-1)*n+k for k in range(n)]))])
    me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
    for f in me.polygons:f.use_smooth=len(f.vertices)==4
    uv=me.uv_layers.new()
    for face in me.polygons:
        for li in face.loop_indices:
            vi=me.loops[li].vertex_index;j,k=divmod(vi,n)
            seam=1 if k==0 and face.index%n==n-1 and len(face.vertices)==4 else 0
            uv.data[li].uv=(k/n+seam,profile[j][0]/max(.1,profile[-1][0]))
    return bind(o,key,parent)
def extrusion(name,points,z,depth,key,parent=None,rounding=.002):
    n=len(points);verts=[cv((x,y,zz)) for zz in [z-depth/2,z+depth/2] for x,y in points]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces+=[(k,(k+1)%n,(k+1)%n+n,k+n) for k in range(n)]
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);bevel(o,rounding)
    return bind(o,key,parent)
def strap_loop(name,p,w,h,t,key='leather',parent=None):
    x,y,z=p
    for xx in [-1,1]:box(name+'Side',(x+xx*(w-t)/2,y,z),(t,h,t),key,.002,parent)
    for yy in [-1,1]:box(name+'End',(x,y+yy*(h-t)/2,z),(w-t*2,t,t),key,.002,parent)
def label(name,p,size,printname,parent=None,horizontal=False):
    x,y,z=p;w,h=size
    if horizontal:pts=[(x-w/2,y,z-h/2),(x-w/2,y,z+h/2),(x+w/2,y,z+h/2),(x+w/2,y,z-h/2)]
    else:pts=[(x-w/2,y-h/2,z),(x+w/2,y-h/2,z),(x+w/2,y+h/2,z),(x-w/2,y+h/2,z)]
    me=bpy.data.meshes.new(name);me.from_pydata([cv(v) for v in pts],[],[(0,1,2,3)]);me.update();uv=me.uv_layers.new()
    for loop,coord in zip(uv.data,[(0,0),(1,0),(1,1),(0,1)]):loop.uv=coord
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);return bind(o,'print:'+printname,parent,False)
def curved_label(name,y,r,w,h,printname):
    vs=[];fs=[];n=20;angle=w/r
    for yy in [y-h/2,y+h/2]:
        for k in range(n+1):
            a=(k/n-.5)*angle;vs.append(cv((math.sin(a)*r,yy,math.cos(a)*r)))
    for k in range(n):fs.append((k,k+1,k+1+n+1,k+n+1))
    me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update();uv=me.uv_layers.new()
    for f in me.polygons:
        for li in f.loop_indices:
            vi=me.loops[li].vertex_index;j,k=divmod(vi,n+1);uv.data[li].uv=(k/n,j)
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);return bind(o,'print:'+printname,uv=False)
def fabric_pack():
    profile=[(.025,.145,.072),(.055,.173,.094),(.17,.18,.102),(.38,.174,.094),(.50,.15,.075),(.55,.118,.056)]
    n=32;vs=[];fs=[]
    for yy,ww,dd in profile:
        for k in range(n):
            a=k*TAU/n;cx=math.cos(a);sz=math.sin(a)
            vs.append(cv((ww*math.copysign(abs(cx)**.55,cx),yy,dd*math.copysign(abs(sz)**.55,sz))))
    for j in range(len(profile)-1):
        for k in range(n):fs.append((j*n+k,(j+1)*n+k,(j+1)*n+(k+1)%n,j*n+(k+1)%n))
    fs.extend([tuple(range(n)),tuple(reversed(range((len(profile)-1)*n,len(profile)*n)))])
    me=bpy.data.meshes.new('TailoredPack');me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new('TailoredPack',me);bpy.context.collection.objects.link(o)
    for f in me.polygons:f.use_smooth=len(f.vertices)==4
    bind(o,'canvas')
    for j in [1,4]:
        pts=[gv(Vector(v)) for v in vs[j*n:(j+1)*n]]
        for k in range(n):cylinder('BoundCanvasSeam',pts[k],pts[(k+1)%n],.0018,'canvas',6)
def marker(name,p):
    o=empty('Socket_'+name,p,current);o['purpose']=name;return o
def start(name,description,nominal):
    global current
    current=empty(name);current['asset_id']=name;current['units']='metres';current['front_axis']='+Z';current['description']=description;current['nominal_size_m']=nominal
    ASSETS.append(current);return current
def bounds(root):
    bpy.context.view_layer.update();pts=[o.matrix_world@v.co for o in root.children_recursive if o.type=='MESH' for v in o.data.vertices]
    lo=Vector([min(v[i] for v in pts) for i in range(3)]);hi=Vector([max(v[i] for v in pts) for i in range(3)])
    return gv(lo),gv(hi),[hi.x-lo.x,hi.z-lo.z,hi.y-lo.y]
def finish_asset():
    # Group static surfaces by material within each animated component.
    objects=list(current.children_recursive)
    groups={}
    for o in objects:
        if o.type=='MESH':groups.setdefault((o.parent,o.data.materials[0]),[]).append(o)
    for (parent,m),arr in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in arr:o.select_set(True)
        bpy.context.view_layer.objects.active=arr[0]
        if len(arr)>1:bpy.ops.object.join()
        bpy.context.object.name=parent.name+'__'+m.name
    bpy.context.view_layer.update();lo,hi,size=bounds(current)
    count=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in current.children_recursive if o.type=='MESH')
    assert count<=24000,(current.name,count)
    # Export all descendants, keeping identity of pivots/attachment empties.
    bpy.ops.object.select_all(action='DESELECT');current.select_set(True)
    for o in current.children_recursive:o.select_set(True)
    bpy.context.view_layer.objects.active=current
    path=ENGINE/(current.name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_extras=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
    meshes=[o for o in current.children_recursive if o.type=='MESH']
    used_images=set()
    for o in meshes:
        for m in o.data.materials:
            for node in m.node_tree.nodes:
                if node.type=='TEX_IMAGE':used_images.add(node.image)
    for im in used_images:im.pack()
    # Native source contains only this hierarchy, with packed original images.
    coll=bpy.data.collections.new(current.name+'_Editable');bpy.context.scene.collection.children.link(coll)
    for o in [current]+list(current.children_recursive):
        for c in list(o.users_collection):c.objects.unlink(o)
        coll.objects.link(o)
    # Scene partial-write crashes this Blender build; write a collection library
    # and turn it into an opening-ready scene in the separate source finalizer.
    native=SRC/(current.name+'.blend');bpy.data.libraries.write(str(native),{coll},fake_user=True,compress=True)
    RECORD[current.name]={'description':current['description'],'nominal_size_m':list(current['nominal_size_m']),'measured_size_m':size,'triangles':count,'mesh_nodes':len(meshes),'materials':len({m.name for o in meshes for m in o.data.materials}),'pivots':[o.name for o in current.children_recursive if o.type=='EMPTY'],'glb':'godot/'+path.name,'glb_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'native':'source/'+native.name,'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest()}
    print('FIELD_ASSET',current.name,count,size,flush=True)

bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1

# 1. Upright cylinder, open protective collar, valve, seam and standing ring.
start('propane_cylinder','Weathered refillable field propane cylinder',[.32,.50,.32])
lathe('PressedTank',[(.04,.095),(.05,.13),(.09,.16),(.35,.16),(.4,.14),(.43,.085)],'rust',48)
torus('WeldSeam',(0,.235,0),.159,.003,'dark_steel')
lathe('FootRing',[(0,.106),(.025,.106),(.032,.09),(.022,.086),(0,.086)],'dark_steel',40,cap=False)
# Continuous rolled guard, with an open front gap rather than picket-like bars.
vs=[];fs=[];n=40
for yy,rr in [(.432,.09),(.5,.09),(.5,.085),(.432,.085)]:
    for k in range(n+1):
        a=math.pi*.8+k/n*math.pi*1.4;vs.append(cv((math.cos(a)*rr,yy,math.sin(a)*rr)))
for j in range(4):
    for k in range(n):fs.append((j*(n+1)+k,j*(n+1)+k+1,((j+1)%4)*(n+1)+k+1,((j+1)%4)*(n+1)+k))
for k in [0,n]:fs.append(tuple(j*(n+1)+k for j in range(4)))
me=bpy.data.meshes.new('GuardCollar');me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new('GuardCollar',me);bpy.context.collection.objects.link(o);bevel(o,.0015);bind(o,'dark_steel')
cylinder('Valve',(0,.428,0),(0,.49,0),.014,'gold');torus('ValveWheel',(0,.49,0),.024,.003,'dark_steel')
curved_label('SafetyPlate',.30,.1605,.13,.075,'propane_label');marker('carry',(0,.465,0));finish_asset()

# 2. Rounded, fitted canvas pack; pockets, back padding, carrying straps and bedroll.
start('canvas_backpack','Canvas rucksack with external bedroll and usable buckles',[.56,.70,.28])
fabric_pack()
box('FrontPocket',(0,.16,.128),(.29,.22,.09),'canvas',.027)
box('TopFlap',(0,.49,.085),(.37,.13,.13),'canvas',.033)
for side in [-1,1]:
    box('SidePouch',(side*.218,.22,0),(.105,.26,.16),'canvas',.025)
    box('BackPad',(side*.093,.29,-.103),(.12,.42,.027),'rubber',.012)
    strap_loop('ShoulderHarness',(side*.104,.31,-.13),.075,.43,.017,'canvas')
    box('FrontStrap',(side*.112,.365,.162),(.025,.36,.009),'leather',.001)
    strap_loop('Buckle',(side*.112,.31,.172),.037,.05,.005,'steel')
    box('BucklePin',(side*.112,.31,.178),(.003,.045,.003),'steel',.0005)
box('PocketStrap',(0,.15,.179),(.025,.16,.009),'leather',.001);strap_loop('PocketBuckle',(0,.125,.187),.037,.047,.004,'steel')
for side in [-1,1]:
    for k in range(18):box('PocketStitch',(side*.136,.07+k*.010,.176),(.0018,.004,.001),'cotton',0)
cylinder('Bedroll',(-.278,.61,0),(.278,.61,0),.085,'canvas',40)
for side in [-1,1]:
    torus('BedrollBinding',(side*.14,.61,0),.087,.009,'leather','X')
    for rr in [.025,.048,.067]:torus('RolledEnd',(side*.28,.61,0),rr,.003,'canvas','X')
strap_loop('TopCarryLoop',(0,.56,-.077),.11,.055,.012,'leather')
marker('back_attachment',(0,.30,-.135));marker('carry',(0,.58,-.077));finish_asset()

# 3/4. Jaw variants share dimensions and named hinge pivots, spring and trigger.
def trap(name,closed):
    start(name,'Mechanical trapping prop; jaws and trigger retain separate pivots',[.40,.16 if closed else .06,.30])
    torus('BaseHoop',(0,.012,0),.145,.009,'dark_steel',n=40)
    box('CrossBar',(0,.012,0),(.31,.014,.027),'dark_steel',.002)
    cylinder('PressurePlate',(0,.021,0),(0,.029,0),.058,'steel',32)
    for side in [-1,1]:
        hinge=empty('Pivot_Jaw_'+('L' if side<0 else 'R'),(0,.028,0),current)
        for k in range(19):
            a=k*math.pi/18;xx=math.cos(a)*.14;zz=side*math.sin(a)*.115
            if k<18:
                b=(k+1)*math.pi/18;cylinder('JawArc',(xx,.032,zz),(math.cos(b)*.14,.032,side*math.sin(b)*.115),.008,'steel',8,hinge)
            if k in range(2,18,2):
                extrusion('Tooth',[(xx-.009,.038),(xx+.009,.038),(xx,.063)],zz,.009,'steel',hinge,.0006)
        if closed:
            hinge.rotation_euler.x=-side*math.radians(78)
    cylinder('PivotPin',(-.15,.028,0),(.15,.028,0),.007,'dark_steel')
    box('SpringBase',(.19,.017,0),(.09,.018,.09),'dark_steel',.003)
    for k in range(10):torus('SpringCoil',(.16+k*.004,.031,0),.025,.0025,'steel','X',n=16)
    box('SpringLever',(.18,.046,0),(.085,.008,.026),'steel',.002)
    for k in range(5):torus('AnchorChain',(.24+k*.017,.012,0),.009,.002,'dark_steel','Y' if k%2 else 'X',n=12)
    marker('trigger',(0,.03,0));finish_asset()
trap('jaw_trap_open',False);trap('jaw_trap_closed',True)

# 5-8. Continuous thick-walled cooking vessels, open interiors, metal and wood handles.
def pot(name,r,height):
    start(name,'Open thick-walled camp cooking pot',[r*2+.05,height,r*2])
    lathe('PotShell',[(0,r*.8),(.008,r*.98),(height-.008,r),(height,r), (height,r-.004),(.014,r-.004),(.014,r*.77)],'steel',48)
    torus('RolledRim',(0,height,0),r-.001,.003,'steel',n=48)
    for side in [-1,1]:strap_loop('SideHandle',(side*(r+.025),height*.65,0),.048,.043,.007,'dark_steel')
    marker('contents',(0,.02,0));finish_asset()
pot('camp_pot_large',.14,.175);pot('camp_pot_small',.086,.067)
def pan(name,r,length):
    start(name,'Cast skillet with wooden grip and continuous hollow bowl',[r*2,.048,length+r*2])
    lathe('Skillet',[(0,r*.74),(.007,r*.85),(.044,r),(.048,r),(.048,r-.004),(.014,r*.81)],'dark_steel',48)
    cylinder('HandleTang',(0,.029,-r*.87),(0,.029,-r-.04),.012,'steel')
    box('WoodenGrip',(0,.029,-r-length/2),(.031,.027,length),'wood',.008)
    cylinder('RivetA',(0,.043,-r-.04),(0,.045,-r-.04),.003,'steel',12)
    marker('grip',(0,.029,-r-length*.58));finish_asset()
pan('skillet_large',.135,.17);pan('skillet_small',.086,.13)

# 9/10. Opaque field bottles rather than unsupported transparent plastic shaders.
def bottle(name,r,h,striped):
    start(name,'Reusable screw-top water bottle; separate cap pivot',[r*2,h,r*2])
    lathe('Bottle',[(0,r*.72),(.012,r), (h-.057,r),(h-.04,r*.8),(h-.03,r*.50)],'blue',40)
    cap=empty('Pivot_Cap',(0,h-.03,0),current)
    cylinder('ScrewTop',(0,h-.028,0),(0,h,0),r*.56,'rubber',32,cap)
    for k in range(16):
        a=k*TAU/16;cylinder('GripRidge',(math.cos(a)*r*.56,h-.025,math.sin(a)*r*.56),(math.cos(a)*r*.56,h-.004,math.sin(a)*r*.56),.001,'rubber',6,cap)
    if striped:
        for yy,key in [(h*.55,'white'),(h*.60,'ochre'),(h*.65,'white')]:lathe('ColourBand',[(yy,r+.0006),(yy+.006,r+.0006)],key,40,cap=False)
    marker('mouth',(0,h-.028,0));marker('grip',(0,h*.42,0));finish_asset()
bottle('water_bottle_tall',.034,.26,False);bottle('water_bottle_short',.037,.205,True)

# 11. Extruded fuel can includes a genuine open carry handle, neck and ribs.
start('fuel_jerrycan','Ribbed 10 litre fuel can with open carrying handle',[.26,.46,.15])
box('PressedCan',(0,.182,0),(.255,.355,.145),'red',.018)
extrusion('SlopedShoulder',[(-.125,.33),(.125,.33),(.105,.402),(.023,.42),(-.1,.386)],0,.139,'red',rounding=.007)
strap_loop('OpenHandle',(.045,.412,0),.145,.082,.016,'red')
for yy in [.031,.14,.27,.335]:box('ReinforcingRib',(0,yy,.074),(.216,.009,.005),'red',.002)
cap=empty('Pivot_FuelCap',(-.09,.389,0),current);cylinder('FuelNeck',(-.09,.385,0),(-.09,.412,0),.025,'dark_steel',32,cap);torus('FuelCapEdge',(-.09,.414,0),.025,.003,'dark_steel',n=32)
label('FuelInstructions',(0,.225,.075),(.16,.074),'fuel_label');marker('carry',(.045,.428,0));finish_asset()

# 12. First-aid case, open handle, separate hinged lid; original white field cross.
start('first_aid_case','Hard field first-aid case; lid and latch pivots',[.255,.23,.09])
box('CaseBase',(0,.105,0),(.255,.21,.085),'green',.012)
lid=empty('Pivot_MedicalLid',(0,.022,-.035),current)
box('CaseLid',(0,.108,.044),(.248,.20,.011),'green',.009,lid)
box('LabelPanel',(0,.108,.051),(.203,.151,.002),'cotton',.002,lid)
box('MedicalMarkVertical',(0,.11,.053),(.017,.071,.002),'green',.0006,lid)
box('MedicalMarkHorizontal',(0,.11,.053),(.066,.017,.002),'green',.0006,lid)
strap_loop('CarryHandle',(0,.229,0),.10,.049,.012,'rubber')
for side in [-1,1]:box('Latch',(side*.075,.20,.052),(.023,.024,.014),'steel',.003)
marker('carry',(0,.241,0));finish_asset()

# 13. Desktop portable radio with speakers, tuning scale, movable controls/antenna.
start('portable_radio','Public AM/FM radio with real speaker grille and tuning marker',[.30,.235,.09])
box('RadioBody',(0,.105,0),(.30,.21,.086),'green',.009)
strap_loop('RadioCarryHandle',(0,.221,0),.25,.045,.009,'dark_steel')
label('TuningScale',(0,.171,.044),(.263,.041),'radio_dial')
for xx,rr in [(-.072,.053),(.028,.031)]:
    cylinder('SpeakerBezel',(xx,.073,.043),(xx,.073,.05),rr,'steel',40)
    cylinder('SpeakerInset',(xx,.073,.051),(xx,.073,.052),rr*.9,'rubber',32)
    for k in range(-4,5):
        yy=.073+k*rr*.18;half=math.sqrt(max(0,(rr*.84)**2-(k*rr*.18)**2))
        if half>.003:box('GrilleSlat',(xx,yy,.053),(half*2,.002,.003),'dark_steel',.0004)
knob=empty('Pivot_TuningKnob',(.108,.099,.052),current);cylinder('TuningKnob',(.108,.099,.045),(.108,.099,.062),.018,'rubber',32,knob)
box('KnobIndicator',(.108,.11,.063),(.002,.011,.002),'white',.0005,knob)
box('TunerNeedle',(-.038,.171,.045),(.002,.032,.001),'red',.0002)
antenna=empty('Pivot_Antenna',(.123,.209,-.024),current);cylinder('Antenna',(.123,.209,-.024),(.123,.47,-.024),.0018,'steel',12,antenna)
marker('carry',(0,.237,0));finish_asset()

# 14/15. Dry matchbox and open tray, original readable sleeve.
def matches(name,opened):
    start(name,'Safety matchbox; sliding tray and actual wooden matches',[.055,.019,.10 if opened else .075])
    box('MatchSleeve',(0,.01,0),(.055,.019,.075),'cotton',.002)
    label('SleevePrint',(0,.020,0),(.051,.071),'matches_label',horizontal=True)
    box('StrikeSurface',(.0277,.01,0),(.001,.010,.06),'leather',.0002)
    tray=empty('Pivot_MatchTray',(0,0,-.025 if opened else 0),current)
    z=-.025 if opened else 0
    box('TrayBottom',(0,.004,z),(.049,.004,.069),'wood',.001,tray)
    if opened:
        for side in [-1,1]:box('TraySide',(side*.024,.01,z),(.003,.015,.069),'wood',.0005,tray)
        box('TrayEnd',(0,.01,z-.034),(.049,.015,.003),'wood',.0005,tray)
        for k in range(8):
            xx=-.02+k*.0055;cylinder('MatchStick',(xx,.009,z-.027),(xx,.009,z+.025),.0012,'wood',6,tray);cylinder('MatchHead',(xx,.009,z-.032),(xx,.009,z-.027),.0018,'red',8,tray)
    finish_asset()
matches('matchbox_closed',False);matches('matchbox_open',True)

# 16. Yellow field torch, recessed reflector, lens and thumb switch.
start('field_flashlight','Sealed field torch; beam origin and holding socket',[.047,.22,.047])
lathe('TorchBarrel',[(0,.015),(.012,.018),(.13,.018),(.145,.02),(.172,.0235),(.19,.0235)],'ochre',40)
for yy in [.005,.035,.049,.063,.077,.12]:torus('GripRib',(0,yy,0),.018,.002,'rubber',n=24)
lathe('HeadGuard',[(.178,.025),(.204,.025),(.204,.021),(.18,.021)],'rubber',40,cap=False)
cylinder('Reflector',(0,.197,0),(0,.201,0),.020,'steel',40)
cylinder('Lens',(0,.202,0),(0,.204,0),.018,'white',40)
box('ThumbSwitch',(0,.139,.021),(.014,.026,.005),'rubber',.003)
marker('grip',(0,.075,0));marker('beam',(0,.205,0));finish_asset()

# 17/18. Two physically sized cells; terminal polarity and label mesh.
def battery(name,r,h):
    start(name,'Primary alkaline cell; plus terminal and polarity print',[2*r,h,2*r])
    cylinder('CellCan',(0,.002,0),(0,h-.006,0),r,'dark_steel',32)
    lathe('LabelBand',[(h*.14,r+.0002),(h*.86,r+.0002)],'ochre',32,cap=False)
    cylinder('PositiveCap',(0,h-.006,0),(0,h,0),r*.34,'steel',20)
    cylinder('NegativeBase',(0,0,0),(0,.002,0),r*.87,'steel',24)
    curved_label('CellPrint',h*.51,r+.0006,r*1.35,h*.46,'battery_label');finish_asset()
battery('battery_aa',.00725,.0505);battery('battery_d',.017,.0615)

# 19/20. Hinged brass compass with original dial and independent needle.
def compass(name,opened):
    start(name,'Field compass with pivoted lid and independent needle',[.061,.075 if opened else .017,.061])
    lathe('CompassBody',[(0,.025),(.003,.029),(.014,.029),(.014,.026),(.007,.026)],'gold',40)
    vs=[cv((0,.0076,0))]+[cv((math.cos(k*TAU/48)*.025,.0076,math.sin(k*TAU/48)*.025)) for k in range(48)]
    fs=[(0,(k+1)%48+1,k+1) for k in range(48)]
    me=bpy.data.meshes.new('NavigationDial');me.from_pydata(vs,[],fs);me.update();uv=me.uv_layers.new()
    for f in me.polygons:
        for li in f.loop_indices:
            p=gv(Vector(vs[me.loops[li].vertex_index]));uv.data[li].uv=(p[0]/.05+.5,-p[2]/.05+.5)
    o=bpy.data.objects.new('NavigationDial',me);bpy.context.collection.objects.link(o);bind(o,'print:compass_dial',uv=False)
    needle=empty('Pivot_Needle',(0,.009,0),current)
    pointer=extrusion('NorthNeedle',[(-.003,0),(.003,0),(0,.023)],0,.001,'red',needle,.0001)
    pointer.rotation_euler.x=math.pi/2;pointer.location=(0,0,0)
    pointer=extrusion('SouthNeedle',[(-.003,0),(0,-.023),(.003,0)],0,.001,'dark_steel',needle,.0001)
    pointer.rotation_euler.x=math.pi/2;pointer.location=(0,0,0)
    cylinder('NeedleHub',(0,.009,0),(0,.012,0),.0025,'dark_steel',12,needle)
    lid=empty('Pivot_CompassLid',(0,.013,-.028),current)
    disc=cylinder('LidDisc',(0,.014,0),(0,.017,0),.029,'gold',40,lid)
    torus('LidRim',(0,.017,0),.027,.0012,'gold','Y',lid,n=40)
    if opened:lid.rotation_euler.x=math.radians(-105)
    torus('LanyardLoop',(0,.008,.034),.007,.0015,'gold',n=20)
    marker('lanyard',(0,.008,.040));finish_asset()
compass('field_compass_closed',False);compass('field_compass_open',True)

# 21-24. Four coordinated original pantry tins, real ridges, pull tab and labels.
for flavour in ['beans','soup','fish','fruit']:
    start('food_can_'+flavour,'400 g pantry tin / '+flavour,[.074,.11,.074])
    profile=[(.002,.036)]
    for yy in [.009,.023,.087,.101]:profile.extend([(yy-.001,.036),(yy,.0368),(yy+.001,.036)])
    profile.append((.107,.036));lathe('PressedTin',profile,'steel',32)
    for yy in [.002,.108]:torus('RolledTinEdge',(0,yy,0),.036,.0013,'steel',n=24,minor=4)
    # Full wrap printed band with proper cylindrical UVs, no floating billboard.
    o=lathe('PaperWrap',[(.031,.0367),(.079,.0367)],'print:can_'+flavour,48,cap=False)
    for f in o.data.polygons:
        for li in f.loop_indices:
            vi=o.data.loops[li].vertex_index;j,k=divmod(vi,48)
            seam=1 if k==0 and f.index==47 else 0
            o.data.uv_layers.active.data[li].uv=(.75-k/48-seam,j)
    torus('PullTab',(0,.110,.006),.007,.0015,'dark_steel',n=16,minor=4)
    cylinder('TabRivet',(0,.108,0),(0,.111,0),.0025,'steel',12)
    marker('contents',(0,.109,0));finish_asset()

# 25. Thick rolled sterile dressing with hollow core and paper sleeve.
start('rolled_bandage','Cotton field dressing with hollow core and print sleeve',[.061,.05,.061])
lathe('RolledCotton',[(0,.029),(.05,.029),(.05,.009),(0,.009)],'cotton',40,cap=False)
for yy in [.001,.049]:
    for rr in [.013,.018,.023,.028]:torus('VisibleCottonLayers',(0,yy,0),rr,.0006,'cotton',n=24,minor=4)
curved_label('DressingSleeve',.025,.0295,.065,.033,'bandage_label');finish_asset()

# 26. True open D handle and shaped curved steel shovel blade.
start('field_shovel','Short field shovel with curved blade and open D handle',[.215,1.05,.095])
extrusion('SpadeBlade',[(-.107,.26),(-.101,.07),(-.055,.018),(0,0),(.055,.018),(.101,.07),(.107,.26)],0,.014,'steel',rounding=.003)
cylinder('Socket',(0,.225,0),(0,.345,0),.022,'dark_steel')
cylinder('AshShaft',(0,.29,0),(0,.915,0),.014,'wood',32)
strap_loop('D_Handle',(0,.971,0),.145,.158,.019,'red')
marker('grip_primary',(0,.68,0));marker('grip_support',(0,.42,0));marker('cutting_edge',(0,.005,0));finish_asset()

# 27. Tang, guard, curved grip, blade edge and brass rivets, reusable grip marker.
start('hunting_knife','Full-tang field knife with separate blade and grip materials',[.037,.27,.020])
extrusion('SteelBlade',[(-.012,.12),(.013,.12),(.014,.222),(.006,.255),(0,.27),(-.013,.232)],0,.0032,'steel',rounding=.0007)
extrusion('CuttingBevel',[(-.012,.125),(-.006,.128),(-.006,.23),(0,.267),(-.013,.232)],.0017,.0004,'white',rounding=0)
extrusion('Grip',[(-.014,0),(.011,0),(.015,.035),(.012,.075),(.017,.109),(-.013,.114),(-.018,.07),(-.014,.033)],0,.018,'canvas',rounding=.002)
box('KnifeGuard',(0,.115,0),(.037,.007,.021),'gold',.001)
for yy in [.025,.09]:cylinder('GripRivet',(0,yy,-.01),(0,yy,.01),.0025,'gold',16)
marker('grip_primary',(0,.057,0));marker('blade_tip',(0,.27,0));finish_asset()

# 28-30. Hewing hatchet, improvised stone axe and compact painted rescue axe.
def axe(name,stone=False,rescue=False):
    h=.58 if not rescue else .47
    start(name,'Field axe with original fitted head and two holding sockets',[.20,h,.043])
    extrusion('CurvedAshHandle',[(-.019,0),(.014,0),(.022,.04),(.017,.21),(.002,h-.12),(-.024,h-.05),(-.036,h-.07),(-.016,.20),(-.026,.04)],0,.030,'wood',rounding=.003)
    if stone:
        head=extrusion('KnappedStone',[(-.058,h-.04),(-.072,h-.11),(-.051,h-.18),(.018,h-.17),(.079,h-.145),(.092,h-.075),(.058,h-.016),(0,h)],0,.041,'stone',rounding=0)
        for yy in [h-.055,h-.074,h-.093,h-.112]:
            strap_loop('Lashing',(-.019,yy,0),.065,.019,.005,'cotton')
        for side in [-1,1]:
            for yy in [h-.05,h-.069,h-.088,h-.107]:
                cylinder('HeadLashing',(-.058,yy,side*.023),(.053,yy-.021,side*.024),.0022,'cotton',8)
        for yy in [.055,.073,.091]:strap_loop('GripBinding',(0,yy,0),.04,.012,.004,'ochre')
    else:
        points=[(-.055,h-.035),(-.061,h-.105),(-.021,h-.12),(.032,h-.15),(.13,h-.18),(.14,h-.09),(.06,h-.075),(.01,h-.023)]
        extrusion('ForgedHead',points,0,.041,'red' if rescue else 'dark_steel',rounding=.003)
        extrusion('HonedBit',[(.116,h-.176),(.14,h-.18),(.15,h-.094),(.127,h-.091)],0,.013,'steel',rounding=.001)
        cylinder('HeadWedge',(-.025,h-.033,-.02),(-.025,h-.033,.022),.005,'dark_steel',16)
    marker('grip_primary',(0,.12,0));marker('grip_support',(-.008,.29,0));marker('cutting_edge',(.145,h-.13,0));finish_asset()
axe('woodcutting_hatchet');axe('improvised_stone_axe',True);axe('rescue_hatchet',rescue=True)

# 31/32. Small fuel/water cookware lids are useful standalone modular variants.
def lid(name,r):
    start(name,'Matching removable cooking-pot lid',[r*2,.034,r*2])
    lathe('DomedLid',[(0,r),(.004,r),(.022,r*.67),(.023,r*.45)],'steel',48)
    strap_loop('LidGrip',(0,.033,0),.050,.020,.007,'dark_steel')
    marker('grip',(0,.035,0));finish_asset()
lid('camp_pot_lid_large',.142);lid('camp_pot_lid_small',.088)

# Editable library at actual scale: separate collections on a metre-spaced grid.
for i,asset in enumerate(ASSETS):
    asset.location=cv(((i%8)*1.3,0,-(i//8)*1.3))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'field_survival_library.blend'),compress=True)
for asset in ASSETS:
    asset.location=(0,0,0)
    bpy.data.collections[asset.name+'_Editable'].hide_render=True
manifest={'name':'North Ridge / Field Survival Kit','version':'1.0.0','units':'metres','front_axis':'+Z','ground_origin':'Y=0 for resting props; sockets are local Godot coordinates','provenance':'Original locally authored meshes and printwork; user-supplied sheet used as visual reference only','source_reference_sha256':None,'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'assets':RECORD}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8',newline='\n')
print('FIELD_KIT_EXPORT_DONE',len(RECORD),sum(r['triangles'] for r in RECORD.values()),flush=True)

# Contact sheet preview: deliberately normalised panels; real dimensions in manifest.
if '--render' in sys.argv:
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.cycles.use_denoising=True;scene.render.resolution_x=450;scene.render.resolution_y=450;scene.render.resolution_percentage=100
    scene.world.color=(.055,.055,.055);scene.view_settings.view_transform='AgX'
    for name,loc,energy,size in [('Key',(3,-4,5),480,4),('Fill',(-3,-2,2.5),240,3),('Rim',(1,3,4),350,3)]:
        bpy.ops.object.light_add(type='AREA',location=loc);light=bpy.context.object;light.name=name;light.data.energy=energy;light.data.shape='DISK';light.data.size=size;light.rotation_euler=(Vector((0,0,.4))-light.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO'
    for asset in ASSETS:
        bpy.data.collections[asset.name+'_Editable'].hide_render=False
        for child in asset.children_recursive:child.hide_render=False
        bpy.context.view_layer.update();pts=[o.matrix_world@Vector(c) for o in asset.children_recursive if o.type=='MESH' for c in o.bound_box];center=Vector([(min(p[i] for p in pts)+max(p[i] for p in pts))/2 for i in range(3)])
        mx=max(RECORD[asset.name]['measured_size_m']);cam.data.ortho_scale=mx*1.5
        cam.location=center+Vector((1.5,-2.6,1.65))*mx;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(SHOTS/(asset.name+'.png'));bpy.ops.render.render(write_still=True)
        for child in asset.children_recursive:child.hide_render=True
        bpy.data.collections[asset.name+'_Editable'].hide_render=True
    print('FIELD_KIT_RENDER_DONE',flush=True)
