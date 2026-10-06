"""Original anatomical skin atlas, with metric-derived tangent-space normals."""
import bpy,math,json,hashlib
import numpy as np
from hand_materials import noise
SIZE=2048
def anatomical_fields(p,n,hand):
    palm=np.clip(-n[:,1],0,1);back=np.clip(n[:,1],0,1)
    fine=noise(p,2300);mottle=noise(p,180);broad=noise(p,48)
    folds=np.zeros(len(p),np.float32);blush=folds.copy();pads=folds.copy()
    for path,r in hand.digits:
        path=np.array([tuple(v) for v in path])
        for j in [1,2]:
            tangent=path[j+1]-path[j-1];tangent/=np.linalg.norm(tangent);d=p-path[j];along=d@tangent
            local=np.exp(-np.sum(d*d,axis=1)/(r*1.45)**2)
            broken=.75+.25*mottle
            crease=np.exp(-((along+(mottle-.5)*.0010)/.00065)**2)
            crease+=.35*np.exp(-((along+.0025)/.0005)**2)
            folds=np.maximum(folds,crease*local*(.30+.70*palm)*broken)
            blush=np.maximum(blush,local*back)
        d=p-path[-1];pads=np.maximum(pads,np.exp(-np.sum(d*d,axis=1)/(r*1.7)**2)*palm)
    x,z=p[:,0],p[:,2];on_palm=((z<-.010)&(z>-.076))*palm
    distal=z+.061-x*.15+(x/.04)**2*.003;proximal=z+.042+x*.26
    thenar=np.sqrt(((x+.031)/.025)**2+((z+.034)/.030)**2)-1
    crease=np.maximum(np.exp(-(distal/.00075)**2),np.exp(-(proximal/.0010)**2)*.65)
    crease=np.maximum(crease,np.exp(-(thenar/.027)**2)*.85)
    folds=np.maximum(folds,crease*on_palm)
    wrist=np.exp(-((z+.0015+.04*x)/.0008)**2)+.55*np.exp(-((z-.006+.035*x)/.0007)**2)
    folds=np.maximum(folds,wrist*palm*((z>-.012)&(z<.015)))
    # Sparse dorsal veins are subtle pigment, not raised tubes or dark outlines.
    vein=np.exp(-((x+.010+z*.15+.0017*np.sin(z*130))/.0012)**2)*back*((z<-.017)&(z>-.068))
    color=np.tile((.405,.275,.225),(len(p),1)).astype('float32')
    color*= (.92+.15*broad+.095*(mottle-.5)+.022*(fine-.5))[:,None]
    color+=palm[:,None]*np.array((.032,.025,.015))+blush[:,None]*np.array((.047,-.007,-.011))
    color+=pads[:,None]*np.array((.014,.003,.001));color-=vein[:,None]*np.array((.007,.001,-.003))
    color*=1-folds[:,None]*.16
    height=(fine-.5)*.000032-folds*.00014
    rough=.57+.075*palm+.025*(mottle-.5)+folds*.035
    return np.clip(color,0,1),height.astype('float32'),np.clip(rough,.48,.72)
def save_map(path,pixels,color=False):
    if pixels.ndim==2:pixels=np.repeat(pixels[:,:,None],3,axis=2)
    if color:pixels=np.where(pixels<=.0031308,pixels*12.92,1.055*np.maximum(pixels,0)**(1/2.4)-.055)
    # Write exact PNG samples as data, then load with the intended colour space.
    image=bpy.data.images.new(path.stem,SIZE,SIZE,alpha=False,is_data=True)
    rgba=np.concatenate((pixels,np.ones((SIZE,SIZE,1),np.float32)),axis=2).astype('float32')
    image.pixels.foreach_set(rgba.ravel());image.filepath_raw=str(path);image.file_format='PNG';image.save()
    bpy.data.images.remove(image);image=bpy.data.images.load(str(path));image.colorspace_settings.name='sRGB' if color else 'Non-Color';image.pack();return image
