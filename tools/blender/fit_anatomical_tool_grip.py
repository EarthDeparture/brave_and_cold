"""Fit new anatomical finger lengths to the real existing 1.2x tool shaft."""
import json,numpy as np
from pathlib import Path
from scipy.optimize import least_squares
LENGTHS=[(.041,.025,.018),(.045,.028,.020),(.043,.027,.019),(.034,.021,.016)]
MCP=[-.085,-.090,-.087,-.075];R=[.0090,.0096,.0091,.0076]
result={}
zaxis=np.array([.40,.60,.693]);zaxis/=np.linalg.norm(zaxis)
yaxis=np.array([1,0,0])-zaxis*zaxis[0];yaxis/=np.linalg.norm(yaxis)
stock_basis=np.stack([np.cross(yaxis,zaxis),yaxis,zaxis],axis=1)
for grip in ['ToolGrip','ForeGrip','StockGrip','BottleGrip']:
 result[grip]={}
 for digit,name in enumerate(['index','middle','ring','little']):
    if grip=='StockGrip' and name=='index':result[grip][name]=[5,9,5];continue
    def residual(angles):
        a=np.cumsum(np.deg2rad(angles));joint=np.r_[[[0,MCP[digit]]],np.cumsum(np.array([-np.sin(a)*LENGTHS[digit],-np.cos(a)*LENGTHS[digit]]).T,axis=0)+[0,MCP[digit]]]
        p=np.concatenate([joint[k]+np.linspace(.05,1,18)[:,None]*(joint[k+1]-joint[k]) for k in range(3)])
        if grip=='ToolGrip':distance=(np.sqrt(((p[:,0]+.0344)/.02016)**2+((p[:,1]+.106)/.01464)**2)-1)*.01464
        elif grip=='ForeGrip':distance=((abs((p[:,0]+.059)/.024)**2.8+abs((p[:,1]+.080)/.026)**2.8)**(1/2.8)-1)*.024
        elif grip=='BottleGrip':distance=(np.sqrt(((p[:,0]+.062)/.031)**2+((p[:,1]+.095)/.031)**2)-1)*.031
        else:
            xyz=np.stack([np.full(len(p),[-.032,-.0105,.0105,.031][digit]),p[:,0],p[:,1]],axis=1)@stock_basis.T+np.array([.065,.030,.1255])
            cy=np.interp(xyz[:,2],[.018,.12,.21,.29],[.014,.008,.015,.012]);hh=np.interp(xyz[:,2],[.018,.12,.21,.29],[.029,.025,.037,.051]);ww=np.interp(xyz[:,2],[.018,.12,.21,.29],[.020,.017,.022,.026])
            distance=((abs(xyz[:,0]/ww)**2.8+abs((xyz[:,1]-cy)/hh)**2.8)**(1/2.8)-1)*np.minimum(ww,hh)
        radius=R[digit]*(1-.22*np.linspace(0,1,len(p)))+.0012
        gap=distance-radius
        return np.r_[np.minimum(gap,0)*40,np.minimum(gap[-18:],.020)*3,(angles-[15,75,50])*.00002]
    best=min((least_squares(residual,start,bounds=([-5,0,0],[85,88,50]),max_nfev=600) for start in [[10,75,45],[0,45,40],[30,85,45]]),key=lambda r:np.linalg.norm(r.fun))
    result[grip][name]=[round(float(v),4) for v in best.x]
path=Path(__file__).parent/'generated/live_hand_rig_v2/grip_fit_candidates.json';path.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n');print(result)
