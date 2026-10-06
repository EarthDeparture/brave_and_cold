"""Original flat letter with sketched city postcard; physical optional story clue."""
from pathlib import Path
import bpy,json,hashlib
src=Path(__file__).with_name('gen_first_week.py').read_text(encoding='utf-8');exec(src[:src.index('clear()\n# Reusable')]);OUT=R/'tools/blender/generated/city_letter';RT=R/'brave-and-cold/assets/city_letter';OUT.mkdir(parents=True,exist_ok=True);RT.mkdir(parents=True,exist_ok=True);receipt={};clear()
box('Envelope',(0,.004,0),(.22,.008,.31),'cream',.001)
box('LetterFold',(0,.010,.015),(.205,.003,.28),'cream',.0005)
M['letter']=mat('EliseLetter',(1,1,1),texture=OUT/'letter.png');me=bpy.data.meshes.new('LetterPrint');me.from_pydata([cv(v) for v in [(-.098,.012,-.12),(.098,.012,-.12),(.098,.012,.14),(-.098,.012,.14)]],[],[(3,2,1,0)]);me.update();uv=me.uv_layers.new()
for li,xy in zip(me.polygons[0].loop_indices,[(0,0),(1,0),(1,1),(0,1)]):uv.data[li].uv=xy
o=bpy.data.objects.new('PrintedLetter',me);bpy.context.collection.objects.link(o);finish(o,'letter');export('city_letter');receipt['city_letter']['source']='tools/blender/generated/city_letter/city_letter.blend';receipt['provenance']={'license':'Original project-authored geometry and illustration','units':'metres','generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()};receipt['graphics']={'letter.png':hashlib.sha256((OUT/'letter.png').read_bytes()).hexdigest()};(RT/'manifest.json').write_text(json.dumps(receipt,indent=2)+'\n')
