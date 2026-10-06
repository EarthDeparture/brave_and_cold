"""Build original contact sheets and an isolated Godot import/render fixture."""
from pathlib import Path
import json, hashlib
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).parent/'generated/field_survival_kit_v1'
meta=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',19)
im=Image.new('RGB',(2560,1480),(27,31,31));d=ImageDraw.Draw(im)
d.text((20,10),'NORTH RIDGE / ORIGINAL FIELD SURVIVAL KIT — panels normalised for inspection; dimensions are real metres',font=font,fill=(226,224,202))
for i,(name,r) in enumerate(meta['assets'].items()):
    x=(i%8)*320;y=40+(i//8)*360
    tile=Image.open(OUT/'previews'/f'{name}.png').convert('RGB').resize((310,310))
    im.paste(tile,(x+5,y));d.text((x+8,y+314),name.replace('_',' '),font=font,fill=(226,224,202))
    w,h,depth=r['measured_size_m']
    d.text((x+8,y+339),f'{r["triangles"]:,} tri / {w:.3f} x {h:.3f} x {depth:.3f} m',font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',15),fill=(166,178,158))
im.save(OUT/'previews/contact_sheet.png')
engine=OUT/'godot'
(engine/'metadata.json').write_text(json.dumps(meta['assets'],indent=2)+'\n',encoding='utf-8')
(engine/'project.godot').write_text('''config_version=5
[application]
config/name="North Ridge Field Kit / Isolated Review"
[display]
window/size/viewport_width=1600
window/size/viewport_height=900
[rendering]
renderer/rendering_method="gl_compatibility"
environment/defaults/default_clear_color=Color(0.07, 0.085, 0.09, 1)
''',encoding='utf-8')
(engine/'gallery.gd').write_text('''extends SceneTree
var w:Node3D
var cam:Camera3D
var entries:Dictionary
var current:Node3D
var results:Dictionary={}
func _initialize()->void:call_deferred("run")
func vertices(n:Node,points:Array[Vector3])->void:
\tif n is MeshInstance3D:
\t\tfor s in n.mesh.get_surface_count():
\t\t\tfor v:Vector3 in n.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:points.append(n.global_transform*v)
\tfor child in n.get_children():vertices(child,points)
func run()->void:
\tcreate_timer(90).timeout.connect(func()->void:quit(2))
\troot.size=Vector2i(1600,900);w=Node3D.new();root.add_child(w)
\tvar env:=WorldEnvironment.new();w.add_child(env);env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.065,.08,.085);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.76,.83,.88);env.environment.ambient_light_energy=.45;env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
\tvar sun:=DirectionalLight3D.new();w.add_child(sun);sun.rotation_degrees=Vector3(-48,-32,0);sun.light_energy=1.2;sun.shadow_enabled=true
\tcam=Camera3D.new();w.add_child(cam);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.keep_aspect=Camera3D.KEEP_WIDTH;cam.current=true
\tentries=JSON.parse_string(FileAccess.get_file_as_string("res://metadata.json"))
\tvar ids:Array=entries.keys()
\tfor page in 4:
\t\tvar group:=Node3D.new();w.add_child(group)
\t\tfor k in 8:
\t\t\tvar name:String=ids[page*8+k];var model:Node3D=load("res://"+name+".glb").instantiate();group.add_child(model)
\t\t\tvar p:Array[Vector3]=[];vertices(model,p);var lo:=Vector3(INF,INF,INF);var hi:=-lo
\t\t\tfor v in p:lo=lo.min(v);hi=hi.max(v)
\t\t\tvar expected:Array=entries[name].measured_size_m;var actual:=hi-lo
\t\t\tassert(actual.distance_to(Vector3(expected[0],expected[1],expected[2]))<.001,"Godot dimension mismatch: "+name)
\t\t\tfor pivot:String in entries[name].pivots:
\t\t\t\tvar part:Node3D=model.find_child(pivot,true,false);assert(part!=null,"Lost pivot: "+pivot)
\t\t\t\tif "__Pivot_" in pivot:
\t\t\t\t\tvar before:Array[Vector3]=[];vertices(part,before);assert(not before.is_empty(),"Unbound pivot: "+pivot)
\t\t\t\t\tvar original:Transform3D=part.transform;part.rotate_x(.3);var after:Array[Vector3]=[];vertices(part,after);part.transform=original
\t\t\t\t\tvar moved:=false
\t\t\t\t\tfor j in before.size():
\t\t\t\t\t\tif before[j].distance_to(after[j])>.00001:moved=true;break
\t\t\t\t\tassert(moved,"Non-functional pivot: "+pivot)
\t\t\tresults[name]={"dimensions_m":[actual.x,actual.y,actual.z],"pivots":entries[name].pivots.size()}
\t\t\t# Gallery display copies are normalised, while imported resources stay metre-scale.
\t\t\tvar factor:float=.98/maxf(actual.x,maxf(actual.y,actual.z));model.scale=Vector3.ONE*factor;model.position=Vector3((k%4)*1.8,.70-(k/4)*1.6,0)-(lo+hi)*.5*factor
\t\t\tvar text:=Label3D.new();group.add_child(text);text.text=name.replace("_"," ")+"\\n"+str(entries[name].triangles)+" triangles";text.font_size=34;text.pixel_size=.0023;text.position=Vector3((k%4)*1.8,-.1-(k/4)*1.6,.20);text.modulate=Color(.83,.85,.77);text.no_depth_test=true
\t\tcam.size=7.4;cam.position=Vector3(2.7,2.0,6.8);cam.look_at(Vector3(2.7,-.05,0),Vector3.UP)
\t\tfor frame in 20:await process_frame
\t\tawait RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("../previews/godot_page_"+str(page+1)+".png").simplify_path())
\t\tgroup.queue_free();await process_frame
\troot.size=Vector2i(900,900)
\tfor name:String in ids:
\t\tvar model:Node3D=load("res://"+name+".glb").instantiate();w.add_child(model)
\t\tvar points:Array[Vector3]=[];vertices(model,points);var lo:=Vector3(INF,INF,INF);var hi:=-lo
\t\tfor v in points:lo=lo.min(v);hi=hi.max(v)
\t\tvar dims:=hi-lo;var length:=maxf(dims.x,maxf(dims.y,dims.z));var center:Vector3=(hi+lo)*.5
\t\tcam.size=length*1.45;cam.position=center+Vector3(.9,.65,1.5)*length;cam.look_at(center,Vector3.UP)
\t\tfor frame in 12:await process_frame
\t\tawait RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("../previews/godot_"+name+".png").simplify_path())
\t\tmodel.queue_free();await process_frame
\tvar f:=FileAccess.open("res://engine_validation.json",FileAccess.WRITE);f.store_string(JSON.stringify({"engine":"Godot 4.7.2","assets":results,"scope":"Isolated import, metre-scale dimensions, named pivots and GPU contact sheets; no gameplay item replacement."},"  "));f.close()
\tprint("FIELD_KIT_GODOT_PASS assets=",results.size());quit()
''',encoding='utf-8',newline='\n')
print('FIELD_KIT_REVIEW_PREPARED')
