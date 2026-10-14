"""Small read-only actual-byte glTF accessor reader for local asset QA."""
import json,struct,numpy as np
class GLB:
 def __init__(self,path):
  raw=path.read_bytes();magic,version,length=struct.unpack_from('<III',raw)
  assert (magic,version,length)==(0x46546c67,2,len(raw))
  jl,jt=struct.unpack_from('<II',raw,12);assert jt==0x4e4f534a
  self.doc=json.loads(raw[20:20+jl]);bl,bt=struct.unpack_from('<II',raw,20+jl);assert bt==0x004e4942
  self.binary=raw[28+jl:28+jl+bl]
 def acc(self,i):
  a=self.doc['accessors'][i];v=self.doc['bufferViews'][a['bufferView']]
  n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']];dt=np.dtype({5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']])
  return np.ndarray((a['count'],n),dtype=dt,buffer=self.binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',dt.itemsize*n),dt.itemsize))
 def image(self,i):
  v=self.doc['bufferViews'][self.doc['images'][i]['bufferView']];at=v.get('byteOffset',0)
  return self.binary[at:at+v['byteLength']]
 def transforms(self):
  result={};parents={c:i for i,n in enumerate(self.doc['nodes']) for c in n.get('children',[])}
  def world(i):
   if i in result:return result[i]
   n=self.doc['nodes'][i]
   if 'matrix' in n:m=np.array(n['matrix']).reshape(4,4).T
   else:
    x,y,z,w=n.get('rotation',[0,0,0,1]);m=np.eye(4)
    m[:3,:3]=np.array([[1-2*y*y-2*z*z,2*x*y-2*z*w,2*x*z+2*y*w],[2*x*y+2*z*w,1-2*x*x-2*z*z,2*y*z-2*x*w],[2*x*z-2*y*w,2*y*z+2*x*w,1-2*x*x-2*y*y]])@np.diag(n.get('scale',[1,1,1]));m[:3,3]=n.get('translation',[0,0,0])
   result[i]=world(parents[i])@m if i in parents else m
   return result[i]
  for i in range(len(self.doc['nodes'])):world(i)
  return result
