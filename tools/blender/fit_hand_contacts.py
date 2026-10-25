"""Fit authored finger angles to the existing shaft/stock dimensions, in metres.
Run with the terrain-tool Python environment (NumPy/SciPy). No asset downloads.
"""
import json
from pathlib import Path
import numpy as np
from scipy.optimize import least_squares
LENGTHS=[(.039,.024,.018),(.044,.027,.019),(.041,.025,.018),(.032,.019,.016)]
MCP=[-.081,-.086,-.080,-.068]
X=[-.030,-.010,.010,.030]
ST=np.array([[-.402,-.044,.0165,.066],[-.380,-.043,.0185,.064],[-.320,-.037,.0195,.056],[-.260,-.028,.0195,.048],[-.200,-.018,.019,.042],[-.140,-.011,.0185,.039],[-.080,-.007,.018,.037],[-.020,-.004,.0185,.038],[.050,0,.019,.040],[.120,.004,.0195,.040],[.220,.008,.0195,.036],[.340,.012,.019,.032],[.460,.016,.0185,.029],[.560,.018,.018,.026],[.600,.019,.0165,.0235]])
def finger(index,angles):
 a=np.cumsum(np.deg2rad(angles)); lengths=np.array(LENGTHS[index])
 j=np.vstack(([X[index],.001,MCP[index]],np.array([X[index],.001,MCP[index]])+np.cumsum(np.array([np.zeros(3),-np.sin(a)*lengths,-np.cos(a)*lengths]).T,axis=0)))
 return np.concatenate([j[k]+np.linspace(.05,1,12)[:,None]*(j[k+1]-j[k]) for k in range(3)])
def stock_distance(points):
 y=-points[:,2]; centre=np.interp(y,ST[:,0],ST[:,1]);w=np.interp(y,ST[:,0],ST[:,2]);h=np.interp(y,ST[:,0],ST[:,3])
 norm=(abs(points[:,0]/w)**2.8+abs((points[:,1]-centre)/h)**2.8)**(1/2.8)
 return (norm-1)*np.minimum(w,h)
rz=np.array([.4,.6,.693]);rz/=np.linalg.norm(rz);ry=np.array([1,0,0])-rz*rz[0];ry/=np.linalg.norm(ry);rx=np.cross(ry,rz)
right_basis=np.stack([rx,ry,rz],axis=1)
left_basis=np.array([[0,0,-1],[0,-1,0],[-1,0,0]])
report={}
for grip in ['Shaft','Trigger','Support']:
 fitted={}
 for digit in range(4):
  if grip=='Trigger' and digit==0:continue
  def residual(angles):
   points=finger(digit,angles)
   if grip=='Shaft':
    distance=(np.sqrt(((points[:,1]+.0344)/.02016)**2+((points[:,2]+.106)/.01464)**2)-1)*.01464
   else:
    basis,wrist=(right_basis,np.array([.070,.026,.175])) if grip=='Trigger' else (left_basis,np.array([-.059,-.041,-.266]))
    distance=stock_distance(points@basis.T+wrist)
   # Keep phalanges outside the tool and fit pads within anatomical bend limits.
   # Distal joints must not fold backwards past a normal closed grip.
   gap=distance-.0065
   return np.r_[np.minimum(gap,0)*35,(gap[-12:])*3,(angles-np.array([20,55,55]))*.00002]
  best=None
  for start in [[15,55,35],[5,20,35],[65,55,40],[25,70,60]]:
   r=least_squares(residual,start,bounds=([-5,0,0],[90,110,75]),max_nfev=600)
   if best is None or np.linalg.norm(r.fun)<np.linalg.norm(best.fun):best=r
  fitted[['index','middle','ring','little'][digit]]=list(np.round(best.x,4))
 report[grip]=fitted
# Reuse the shaft pinch for the smaller bolt knob; thumb opposition is fit in Blender.
report['Bolt']=report['Shaft']
Path(__file__).with_name('hand_contact_fit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
