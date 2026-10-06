"""Seal the original field kit with file hashes, review evidence and an archive."""
from pathlib import Path
import json,hashlib,shutil,zipfile
from validate_field_survival_kit import validate,read_glb
OUT=Path(__file__).parent/'generated/field_survival_kit_v1'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
meta=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
results=validate()
texture_manifest=json.loads((OUT/'textures/manifest.json').read_text(encoding='utf-8'))
for name,digest in texture_manifest['files'].items():assert sha(OUT/'textures'/name)==digest,name
native=json.loads((OUT/'native_validation.json').read_text(encoding='utf-8'));assert len(native)==32
engine=json.loads((OUT/'godot/engine_validation.json').read_text(encoding='utf-8'));assert len(engine['assets'])==32
for log,success in [('native_check.log','FIELD_KIT_NATIVE_PASS 32'),('godot_gpu_final.log','FIELD_KIT_GODOT_PASS assets=32')]:
    text=(OUT/log).read_text(encoding='utf-8');assert success in text and 'SCRIPT ERROR' not in text and 'Traceback' not in text,log
assert not any(t in (OUT/'godot_import_final.log').read_text(encoding='utf-8') for t in ['SCRIPT ERROR','Parse Error','Error importing'])
reference=Path('C:/Users/parst/AppData/Local/Temp/codex-clipboard-6a2b4463-7b88-4da9-821a-0bdf61fd0af9.png')
meta['source_reference_sha256']=sha(reference)
meta['reference_usage']='User-provided 1920x1080 survival equipment sheet; visual guidance. Reference image is not redistributed.'
meta['dimension_basis']='Chosen plausible real-world dimensions, measured from final vertices; the reference supplies no reliable absolute scale.'
meta['license_note']='Original project-authored geometry and printwork. Ownership/licensing follows this project; no third-party mesh or texture package is included.'
meta['library_sha256']=sha(OUT/'field_survival_library.blend')
scripts=['gen_field_kit_textures.py','gen_field_survival_kit.py','finalize_field_kit_sources.py','refresh_field_kit_radio.py','refine_field_kit_case.py','verify_field_kit_native.py','validate_field_survival_kit.py','prepare_field_kit_review.py','package_field_survival_kit.py']
(OUT/'build_scripts').mkdir(exist_ok=True)
for name in scripts:
    (OUT/'build_scripts'/name).write_text((Path(__file__).parent/name).read_text(encoding='utf-8'),encoding='utf-8',newline='\n')
meta['build_scripts']={name:sha(OUT/'build_scripts'/name) for name in scripts}
for name,r in meta['assets'].items():
    _,glb,_=read_glb(OUT/r['glb'])
    r['attachment_transforms']={n['name']:{'translation_m':n.get('translation',[0,0,0]),'rotation_xyzw':n.get('rotation',[0,0,0,1]),'scale':n.get('scale',[1,1,1])} for n in glb['nodes'] if n.get('name') in r['pivots']}
    r['pivot_use']={}
    for pivot in r['pivots']:
        if '__Pivot_' in pivot:
            axis='Z' if any(s in pivot for s in ['_MatchTray','_TuningKnob']) else ('Y' if any(s in pivot for s in ['_Cap','_FuelCap','_Needle']) else 'X')
            r['pivot_use'][pivot]={'operation':'translate' if '_MatchTray' in pivot else 'rotate','axis':axis,'note':'Local component pivot, geometry attached.'}
    r['collision_recommendation']='No collision is exported. Use a simple engine shape for world placement; inventory/held copies should not block the player.'
    if any(s in name for s in ['pot','skillet','first_aid']):r['collision_recommendation']='Compound low-detail shapes if the hollow interior is interactive; avoid a convex hull that fills the cavity.'
