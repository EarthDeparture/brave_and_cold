"""Band-limited local development radio, original text and seeded noise."""
from pathlib import Path
import wave,json,hashlib
import numpy as np
from scipy.signal import butter,sosfilt,resample_poly
R=Path(__file__).resolve().parents[2];A=R/'brave-and-cold/assets/audio/radio_opening'
rng=np.random.default_rng(20261004);entries={}
for p in sorted(A.glob('*.wav')):
 with wave.open(str(p),'rb') as w:
  rate=w.getframerate();channels=w.getnchannels();width=w.getsampwidth();assert width==2
  data=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(float).reshape(-1,channels).mean(axis=1)/32768
 if rate!=22050:
  import math
  g=math.gcd(rate,22050);data=resample_poly(data,22050//g,rate//g)
 data=sosfilt(butter(3,[280,3500],btype='bandpass',fs=22050,output='sos'),data)
 data=np.tanh(data*2.0)*.65+rng.normal(0,.0015,data.shape)
 fade=min(2205,len(data)//4);data[:fade]*=np.linspace(0,1,fade);data[-fade:]*=np.linspace(1,0,fade)
 with wave.open(str(p),'wb') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(22050);w.writeframes((np.clip(data,-1,1)*32767).astype('<i2').tobytes())
 entries[p.name]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'seconds':len(data)/22050,'sample_rate':22050}
 assert len(data)/22050<37.5,(p.name,'exceeds live broadcast window')
(A/'manifest.json').write_text(json.dumps({'status':'Development audio: local synthesized speech, not recorded actors','text_source':'data/lookout_broadcasts.json (original project writing)','synthesis':'Windows System.Speech / Microsoft David Desktop, rate -1','processing':'280-3500 Hz bandpass; mono PCM16 22050 Hz; seeded low hiss; no downloads or paid service','seed':20261004,'clips':entries},indent=2),encoding='utf-8')
print('RADIO_AUDIO_VALIDATED',len(entries),max(e['seconds'] for e in entries.values()))
