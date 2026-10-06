"""Package reviewed real renders, source dependencies and an exact SHA256 roster."""
from pathlib import Path
import hashlib,json,shutil,zipfile
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).parent;OUT=ROOT/'generated/anatomical_hands_v2'
sources=['gen_anatomical_hands_v2.py','hand_anatomy_materials_v2.py','render_anatomical_hands_v2.py','export_hand_morph_tracks_v2.py','finalize_anatomical_hands_v2.py','preview_anatomical_hands_v2.py','audit_anatomical_hands_v2.py','validate_native_anatomical_hands_v2.py','validate_anatomical_hands_v2.py','package_anatomical_hands_v2.py','gen_hand_rig.py','gen_survivor_hands.py','hand_materials.py','hand_contact_fit.json','validate_field_survival_kit.py']
(OUT/'source').mkdir(exist_ok=True)
for name in sources:shutil.copy2(ROOT/name,OUT/'source'/name)
for p in OUT.rglob('*'):
    if p.is_file() and p.suffix in ['.py','.gd','.json','.md','.godot','.uid'] and '.godot' not in p.parts:
        text=p.read_text(encoding='utf-8');p.write_text(text,encoding='utf-8',newline='\n')
old=OUT/'previews/pose_Pinch.png'
if old.exists():old.unlink() # This generator's obsolete first-iteration preview only.
try:
    title_font=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',30)
    label_font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',21)
except OSError:title_font=label_font=ImageFont.load_default()
sheet=Image.new('RGB',(1500,1140),(27,30,32));draw=ImageDraw.Draw(sheet)
draw.text((24,18),'North Ridge / Anatomical Hands v2',font=title_font,fill=(233,236,235))
draw.text((24,62),'Actual Blender meshes and renders | Original connected anatomy and reusable rig',font=label_font,fill=(160,175,176))
panels=[('open_hand_detail','Dorsum / curved nails'),('open_palm','Palm / thumb saddle'),('quad_cage_dorsal','Editable connected cage'),('pose_Fist','Fist / corrective skinning'),('pose_Shaft','Generic tool grip'),('godot_Trigger','Godot / index off trigger')]
for i,(name,label) in enumerate(panels):
    x=(i%3)*500;y=110+(i//3)*510
    image=Image.open(OUT/'previews'/(name+'.png')).convert('RGB');assert image.width==image.height
    image.thumbnail((486,486),Image.Resampling.LANCZOS);sheet.paste(image,(x+7,y))
    draw.text((x+14,y+486),label,font=label_font,fill=(218,225,225))
sheet.save(OUT/'previews/review_sheet.png')
frames=[Image.open(OUT/'previews'/('godot_flex_'+str(i)+'.png')).convert('RGB').resize((500,500),Image.Resampling.LANCZOS) for i in range(5)]
frames[0].save(OUT/'previews/flex_review.gif',save_all=True,append_images=frames[1:],duration=[600,350,600,350,600],loop=0)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((OUT/'manifest.json').read_text());validation=json.loads((OUT/'validation.json').read_text());native=json.loads((OUT/'native_validation.json').read_text());audit=json.loads((OUT/'pose_audit.json').read_text());engine=json.loads((OUT/'godot/engine_validation.json').read_text())
assert manifest['native_sha256']==sha(OUT/'anatomical_hands.blend')==native['native_sha256']==audit['source_sha256']
assert manifest['glb_sha256']==sha(OUT/'godot/anatomical_hands.glb')
assert len(engine['clips'])==10 and validation['glb']=='passed'
# Explicitly include only the native source, documented assets and portable review files.
files=[]
for p in OUT.rglob('*'):
    rel=p.relative_to(OUT)
    if not p.is_file() or '.godot' in rel.parts or '__pycache__' in rel.parts:continue
    if p.suffix in ['.zip','.import','.log'] or p.name=='package_hashes.json' or p.name.startswith('anatomical_hands.blend') and p.name!='anatomical_hands.blend':continue
    if rel.parts[0]=='godot' and p.suffix=='.png':continue
    files.append(p)
hashes={p.relative_to(OUT).as_posix():sha(p) for p in sorted(files)}
roster=OUT/'package_hashes.json';roster.write_text(json.dumps({'algorithm':'SHA256','scope':'Exact ZIP file roster excluding this self-referential receipt','files':hashes},indent=2)+'\n',encoding='utf-8',newline='\n')
archive=OUT/'anatomical_hands_v2.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as zipped:
    for p in files+[roster]:zipped.write(p,p.relative_to(OUT).as_posix())
with zipfile.ZipFile(archive) as zipped:
    assert set(zipped.namelist())==set(hashes)|{'package_hashes.json'}
    assert all(hashlib.sha256(zipped.read(name)).hexdigest()==value for name,value in hashes.items())
print('ANATOMICAL_PACKAGE_PASS',len(hashes),'files',archive.stat().st_size,'bytes')
