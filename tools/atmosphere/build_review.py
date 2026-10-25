from pathlib import Path
import hashlib, json, statistics
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[2]
shots = root / "brave-and-cold/shots/atmosphere"
review = shots / "review"
review.mkdir(parents=True, exist_ok=True)
before = json.loads((shots / "final-before/manifest.json").read_text())
after = json.loads((shots / "final/manifest.json").read_text())
b = {r["id"]:r for r in before["captures"]}
a = {r["id"]:r for r in after["captures"]}
assert b.keys() == a.keys() and len(a) == 20
for name in a:
    for key in ["hour","weather","eye","target","inside","fov","overcast","cloud_coverage"]:
        assert a[name][key] == b[name][key], (name,key)
    for folder, manifest in [("final-before",b),("final",a)]:
        path = shots / folder / (name+".png")
        assert hashlib.sha256(path.read_bytes()).hexdigest() == manifest[name]["sha256"]
assert before["wind_phase_s"] == after["wind_phase_s"] == 120
font_path = Path("C:/Windows/Fonts/segoeui.ttf")
font = ImageFont.truetype(str(font_path),24) if font_path.exists() else ImageFont.load_default()
small = ImageFont.truetype(str(font_path),18) if font_path.exists() else ImageFont.load_default()
def cell(folder,name,width):
    im=Image.open(shots/folder/(name+".png")).convert("RGB")
    return im.resize((width,round(width*9/16)),Image.Resampling.LANCZOS)
def pairs(names,target):
    width=800; height=450
    im=Image.new("RGB",(1600,len(names)*(height+44)),(17,23,31))
    draw=ImageDraw.Draw(im)
    for row,name in enumerate(names):
        y=row*(height+44)
        draw.text((16,y+8),"BEFORE — "+name.replace("-"," "),font=font,fill="white")
        draw.text((816,y+8),"AFTER — "+name.replace("-"," "),font=font,fill="white")
        im.paste(cell("final-before",name,width),(0,y+44))
        im.paste(cell("final",name,width),(800,y+44))
    im.save(review/target)
pairs(["clear-lookout","dusk-lookout"],"before-after.png")
pairs(["clear-forest","overcast-forest","clear-lake","blizzard-interior","night-interior"],"surface-shelter-comparisons.png")
names=list(a)
sheet=Image.new("RGB",(2400,5*374),(17,23,31))
draw=ImageDraw.Draw(sheet)
for i,name in enumerate(names):
    x=(i%4)*600; y=(i//4)*374
    draw.text((x+12,y+6),name.replace("-"," "),font=small,fill="white")
    sheet.paste(cell("final",name,600),(x,y+36))
sheet.save(review/"all-20-final-views.png")
frames=[]
old=sorted((shots/"film-baseline").glob("deck-day-*.png"))
new=sorted((shots/"film-winter").glob("deck-day-*.png"))
assert len(old)==len(new)==40
for op,np in zip(old,new):
    frame=Image.new("RGB",(1600,494),(17,23,31))
    draw=ImageDraw.Draw(frame)
    draw.text((16,8),"BEFORE — actual moving-camera render",font=font,fill="white")
    draw.text((816,8),"AFTER — actual moving-camera render",font=font,fill="white")
    frame.paste(Image.open(op).convert("RGB").resize((800,450),Image.Resampling.LANCZOS),(0,44))
    frame.paste(Image.open(np).convert("RGB").resize((800,450),Image.Resampling.LANCZOS),(800,44))
    frames.append(frame)
frames[0].save(review/"moving-before-after.gif",save_all=True,append_images=frames[1:],duration=100,loop=0,optimize=False)
def measured(folder):
    return json.loads((shots/folder/"manifest.json").read_text())
metrics=[]
for old_folder,new_folder in [("motion-before","motion-after"),("live-before","live-after")]:
    om,nm=measured(old_folder),measured(new_folder)
    for name in dict.fromkeys(r["id"] for r in om["scenarios"]):
        rows=[]
        for m in [om,nm]:
            rows.append({key:round(statistics.median(r[key] for r in m["scenarios"] if r["id"]==name),3) for key in ["median_ms","p99_ms","engine_process_median_ms"]})
        metrics.append({"scenario":name,"live":nm["live_gameplay"],"before":rows[0],"after":rows[1],"delta_ms":round(rows[1]["median_ms"]-rows[0]["median_ms"],3),"median_increase_percent":round(100*(rows[1]["median_ms"]/rows[0]["median_ms"]-1),1)})
receipt={"schema":1,"renderer_commit":"12b3ccd","baseline_commit":"8a623693988c371a976d6a304151c78cdf4a37ae","matched_views":20,"image_hashes_verified":True,"camera_weather_wind_inputs_verified":True,"gpu":after["gpu"],"resolution":after["resolution"],"engine":after["engine"],"metrics":metrics,"caveat":"Median across three repeat medians and three repeat p99 values. These are bounded wall-clock frame observations, not full campaign or horde stress performance. Film captures include readback overhead and are excluded from performance claims.","render_source_hashes":after["source_hashes"]}
(review/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n")
print(json.dumps(metrics,indent=2))
print("VERIFIED 20 matched camera/weather views and unchanged render image hashes; 40 actual moving frames per variant.")
