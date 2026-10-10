class_name FoodPreservation
extends RefCounted
## Cook first; slice and dry four portions beside the burning lookout stove.
const CAP:=4
const DRY_S:=7200.0
const RECIPES:={"venison_cooked":"venison_dried","wolf_meat_cooked":"wolf_meat_dried","bear_meat_cooked":"bear_meat_dried","trout_cooked":"trout_dried","whitefish_cooked":"whitefish_dried","pike_cooked":"pike_dried"}
var portions:Array=[]

func reason(inv:Inventory) -> String:
	if not portions.is_empty():return "Empty the drying rack before loading it again"
	if inv.count("knife")==0 or inv.condition("knife")<.04:return "Bring a hunting knife with at least 4% condition"
	for id:String in RECIPES:
		if inv.count(id)>0 and inv.freshness(id)>0:return ""
	return "Cook meat or fish before slicing it for drying"

func begin(inv:Inventory) -> String:
	var why:=reason(inv)
	if why!="":return why
	var ids:Array=RECIPES.keys()
	ids.sort_custom(func(a,b)->bool:return inv.freshness(a)<inv.freshness(b) if not is_equal_approx(inv.freshness(a),inv.freshness(b)) else String(a)<String(b))
	for id:String in ids:
		while inv.count(id)>0 and inv.freshness(id)>0 and portions.size()<CAP:
			var age:=float(inv.age.get(id,0))
			if not inv.remove(id):break
			portions.append(FoodPortion.create(id,RECIPES[id],DRY_S,age))
	inv.wear("knife",.01*portions.size())
	return "Sliced %d portions. Drying needs two hours of stove burn; unheated food still spoils."%portions.size()

## Rack model: one strip per uncollected, unspoiled portion (Portion0..3 nodes).
static func sync_model(model:Node3D,pres:FoodPreservation) -> void:
	for i in CAP:
		var portion:=model.find_child("Portion%d"%i,true,false) as Node3D
		if portion!=null:portion.visible=i<pres.portions.size() and pres.portions[i].id!="rotten_meat"

func advance(game_s:float,burn_s:float) -> void:
	for p:Dictionary in portions:FoodPortion.advance(p,game_s,burn_s)

func collect(inv:Inventory) -> int:
	var keep:Array=[];var taken:=0
	for p:Dictionary in portions:
		if FoodPortion.collect(p,inv):taken+=1
		else:keep.append(p)
	portions=keep;return taken

func ready_count() -> int:
	var n:=0
	for p:Dictionary in portions:
		if float(p.remaining_s)<=0:n+=1
	return n

func status() -> String:
	if portions.is_empty():return "Load cooked meat or fish • 4-portion drying rack"
	var spoiled:=0;var remaining:=0.0
	for p:Dictionary in portions:
		if p.id=="rotten_meat":spoiled+=1
		remaining=maxf(remaining,float(p.remaining_s))
	if ready_count()>0:return "Collect rack food (%d ready%s)"%[ready_count()," • %d spoiled"%spoiled if spoiled else ""]
	return "Drying %d portions • %d min of stove burn left"%[portions.size(),int(ceil(remaining/60))]

func to_dict() -> Dictionary:return {"portions":portions.duplicate(true)}
func restore(saved:Dictionary) -> void:
	portions=[]
	for entry:Variant in saved.get("portions",[]):
		if entry is not Dictionary or portions.size()>=CAP:continue
		var p:Dictionary=entry.duplicate(true)
		if String(p.get("id","")) not in RECIPES.values() and p.get("id","")!="rotten_meat":continue
		p.remaining_s=clampf(float(p.get("remaining_s",0)),0,DRY_S)
		FoodPortion.advance(p,0,0);portions.append(p)
