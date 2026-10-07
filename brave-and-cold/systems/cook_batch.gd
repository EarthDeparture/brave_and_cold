class_name CookBatch
extends RefCounted
## One portion per load, bounded stove slots, authoritative game-time aging.
const COOK_S:=1200.0
var capacity:=2
var portions:Array=[]
func _init(slots:int=2) -> void:capacity=clampi(slots,1,4)
func free_slots() -> int:return maxi(0,capacity-portions.size())
func begin(inv:Inventory,lit:bool) -> String:
	if not lit:return "Light the stove before cooking"
	if free_slots()==0:return "Collect food to free a stove slot"
	var ids:Array=[]
	for id:String in inv.counts:
		if Inventory.ITEMS[id].get("raw",false) and inv.freshness(id)>0:ids.append(id)
	ids.sort_custom(func(a,b)->bool:return inv.freshness(a)<inv.freshness(b) if not is_equal_approx(inv.freshness(a),inv.freshness(b)) else String(a)<String(b))
	if ids.is_empty():return "Bring raw meat or fish"
	var id:String=ids[0];var age:=float(inv.age.get(id,0))
	if not inv.remove(id):return "Food is no longer available"
	portions.append(FoodPortion.create(id,String(Inventory.ITEMS[id].cooked),COOK_S,age))
	return "Cooking %s - 20 minutes of stove burn"%inv.name_of(id)
func advance(game_s:float,burn_s:float) -> void:
	for p:Dictionary in portions:FoodPortion.advance(p,game_s,burn_s)
func ready_count() -> int:
	var n:=0
	for p:Dictionary in portions:
		if float(p.remaining_s)<=0:n+=1
	return n
func collect(inv:Inventory) -> int:
	var keep:Array=[];var n:=0
	for p:Dictionary in portions:
		if FoodPortion.collect(p,inv):n+=1
		else:keep.append(p)
	portions=keep;return n
func status() -> String:
	if ready_count()>0:return "Collect stove food (%d ready)"%ready_count()
	var seconds:=0.0
	for p:Dictionary in portions:seconds=maxf(seconds,float(p.remaining_s))
	return "Food cooking - %d min of burn left"%int(ceil(seconds/60))
func to_dict() -> Dictionary:return {"portions":portions.duplicate(true)}
func restore(saved:Dictionary) -> void:
	portions=[]
	for entry:Variant in saved.get("portions",[]):
		if entry is not Dictionary or portions.size()>=capacity:continue
		var p:Dictionary=entry.duplicate(true);var id:=String(p.get("id",""))
		if id!="rotten_meat" and id not in FoodPreservation.RECIPES:continue
		p.remaining_s=clampf(float(p.get("remaining_s",0)),0,COOK_S)
		FoodPortion.advance(p,0,0);portions.append(p)
