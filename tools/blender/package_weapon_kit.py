"""Seal our editable weapon art kit, review evidence and exact file roster."""
from pathlib import Path
import hashlib,json,zipfile,re
from PIL import Image,ImageDraw,ImageFont
from validate_weapon_kit import validate,read_glb,transform
import numpy as np
OUT=Path(__file__).parent/'generated/north_ridge_weapon_kit_v1'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
meta=json.loads((OUT/'manifest.json').read_text());results=validate()
native=json.loads((OUT/'native_validation.json').read_text());engine=json.loads((OUT/'godot/engine_validation.json').read_text())
assert set(results)==set(native)==set(engine['assets'])
count=sum(len(r['animations']) for r in results.values());assert count==67
for name,r in meta['assets'].items():assert set(r['animations'])==set(native[name]['animations'])==set(engine['assets'][name]['animations'])
logs={'native_check_final.log':'WEAPON_NATIVE_PASS 18','godot_gpu_final.log':'WEAPON_GODOT_PASS assets=18','godot_import_final.log':'[ DONE ] reimport'}
for name,success in logs.items():
    log=re.sub(r'\x1b\[[0-9;]*m','',(OUT/name).read_text(encoding='utf-8'));assert success in log and not any(e in log for e in ['Traceback','SCRIPT ERROR','ERROR:','WARNING:','Parse Error']),name
for name,digest in json.loads((OUT/'textures/manifest.json').read_text())['files'].items():assert sha(OUT/'textures'/name)==digest
meta['generator_sha256']=sha(Path(__file__).with_name('gen_north_ridge_weapons.py'))
meta['library_sha256']=sha(OUT/'north_ridge_weapon_library.blend')
meta['source_reference_sha256']=sha(Path('C:/Users/parst/AppData/Local/Temp/codex-clipboard-369ba18a-d021-47d5-b603-69ca73108609.png'))
meta['reference_usage']='User-provided eight-weapon sheet as silhouette/material guidance; image not redistributed.'
meta['dimension_basis']='Plausible chosen metre scales, independently measured from final mesh vertices. The image does not establish real dimensions or exact underlying designs.'
meta['production_scope']='Standalone original fictional weapon art. No live gameplay, existing held items or maps are replaced.'
scripts=['gen_weapon_kit_textures.py','gen_north_ridge_weapons.py','gen_field_survival_kit.py','finalize_weapon_kit_sources.py','preview_weapon_kit_clip.py','verify_weapon_kit_native.py','validate_weapon_kit.py','validate_field_survival_kit.py','prepare_weapon_kit_review.py','package_weapon_kit.py']
(OUT/'build_scripts').mkdir(exist_ok=True)
for name in scripts:(OUT/'build_scripts'/name).write_text(Path(__file__).with_name(name).read_text(encoding='utf-8'),encoding='utf-8',newline='\n')
meta['build_scripts']={name:sha(OUT/'build_scripts'/name) for name in scripts}
for name,r in meta['assets'].items():
    _,g,v=read_glb(OUT/r['glb']);world={}
    def visit(i,parent):
        n=g['nodes'][i];m=parent@transform(n);world[n['name']]=m
        for c in n.get('children',[]):visit(c,m)
    for i in g['scenes'][g.get('scene',0)]['nodes']:visit(i,np.eye(4))
    r['attachments']={n['name']:{'parent_local_translation_m':n.get('translation',[0,0,0]),'rotation_xyzw':n.get('rotation',[0,0,0,1]),'rest_root_space_translation_m':world[n['name']][:3,3].tolist()} for n in g['nodes'] if n.get('name') in r['nodes']}
    r['collision_policy']='No collision exported. Held models use no player collision; world pickups need simple engine collision shapes.'
(OUT/'manifest.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8',newline='\n')

