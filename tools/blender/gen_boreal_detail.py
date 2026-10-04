"""Original boreal spruce family with branch volumes and separate snow pillows.
Blender --background --factory-startup --python-exit-code 1 --python FILE
Uses no source meshes or external art. Outputs into a new presentation bank.
"""
from pathlib import Path
import math, random, json, hashlib
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"brave-and-cold/assets/environment_detail/trees"
OUT.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/"tools/blender/generated/environment_detail"
SOURCE.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
mat=bpy.data.materials.new("BorealVertexSurface")
mat.diffuse_color=(.65,.70,.76,1)
SPEC={"spruce_a":(211,13,.165,.17,.82),"spruce_b":(317,14,.135,.24,.68),"spruce_c":(419,11,.190,.20,.91)}
BARK=(.105,.068,.041); LEAF=(.023,.063,.052); SNOW=(.65,.72,.81)

class Mesh:
    def __init__(self,name,rng):
        self.name=name; self.rng=rng; self.v=[]; self.f=[]; self.col=[]; self.uv=[]
    def vertex(self,p,c,uv):
        self.v.append(tuple(p)); self.col.append(c); self.uv.append(uv); return len(self.v)-1
    def face(self,ids): self.f.append(tuple(ids))
    def tube(self,a,b,r0,r1,col,kind=0,sides=6):
        a,b=Vector(a),Vector(b); axis=(b-a).normalized()
        ref=Vector((0,0,1)) if abs(axis.z)<.95 else Vector((1,0,0))
        u=axis.cross(ref).normalized(); v=axis.cross(u).normalized()
        rings=[]
        for t in [0,.5,1]:
            r=r0*(1-t)+r1*t
            c=a.lerp(b,t); ring=[]
            for i in range(sides):
                ang=i*math.tau/sides
                ring.append(self.vertex(c+(u*math.cos(ang)+v*math.sin(ang))*r,(*col,kind),(i/sides,t*max((b-a).length*35,.5))))
            rings.append(ring)
        self.face(reversed(rings[0]));self.face(rings[-1])
        for j in range(2):
            for i in range(sides): self.face([rings[j][i],rings[j][(i+1)%sides],rings[j+1][(i+1)%sides],rings[j+1][i]])
    def tuft(self,center,axis,length,width,height,col,kind,far=False):
        # Closed, tapered irregular bough mass: no flat triangular needle fans.
        center=Vector(center); axis=Vector(axis).normalized()
        cross=Vector((-axis.y,axis.x,0)).normalized()
        up=axis.cross(cross).normalized()
        ring_count=3 if far else 5
        rings=[]
        for j,(t,scale) in enumerate([(-.48,.26),(-.16,.92),(.20,.77),(.49,.12)]):
            ring=[]
            for i in range(ring_count):
                a=i*math.tau/ring_count
                jitter=self.rng.uniform(.87,1.13)
                p=center+axis*(length*t)+cross*(math.cos(a)*width*scale*jitter)+up*(math.sin(a)*height*scale*jitter)
                ring.append(self.vertex(p,(*col,kind),(i/ring_count,j/3)))
            rings.append(ring)
        self.face(reversed(rings[0]));self.face(rings[-1])
        for j in range(3):
            for i in range(ring_count):self.face([rings[j][i],rings[j][(i+1)%ring_count],rings[j+1][(i+1)%ring_count],rings[j+1][i]])
    def snow(self,center,axis,length,width,depth,far=False):
        # Rounded upper cap with a closed underside; visible thickness at branch edges.
        center=Vector(center); axis=Vector(axis).normalized()
        cross=Vector((-axis.y,axis.x,0)).normalized()
        sides=4 if far else 5
        rings=[]
        for level,scale in [(0,1),(.7,.70),(1,.13)]:
            ring=[]
            for i in range(sides):
                angle=i*math.tau/sides
                jitter=self.rng.uniform(.88,1.10)
                p=center+axis*(math.cos(angle)*length*.5*scale*jitter)+cross*(math.sin(angle)*width*scale*jitter)+Vector((0,0,depth*level))
                tone=self.rng.uniform(.94,1.02)
                ring.append(self.vertex(p,tuple(c*tone for c in SNOW)+(1,),(math.cos(angle)*.5+.5,math.sin(angle)*.5+.5)))
            rings.append(ring)
        self.face(reversed(rings[0]));self.face(rings[-1])
        for j in range(2):
            for i in range(sides):self.face([rings[j][i],rings[j][(i+1)%sides],rings[j+1][(i+1)%sides],rings[j+1][i]])
    def finish(self):
        mesh=bpy.data.meshes.new(self.name); mesh.from_pydata(self.v,[],self.f);mesh.update()
        layer=mesh.color_attributes.new(name="Surface",type="FLOAT_COLOR",domain="CORNER")
        uv=mesh.uv_layers.new(name="SurfaceUV")
        for p in mesh.polygons:
            p.use_smooth=True
            for li in p.loop_indices:
                vi=mesh.loops[li].vertex_index
                layer.data[li].color=self.col[vi];uv.data[li].uv=self.uv[vi]
        mesh.color_attributes.active_color=layer;mesh.color_attributes.render_color_index=0
        mesh.materials.append(mat)
        obj=bpy.data.objects.new(self.name,mesh);bpy.context.collection.objects.link(obj)
        return obj

