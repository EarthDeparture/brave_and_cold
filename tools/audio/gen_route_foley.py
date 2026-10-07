"""Original short gate handling sounds, deterministic local synthesis."""
from pathlib import Path
import wave,json,hashlib
import numpy as np
from scipy.signal import butter,sosfilt
R=Path(__file__).resolve().parents[2];out=R/'brave-and-cold/assets/audio/sfx';rate=22050;rng=np.random.default_rng(71007);clips={}
for name,seconds in [('gate_latch',.26),('gate_hinge',1.0),('gate_stop',.20)]:
 t=np.arange(int(rate*seconds))/rate;noise=rng.normal(0,1,len(t))
 if name=='gate_hinge':
  signal=(np.sin(2*np.pi*(210*t+22*np.sin(t*7)))+.22*np.sin(t*2*np.pi*790)+.15*sosfilt(butter(2,[180,1200],fs=rate,btype='bandpass',output='sos'),noise))*np.sin(np.pi*t/seconds)**2
 else:
  signal=sum(np.sin(t*2*np.pi*f)*np.exp(-t*d) for f,d in [(620,35),(1550,60),(2700,85)])+.5*noise*np.exp(-t*90)
  if name=='gate_stop':signal*=.6
 signal*=.22/max(abs(signal));signal[:90]*=np.linspace(0,1,90);signal[-90:]*=np.linspace(1,0,90)
 p=out/(name+'.wav')
 with wave.open(str(p),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes((signal*32767).astype('<i2').tobytes())
 clips[name]={'seconds':seconds,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'peak':float(max(abs(signal))),'rms':float(np.sqrt(np.mean(signal**2)))}
(out/'route_foley.json').write_text(json.dumps({'source':'Original deterministic local synthesis; no external recordings','seed':71007,'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'clips':clips},indent=2)+'\n',encoding='utf8',newline='\n')
print('ROUTE_FOLEY',len(clips))
