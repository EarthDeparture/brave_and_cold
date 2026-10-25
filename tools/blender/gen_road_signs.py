"""Original winter roadside sign assemblies, in metres. No external models.
Blender -Y face -> Godot +Z face; origin at terrain/post base.
"""
from pathlib import Path
import bpy, bmesh, math, json, hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'brave-and-cold/assets/road_detail/models';OUT.mkdir(parents=True,exist_ok=True)
TEX=OUT.parent/'textures';SOURCE=ROOT/'tools/blender/generated/road_detail';SOURCE.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def material(name,color,rough=.7,metal=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
    return m
steel=material('galvanized_metal',(.36,.39,.41),.66,.72)
edge=material('pressed_aluminum_edge',(.41,.44,.46),.56,.78)
snow=material('resting_powder',(.83,.88,.94),.94,0)
dark=material('dark_mounting_slots',(.08,.095,.1),.8,.45)
def mesh(name,verts,faces,mat):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free()
    me.materials.append(mat);obj=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(obj);return obj

def cube(name,center,size,mat,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=center);obj=bpy.context.object;obj.name=name;obj.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod=obj.modifiers.new('small manufactured edges','BEVEL');mod.width=bevel;mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj

def bolt(x,z,front=True):
    y=-.014 if front else .070
    bpy.ops.mesh.primitive_cylinder_add(vertices=6,radius=.009,depth=.006,location=(x,y,z),rotation=(math.pi/2,0,0))
    obj=bpy.context.object;obj.name='hex_bolt';obj.data.materials.append(steel);return obj

models=[]
for kind in ['speed','deer','bear','icy','curve_left','curve_right']:
    objects=[];before=set(bpy.data.objects)
    width,height=(.60,.78) if kind=='speed' else (.88,.88)
    if kind=='speed':
        w=width/2;h=height/2;c=.025
        outline=[(-w+c,-h),(w-c,-h),(w,-h+c),(w,h-c),(w-c,h),(-w+c,h),(-w,h-c),(-w,-h+c)]
    else:outline=[(0,-height/2),(width/2,0),(0,height/2),(-width/2,0)]
    v=[(x,y,2.25+z) for y in [-.008,.008] for x,z in outline];n=len(outline)
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    for i in range(n):faces.append((i,(i+1)%n,(i+1)%n+n,i+n))
    body=mesh(kind+'_pressed_plate',v,faces,edge)
    bevel=body.modifiers.new('pressed rim bevel','BEVEL');bevel.width=.0025;bevel.segments=1;bpy.context.view_layer.objects.active=body;bpy.ops.object.modifier_apply(modifier=bevel.name)
    frontmat=material(kind+'_reflective_print',(.95,.95,.95),.51)
    image=bpy.data.images.load(str(TEX/f'sign_{kind}.png'));tex=frontmat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
    frontmat.node_tree.links.new(tex.outputs['Color'],frontmat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    fv=[(x*.985,-.011,2.25+z*.985) for x,z in outline]
    face=mesh(kind+'_graphic',fv,[tuple(range(n))],frontmat)
    uv=face.data.uv_layers.new(name='UVMap')
    for loop in face.data.loops:
        x,_,z=face.data.vertices[loop.vertex_index].co;uv.data[loop.index].uv=(x/width+.5,(z-2.25)/height+.5)
    # Punched U-channel: slots are actual openings, not painted black dots.
    pv=[];pf=[]
    def quad(points):
        start=len(pv);pv.extend(points);pf.append(tuple(range(start,start+len(points))))
    for x in [-.032,.032]:quad([(x,.025,-.05),(x,.070,-.05),(x,.070,2.67),(x,.025,2.67)])
    # Narrow web with 20 mm slots at 100 mm spacing.
    for j in range(28):
        lo=-.05+j*.10;hi=min(lo+.10,2.67)
        if hi<=lo:continue
        for a,b in [(-.032,-.010),(.010,.032)]:quad([(a,.025,lo),(b,.025,lo),(b,.025,hi),(a,.025,hi)])
        quad([(-.010,.025,lo),(.010,.025,lo),(.010,.025,min(hi,lo+.076)),(-.010,.025,min(hi,lo+.076))])
    mesh(kind+'_punched_post',pv,pf,steel)
    for z in [2.08,2.43]:
        cube('mounting_saddle',(0,.023,z),(.12,.032,.04),steel,.002)
        bolt(0,z);bolt(0,z,False)
    # A fine asymmetric snow ridge catches on the physical top lip.
    top=2.25+height/2
    if kind=='speed':
        cube('snow_on_top',(-.055,-.002,top+.008),(.43,.031,.017),snow,.005)
    else:
        for side in [-1,1]:
            a=outline[2];b=outline[1 if side==1 else 3]
            a=(a[0]*.985,a[1]*.985);b=(a[0]+(b[0]*.985-a[0])*.38,a[1]+(b[1]*.985-a[1])*.38)
            vx=b[0]-a[0];vz=b[1]-a[1];length=math.hypot(vx,vz)
            obj=cube('snow_on_rim',((a[0]+b[0])/2,-.001,2.25+(a[1]+b[1])/2+.008),(length,.030,.014),snow,.003)
            obj.rotation_euler.y=-math.atan2(vz,vx)
    objects=list(set(bpy.data.objects)-before)
    # Four draw surfaces per assembly, rather than one per small bolt/bracket.
    for mat in [steel,edge,snow]:
        group=[obj for obj in objects if len(obj.data.materials)==1 and obj.data.materials[0]==mat]
        if len(group)>1:
            bpy.ops.object.select_all(action='DESELECT')
            for obj in group:obj.select_set(True)
            bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join()
            objects=list(set(bpy.data.objects)-before)
    objects=list(set(bpy.data.objects)-before)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    path=OUT/f'{kind}.glb'
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_apply=True)
    triangles=0;vertices=0
    for obj in objects:
        obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles);vertices+=len(obj.data.vertices)
    models.append({'name':kind,'triangles':triangles,'vertices':vertices,'width_m':width,'height_m':height,'post_height_m':2.67,'front':'Godot +Z','sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    # Move only the source display row, after canonical origin exports.
    for obj in objects:obj.location.x+=len(models)*1.5
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'winter_road_signs.blend'))
(OUT/'provenance.json').write_text(json.dumps({'origin':'Original Blender roadside assemblies','generator':'tools/blender/gen_road_signs.py','units':'metres','models':models},indent=2)+'\n')
print('ROAD_SIGN_MODELS',models)
