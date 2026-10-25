"""Seal route checks, actual movement and original-asset/render evidence."""
from pathlib import Path
import hashlib,json,re
from PIL import Image,ImageDraw,ImageFont
from validate_route_assets import validate
R=Path(__file__).resolve().parents[1];S=R/'brave-and-cold/shots/route-polish-2026-10-07';D=R/'docs/validation'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def source_sha(p):return hashlib.sha256(p.read_text(encoding='utf8').replace('\r\n','\n').encode()).hexdigest()
expected={'route_polish':31,'road_detail':15,'walk_surfaces':18,'lookout_stair_turns':91,'lookout_opening':53,'opening_traversal':5,'watch_walkie_door':46,'first_week_core':33,'first_week_story':38,'first_week_collapse':185,'opening_pacing':50}
tests={}
for name,n in expected.items():
 p=S/('test_'+name+'.log');t=p.read_text(encoding='utf-8-sig')
 assert len(re.findall(r'^PASS ',t,re.M))==n,(name,n)
 assert 'failures=0' in t and not re.search(r'^FAIL |SCRIPT ERROR|Parse Error',t,re.M),name
 tests[name]={'pass_assertions':n,'log':str(p.relative_to(R)).replace('\\','/'),'sha256':sha(p),'native_exit_code':0}
shore=S/'test_shore_walking.log';text=shore.read_text(encoding='utf-8-sig')
assert not re.search(r'SCRIPT ERROR|Parse Error|^FAIL ',text,re.M)
assert len(re.findall(r'SHORE_WALK fps=(?:30|60|120) crossings=28 blocked_frames=0',text))==3
assert 'STAIR_CONTROLLER ascent=true' in text and 'STAIR_CONTROLLER descent=true' in text
route=S/'traversal/route-polish-route.json';outing=json.loads(route.read_text());assert outing['completed'] and not outing['failure'] and outing['repair_stage']==3
assert 'SCRIPT ERROR' not in (S/'measure_opening_route.log').read_text(encoding='utf-8-sig')
capture=S/'final.log';text=capture.read_text(encoding='utf-8-sig');assert 'ROUTE_CAPTURE_DONE gpu=NVIDIA GeForce GTX 1080 Ti' in text and 'SCRIPT ERROR' not in text and 'Shader compilation' not in text
ids=['road-180','road-360','trail-4','trail-75','trail-165','trail-238','trail-dusk','trail-storm-light','gate-closed','gate-open','service_marker','drain_headwall','trail-settled-snow']
images={}
for name in ids:
 p=S/'final'/(name+'.png');assert Image.open(p).size==(1600,900)
 images[name]={'path':str(p.relative_to(R)).replace('\\','/'),'sha256':sha(p),'agent_visual_review':'accepted'}
font=ImageFont.truetype('C:/Windows/Fonts/bahnschrift.ttf',22)
rows=['trail-165','road-360','gate-closed'];sheet=Image.new('RGB',(1600,1440),(18,23,27));draw=ImageDraw.Draw(sheet)
for i,name in enumerate(rows):
 for j,folder in enumerate(['before','final']):
  im=Image.open(S/folder/(name+'.png')).convert('RGB').resize((800,450),Image.Resampling.LANCZOS);sheet.paste(im,(j*800,i*480+30));draw.text((j*800+12,i*480+3),folder.upper()+'  '+name,font=font,fill=(230,236,234))
sheet.save(D/'ROUTE_POLISH_COMPARISON.jpg',quality=94)
frames=[];motion={}
for prefix in ['gate-open','gate-close']:
 for i in range(42):
  p=S/'final'/(prefix+'-%03d.png'%i);assert p.exists();motion[p.name]=sha(p)
  if i%2==0:frames.append(Image.open(p).convert('RGB').resize((640,360),Image.Resampling.LANCZOS).quantize(colors=128))
frames[0].save(D/'ROUTE_GATE_MOTION.gif',save_all=True,append_images=frames[1:],duration=66,loop=0,optimize=True)
sources=['.gitignore','brave-and-cold/world/refuge_boundary.gd','brave-and-cold/world/lookout_opening.gd','brave-and-cold/world/fire_lookout.gd','brave-and-cold/world/trail_net.gd','brave-and-cold/world/road_net.gd','brave-and-cold/world/game_world.gd','brave-and-cold/world/route_dressing.gd','brave-and-cold/world/winter_path_material.gd','brave-and-cold/world/shaders/winter_service_path.gdshader','brave-and-cold/world/shaders/winter_road.gdshader','brave-and-cold/tests/test_route_polish.gd','brave-and-cold/tests/test_opening_traversal.gd','brave-and-cold/tests/test_lookout_opening.gd','brave-and-cold/tests/measure_opening_route.gd','brave-and-cold/tests/visual/capture_route_polish.gd','tools/blender/gen_route_graphics.py','tools/blender/gen_route_detail.py','tools/audio/gen_route_foley.py','tools/validate_route_assets.py','tools/record_route_validation.py']
route_test=(S/'test_route_polish.log').read_text(encoding='utf-8-sig')
metrics=re.search(r'ROUTE_METRICS contact_m=([0-9.]+) jerk_m=([0-9.]+)',route_test)
out={'date':'2026-10-07','baseline':'8462bf3','branch':'codex/route-polish','rollback_tag':'checkpoint/pre-route-polish-2026-10-07','assertions_passed':sum(expected.values()),'tests':tests,'shore':{'crossings':84,'blocked_frames':0,'log_sha256':sha(shore)},'trail_movement':{'complete_traversals':6,'fps':[30,60,120],'max_contact_m':float(metrics[1]),'max_change_in_vertical_step_m':float(metrics[2])},'controlled_outing':outing,'outing_sha256':sha(route),'assets':validate(),'manifest_sha256':sha(R/'brave-and-cold/assets/route_detail/manifest.json'),'source_sha256_lf':{p:source_sha(R/p) for p in sources},'render':{'renderer':'Forward+ D3D12','gpu':'NVIDIA GeForce GTX 1080 Ti','viewport':[1600,900],'capture_log_sha256':sha(capture),'images':images,'gate_motion_frame_sha256':motion,'scope':'Frozen player-camera captures and explicit gate advancement; synthetic settled-snow mask is labelled. No human-playtest or performance claim.'},'review_artifacts':{p:sha(D/p) for p in ['ROUTE_POLISH_COMPARISON.jpg','ROUTE_GATE_MOTION.gif']}}
(D/'ROUTE_POLISH_RECEIPT.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf8',newline='\n')
print('ROUTE_RECEIPT assertions=',sum(expected.values()),'shore=84 views=',len(images),'motion_frames=',len(motion))