(OUT/'manifest.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8',newline='\n')
lines=['# North Ridge / Field Survival Kit v1\n',
'32 original props and state variants, created with local Blender 5.2.2/Python from the user-provided visual reference. Includes its survival-equipment categories plus two matching removable pot lids.\n',
'## Open and edit\n',
'Open **field_survival_library.blend** for the complete collection at actual metre scale on a spaced grid. Each asset also has an opening-ready individual scene under **source/**, with original textures packed. **godot/*.glb** are independent portable Y-up exports with embedded PBR textures. **previews/contact_sheet.png** normalises panel size for comparison; it does not show relative physical scale.\n',
'Front is +Z, height is +Y in Godot; tools are upright along +Y. Blender uses its normal Z-up coordinates and a 1 metre unit scale. Resting geometry stays within 2 mm of Y=0. Dimensions below are measured from the actual final vertices, including handles, caps and the extended radio antenna. Physical sizes were selected for plausible use; the sheet cannot establish absolute scale.\n',
'Each moving component keeps an asset-prefixed Pivot node. Socket nodes mark grip, carry, mouth, beam, back attachment or working contact locations. Use the exact names and local transforms in the GLB, rather than relying on mesh order. These are rigid component pivots and attachment markers; character hand skinning is a separate system.\n',
'## Contents and dimensions\n',
'| Asset | Width x height x depth (m) | Triangles |\n|---|---:|---:|']
for name,r in meta['assets'].items():lines.append('| '+name+' | '+' x '.join(f'{v:.3f}' for v in r['measured_size_m'])+' | '+str(r['triangles'])+' |')
lines+=['\n## Surface and geometry policy\n',
'Original shared 512px surface maps for cloth, cotton, leather, wood, stone, enamel, rubber and metal; readable original 1024px packaging and a 1536x256 radio strip. Normal maps use OpenGL +Y. Images are embedded in the GLBs and packed into native scenes. Geometry budgets: at most 24,000 triangles and eight materials per prop. Final total: '+str(sum(r['triangles'] for r in meta['assets'].values()))+' triangles. The largest model is the 10,124-triangle backpack. Meshes remain separate only where materials or moving components need that separation.\n',
'Cooking vessels have continuous thick walls and open cavities. The first-aid case has a hollow body and front-bottom lid hinge. Trap jaws share the same mechanical hinge axis between open/closed variants. Compass lid and needle remain independent; closed lid hides the needle. Match tray slides; bottle caps detach; radio antenna and tuning knob remain adjustable.\n',
'No rigid-body mass, collision meshes, interaction scripts, fuel functionality or inventory entries are added by this asset package. World placement should use simple engine collision shapes; hollow vessels/cases need compound shapes if their cavities matter. Held/inventory copies should have no player-blocking collision. Existing maps, held models, saves and gameplay code are unchanged.\n',
'## Validation and review\n',
'validation.json independently checks GLB structure, exact hashes, vertex dimensions, finite unit normals, UVs, embedded textures, non-degenerate triangles and named pivots. native_validation.json records reopening all 32 individual Blender scenes and checking metre scale, packed textures and dimensions. godot/engine_validation.json records actual Godot 4.7.2 import, metre dimensions, named sockets and moving each Pivot with its attached vertices. Forward+ D3D12 previews were rendered on a GTX 1080 Ti; this is an isolated art/import review, not a gameplay performance benchmark.\n',
'Reviewed iterations corrected the tank collar, backpack body, curved labels and mirrored tin print, closed-compass overlap, trap hinge placement, excess small-prop triangles, radio label aspect, and the medical case cavity. Final Blender contact sheet and Godot close-ups show the shipped shapes. Live held-item integration still requires fitting each tool to the existing hand poses and confirming reach/contact in player-camera views. Mass and resource balancing should continue to use the existing gameplay definitions.\n',
'## Rebuild\n',
'Run the original scripts under tools/blender from the repository root: generate textures; run gen_field_survival_kit.py in Blender with --render; run finalize_field_kit_sources.py; refresh_field_kit_radio.py; refine_field_kit_case.py; verify_field_kit_native.py; run validate_field_survival_kit.py and prepare_field_kit_review.py with the existing Python environment. Import the isolated godot/ project and run gallery.gd for GPU checks, then package_field_survival_kit.py. The included build_scripts/ copies are provenance copies; the original repository paths preserve root resolution. No downloaded addons or asset services are required.\n',
'## Provenance and package integrity\n',
'All new geometry, printwork and surfaces were authored locally for this project. The user reference image is recorded by hash and is not included. package_hashes.json binds the delivered Blender, GLB, source, texture, metadata and preview files. It excludes disposable Blender backups, import caches and logs. The ZIP contains precisely that roster plus the hash file. No push was made.']
(OUT/'README.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
receipt={'asset_count':32,'triangles':sum(r['triangles'] for r in meta['assets'].values()),'static_glb':'passed','native_reopen':'32 passed','godot_gpu_import_and_pivots':'32 passed','renderer':'Forward+ D3D12 / GTX 1080 Ti','runtime_replacement':False,'accepted_log_hashes':{n:sha(OUT/n) for n in ['native_check.log','godot_gpu_final.log','godot_import_final.log']},'reviewed':'Blender sheet and Godot close-ups; original reference used as guidance; no human gameplay assessment claimed.'}
(OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
# Canonical LF text survives the repository's text=eol=lf checkout policy.
for p in OUT.rglob('*'):
    if p.is_file() and '.godot' not in p.relative_to(OUT).parts and p.suffix in ('.json','.gd','.godot','.md','.py','.uid'):
        p.write_text(p.read_text(encoding='utf-8'),encoding='utf-8',newline='\n')
files=[]
for p in sorted(OUT.rglob('*')):
    if not p.is_file():continue
    rel=p.relative_to(OUT)
    if '.godot' in rel.parts or p.suffix in ('.log','.zip','.blend1','.blend2','.import') or p.name=='package_hashes.json':continue
    if rel.parts[0]=='godot' and p.suffix=='.png':continue
    files.append(p)
roster={p.relative_to(OUT).as_posix():sha(p) for p in files}
roster_path=OUT/'package_hashes.json';roster_path.write_text(json.dumps(roster,indent=2)+'\n',encoding='utf-8',newline='\n')
archive=OUT/'north_ridge_field_survival_kit_v1.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=4) as z:
    for p in files+[roster_path]:z.write(p,p.relative_to(OUT).as_posix())
with zipfile.ZipFile(archive) as z:
    assert set(z.namelist())==set(roster)|{'package_hashes.json'}
    for name,digest in roster.items():assert hashlib.sha256(z.read(name)).hexdigest()==digest,name
print('FIELD_KIT_PACKAGE_VERIFIED',len(roster),'files',round(archive.stat().st_size/1000000,2),'MB')
