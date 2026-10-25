"""New original human geometry, from an empty scene. Metres, Godot Y up/-Z face.
No legacy meshes imported. Shared 45-bone body/garment contract for civilian and infected use.
"""
from pathlib import Path
import bpy, bmesh, math, json, hashlib, numpy as np
from mathutils import Vector
R=Path(__file__).resolve().parents[2];OUT=R/'tools/blender/generated/modular_human';RT=R/'brave-and-cold/assets/modular_human'
OUT.mkdir(parents=True,exist_ok=True);RT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
def cv(v):return Vector((v[0],-v[2],v[1]))
def active(o):
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def gauss(x,y,cx,cy,sx,sy):return math.exp(-((x-cx)/sx)**2-((y-cy)/sy)**2)
def material(name,col,rough=.8):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*col,1)
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*col,1);p.inputs['Roughness'].default_value=rough
 return m
skin=material('HumanSkin',(1,1,1),.62);eye=material('HumanEye',(1,1,1),.38)
cloth=material('HumanJacket',(1,1,1),.88);pants=material('HumanTrousers',(.10,.115,.125),.91)
boot=material('HumanBootLeather',(.065,.050,.035),.77);binding=material('HumanBindings',(.08,.07,.05),.86)
capmat=material('HumanKnitCap',(.09,.022,.013));apronmat=material('HumanApron',(.14,.10,.055))
def image(name,fn,size=512,non_color=False):
 im=bpy.data.images.new(name,width=size,height=size,alpha=True);pix=[]
 if non_color:im.colorspace_settings.name='Non-Color'
 for py in range(size):
  for px in range(size):pix.extend((*fn(px/(size-1),py/(size-1),px,py),1))
 im.pixels[:]=pix;im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();im.pack();return im
def skin_pixel(u,v,x,y):
 # Warm colour variation and restrained pores. Face UV is planar; spare lower
 # atlas strip supplies hands/neck, avoiding painted features on fingers.
 xx=(u-.5)*.21;yy=1.49+v*.32
 noise=.010*math.sin(x*2.61+y*.79)*math.sin(y*1.63-x*.13)+.006*math.sin(x*.064)*math.cos(y*.041)
 cheek=gauss(xx,yy,-.049,1.649,.030,.032)+gauss(xx,yy,.049,1.649,.030,.032)
 lips=gauss(xx,yy,0,1.618,.032,.009)
 socket=gauss(xx,yy,-.033,1.692,.027,.015)+gauss(xx,yy,.033,1.692,.027,.015)
 beard=gauss(xx,yy,0,1.600,.062,.036)*(.02+.006*math.sin(x*2.2+y*3.8))
 brows=gauss(xx,yy,-.033,1.710,.023,.002)+gauss(xx,yy,.033,1.710,.023,.002)
 nostrils=gauss(xx,yy,-.011,1.649,.003,.0025)+gauss(xx,yy,.011,1.649,.003,.0025)
 detail=.16*brows+.11*nostrils
 return (.38+noise+cheek*.022-lips*.018-socket*.020-beard-detail,.225+noise-cheek*.010-lips*.038-socket*.024-beard-detail*.70,.155+noise-cheek*.012-lips*.031-socket*.023-beard-detail*.55)
