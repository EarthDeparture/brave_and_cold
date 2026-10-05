"""Original, reproducible local radio production. Raw speech is never overwritten."""
from pathlib import Path
import wave,json,hashlib,math
import numpy as np
from scipy.signal import butter,sosfilt,resample_poly
R=Path(__file__).resolve().parents[2]
A=R/'brave-and-cold/assets/audio/radio_bulletins';A.mkdir(parents=True,exist_ok=True)
RAW=R/'tools/audio/generated/radio_bulletins'
DATA=R/'brave-and-cold/data/lookout_broadcasts.json'
data=json.loads(DATA.read_text(encoding='utf8'));speech=json.loads((RAW/'speech_manifest.json').read_text(encoding='utf-8-sig'))
entries={};RATE=22050
for entry in data['broadcasts']:
 ident=entry['id'];source=RAW/(ident+'.wav');p=A/source.name
 with wave.open(str(source),'rb') as w:
  rate=w.getframerate();channels=w.getnchannels();assert w.getsampwidth()==2
  audio=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(float).reshape(-1,channels).mean(axis=1)/32768
 if rate!=RATE:
  divisor=math.gcd(rate,RATE);audio=resample_poly(audio,RATE//divisor,rate//divisor)
 rng=np.random.default_rng(int(hashlib.sha256(ident.encode()).hexdigest()[:8],16))
 public=entry['device']=='public'
 audio=sosfilt(butter(3,[180,4300] if public else [300,3000],btype='bandpass',fs=RATE,output='sos'),audio)
 audio=np.tanh(audio*(1.8 if public else 2.2))*(.65 if public else .60)
 audio+=rng.normal(0,.0006 if public else .0015,audio.shape)
 fade=min(2205,len(audio)//4);audio[:fade]*=np.linspace(0,1,fade);audio[-fade:]*=np.linspace(1,0,fade)
 def tone(freq,seconds,level):
  t=np.arange(int(RATE*seconds))/RATE;envelope=np.sin(np.linspace(0,np.pi,len(t)))**2
  return np.sin(t*freq*math.tau)*envelope*level
 if public:
  intro=np.concatenate([tone(620,.13,.11),tone(830,.13,.11),np.zeros(int(RATE*.10))]);outro=tone(620,.10,.08)
 else:
  intro=rng.normal(0,.012,int(RATE*.08))*np.linspace(1,0,int(RATE*.08));outro=tone(920,.075,.08)
 audio=np.concatenate([intro,audio,outro])
 length=len(audio)/RATE
 assert length*data['audio_game_seconds_per_second']<=entry['window_game_s'],(ident,'speech exceeds reserved slot')
 with wave.open(str(p),'wb') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes((np.clip(audio,-1,1)*32767).astype('<i2').tobytes())
 # Use actual SAPI word audio positions, grouped into readable sentence/chunks.
 words=sorted(speech[ident]['words'],key=lambda w:w['Seconds']);assert words,ident
 captions=[];i=0;intro_s=len(intro)/RATE
 while i<len(words):
  first=i;begin=words[i]['Start'];j=i+1
  while j<len(words) and j-first<16:
   end=words[j]['Start'];prior=entry['text'][begin:end].rstrip()
   if prior.endswith(('.', '!', '?')):break
   j+=1
  end=words[j]['Start'] if j<len(words) else len(entry['text'])
  caption=entry['text'][begin:end].strip()
  start=words[first]['Seconds']+intro_s
  finish=words[j]['Seconds']+intro_s if j<len(words) else length-len(outro)/RATE
  assert 0<=start<finish<=length,(ident,caption,start,finish)
  captions.append({'start_s':start,'end_s':finish,'text':caption});i=j
 entries[p.name]={'captions':captions,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'seconds':length,'sample_rate':RATE,'device':entry['device'],'voice':speech[ident]['voice'],'rate':speech[ident]['rate'],'text_sha256':hashlib.sha256(entry['text'].encode()).hexdigest()}
manifest={'status':'Development audio: local synthesized speech; directed human performances remain future production work','text_source':'data/lookout_broadcasts.json (original project writing)','data_sha256':hashlib.sha256(DATA.read_text(encoding='utf8').replace('\r\n','\n').encode()).hexdigest(),'synthesis':'Windows System.Speech; actual voice and rate recorded per clip','processing':'Public: 180-4300 Hz, quiet hiss and station chime. Dispatch: 300-3000 Hz, handset squelch and acknowledgement tone. Mono PCM16 22050 Hz.','seed':'SHA256 of stable broadcast ID; no downloads or paid service','clips':entries}
(A/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n')
print('RADIO_AUDIO_VALIDATED',len(entries),'longest_seconds',max(e['seconds'] for e in entries.values()))
