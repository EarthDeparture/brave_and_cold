"""Original metre-scale resources and fitted service hammer. Seed 4106.
Blender background --python this_file -- OUTPUT_DIRECTORY
GLBs have no collisions. Wood/plank/stick origins rest on y=0 in Godot;
the hammer origin matches the already fitted Shaft grip of the hatchet.
"""
import sys, math, json, hashlib, shutil
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'tex').mkdir(exist_ok=True)
for name in ['ash','leather','steel']:
    shutil.copyfile(ROOT/f'brave-and-cold/assets/models/viewmodel/tex/vm_{name}.png',OUT/f'tex/vm_{name}.png')
sys.path.insert(0,str(Path(__file__).parent))
from vmlib import Part, limb, export_glb, tris, MATS, get_material
MATS['bark']=('bark.png',.32,.96,0)
MATS['endgrain']=('endgrain.png',.14,.92,0)
MATS['ration']=('ration.png',.30,.88,0)
MATS['canvas']=('canvas.png',.12,.97,0)
rng=np.random.default_rng(4106)
y,x=np.mgrid[0:512,0:512]/512
noise=rng.normal(0,1,(512,512))
def image(name, rgb):
    im=bpy.data.images.new(name,width=512,height=512)
    arr=np.ones((512,512,4),dtype=np.float32);arr[:,:,:3]=np.clip(rgb,0,1)
    im.pixels.foreach_set(arr.ravel());im.filepath_raw=str(OUT/'tex'/name);im.file_format='PNG';im.save()
# Longitudinal fissures, low-contrast scales and cut growth rings; no copied textures.
fiss=(.5+.5*np.sin(y*150+2*np.sin(x*17)))**18
val=.75+.06*np.sin(y*87+3*np.sin(x*9))+.035*noise-.27*fiss
image('bark.png',val[:,:,None]*np.array([.43,.35,.27]))
r=np.sqrt((x-.52)**2+(y-.48)**2);ang=np.arctan2(y-.48,x-.52)
val=.88+.055*np.sin(r*125+1.1*np.sin(ang*3))+.02*noise
val-=.16*((np.sin(ang*9+.6)> .998)&(r>.18))
image('endgrain.png',val[:,:,None]*np.array([.70,.56,.39]))
val=.88+.025*noise+.022*np.sin(x*850)*np.sin(y*850)
image('canvas.png',val[:,:,None]*np.array([.54,.44,.30]))
label=np.ones((512,512,3))*np.array([.62,.57,.41]);label[:45]*=.45;label[-45:]*=.45
label[65:73]=[.21,.32,.29];label[425:433]=[.21,.32,.29]
# Original small stamped bean motif, deliberately no printed inventory counts.
bean=((x-.50)/.19)**2+((y-.5)/.22)**2<1
label[bean]=[.24,.33,.29];label+=noise[:,:,None]*.005
image('ration.png',label)
# Original microrelief, bounded to avoid sparkling under moving light.
for name,strength in [('bark',.60),('endgrain',.15),('canvas',.12)]:
    source=bpy.data.images.load(str(OUT/'tex'/(name+'.png')))
    pixels=np.array(source.pixels[:],dtype=np.float32).reshape(512,512,4)
    dy,dx=np.gradient(pixels[:,:,:3].mean(axis=2))
    normal=np.stack([-dx*strength*25,-dy*strength*25,np.ones_like(dx)],axis=2)
    normal/=np.linalg.norm(normal,axis=2)[:,:,None]
    image(name+'_normal.png',normal*.5+.5)
    nt=get_material(name).node_tree
    texture=nt.nodes.new('ShaderNodeTexImage');texture.image=bpy.data.images.load(str(OUT/'tex'/(name+'_normal.png')))
    texture.image.colorspace_settings.name='Non-Color'
    nm=nt.nodes.new('ShaderNodeNormalMap');nt.links.new(texture.outputs['Color'],nm.inputs['Color'])
    nt.links.new(nm.outputs['Normal'],nt.nodes.get('Principled BSDF').inputs['Normal'])
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def godot(v): return (v[0],-v[2],v[1])
def face(a, vs, mat, uv=None):
    a.mat=mat;a.face(list(reversed(vs)),list(reversed(uv)) if uv else None,smooth=False)
def resource_wood():
    a=Part('resource_wood');a.smooth=False
    rows=[]
    for i in range(5):
        xx=-.21+i*.105
        rr=.062*(1+.025*math.sin(i*2.7))
        rows.append([a.vert(godot((xx,math.sin(k*math.pi/10)*rr,math.cos(k*math.pi/10)*rr)),(.92,.92,.92)) for k in range(11)])
    for j in range(4):
        for k in range(10):
            face(a,[rows[j][k],rows[j][k+1],rows[j+1][k+1],rows[j+1][k]],'bark',[(j/4,k/10),(j/4,(k+1)/10),((j+1)/4,(k+1)/10),((j+1)/4,k/10)])
        face(a,[rows[j][10],rows[j][0],rows[j+1][0],rows[j+1][10]],'ash')
    for j in [0,4]:
        row=rows[j] if j==4 else list(reversed(rows[j]))
        face(a,row,'endgrain',[(v.co.y/.14+.5,v.co.z/.14+.05) for v in row])
    return a.finish()
def resource_stick():
    a=Part('resource_stick');a.mat='bark'
    pts=[Vector(godot((-.19+i*.095,.011+math.sin(i)*.003,math.sin(i*1.8)*.008))) for i in range(5)]
    limb(a,pts,[(.011-i*.0015,.010-i*.0013) for i in range(5)],[(.86,)*3]*5,sides=8,ref=Vector((0,0,1)))
    limb(a,[pts[3],pts[3]+Vector(godot((.06,.008,.045)))],[(.006,.005),(.003,.003)],[(.86,)*3]*2,sides=8,ref=Vector((0,0,1)))
    return a.finish()
