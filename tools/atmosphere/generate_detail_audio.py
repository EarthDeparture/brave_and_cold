"""Original short material sounds, deterministically synthesized; no external audio."""
from pathlib import Path
import numpy as np
from scipy.signal import butter,sosfilt
import wave,json,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'brave-and-cold/assets/environment_detail/audio';OUT.mkdir(parents=True,exist_ok=True)
SR=22050;rng=np.random.default_rng(31871);receipt={'origin':'Original procedural material sounds','seed':31871,'files':[]}
def filtered(n,lo,hi):
 return sosfilt(butter(2,[lo,hi],fs=SR,btype='bandpass',output='sos'),rng.normal(size=n))
def save(name,x):
 x*=np.minimum(np.arange(len(x))/200,1)*np.minimum(np.arange(len(x))[::-1]/400,1)
 x=x/max(np.max(abs(x)),1e-6)*.68
 assert np.isfinite(x).all() and abs(x[0])<.001 and abs(x[-1])<.001
 data=(x*32767).astype('<i2');path=OUT/(name+'.wav')
 with wave.open(str(path),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(SR);f.writeframes(data.tobytes())
 receipt['files'].append({'file':path.name,'duration_s':len(x)/SR,'peak':float(np.max(abs(x))),'rms':float(np.sqrt(np.mean(x*x))),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
for name,duration in [('timber_creak',1.45),('window_rattle',.80),('step_wood',.26),('step_ice',.30)]:
 t=np.arange(int(SR*duration))/SR;n=len(t)
 if name=='timber_creak':
  envelope=np.sin(np.pi*t/duration)**2*(.65+.35*np.sin(t*41+np.sin(t*13)))
  x=filtered(n,110,1600)*envelope
  for freq in [127,203,349]:x+=.16*np.sin(2*np.pi*(freq*t+1.3*np.sin(t*8)))*envelope
 elif name=='window_rattle':
  envelope=np.zeros(n)
  for when in [.05,.12,.23,.32,.51,.58]:envelope+=np.where(t>when,np.exp(-np.maximum(t-when,0)*65),0)
  x=filtered(n,350,3100)*envelope*.6
  for freq in [620,970,1420]:x+=.07*np.sin(2*np.pi*freq*t)*envelope
 elif name=='step_wood':
  envelope=np.exp(-t*20);x=filtered(n,70,900)*envelope*.7
  for freq in [87,146,233]:x+=.3*np.sin(2*np.pi*freq*t)*np.exp(-t*32)
 else:
  x=filtered(n,800,6000)*np.exp(-t*17)*(.6+.4*np.sin(t*150))
  x+=.55*np.sin(2*np.pi*91*t)*np.exp(-t*34)
 save(name,x)
(OUT/'provenance.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('DETAIL_AUDIO',len(receipt['files']))
