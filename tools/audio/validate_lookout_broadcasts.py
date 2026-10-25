"""Verify authored slot separation, original speech receipts and shipped PCM."""
from pathlib import Path
import hashlib,json,wave
import numpy as np
R=Path(__file__).resolve().parents[2]
P=R/'brave-and-cold/data/lookout_broadcasts.json'
data=json.loads(P.read_text(encoding='utf8'))
A=R/'brave-and-cold/assets/audio/radio_bulletins'
manifest=json.loads((A/'manifest.json').read_text(encoding='utf8'))
assert manifest['data_sha256']==hashlib.sha256(P.read_text(encoding='utf8').replace('\r\n','\n').encode()).hexdigest(),'stale script/audio manifest'
entries=data['broadcasts'];ids=[e['id'] for e in entries];assert len(set(ids))==len(ids)==30
assert data['public_hours']==[6,12,17,0]
public=[e for e in entries if e['device']=='public'];dispatch=[e for e in entries if e['device']=='dispatch']
assert len(public)==20 and len(dispatch)==10
for day in range(1,6):
 assert sorted(e['hour'] for e in public if e['day']==day)==[6,12,17,24]
start=lambda e:(e['day']-1)*86400+e['hour']*3600
# All recurring slots, including midnight and days after source ends.
slots=[d*86400+h*3600 for d in range(7) for h in data['public_hours']]
for e in dispatch:
 lo=start(e);hi=lo+e['window_game_s']
 assert all(hi<=slot-data['dispatch_guard_game_s'] or lo>=slot+data['public_window_game_s']+data['dispatch_guard_game_s'] for slot in slots),('dispatch/public overlap',e['id'])
for device in ['public','dispatch']:
 ordered=sorted((start(e),start(e)+e['window_game_s']) for e in entries if e['device']==device)
 assert all(a[1]<=b[0] for a,b in zip(ordered,ordered[1:])),('same device overlap',device)
clips=[]
for e in entries:
 path=R/'brave-and-cold'/e['audio'].removeprefix('res://');record=manifest['clips'][path.name]
 assert record['sha256']==hashlib.sha256(path.read_bytes()).hexdigest(),('changed asset',e['id'])
 assert record['text_sha256']==hashlib.sha256(e['text'].encode()).hexdigest(),('stale voice script',e['id'])
 with wave.open(str(path),'rb') as w:
  assert (w.getnchannels(),w.getsampwidth(),w.getframerate())==(1,2,22050)
  pcm=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(float)/32768
  duration=w.getnframes()/w.getframerate()
 assert abs(duration-record['seconds'])<.001
 assert duration*data['audio_game_seconds_per_second']<=e['window_game_s']
 rms=float(np.sqrt(np.mean(pcm**2)));peak=float(np.max(np.abs(pcm)))
 assert .005<rms<.35 and peak<.95,('silent or clipped audio',e['id'],rms,peak)
 cues=record['captions'];assert cues
 assert all(0<=c['start_s']<c['end_s']<=duration and c['text'] for c in cues)
 assert all(a['end_s']<=b['start_s'] for a,b in zip(cues,cues[1:]))
 assert ' '.join(c['text'] for c in cues)==e['text'],('caption/script mismatch',e['id'])
 clips.append({'caption_chunks':len(cues),'id':e['id'],'seconds':duration,'rms':rms,'peak':peak,'voice':record['voice']})
receipt={'date':'2026-10-05','slots':'06:00, 12:00, 17:00, closing-day 00:00','public_bulletins':len(public),'dispatch_calls':len(dispatch),'nonoverlap':'entire dispatch window vs every recurring public slot plus guards','all_pcm_hashes_and_script_hashes_verified':True,'clips':clips}
out=R/'docs/validation/RADIO_BULLETINS_AUDIO_RECEIPT.json';out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print('BROADCAST_PREFLIGHT_PASS',len(clips),'clips; full windows separated; PCM/hash/script checks passed')