def box(name,pos,size,mat,bevel):
    bpy.ops.mesh.primitive_cube_add(size=1,location=godot(pos));o=bpy.context.object;o.name=name
    o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    from vmlib import get_material
    o.data.materials.append(get_material(mat))
    mod=o.modifiers.new('soft worn edges','BEVEL');mod.width=bevel;mod.segments=2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for poly in o.data.polygons:poly.use_smooth=False
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return o
def cylinder(name,yy,rad,depth,mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=rad,depth=depth,location=(0,0,yy))
    o=bpy.context.object;o.name=name
    o.data.uv_layers.active.name='UV'
    from vmlib import get_material
    o.data.materials.append(get_material(mat))
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return o
def tin():
    objs=[cylinder('tin_body',.092,.060,.174,'steel'),cylinder('rolled_base',.006,.063,.012,'steel'),cylinder('rolled_rim',.179,.063,.010,'steel')]
    a=Part('ration_tin');a.mat='ration'
    for k in range(32):
        ang=k*math.tau/32;nextang=(k+1)*math.tau/32
        vs=[a.vert((math.cos(t)*.0605,-math.sin(t)*.0605,z)) for t,z in [(ang,.035),(nextang,.035),(nextang,.153),(ang,.153)]]
        a.face(list(reversed(vs)),[(k/32,1),((k+1)/32,1),((k+1)/32,0),(k/32,0)],smooth=True)
    objs.append(a.finish());bpy.ops.object.select_all(action='DESELECT')
    for ob in objs:ob.select_set(True)
    bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();objs[0].name='ration_tin'
    return objs[0]
def hammer():
    a=Part('work_hammer');a.mat='ash'
    limb(a,[Vector((0,-.002,z)) for z in [-.15,-.115,-.04,0,.04,.075,.19,.25]],[(.010,.014),(.010,.014),(.010,.014),(.010,.014),(.010,.014),(.010,.014),(.010,.014),(.011,.016)],[(.92,)*3]*8,sides=12,ref=Vector((0,1,0)),n=2.4)
    a.mat='leather'
    limb(a,[Vector((0,-.002,z)) for z in [-.115,-.085,-.04,0,.04,.075]],[(.0112,.0158),(.0120,.0166),(.0122,.0168),(.0122,.0168),(.0120,.0166),(.0112,.0158)],[(.92,)*3]*6,sides=12,ref=Vector((0,1,0)),n=2.4)
    a.mat='steel'
    limb(a,[Vector((0,y,.255)) for y in [-.045,-.022,.015,.045,.075]],[(.018,.022),(.022,.025),(.020,.023),(.015,.016),(.019,.019)],[(.90,)*3]*5,sides=12,ref=Vector((1,0,0)))
    # Two swept, separated claws; angled tips and central notch remain in silhouette.
    for sx in [-1,1]:
        limb(a,[Vector((sx*.013,-.034,.255)),Vector((sx*.013,-.073,.244)),Vector((sx*.014,-.097,.219))],[(.009,.012),(.007,.006),(.005,.003)],[(.88,)*3]*3,sides=8,ref=Vector((1,0,0)))
    return a.finish()
objects=[resource_wood(),resource_stick(),box('resource_plank',(0,.014,0),(.85,.028,.155),'ash',.003),tin(),box('ration_pouch',(0,.071,0),(.19,.142,.12),'canvas',.025),box('provisions_tray',(0,.0075,0),(1.05,.015,.36),'ash',.002),hammer()]
receipt={'seed':4106,'units':'metres','license':'Project-authored original geometry and textures; same ownership as repository','source':'tools/blender/gen_survival_props.py','source_sha256':hashlib.sha256(Path(__file__).read_text(encoding='utf8').replace('\r\n','\n').encode('utf8')).hexdigest(),'design':'Weathered split firewood with bark and cut growth rings; beveled planks; tapered forked sticks; individual provisions; fitted claw hammer','negative_constraints':'No third-party assets, no collision bodies, no map grading, maximum 2000 triangles per unit, maximum 512px new textures','source_dependencies':{f.relative_to(ROOT).as_posix():hashlib.sha256(f.read_text(encoding='utf8').replace('\r\n','\n').encode('utf8') if f.suffix=='.py' else f.read_bytes()).hexdigest() for f in [Path(__file__).parent/'vmlib.py']+[ROOT/f'brave-and-cold/assets/models/viewmodel/tex/vm_{n}.png' for n in ['ash','leather','steel']]},'assets':{}}
runtime=ROOT/'brave-and-cold/assets/survival_props';runtime.mkdir(exist_ok=True)
for o in objects:
    path=OUT/(o.name+'.glb');export_glb([o],str(path));assert tris(o)<=2000
    lo=[min(v.co[i] for v in o.data.vertices) for i in range(3)];hi=[max(v.co[i] for v in o.data.vertices) for i in range(3)]
    receipt['assets'][o.name]={'triangles':tris(o),'blender_bounds':[lo,hi],'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    shutil.copyfile(path,runtime/path.name)
for img in bpy.data.images:
    if img.source=='FILE':img.pack()
bpy.ops.object.select_all(action='SELECT');bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'survival_props.blend'))
(runtime/'provenance.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8')
print('SURVIVAL_PROPS',json.dumps(receipt))