def card(m,root,direction,length,width,tilt):
    axis=direction.normalized()
    cross=Vector((-axis.y,axis.x,0)).normalized()
    vertical=axis.cross(cross).normalized()
    side=cross*math.cos(tilt)+vertical*math.sin(tilt)
    ids=[]
    for t,v in [(0,0),(1,0),(1,1),(0,1)]:
        point=root+axis*(length*t)+side*((v-.5)*width)
        ids.append(m.vertex(point,(1,1,1,.5),(t,.38+v*.36)))
    m.face(ids)

def build(name,cfg,far=False):
    seed,tiers,radius,droop,load=cfg
    rng=random.Random(seed); m=Mesh(name,rng)
    bend=Vector((rng.uniform(-.015,.015),rng.uniform(-.010,.010),0))
    for i in range(4):
        za=i*.24;zb=(i+1)*.24
        m.tube(bend*za*za+Vector((0,0,za)),bend*zb*zb+Vector((0,0,zb)),.0105*(1-za*.84),.0105*(1-zb*.84),BARK,sides=4 if far else 8)
    effective=11 if far else tiers+3
    for tier in range(effective):
        f=tier/(effective-1)
        z=.14+f*.79
        reach=radius*(1-f)**.78+.012
        count=5
        phase=tier*2.399+rng.uniform(-.22,.22)
        for branch in range(count):
            angle=phase+branch*math.tau/count+rng.uniform(-.15,.15)
            direction=Vector((math.cos(angle),math.sin(angle),-droop*(1-f*.4))).normalized()
            length=reach*rng.uniform(.88,1.15)
            root=bend*z*z+Vector((0,0,z+rng.uniform(-.012,.012)))
            tip=root+direction*length
            if not far: m.tube(root,tip,.0022*(1-f*.4),.0006,BARK,sides=4)
            for tilt in ([.65,-.65] if far else [0,.85,-.85]):
                card(m,root,direction,length,length*.82,tilt)
            if not far and tier%2==0 and rng.random()<load*.65:
                m.snow(root+direction*length*.6+Vector((0,0,.003)),direction,length*.46,length*.115,.0035,False)
    for j in range(3):
        ang=j*math.tau/3
        card(m,bend*.96+Vector((0,0,.945)),Vector((math.cos(ang)*.3,math.sin(ang)*.3,1)),.045,.019,.5)
    return m.finish()

receipt={"schema":1,"origin":"Original project-authored Blender geometry","generator":"tools/blender/gen_boreal_detail.py","art_spec":"Boreal spruce, rooted tapered trunks, separated drooping boughs, crossed botanical needle boughs and rounded resting snow; restrained painterly winter colours","negative_spec":"No copied assets, solid triangular skirts, oversized pillows, changed scatter locations or physical colliders","units":"metres; 1 m source height scaled by existing canopy data","models":[]}
all_models=[]
for family,cfg in SPEC.items():
    for far in [False,True]:
        name=family+("_far" if far else "")
        obj=build(name,cfg,far);all_models.append(obj)
        bpy.ops.object.select_all(action="DESELECT");obj.select_set(True);bpy.context.view_layer.objects.active=obj
        path=OUT/(name+".glb")
        bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,export_yup=True,export_vertex_color="ACTIVE",export_all_vertex_colors=False,export_normals=True)
        obj.data.calc_loop_triangles();tris=len(obj.data.loop_triangles)
        assert tris <= (900 if far else 4200),(name,tris)
        coords=[v.co for v in obj.data.vertices]
        assert all(math.isfinite(c) for v in coords for c in v)
        assert min(v.z for v in coords)>=-.012 and max(v.z for v in coords)<=1.03
        receipt["models"].append({"name":name,"seed":cfg[0],"triangles":tris,"vertices":len(obj.data.vertices),"sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
        print("BOREAL_DETAIL",name,tris,len(obj.data.vertices),flush=True)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"boreal_family.blend"))
(OUT/"provenance.json").write_text(json.dumps(receipt,indent=2)+"\n")
