"""Original deterministic synthesis for field handling, no external recordings."""
from pathlib import Path
import numpy as np,wave,json,hashlib
from scipy.signal import butter,sosfilt
R=Path(__file__).resolve().parents[2];out=R/'brave-and-cold/assets/audio/sfx';rate=22050;receipt={};rng=np.random.default_rng(70907)
for name,seconds in [('cloth_wrap',1.2),('bottle_sip',1.4),('switch_click',.16),('stone_hone',1.1),('paper_turn',.6)]:
 t=np.arange(int(seconds*rate))/rate;noise=rng.normal(0,1,len(t));env=np.sin(np.pi*t/seconds)**2
 if name=='cloth_wrap':signal=sosfilt(butter(2,[600,4000],fs=rate,btype='bandpass',output='sos'),noise)*env*(.3+.7*np.sin(t*11)**2)
 elif name=='paper_turn':signal=sosfilt(butter(2,[800,5200],fs=rate,btype='bandpass',output='sos'),noise)*env*np.exp(-t*2)
 elif name=='bottle_sip':signal=(sosfilt(butter(2,[180,1300],fs=rate,btype='bandpass',output='sos'),noise)*(.3+.7*np.sin(t*16)**8)+np.sin(t*2*np.pi*(340+110*np.sin(t*8)))*.14)*env
 elif name=='switch_click':signal=(np.sin(t*2*np.pi*1450)+noise*.4)*np.exp(-t*90)*(1-np.exp(-t*600))
 else:signal=sosfilt(butter(2,[450,3900],fs=rate,btype='bandpass',output='sos'),noise)*env*np.sin(t*13)**2
 signal*=.25/max(np.max(np.abs(signal)),1e-6);signal[:110]*=np.linspace(0,1,110);signal[-110:]*=np.linspace(1,0,110)
 p=out/(name+'.wav')
 with wave.open(str(p),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes((signal*32767).astype('<i2').tobytes())
 rms=float(np.sqrt(np.mean(signal**2)));assert .01<rms<.15 and max(abs(signal))<.3
 receipt[name]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'seconds':seconds,'peak':float(max(abs(signal))),'rms':rms}
(out/'first_week_foley.json').write_text(json.dumps({'source':'Original deterministic local synthesis; no external recordings','generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'sample_rate':rate,'clips':receipt},indent=2)+'\n',encoding='utf-8',newline='\n');print('FOLEY_VALIDATED',len(receipt))
