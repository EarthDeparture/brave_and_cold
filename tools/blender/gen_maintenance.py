"""Original upkeep props: replace dropped-item boxes and support wrist treatment."""
from pathlib import Path
import bpy,json,hashlib,math
src=Path(__file__).with_name('gen_first_week.py').read_text(encoding='utf-8');exec(src[:src.index('clear()\n# Reusable')]);OUT=R/'tools/blender/generated/maintenance';RT=R/'brave-and-cold/assets/maintenance';OUT.mkdir(parents=True,exist_ok=True);RT.mkdir(parents=True,exist_ok=True);receipt={};clear()
M['stone']=mat('AbrasiveStone',(.25,.29,.27),.95,texture=OUT/'stone.png');M['canvas']=mat('DressingCotton',(.72,.70,.62),.98,texture=OUT/'cotton.png')
box('Whetstone',(0,.021,0),(.17,.040,.060),'stone',.005);box('RubberFoot',(0,.004,0),(.15,.008,.052),'rubber',.002);export('whetstone')
box('SewingTin',(0,.025,0),(.15,.05,.11),'forest_enamel',.008);box('FoldedTinLid',(0,.052,0),(.151,.010,.111),'steel',.004)
label('SewingPrint',(0,.027,.056),(.13,.029),'sewing')
for x in [-.041,.010,.052]:
 cyl('ThreadCore',(x,.058,-.02),(x,.089,-.02),.010,'cream',24);cyl('ThreadSpool',(x,.058,-.02),(x,.083,-.02),.013,'canvas',24)
cyl('Needle',(-.059,.067,.028),(.055,.067,.028),.001,'steel',12);export('sewing_kit')
# Rolled strip with exposed concentric textile layers and small loose tail.
cyl('DressingRoll',(-.033,.037,0),(.033,.037,0),.035,'canvas',32)
for x in [-.034,.034]:
 for rr in [.013,.020,.027,.034]:
  vs=[];fs=[]
  for k in range(48):
   a=k*math.tau/48
   for rad in [rr-.0007,rr+.0007]:vs.append(cv((x,.037+math.sin(a)*rad,math.cos(a)*rad)))
  for k in range(48):j=(k+1)%48;fs.append((2*k,2*j,2*j+1,2*k+1))
  me=bpy.data.meshes.new('RollEdges');me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new('RollEdges',me);bpy.context.collection.objects.link(o);finish(o,'cream')
box('LooseCloth',(0,.008,.058),(.065,.003,.065),'canvas',.001);export('dressing_roll')
for name in ['whetstone','sewing_kit','dressing_roll']:receipt[name]['source']='tools/blender/generated/maintenance/'+name+'.blend'
receipt['provenance']={'license':'Original project-authored geometry and printwork','blender':bpy.app.version_string,'units':'metres','generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()};receipt['graphics']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.png')};(RT/'manifest.json').write_text(json.dumps(receipt,indent=2)+'\n')
