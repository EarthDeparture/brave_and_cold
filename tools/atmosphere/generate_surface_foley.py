"""Original heel/toe timber and ice variants, no downloaded recordings."""
from pathlib import Path
import numpy as np
from scipy.signal import butter,sosfilt
import wave,json,hashlib
R=Path(__file__).resolve().parents[2];O=R/'brave-and-cold/assets/environment_detail/audio/surface_foley';O.mkdir(parents=True,exist_ok=True)
SR=22050;rng=np.random.default_rng(8180);files=[]
for material,count in [('wood',4),('ice',3)]:
 for variation in range(count):
  duration=.33+variation*.012;t=np.arange(int(SR*duration))/SR
  x=np.zeros(len(t))
  for onset,strength in [(0,1),(.075+variation*.007,.44)]:
   tt=np.maximum(0,t-onset);e=np.exp(-tt*(29 if material=='wood' else 21))*(t>=onset)
   lo,hi=(65,1100) if material=='wood' else (650,5400)
   noise=sosfilt(butter(2,[lo,hi],fs=SR,btype='bandpass',output='sos'),rng.normal(size=len(t)))
   x+=noise*e*strength*.45
   for freq,gain in ([(82,.34),(148,.13),(227,.07)] if material=='wood' else [(96,.22),(680,.018)]):
    x+=np.sin(2*np.pi*(freq+variation*5)*tt)*e*strength*gain
  x*=np.minimum(np.arange(len(x))/100,1)*np.minimum(np.arange(len(x))[::-1]/400,1)
  x=x/max(abs(x).max(),1e-9)*(.64+variation*.015)
  assert np.isfinite(x).all() and abs(x[0])<.001 and abs(x[-1])<.001
  p=O/f'step_{material}_{variation}.wav'
  with wave.open(str(p),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(SR);f.writeframes((x*32767).astype('<i2').tobytes())
  files.append({'file':p.name,'duration_s':len(x)/SR,'peak':float(abs(x).max()),'rms':float(np.sqrt(np.mean(x*x))),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(O/'provenance.json').write_text(json.dumps({'origin':'Original NumPy/SciPy synthesis; heel/toe contact plus distinct resonances','seed':8180,'files':files},indent=2)+'\n')
print('SURFACE_FOLEY_READY',len(files))