def paint_skin(obj,hand,out):
    shape=(SIZE,SIZE,3);pmap=np.zeros(shape,'float32');nmap=np.zeros(shape,'float32');du=np.zeros(shape,'float32');dv=np.zeros(shape,'float32');filled=np.zeros((SIZE,SIZE),bool)
    mesh=obj.data;mesh.calc_loop_triangles();uv=mesh.uv_layers.active.data
    for tri in mesh.loop_triangles:
        coords=np.array([tuple(uv[i].uv) for i in tri.loops]);u=coords*SIZE-.5
        lo=np.maximum(np.floor(u.min(0)).astype(int),0);hi=np.minimum(np.ceil(u.max(0)).astype(int),SIZE-1)
        if np.any(lo>hi):continue
        xx,yy=np.meshgrid(np.arange(lo[0],hi[0]+1),np.arange(lo[1],hi[1]+1));a,b=u[1]-u[0],u[2]-u[0];det=a[0]*b[1]-a[1]*b[0]
        if abs(det)<1e-8:continue
        dx,dy=xx-u[0,0],yy-u[0,1];bb=(dx*b[1]-b[0]*dy)/det;cc=(a[0]*dy-dx*a[1])/det;w=np.stack([1-bb-cc,bb,cc],axis=-1);inside=w.min(-1)>=-1e-5
        xs,ys=xx[inside],yy[inside]
        p=np.array([tuple(mesh.vertices[i].co) for i in tri.vertices])[:,[0,2,1]]*np.array([1,1,-1])
        n=np.array([tuple(mesh.vertices[i].normal) for i in tri.vertices])[:,[0,2,1]]*np.array([1,1,-1])
        pmap[ys,xs]=w[inside]@p;nmap[ys,xs]=w[inside]@n
        a,b=coords[1]-coords[0],coords[2]-coords[0];det=a[0]*b[1]-a[1]*b[0];e1,e2=p[1]-p[0],p[2]-p[0]
        du[ys,xs]=(e1*b[1]-e2*a[1])/det;dv[ys,xs]=(e2*a[0]-e1*b[0])/det;filled[ys,xs]=True
    count=int(filled.sum());assert count>SIZE*SIZE*.45,('atlas coverage',count)
    color=np.zeros(shape,'float32');height=np.zeros((SIZE,SIZE),'float32');rough=np.ones((SIZE,SIZE),'float32')*.63
    n=nmap[filled];n/=np.maximum(np.linalg.norm(n,axis=1)[:,None],1e-8);nmap[filled]=n
    color[filled],height[filled],rough[filled]=anatomical_fields(pmap[filled],n,hand)
    # Extend island gutters before gradients/mips, without bleeding across islands.
    original=filled.copy()
    for iteration in range(10):
        old=filled.copy()
        for axis,step in [(0,1),(0,-1),(1,1),(1,-1)]:
            take=~filled&np.roll(old,step,axis)
            for a in [color,height,rough,nmap,du,dv]:a[take]=np.roll(a,step,axis)[take]
            filled[take]=True
    gy,gx=np.gradient(height);gx*=SIZE;gy*=SIZE
    a,b=du[original],dv[original];n=nmap[original];aa=np.sum(a*a,1);bb=np.sum(b*b,1);ab=np.sum(a*b,1);det=np.maximum(aa*bb-ab*ab,1e-12)
    ga=(bb*gx[original]-ab*gy[original])/det;gb=(aa*gy[original]-ab*gx[original])/det
    gradient=a*ga[:,None]+b*gb[:,None];perturbed=n-gradient;perturbed/=np.maximum(np.linalg.norm(perturbed,axis=1)[:,None],1e-8)
    t=a-n*np.sum(a*n,1)[:,None];t/=np.maximum(np.linalg.norm(t,axis=1)[:,None],1e-8)
    bit=np.cross(n,t);sign=np.sign(np.sum(bit*b,1));bit*=sign[:,None]
    normal=np.ones(shape,'float32')*np.array([.5,.5,1]);normal[original]=np.stack([np.sum(perturbed*t,1),np.sum(perturbed*bit,1),np.sum(perturbed*n,1)],1)*.5+.5
    for iteration in range(10):
        old=original.copy()
        for axis,step in [(0,1),(0,-1),(1,1),(1,-1)]:
            take=~original&np.roll(old,step,axis);normal[take]=np.roll(normal,step,axis)[take];original[take]=True
    images={name:save_map(out/('skin_'+name+'.png'),pixels,name=='albedo') for name,pixels in [('albedo',color),('roughness',rough),('normal',normal)]}
    mat=bpy.data.materials.new('NorthRidge_AnatomicalSkin');mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Specular IOR Level'].default_value=.28;bs.inputs['Subsurface Weight'].default_value=.035;bs.inputs['Subsurface Radius'].default_value=(.9,.35,.2);bs.inputs['Subsurface Scale'].default_value=.001
    for name,socket in [('albedo','Base Color'),('roughness','Roughness')]:
        node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=images[name];mat.node_tree.links.new(node.outputs['Color'],bs.inputs[socket])
    node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=images['normal'];nm=mat.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.7;mat.node_tree.links.new(node.outputs['Color'],nm.inputs['Color']);mat.node_tree.links.new(nm.outputs[0],bs.inputs['Normal'])
    obj.data.materials.append(mat)
    (out/'manifest.json').write_text(json.dumps({'size':SIZE,'original':True,'normal':'OpenGL +Y, metric UV-derived tangent space','uv_coverage_pixels':count,'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.png')}},indent=2)+'\n',encoding='utf-8',newline='\n')
    print('ANATOMY_SKIN_BAKED',count,'texels',flush=True)
def make_nail_material():
    mat=bpy.data.materials.get('NorthRidge_NaturalNails')
    if mat:return mat
    mat=bpy.data.materials.new('NorthRidge_NaturalNails');mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.44,.30,.26,1);bs.inputs['Roughness'].default_value=.49;bs.inputs['Specular IOR Level'].default_value=.22
    return mat