font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',23);small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
weapons=[(n,r) for n,r in meta['assets'].items() if r['kind']=='weapon'];extras=[(n,r) for n,r in meta['assets'].items() if r['kind']=='reload_extra']
sheet=Image.new('RGB',(1800,1640),(22,28,30));d=ImageDraw.Draw(sheet);d.text((20,12),'NORTH RIDGE / GODOT GPU REVIEW — original proportions, panels normalised',font=font,fill=(227,224,206))
for i,(name,r) in enumerate(weapons):
    x=(i%2)*900;y=50+(i//2)*394
    tile=Image.open(OUT/'previews'/('godot_'+name+'.png')).convert('RGB').crop((0,80,1200,535)).resize((880,334));sheet.paste(tile,(x+10,y))
    d.text((x+18,y+336),name.replace('_',' '),font=font,fill=(227,224,206));d.text((x+18,y+365),f'{r["triangles"]:,} triangles / {len(r["animations"])} clips',font=small,fill=(170,187,167))
sheet.save(OUT/'previews/godot_contact_sheet.png')
for name in ['ridge_scout_rifle','brush_lever_rifle','compact_patrol_rifle']:
    board=Image.new('RGB',(1800,1500),(22,28,30));d=ImageDraw.Draw(board)
    clip='reload_insert' if name=='brush_lever_rifle' else 'reload_empty';duration=meta['assets'][name]['animations'][clip]['duration_s']
    d.text((15,10),name.replace('_',' ')+' / '+clip+' — exported component animation; character hands not shown',font=font,fill=(227,224,206))
    for k in range(5):
        x=(k%2)*900;y=50+(k//2)*480
        tile=Image.open(OUT/'previews'/f'reload_{name}_{k}.png').convert('RGB').resize((880,440));board.paste(tile,(x+10,y))
        d.text((x+15,y+442),f'{duration*k/4:.2f} seconds',font=small,fill=(170,187,167))
    board.save(OUT/'previews'/('storyboard_'+name+'.png'))
extra_sheet=Image.new('RGB',(1800,1070),(22,28,30));d=ImageDraw.Draw(extra_sheet)
d.text((20,12),'NORTH RIDGE / RELOAD EXTRAS — seven matched magazines and three handling props',font=font,fill=(227,224,206))
for i,(name,r) in enumerate(extras):
    x=(i%5)*360;y=55+(i//5)*500
    tile=Image.open(OUT/'previews'/('godot_'+name+'.png')).convert('RGB').resize((350,175));extra_sheet.paste(tile,(x+5,y+80))
    label=name.replace('_spare_magazine','\nmagazine').replace('_',' ');d.text((x+10,y+355),label,font=small,fill=(227,224,206))
    d.text((x+10,y+412),' x '.join(f'{v:.3f}' for v in r['dimensions_m'])+' m',font=small,fill=(170,187,167))
extra_sheet.save(OUT/'previews/reload_extras.png')

lines=['# North Ridge / Weapon Art Kit v1','',
'Eight original fictional firearms inspired by the supplied visual sheet, plus seven matching spare magazines, one visual round, one spent case and one loading strip. Created locally with Blender 5.2.2 and Python; no downloaded meshes, paid services or addons. All dimensions below are final vertex measurements at a 1 metre unit scale. The reference image supplies appearance guidance, not reliable absolute dimensions.','',
'## Open and edit','',
'Open **north_ridge_weapon_library.blend** for the actual-scale library. Individual **source/*.blend** are normal editable scenes with packed original textures. **godot/*.glb** embed their textures, named component nodes and animations. The isolated **godot/project.godot** and **gallery.gd** exercise imports and render review images. The live game is unchanged.','',
'In Blender, select **Preview_Clips.py** in the Text Editor, set ASSET and CLIP at the top, then Run Script and play the timeline. The helper binds the matching component actions and their Blender 5.2 action slots directly; it restores the saved resting transforms on every selection. Named NLA tracks remain the export grouping. Their native export sampling state is not used as the preview mixer. Spare props have no animation clips.','',
'## Scale and attachments','',
'Godot uses +Y up and -Z muzzle forward. Blender uses Z up, with +Y muzzle forward. Weapon origin is a trigger-hand reference rather than a ground-resting pivot. Socket_HandR and Socket_HandL are animated wrist reference targets. Socket_TriggerFinger, Socket_BoltHand, Socket_MagazineHand, Socket_MagazineInsert, Socket_Aim, Socket_Muzzle and Socket_Ejection identify handling and effects locations; the lever rifle also has Socket_LoadingGate. Asset IDs prefix every node. Attachment records include parent-local transforms and composed rest positions in weapon-root space.','',
'Rigid components use Pivot nodes with attached meshes, not one merged static weapon. Bolts, charging handles, triggers, magazine releases, safeties and magazines stay independent; the carbine includes a bolt handle, the lever gun its lever/loading gate, and the compact rifle its folding stock. Safety controls are editable pivots, with no safety-toggle animation authored. No collision is exported. Use simple pickup collision shapes for world weapons and no player-blocking collision for held copies.','',
'## Contents','',
'| Asset | Width x height x length (m) | Triangles | Clips |','|---|---:|---:|---:|']
for name,r in meta['assets'].items():lines.append('| '+name+' | '+' x '.join(f'{v:.3f}' for v in r['dimensions_m'])+' | '+str(r['triangles'])+' | '+str(len(r['animations']))+' |')
lines+=['','## Animation contract','',
'67 exported clips in total. Every weapon has idle, fire, cycle, inspect, equip and unequip. Seven detachable-magazine weapons have reload_tactical and reload_empty. The lever weapon instead has reload_start, reload_insert and reload_end; reload_insert can repeat, retaining the tilt and matching the preceding/following wrist targets. The compact rifle also has stock_fold and stock_unfold. Durations and events are quantised to the actual 30 fps keyframes and recorded separately in manifest.json.','',
'Tactical reloads detach a magazine, carry it out of the view area, return and reseat. The magazine_exchange_out_of_view marker permits a future runtime magazine resource swap; the art reuses the same mesh. Empty reloads also operate the action. The lever insertion exposes a temporary visual round and moves the loading gate. Self-loading fire clips include action movement and case ejection; bolt/lever rifles use a separate manual cycle. Ejection and insertion props hide using a tiny nonzero scale, preserving invertible transforms and their geometry through export.','',
'Events are metadata rather than gameplay callbacks. magazine_seated, round_inserted and reload_complete must be connected to the existing inventory/ammo state machine deliberately. Reload cancellation must preserve already completed resource transfers and restore or persist the current magazine/action state. Avoid awarding ammunition when a clip merely starts or an inspect action plays. Held props and ejection display meshes are visual state, not duplicate inventory items.','',
'## Surface and geometry policy','',
'Original 1024px albedo, roughness and OpenGL +Y normal maps for three woods, blued steel, lighter steel, brass and rubber, plus eight original receiver markings. Textures are packed in Blender and embedded in GLB exports. Static surfaces share meshes by material within each rigid component. Each weapon is under 8,000 triangles; the full 18-asset kit totals '+str(sum(r['triangles'] for r in meta['assets'].values()))+' triangles. Barrel muzzles are recessed openings, the vented shields have actual holes and wall thickness, and the receiver shells have bounded action recesses.','',
'## Verification and review','',
'validation.json independently checks the GLB binary structure, exact hashes, actual vertex dimensions and bounds, finite unit normals/UVs, embedded textures, non-degenerate triangles, component names, all clip names, key times, nonempty movement and duration/event contracts. native_validation.json records reopening all 18 normal Blender scenes, packed textures and exercising all component action clips with the shipped preview helper. godot/engine_validation.json records actual Godot 4.7.2 import and motion for all 67 clips, magazine detachment/reseating and visible uncollapsed case geometry. Forward+ Vulkan GPU renders ran on the GTX 1080 Ti.','',
'previews/contact_sheet.png shows Blender output; godot_contact_sheet.png and left/right close-ups show actual Godot rendering. Three storyboards show reload phases; reload_extras.png shows the detachable props. Panels preserve proportions but normalise display size. Iterations corrected stock/trigger gaps, overlarge ports, repeated action controls, hidden-prop geometry collapse, native rest-pose export side effects, Blender action preview bindings, stock variety and receiver identities.','',
'## Gameplay integration still required','',
'These assets are prepared and validated separately from the player viewmodel. Animated wrist targets are not skinned hand animations. Each design still needs palm/finger fitting, magazine and bolt hand contact, wrist/elbow reach checks, ADS camera alignment and player-camera clipping review with the existing hand system. Reload/firing sounds, muzzle/impact effects, runtime ammo transfers and interruptible weapon state are not implemented by this pack. The current single-rifle offsets cannot be assumed to fit all eight designs.','',
'Review first-person lighting and texture density at the real gameplay field of view before selecting final weapon offsets. Decide which firearms belong in the Canadian survival setting and their loot/ammo balance before admission. Use a smaller world-pickup representation/LOD when many are visible; this pack supplies the editable near-view geometry, with no separately authored world LOD tiers. No gameplay performance result or human playtest is claimed by the isolated GPU check.','',
'## Rebuild','',
'Use the repository scripts in tools/blender: gen_weapon_kit_textures.py with the existing Python environment; gen_north_ridge_weapons.py in Blender with --render; finalize_weapon_kit_sources.py; verify_weapon_kit_native.py; validate_weapon_kit.py and prepare_weapon_kit_review.py with Python. Import the isolated Godot project to completion, then run gallery.gd with --rendering-method forward_plus. Finally run package_weapon_kit.py. Included build_scripts copies record the pipeline; root resolution expects their original repository locations. The mesh/PBR helper prefix and GLB binary reader come from our preceding original survival-kit tools.','',
'## Integrity and rollback','',
'All new geometry, surfaces and printwork are original project work; the user image is recorded by hash and excluded from distribution. package_hashes.json lists exactly the delivered package files. The ZIP contains that roster and the hash list. Disposable import caches, extracted PNGs, logs, local iteration sheets and Blender backups are excluded. Reverting the scoped asset commit removes this package and its tools; live gameplay and map files are not part of the change. No push is made.']
(OUT/'README.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
receipt={'assets':18,'weapons':8,'reload_extras':10,'animation_clips':count,'triangles':sum(r['triangles'] for r in results.values()),'glb_geometry_and_animation':'passed','native_sources_and_action_playback':'18 passed / 67 clips','godot_gpu_playback':'18 passed / 67 clips','renderer':'Forward+ Vulkan / GTX 1080 Ti','runtime_replacement':False,'human_hand_fitting':False,'accepted_logs':{name:sha(OUT/name) for name in logs}}
(OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8',newline='\n')
for p in OUT.rglob('*'):
    if p.is_file() and '.godot' not in p.relative_to(OUT).parts and p.suffix in ('.json','.gd','.godot','.md','.py','.uid'):p.write_text(p.read_text(encoding='utf-8'),encoding='utf-8',newline='\n')
files=[]
for p in sorted(OUT.rglob('*')):
    if not p.is_file():continue
    rel=p.relative_to(OUT)
    if '.godot' in rel.parts or p.suffix in ('.log','.zip','.blend1','.blend2','.import') or p.name in ('package_hashes.json','iteration_review.png'):continue
    if rel.parts[0]=='godot' and p.suffix=='.png':continue
    files.append(p)
roster={p.relative_to(OUT).as_posix():sha(p) for p in files};hashfile=OUT/'package_hashes.json'
hashfile.write_text(json.dumps(roster,indent=2)+'\n',encoding='utf-8',newline='\n')
archive=OUT/'north_ridge_weapon_kit_v1.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=4) as z:
    for p in files+[hashfile]:z.write(p,p.relative_to(OUT).as_posix())
with zipfile.ZipFile(archive) as z:
    assert set(z.namelist())==set(roster)|{'package_hashes.json'}
    for name,digest in roster.items():assert hashlib.sha256(z.read(name)).hexdigest()==digest
print('WEAPON_PACKAGE_VERIFIED',len(roster),'files',round(archive.stat().st_size/1000000,2),'MB',count,'clips')
