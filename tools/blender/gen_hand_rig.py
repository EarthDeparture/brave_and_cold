"""Continuous quad hand topology, articulated fingers and original painted gloves.

Blender --background --factory-startup --python-exit-code 1 --python FILE -- --output-dir DIR
Two anatomical hands with properly mirrored topology and bone poses.
Metres, neutral wrist at zero, dorsal +Y, fingers -Z, forearm +Z (Godot).
"""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
from types import SimpleNamespace

import bpy
import bmesh
from mathutils import Vector, Quaternion, Euler

sys.path.insert(0, str(Path(__file__).resolve().parent))
import hand_materials as paint
from gen_survivor_hands import blender, material, sleeve

NAMES = ['index', 'middle', 'ring', 'little']
LENGTHS = [(.039,.024,.018), (.044,.027,.019), (.041,.025,.018), (.032,.019,.016)]
MCP = [-.081, -.086, -.080, -.068]
XS = [-.040,-.030,-.020,-.010,0,.010,.020,.030,.039]
RADII = [.0090,.0095,.0089,.0078]


class Hand:
    def __init__(self):
        self.v, self.f, self.w = [], [], []
        self.bones = {'hand': ((0,0,.012), (0,0,-.050), None)}
        self.digits = []

    def vertex(self, p, weights=None):
        self.v.append(Vector(p)); self.w.append(weights or {'hand':1.0})
        return len(self.v)-1

    def quad(self, a,b,c,d): self.f.append((a,b,c,d))

    def palm(self):
        self.top, self.bottom = [], []
        self.zrows = [.012,0,-.012,-.025,-.040,-.054,-.067,-.076]
        widths = [.57,.59,.67,.79,.92,1,1,1]
        for row,z in enumerate(self.zrows):
            t,b = [],[]
            for col,x0 in enumerate(XS):
                x = x0*widths[row]
                # Staggered MCP row: fingertip lengths and knuckles are not a box.
                zz = z if row < 7 else (MCP[min(col//2,3)] if col%2 else
                    (MCP[0]+.005 if col==0 else MCP[3]+.005 if col==8 else (MCP[col//2-1]+MCP[col//2])*.5+.007))
                cross = math.sqrt(max(0,1-(x0/.049)**2))
                # Rounded metacarpal arch with individual tendon ridges. The
                # lateral contour drops toward the web rather than forming a
                # flat rectangular slab between the wrist and finger roots.
                dorsal = .004 + .010*cross + .002*math.sin(row/7*math.pi)
                dorsal += .006*math.exp(-((zz+.077)/.011)**2)*(.30+.70*(col%2))
                for tendon in [-.030,-.010,.010,.030]:
                    dorsal += .0022*math.exp(-((x0-tendon)/.007)**2-((zz+.046)/.027)**2)
                # Thenar and hypothenar pads are part of the palm surface.
                pad = .007*math.exp(-((x+.025)/.020)**2-((zz+.034)/.026)**2)
                pad += .004*math.exp(-((x-.026)/.020)**2-((zz+.050)/.029)**2)
                volar = -.006 - .008*cross - pad
                t.append(self.vertex((x,dorsal,zz)))
                b.append(self.vertex((x,volar,zz)))
            self.top.append(t); self.bottom.append(b)
        for row in range(7):
            for col in range(8):
                self.quad(self.top[row][col],self.top[row+1][col],self.top[row+1][col+1],self.top[row][col+1])
                self.quad(self.bottom[row][col+1],self.bottom[row+1][col+1],self.bottom[row+1][col],self.bottom[row][col])
        self.side = {}
        for col in [0,8]:
            mids = [self.vertex((self.v[self.top[r][col]]+self.v[self.bottom[r][col]])*.5) for r in range(8)]
            self.side[col] = mids
            for r in range(7):
                if col==0 and r in [2,3]: continue # Thumb opening, not an intersecting attached tube.
                self.quad(self.top[r][col],self.top[r+1][col],mids[r+1],mids[r])
                self.quad(mids[r],mids[r+1],self.bottom[r+1][col],self.bottom[r][col])
        # Wrist cap stays hidden within sleeve; closes the skin volume.
        self.f.append(tuple(self.top[0]+[self.side[8][0]]+list(reversed(self.bottom[0]))+[self.side[0][0]]))
        self.endmids = [self.side[0][-1]]
        for col in [2,4,6]:
            self.endmids.append(self.vertex((self.v[self.top[-1][col]]+self.v[self.bottom[-1][col]])*.5))
        self.endmids.append(self.side[8][-1])

    def digit(self, name, root, centers, lengths, radius, ref=(1,0,0)):
        # Three bend joints, extra loops on each side of the creases.
        centers = [Vector(p) for p in centers]
        parent='hand'
        for j in range(3):
            bone=name+'_'+str(j+1).zfill(2)
            self.bones[bone]=(tuple(centers[j]),tuple(centers[j+1]),parent)
            parent=bone
        self.digits.append((centers,radius))
        # The web and dorsal MCP skin follow both the palm and adjacent digit.
        # Shared crotch vertices keep contributions from both neighbouring fingers.
        for index in root:
            self.w[index]['hand']-=.20
            self.w[index][name+'_01']=.20
        prev=root
        for segment in range(3):
            a,b=centers[segment:segment+2]
            tangent=(b-a).normalized()
            u=Vector(ref); u=(u-tangent*u.dot(tangent)).normalized()
            v=u.cross(tangent).normalized()
            # Ring ordering matches palm root: dorsal-left through dorsal-right,
            # volar-right through volar-left. Radius tapers along each phalanx.
            for t in [.06,.20,.48,.76,.93,1.0]:
                along=(sum(lengths[:segment])+lengths[segment]*t)/sum(lengths)
                r=radius*(1-.25*along)
                r*=1+.075*math.exp(-(t/.12)**2)+.09*math.exp(-((t-1)/.12)**2)-.05*math.exp(-((t-.5)/.30)**2)
                if segment==2:
                    # Rounded terminal pad, rather than an abrupt cylinder cap.
                    r*=max(.10,math.sqrt(max(0,1-max(0,(t-.63)/.37)**2)))
                center=a.lerp(b,t)
                weights={name+'_'+str(segment+1).zfill(2):1.0}
                blend=.18
                if t<blend:
                    previous='hand' if segment==0 else name+'_'+str(segment).zfill(2)
                    k=.5*(1-t/blend)
                    weights={previous:k,name+'_'+str(segment+1).zfill(2):1-k}
                elif t>1-blend and segment<2:
                    k=.5*(t-(1-blend))/blend
                    weights={name+'_'+str(segment+1).zfill(2):1-k,name+'_'+str(segment+2).zfill(2):k}
                ring=[]
                for k in range(8):
                    angle=math.pi*3/4 - math.tau*k/8
                    # Slightly flatter dorsum and fuller fingertip pads.
                    off=u*(math.cos(angle)*r)+v*(math.sin(angle)*r*.86)
                    ring.append(self.vertex(center+off,weights))
                for k in range(8): self.quad(prev[k],prev[(k+1)%8],ring[(k+1)%8],ring[k])
                prev=ring
        self.f.append(tuple(reversed(prev)))

    def build(self):
        self.palm()
        for j,name in enumerate(NAMES):
            col=j*2
            root=[*self.top[-1][col:col+3],self.endmids[j+1],
                  *reversed(self.bottom[-1][col:col+3]),self.endmids[j]]
            x=XS[col+1]; z=MCP[j]
            p=Vector((x,.001,z)); centers=[p.copy()]
            splay=[-.032,0,.022,.075][j]
            for length in LENGTHS[j]:
                p=p+Vector((splay*length,0,-length)); centers.append(p.copy())
            self.digit(name,root,centers,LENGTHS[j],RADII[j])
        root=[self.top[4][0],self.top[3][0],self.top[2][0],self.side[0][2],
              self.bottom[2][0],self.bottom[3][0],self.bottom[4][0],self.side[0][4]]
        centers=[(-.028,-.001,-.029),(-.054,-.002,-.052),(-.069,-.002,-.075),(-.078,-.001,-.095)]
        lengths=[(Vector(b)-Vector(a)).length for a,b in zip(centers,centers[1:])]
        self.digit('thumb',root,centers,lengths,.0115,ref=(.66,0,-.75))
        mesh=bpy.data.meshes.new('AnatomicalHand');mesh.from_pydata([blender(v) for v in self.v],[],self.f);mesh.update()
        obj=bpy.data.objects.new('BareHand',mesh);bpy.context.collection.objects.link(obj)
        bpy.context.view_layer.objects.active=obj;obj.select_set(True)
        bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
        # Verify shared webs before subdivision, not just overall bounds.
        assert all(e.is_manifold for e in bm.edges), [(e.index,len(e.link_faces)) for e in bm.edges if not e.is_manifold]
        bm.to_mesh(mesh);bm.free()
        for name in self.bones: obj.vertex_groups.new(name=name)
        for i,weights in enumerate(self.w):
            for name,w in weights.items(): obj.vertex_groups[name].add([i],w,'REPLACE')
        sub=obj.modifiers.new('Anatomical quad subdivision','SUBSURF');sub.levels=2
        bpy.ops.object.modifier_apply(modifier=sub.name)
        for vertex in obj.data.vertices:
            total=sum(g.weight for g in vertex.groups)
            for group in list(vertex.groups):
                obj.vertex_groups[group.group].add([vertex.index],min(1.0,group.weight/total),'REPLACE')
        obj.data.validate(verbose=True)
        obj.data.update()
        for p in mesh.polygons: p.use_smooth=True
        for p in obj.data.polygons: p.use_smooth=True
        col=obj.data.color_attributes.new(name='Col',type='FLOAT_COLOR',domain='CORNER')
        for datum in col.data: datum.color=(1,1,1,1)
        return obj


def make_rig(hand,obj,side=1):
    bpy.ops.object.select_all(action='DESELECT')
    arm=bpy.data.armatures.new('SurvivorHandSkeleton');rig=bpy.data.objects.new('HandRig' if side==1 else 'LeftHandRig',arm)
    bpy.context.collection.objects.link(rig);bpy.context.view_layer.objects.active=rig;rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for name,(a,b,parent) in hand.bones.items():
        bone=arm.edit_bones.new(name)
        bone.head=blender((a[0]*side,a[1],a[2]));bone.tail=blender((b[0]*side,b[1],b[2]))
        bone.align_roll(Vector((0,0,1)))
        if parent: bone.parent=arm.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.parent=rig;mod=obj.modifiers.new('Articulated skin','ARMATURE');mod.object=rig
    return rig


PRESETS={
    'Open': ([0,0,0],[0,0,0],0),
    'Fist': ([90,100,40],[25,0,22],-47),
    'Shaft': ([57,73,56],[0,0,55.8],-60.5),
    'Trigger': ([63,70,54],[18,61.3,57.7],17.4),
    'Support': ([45,61,42],[11.5,76.1,62.2],22.9),
    'Bolt': ([61,80,61],[0,11.8,36],-51.3),
}
THUMB_TARGETS={'Fist':[-.01319,-.04137,-.09882],'Shaft':[0,-.018,-.098],
               'Bolt':[-.010,-.022,-.103],'Trigger':[-.047,-.055,-.040],
               'Support':[-.044,-.048,-.033]}


def pose_actions(rig,side=1):
    rig.animation_data_create()
    for name,(fingers,thumb,opposition) in PRESETS.items():
        action=bpy.data.actions.new(name);action.use_fake_user=True
        rig.animation_data.action=action
        for b in rig.pose.bones:
            b.rotation_mode='QUATERNION';b.rotation_quaternion=Quaternion()
        for digit in NAMES:
            for j,angle in enumerate(fingers):
                if name=='Fist':
                    # The shorter little finger must not use the middle
                    # finger's curl: each fingertip settles against its own
                    # palm pad instead of leaving a visible open loop.
                    angle={'index':[90,100,40], 'middle':[90,100,45],
                           'ring':[90,100,35], 'little':[90,90,40]}[digit][j]
                # Straight trigger finger rests alongside guard before firing.
                if name=='Trigger' and digit=='index': angle=[5,15,10][j]
                rig.pose.bones[digit+'_'+str(j+1).zfill(2)].rotation_quaternion=Euler((math.radians(-angle),0,0)).to_quaternion()
                if name=='Trigger' and digit=='index' and j==0:
                    rig.pose.bones['index_01'].rotation_quaternion=Euler((math.radians(-angle),0,math.radians(35*side))).to_quaternion()
        for j,angle in enumerate(thumb):
            rig.pose.bones['thumb_'+str(j+1).zfill(2)].rotation_quaternion=Euler((math.radians(-angle),0,math.radians(opposition*side if j==0 else 0))).to_quaternion()
        for bone in rig.pose.bones:
            bone.keyframe_insert(data_path='rotation_quaternion',frame=1,group=bone.name)
            bone.keyframe_insert(data_path='rotation_quaternion',frame=2,group=bone.name)
        # Export individual actions through NLA strips, no merged animation names.
        track=rig.animation_data.nla_tracks.new();track.name=name
        strip=track.strips.new(name,1,action);strip.name=name
        track.mute=True
    rig.animation_data.action=None
    for b in rig.pose.bones: b.rotation_quaternion=Quaternion()


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output-dir',required=True)
    out=Path(ap.parse_args(sys.argv[sys.argv.index('--')+1:]).output_dir).resolve();out.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    hand=Hand();bare=hand.build();rig=make_rig(hand,bare)
    glove=bare.copy();glove.data=bare.data.copy();glove.name='LeatherGlove';bpy.context.collection.objects.link(glove)
    for v in glove.data.vertices: v.co+=v.normal*.0015
    glove.data.update()
    shape=SimpleNamespace(name='rig_hand',wrist=(0,0,0),digits=hand.digits)
    paint.PALM['rig_hand']=(0,-1,0)
    paint.paint_atlas([bare],[shape],out,'skin')
    paint.paint_atlas([glove],[shape],out,'leather')
    paint.fabric_grain(out)
    sleeves=[sleeve(n).finish(material('survivor_cloth')) for n in ['vm_sleeve_r','vm_sleeve_l']]
    # Reflect vertices and recalculate outward winding in Blender. No negative
    # node scale at runtime: double-sided materials must light both hands alike.
    left=[]
    for src,name in [(bare,'BareHandLeft'),(glove,'LeatherGloveLeft')]:
        obj=src.copy();obj.data=src.data.copy();obj.name=name
        bpy.context.collection.objects.link(obj)
        obj.parent=None;obj.modifiers.clear()
        for v in obj.data.vertices:v.co.x=-v.co.x
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
        bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(obj.data);bm.free()
        obj.data.update();left.append(obj)
    left_rig=make_rig(hand,left[0],-1)
    left[1].parent=left_rig;mod=left[1].modifiers.new('Articulated left skin','ARMATURE');mod.object=left_rig
    pose_actions(rig);pose_actions(left_rig,-1)
    # Normalised, bounded skinning is checked after the subdivision interpolation.
    report={}
    for obj in [bare,glove,*left]:
        for v in obj.data.vertices:
            weights=[g.weight for g in v.groups if g.weight>1e-6]
            assert 1<=len(weights)<=4 and abs(sum(weights)-1)<1e-5,(obj.name,v.index,weights)
        bm=bmesh.new();bm.from_mesh(obj.data)
        assert all(e.is_manifold for e in bm.edges)
        assert all(f.calc_area()>1e-12 for f in bm.faces)
        report[obj.name]={'vertices':len(bm.verts),'triangles':sum(len(f.verts)-2 for f in bm.faces),'closed':True}
        bm.free()
    bpy.ops.object.select_all(action='SELECT')
    if hasattr(bpy.context.preferences.filepaths,'save_preview_images'):
        bpy.context.preferences.filepaths.save_preview_images=False
    glb=out/'survivor_hand_rig.glb'
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,
        export_yup=True,export_apply=False,export_normals=True,export_vertex_color='ACTIVE',
        export_all_vertex_colors=False,export_materials='EXPORT',export_animations=True,
        export_animation_mode='NLA_TRACKS',export_skins=True,export_def_bones=True)
    # Native source opens on one readable bare hand. Hidden variants remain
    # editable, with their own skeletons; the exported package contains all four.
    for obj in [glove,*left,left_rig,*sleeves]:obj.hide_set(True)
    rig.show_in_front=True
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'survivor_hand_rig.blend'))
    receipt={'version':3,'source':'tools/blender/gen_hand_rig.py','blender':bpy.app.version_string,
        'units':'metres','wrist_origin':[0,0,0],'forearm_axis':[0,0,1],
        'bones':list(hand.bones),'grips':list(PRESETS),'validation':report,
        'thumb_targets_godot':THUMB_TARGETS,'thumb_distal_length':(Vector(hand.bones['thumb_03'][1])-Vector(hand.bones['thumb_03'][0])).length,
        'sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),
        'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'material_source_sha256':hashlib.sha256(Path(__file__).with_name('hand_materials.py').read_bytes()).hexdigest(),
        'license':'Project-authored original geometry and procedural textures; repository ownership'}
    (out/'survivor_hand_rig.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print('HAND_RIG_EXPORTED',json.dumps(report),flush=True)


if __name__=='__main__':main()