skinmap=image('human_skin_albedo',skin_pixel,1024)
skintex=skin.node_tree.nodes.new('ShaderNodeTexImage');skintex.image=skinmap;skin.node_tree.links.new(skintex.outputs['Color'],skin.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
def cloth_pixel(u,v,x,y):
 weave=.010*(math.sin(x*math.pi*.5)+math.sin(y*math.pi*.5));wear=.018*math.sin(x*.11)*math.cos(y*.07)
 return (.105+weave*.28+wear,.142+weave*.28+wear,.098+weave*.28+wear)
clothmap=image('human_canvas_albedo',cloth_pixel)
tex=cloth.node_tree.nodes.new('ShaderNodeTexImage');tex.image=clothmap;cloth.node_tree.links.new(tex.outputs['Color'],cloth.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
normal=image('human_canvas_normal',lambda u,v,x,y:(.5+.014*math.sin(x*math.pi*.5),.5+.014*math.sin(y*math.pi*.5),.995),non_color=True)
normal.colorspace_settings.name='Non-Color';nt=cloth.node_tree.nodes.new('ShaderNodeTexImage');nt.image=normal
nm=cloth.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.4;cloth.node_tree.links.new(nt.outputs['Color'],nm.inputs['Color']);cloth.node_tree.links.new(nm.outputs['Normal'],cloth.node_tree.nodes.get('Principled BSDF').inputs['Normal'])
eyemap=image('human_eye_albedo',lambda u,v,x,y:((.55,.56,.52) if math.hypot(u-.5,v-.5)>.18 else ((.004,.004,.005) if math.hypot(u-.5,v-.5)<.075 else (.09+.015*math.sin(math.atan2(v-.5,u-.5)*67),.065+.015*math.sin(math.atan2(v-.5,u-.5)*67),.033))))
et=eye.node_tree.nodes.new('ShaderNodeTexImage');et.image=eyemap;eye.node_tree.links.new(et.outputs['Color'],eye.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
defs={'pelvis':((0,.92,0),(0,1.02,0),None),'spine':((0,1.02,0),(0,1.49,0),'pelvis'),'head':((0,1.49,0),(0,1.80,0),'spine')}
for s,side in [(-1,'l'),(1,'r')]:
 defs['skin_zombie_leg_'+side]=((s*.10,.92,0),(s*.10,.48,.01),'pelvis')
 defs['skin_zombie_knee_'+side]=((s*.10,.48,.01),(s*.10,.09,-.015),'skin_zombie_leg_'+side)
 defs['skin_zombie_arm_'+side]=((s*.260,1.42,0),(s*.300,1.12,.012),'spine')
 defs['skin_zombie_elbow_'+side]=((s*.300,1.12,.012),(s*.285,.84,-.006),'skin_zombie_arm_'+side)
for s,side in [(-1,'l'),(1,'r')]:defs['skin_zombie_ankle_'+side]=((s*.10,.09,-.015),(s*.10,.09,-.18),'skin_zombie_knee_'+side)
finger_paths={}
for s,side in [(-1,'l'),(1,'r')]:
 defs['wrist_'+side]=((s*.285,.84,-.006),(s*.287,.748,-.008),'skin_zombie_elbow_'+side)
 for digit,offset,length in [('index',-.026,.088),('middle',-.008,.099),('ring',.011,.092),('little',.028,.073)]:
  x=s*(.287+offset);start=.752
  path=[(x,start,-.008),(x,start-length*.46,-.010),(x,start-length*.76,-.020),(x,start-length,-.033)];finger_paths[side,digit]=path
 for digit in ['thumb']:
  path=[(s*.254,.807,-.006),(s*.240,.780,-.017),(s*.234,.754,-.025),(s*.241,.730,-.032)];finger_paths[side,digit]=path
 for digit in ['index','middle','ring','little','thumb']:
  path=finger_paths[side,digit]
  for i in range(3):defs[f'{digit}_{i+1}_{side}']=(path[i],path[i+1],'wrist_'+side if i==0 else f'{digit}_{i}_{side}')
data=bpy.data.armatures.new('HumanFoundationDeformation');rig=bpy.data.objects.new('HumanFoundationRig',data);bpy.context.collection.objects.link(rig);active(rig);bpy.ops.object.mode_set(mode='EDIT')
for name,(h,t,parent) in defs.items():
 b=data.edit_bones.new(name);b.head=cv(h);b.tail=cv(t)
 if parent:b.parent=data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
for side in ['l','r']:
 for prefix in ['zombie_arm_','zombie_elbow_','zombie_leg_','zombie_knee_']:
  o=bpy.data.objects.new(prefix+side,None);bpy.context.collection.objects.link(o);o.location=cv(defs['skin_'+prefix+side][0])
modules={};full=[];finished_hands=[]
def mesh(name,vs,fs,ma,module):
 me=bpy.data.meshes.new(name);me.from_pydata([cv(v) for v in vs],[],fs);me.update()
 o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);me.materials.append(ma)
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
 for f in me.polygons:f.use_smooth=True
 modules.setdefault(module,[]).append(o);return o
def loft(name,rows,ma,module,n=32,fold=0):
 vs=[];fs=[]
 for j,(x,y,z,rx,rz) in enumerate(rows):
  for k in range(n):
   a=k*math.tau/n;wr=fold*math.sin(5*a+j*.8);vs.append((x+(rx+wr)*math.cos(a),y,z+(rz+wr)*math.sin(a)))
 for j in range(len(rows)-1):
  for k in range(n):fs.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
 fs.extend([tuple(reversed(range(n))),tuple((len(rows)-1)*n+k for k in range(n))]);return mesh(name,vs,fs,ma,module)
def skin_weights(o,fn):
 groups={n:o.vertex_groups.new(name=n) for n in defs}
 for v in o.data.vertices:
  ws=fn(v.co.x,v.co.z,-v.co.y);total=sum(ws.values())
  for n,w in ws.items():
   if w>1e-7:groups[n].add([v.index],w/total,'REPLACE')
 o.parent=rig;o.modifiers.new('HumanDeformation','ARMATURE').object=rig
 uv=o.data.uv_layers.new(name='HumanUV')
 for loop in o.data.loops:
  v=o.data.vertices[loop.vertex_index].co;x,y,z=v.x,v.z,-v.y
  uv.data[loop.index].uv=((x/.21+.5,(y-1.49)/.32) if o.data.materials[0]==skin and y>1.49 and z<.015 else ((.04,.02) if o.data.materials[0]==skin else (x*3+z*2,y*3)))
def torso_weight(x,y,z):
 t=smooth(.98,1.14,y);return {'spine':t,'pelvis':1-t}
def coat_weight(x,y,z):
 side='l' if x<0 else 'r';shoulder=smooth(.12,.27,abs(x))*(1-smooth(1.40,1.515,y));blend=smooth(1.32,1.40,y);arm=smooth(.204,.223,abs(x))*(1-blend)+shoulder*blend;lower=1-smooth(1.05,1.18,y)
 t=smooth(.98,1.14,y);return {'spine':(1-arm)*t,'pelvis':(1-arm)*(1-t),'skin_zombie_arm_'+side:arm*(1-lower),'skin_zombie_elbow_'+side:arm*lower}
def join_remesh(obs,name,voxel,budget):
 active(obs[0])
 for o in obs:o.select_set(True)
 bpy.ops.object.join();o=bpy.context.object;o.name=name
 rem=o.modifiers.new('Continuous anatomical volume','REMESH');rem.mode='VOXEL';rem.voxel_size=voxel;rem.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=rem.name)
 sm=o.modifiers.new('Relax surface','SMOOTH');sm.factor=.35;sm.iterations=3;bpy.ops.object.modifier_apply(modifier=sm.name)
 de=o.modifiers.new('Retain bounded silhouette','DECIMATE');de.ratio=min(1,budget/max(1,sum(len(p.vertices)-2 for p in o.data.polygons)));bpy.ops.object.modifier_apply(modifier=de.name)
 return o
torso=[(0,.925,.015,.169,.113),(0,1.00,.008,.163,.106),(0,1.10,.005,.151,.099),(0,1.21,.005,.172,.119),(0,1.31,.009,.175,.119),(0,1.36,.007,.189,.111),(0,1.39,.005,.207,.100),(0,1.43,0,.205,.088),(0,1.46,0,.157,.074),(0,1.485,0,.073,.065),(0,1.51,.005,.046,.046)]
o=loft('AnatomicalTorso',torso,skin,'Anatomy',48);skin_weights(o,torso_weight);full.append(o)
for s,side in [(-1,'l'),(1,'r')]:
 armrows=[(s*.226,1.445,0,.022,.030),(s*.236,1.432,0,.044,.054),(s*.270,1.407,0,.060,.066),(s*.293,1.37,.002,.060,.063),(s*.301,1.35,.004,.054,.057),(s*.300,1.24,.008,.050,.047),(s*.300,1.12,.012,.038,.038),(s*.296,1.04,.007,.046,.041),(s*.290,.95,0,.037,.034),(s*.285,.84,-.006,.024,.025)]
 o=loft('AnatomicalArm_'+side,armrows,skin,'Anatomy',32);skin_weights(o,coat_weight);full.append(o)
 legrows=[(s*.10,.95,.012,.089,.099),(s*.10,.84,.015,.090,.089),(s*.10,.69,.011,.074,.073),(s*.10,.55,.009,.055,.055),(s*.10,.48,.01,.047,.046),(s*.10,.39,.006,.059,.057),(s*.10,.27,.002,.047,.046),(s*.10,.15,-.01,.028,.029),(s*.10,.09,-.015,.027,.028)]
 def leg_weight(x,y,z,side=side):
  hip=smooth(.85,.98,y);knee=1-smooth(.43,.54,y)
  return {'pelvis':hip,'skin_zombie_leg_'+side:(1-hip)*(1-knee),'skin_zombie_knee_'+side:(1-hip)*knee}
 o=loft('AnatomicalLeg_'+side,legrows,skin,'Anatomy',32);skin_weights(o,leg_weight);full.append(o)
 # Clothing is a separate fitted layer, not colour applied to bare cylinders.
 jacket=[]
 for x,y,z,rx,rz in torso:jacket.append((x,y,z,rx+.018,rz+.016))
 if side=='l':coatparts=[loft('JacketTorso',jacket,cloth,'Jacket',48,.0018)]
 coatparts.append(loft('JacketSleeve_'+side,[(x,y,z,rx+.014,rz+.014) for x,y,z,rx,rz in armrows],cloth,'Jacket',32,.0014))
 trouser=loft('TrouserLeg_'+side,[(x,y,z,rx+.011-(.018 if y>=.90 else 0),rz+.012) for x,y,z,rx,rz in legrows if y>=.15],pants,'Trousers',32,.0014);skin_weights(trouser,leg_weight)
 # Hands: integrated palm, webbing and tapering fingers, all newly constructed.
 palm=loft('Palm_'+side,[(s*.285,.845,-.006,.024,.025),(s*.287,.82,-.007,.030,.023),(s*.288,.79,-.007,.038,.019),(s*.288,.76,-.003,.040,.015),(s*.288,.746,0,.034,.010)],skin,'Hands',32)
 handparts=[palm]
 for digit in ['index','middle','ring','little','thumb']:
  path=finger_paths[side,digit];rad=.009 if digit=='thumb' else (.0072 if digit=='little' else .0083)
  rows=[]
  for j,p in enumerate(path):
   rows.append((*p,rad*(1-j*.13),rad*(.91-j*.10)))
   if j<3:
    mid=(Vector(p)+Vector(path[j+1]))*.5;rows.append((*mid,rad*(.96-j*.13),rad*(.84-j*.10)))
  end=Vector(path[-1]);end.y-=.003;rows.append((*end,.002,.002))
  handparts.append(loft(digit+'Surface_'+side,rows,skin,'Hands',20))
 hand=join_remesh(handparts,'AnatomicalHand_'+side,.0025,3800)
 finished_hands.append(hand)
 modules['Hands']=list(finished_hands)
 def hand_weight(x,y,z,side=side):
  p=Vector((x,y,z));candidates=[]
  for digit in ['index','middle','ring','little','thumb']:
   path=finger_paths[side,digit]
   for i in range(3):
    a,b=Vector(path[i]),Vector(path[i+1]);d=b-a;t=max(0,min(1,(p-a).dot(d)/d.length_squared));dist=(p-(a+t*d)).length
    candidates.append((dist,f'{digit}_{i+1}_{side}'))
  candidates.sort();digit=next(n.split('_')[0] for _,n in candidates if not n.startswith('thumb'))
  # A smooth thumb/web field, rather than switching joints at an arbitrary
  # closest-surface boundary through the continuous thumb-index webbing.
  tf=(1-smooth(.242,.274,abs(x)))*(1-smooth(.790,.824,y));web=smooth(.732,.760,y)
  tf=(1 if candidates[0][1].startswith('thumb') else 0)*(1-web)+tf*web
  ff=1-smooth(.748,.784,y);weights={'wrist_'+side:(1-tf)*(1-ff)}
  for name,amount in [(digit,(1-tf)*ff),('thumb',tf)]:
   path=finger_paths[side,name];pip=smooth(path[1][1]+.020,path[1][1]-.020,y);dip=smooth(path[2][1]+.014,path[2][1]-.014,y)
   for j,w in enumerate([(1-pip)*(1-dip),pip*(1-dip),dip]):weights[f'{name}_{j+1}_{side}']=amount*w
  return dict(sorted(weights.items(),key=lambda it:it[1],reverse=True)[:4])
 skin_weights(hand,hand_weight)
 # Sole datum matches the established world-space ankle solver exactly.
 vs=[];fs=[];n=32
 for z,rx,cy,ry in [(-.203,.002,.047,.008),(-.192,.035,.056,.032),(-.159,.063,.066,.048),(-.09,.070,.078,.058),(-.028,.065,.105,.077),(.04,.057,.121,.104),(.078,.047,.080,.067)]:
  for k in range(n):a=k*math.tau/n;vs.append((s*.1+rx*math.cos(a),max(.0115,cy+ry*math.sin(a)-.019),z))
 for j in range(6):
  for k in range(n):fs.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
 fs += [tuple(reversed(range(n))),tuple(6*n+k for k in range(n))]
 shoe=mesh('FittedBoot_'+side,vs,fs,boot,'Boots');skin_weights(shoe,lambda x,y,z,side=side:{'skin_zombie_ankle_'+side:1})
 foot=mesh('AnatomicalFoot_'+side,[(s*.1+(x-s*.1)*.87,max(.020,.09+(y-.09)*.82),z*.92) for x,y,z in vs],fs,skin,'Anatomy');skin_weights(foot,lambda x,y,z,side=side:{'skin_zombie_ankle_'+side:1});full.append(foot)
coat=join_remesh(coatparts,'FittedWinterJacket',.0065,6500);modules['Jacket']=[coat];skin_weights(coat,coat_weight)
pelvis=loft('TrouserSeat',[(0,.865,.018,.159,.105),(0,.92,.016,.180,.117),(0,.975,.012,.173,.113),(0,1.005,.01,.167,.109)],pants,'Trousers',48,.0015)
# Remesh before skinning the joined garment; remove old modifiers/groups once.
tr=join_remesh(modules['Trousers'],'ContinuousFittedTrousers',.006,4400);modules['Trousers']=[tr]
tr.modifiers.clear();tr.vertex_groups.clear()
def pants_weight(x,y,z):
 hip=max(smooth(.76,.95,y),(1-smooth(.025,.155,abs(x)))*smooth(.64,.775,y));cross=smooth(.76,.85,y);right=(1 if x>0 else 0)*(1-cross)+smooth(-.075,.075,x)*cross;knee=1-smooth(.41,.56,y)
 return {'pelvis':hip,'skin_zombie_leg_l':(1-hip)*(1-right)*(1-knee),'skin_zombie_leg_r':(1-hip)*right*(1-knee),'skin_zombie_knee_l':(1-hip)*(1-right)*knee,'skin_zombie_knee_r':(1-hip)*right*knee}
skin_weights(tr,pants_weight)
# Facially structured continuous surface; actual eye openings, not black paint.
profile=[(1.485,.047,.047,.008),(1.54,.047,.050,.008),(1.566,.053,.056,.006),(1.59,.067,.064,.006),(1.62,.074,.070,.008),(1.65,.079,.074,.009),(1.69,.081,.079,.013),(1.73,.079,.083,.016),(1.77,.062,.071,.015),(1.80,.027,.039,.011),(1.806,.002,.003,.01)]
def face_z(x,y):
 at=next((i for i in range(len(profile)-1) if profile[i][0]<=y<=profile[i+1][0]),len(profile)-2)
 lo,hi=profile[at],profile[at+1];t=(y-lo[0])/(hi[0]-lo[0]);rx,rz,zc=[lo[k]*(1-t)+hi[k]*t for k in [1,2,3]]
 si=-math.sqrt(max(0,1-(x/rx)**2));z=zc+si*rz;front=(-si)**6
 def g(cx,cy,sx,sy):return gauss(x,y,cx,cy,sx,sy)
 nose=.024*g(0,1.658,.014,.016)+.012*g(0,1.687,.012,.025)+.007*(g(-.012,1.651,.007,.006)+g(.012,1.651,.007,.006))
 socket=.004*(g(-.033,1.694,.023,.012)+g(.033,1.694,.023,.012));brow=.006*(g(-.032,1.712,.025,.006)+g(.032,1.712,.025,.006))
 cheek=.005*(g(-.047,1.657,.023,.018)+g(.047,1.657,.023,.018));lips=.0035*g(0,1.622,.028,.004)+.004*g(0,1.614,.027,.004)-.003*g(0,1.618,.029,.0018)
 chin=.005*g(0,1.589,.035,.009)
 return z-front*(nose+brow+cheek+lips+chin-socket)
vs=[];fs=[];n=96;nr=86
for j in range(nr):
 y=1.485+j/(nr-1)*.321;at=next((i for i in range(len(profile)-1) if profile[i][0]<=y<=profile[i+1][0]),len(profile)-2)
 lo,hi=profile[at],profile[at+1];t=(y-lo[0])/(hi[0]-lo[0]);rx,rz,zc=[lo[k]*(1-t)+hi[k]*t for k in [1,2,3]]
 for k in range(n):
  a=k*math.tau/n;x=math.cos(a)*rx;z=zc+math.sin(a)*rz;front=max(0,-math.sin(a))**6
  if math.sin(a)<0:z=face_z(x,y)
  vs.append((x,y,z))
for j in range(nr-1):
 for k in range(n):
  ids=(j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k);p=sum((Vector(vs[i]) for i in ids),Vector())/4
  hole=p.z<-.040 and min(((p.x-s*.033)/.015)**2+((p.y-1.694)/.0055)**2 for s in [-1,1])<.82
  if not hole:fs.append(ids)
fs += [tuple(reversed(range(n))),tuple((nr-1)*n+k for k in range(n))]
head=mesh('AnatomicalHeadNeck',vs,fs,skin,'Head');skin_weights(head,lambda x,y,z:{'head':smooth(1.50,1.55,y),'spine':1-smooth(1.50,1.55,y)})
# Ears with a helix ridge and recessed bowl on the same head rig.
for s,side in [(-1,'l'),(1,'r')]:
 rows=[(s*.078,1.625,.010,.005,.012),(s*.085,1.637,.015,.010,.016),(s*.089,1.658,.018,.010,.019),(s*.085,1.677,.018,.008,.014),(s*.081,1.685,.014,.003,.006)]
 ear=loft('Ear_'+side,rows,skin,'Head',24);skin_weights(ear,lambda x,y,z:{'head':1})
 # Visible eye front is an oval cap with a radial iris UV; eyelids cover its edges.
 vs=[(s*.033,1.694,face_z(s*.033,1.694)-.004)];fs=[];segments=48;rings=8
 for j in range(1,rings+1):
  r=j/rings
  for k in range(segments):
   a=k*math.tau/segments;x=s*.033+r*.015*math.cos(a);y=1.694+r*.0055*math.sin(a);z=face_z(x,y)-.001-.002*math.sqrt(max(0,1-r*r));vs.append((x,y,z))
 for k in range(segments):fs.append((0,1+k,1+(k+1)%segments))
 for j in range(rings-1):
  for k in range(segments):fs.append((1+j*segments+k,1+j*segments+(k+1)%segments,1+(j+1)*segments+(k+1)%segments,1+(j+1)*segments+k))
 e=mesh('Eye_'+side,vs,fs,eye,'Eyes');skin_weights(e,lambda x,y,z:{'head':1})
 for loop in e.data.loops:
  v=e.data.vertices[loop.vertex_index].co;e.data.uv_layers.active.data[loop.index].uv=((v.x-s*.033)/.037+.5,(v.z-1.694)/.037+.5)
 # Model lids around the opening; cover the cut edge without floating eyeballs.
 vs=[];fs=[]
 for j in range(5):
  r=.87+j*.095
  for k in range(segments):
   a=k*math.tau/segments;x=s*.033+r*.015*math.cos(a);y=1.694+r*.0055*math.sin(a)
   vs.append((x,y,face_z(x,y)-.0012-.0014*math.sin(j*math.pi/4)))
 for j in range(4):
  for k in range(segments):fs.append((j*segments+k,j*segments+(k+1)%segments,(j+1)*segments+(k+1)%segments,(j+1)*segments+k))
 lid=mesh('Eyelids_'+side,vs,fs,skin,'Head');skin_weights(lid,lambda x,y,z:{'head':1})
# Structured cap and apron: independent removable modules on the shared rig.
hat=loft('KnitCap',[(0,1.715,.01,.084,.087),(0,1.733,.014,.086,.087),(0,1.775,.012,.068,.075),(0,1.815,.01,.027,.038),(0,1.82,.01,.002,.003)],capmat,'Cap',48,.0006);skin_weights(hat,lambda x,y,z:{'head':1})
vs=[];fs=[];cols=16;rows=20
for j in range(rows):
 y=.90+j/(rows-1)*.46;half=.151 if y<1.22 else .151-(y-1.22)*.40
 at=next((i for i in range(len(torso)-1) if torso[i][1]<=y<=torso[i+1][1]),0)
 lo,hi=torso[at],torso[at+1];t=max(0,min(1,(y-lo[1])/(hi[1]-lo[1])));rx=lo[3]*(1-t)+hi[3]*t+.018;rz=lo[4]*(1-t)+hi[4]*t+.016;zc=lo[2]*(1-t)+hi[2]*t
 for k in range(cols):
  x=(k/(cols-1)*2-1)*half;z=zc-rz*math.sqrt(max(0,1-(x/rx)**2))-.006-.0025*math.sin(k*.8+j*.2)
  vs.append((x,y,z))
for j in range(rows-1):
 for k in range(cols-1):fs.append((j*cols+k,j*cols+k+1,(j+1)*cols+k+1,(j+1)*cols+k))
ap=mesh('DrapedShopApron',vs,fs,apronmat,'Apron');skin_weights(ap,torso_weight)
# Sewn front placket and breast pocket. Same rig, one extra material surface.
vs=[];fs=[]
for j,(x,y,z,rx,rz) in enumerate(jacket[:-1]):
 for sign in [-1,1]:vs.append((sign*.007,y,z-rz-.002))
for j in range(len(jacket)-2):fs.append((2*j,2*j+1,2*j+3,2*j+2))
pl=mesh('JacketPlacket',vs,fs,binding,'Jacket');skin_weights(pl,torso_weight)
def relax_weights(o,iterations=44):
 n=len(o.data.vertices);w=np.zeros((n,len(defs)),dtype=np.float64)
 for v in o.data.vertices:
  for g in v.groups:w[v.index,g.group]=g.weight
 edges=np.array([e.vertices[:] for e in o.data.edges]);a=edges[:,0];b=edges[:,1]
 counts=np.bincount(np.concatenate((a,b)),minlength=n).clip(1)[:,None]
 for _ in range(iterations):
  near=np.zeros_like(w);np.add.at(near,a,w[b]);np.add.at(near,b,w[a]);w=w*.35+near/counts*.65
 keep=np.argsort(w,axis=1)[:,-4:];filtered=np.zeros_like(w);np.put_along_axis(filtered,keep,np.take_along_axis(w,keep,axis=1),axis=1);filtered/=filtered.sum(axis=1)[:,None]
 for group in o.vertex_groups:group.remove(range(n))
 for i,row in enumerate(filtered):
  for j in np.flatnonzero(row>1e-7):o.vertex_groups[int(j)].add([i],float(row[j]),'REPLACE')
relax_weights(coat,80)
# Consolidate each removable module; retain all bone groups and UVs.
for module,obs in list(modules.items()):
 if module=='Anatomy' or len(obs)<2:continue
 active(obs[0])
 for o in obs:o.select_set(True)
 bpy.ops.object.join();o=bpy.context.object;o.name=module;modules[module]=[o]
# Keep skin at hands/head only for clothed exports; underlying body remains editable.
for o in full:o.hide_render=True;o.hide_set(True)
for pb in rig.pose.bones:pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0)
bpy.context.view_layer.update();bpy.ops.file.pack_all()
native=OUT/'human_foundation.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native))
exports=[]
def export(name,include):
 bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
 for o in bpy.context.scene.objects:
  if o.type=='EMPTY':o.select_set(True)
 selected=[]
 for module in include:
  for o in modules[module]:
   if o.name not in bpy.data.objects:continue
   o.hide_set(False);o.select_set(True);selected.append(o)
 path=RT/(name+'.glb');bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_skins=True,export_animations=False)
 tris=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in selected);surfaces=sum(len(o.data.materials) for o in selected)
 assert tris<=40000 and surfaces<=10,(name,tris,surfaces)
 exports.append({'id':name,'triangles':tris,'surfaces':surfaces,'modules':include,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
default=['Head','Eyes','Hands','Jacket','Trousers','Boots']
export('rowan',default+['Cap','Apron'])
# Independent texture maps guarantee real colour variants in exported bytes.
def tint_cloth(name,col):
 im=clothmap.copy();im.name=name;p=list(clothmap.pixels[:])
 for i in range(0,len(p),4):
  for j in range(3):p[i+j]=min(1,p[i+j]*col[j])
 im.pixels[:]=p;im.pack();tex.image=im
tint_cloth('sam_canvas',( .85,1.12,1.32));export('sam',default)
tint_cloth('lin_canvas',(1.30,.92,.73));export('lin',default)
tint_cloth('infected_canvas',(.75,.83,.75))
infectedmap=skinmap.copy();infectedmap.name='human_infected_skin';p=list(skinmap.pixels[:])
for i in range(0,len(p),4):
 grey=sum(p[i:i+3])/3
 for j,factor in enumerate([.84,.96,.86]):p[i+j]=grey*factor
infectedmap.pixels[:]=p;infectedmap.pack();skintex.image=infectedmap
export('infected_preview',default)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
(RT/'manifest.json').write_text(json.dumps({'license':'Original anatomy, geometry and procedural textures authored from an empty Blender scene; no imported meshes','blender':bpy.app.version_string,'units':'metres; Y up / -Z front after export','native_sha256':sha(native),'generator_sha256':sha(Path(__file__)),'bones':list(defs),'modules':list(modules),'exports':exports,'textures':{p.name:sha(p) for p in OUT.glob('*.png')}},indent=2)+'\n')
print('MODULAR_HUMAN_EXPORTED',json.dumps(exports),flush=True)
