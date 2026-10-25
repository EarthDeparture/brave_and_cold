class_name FoodPortion
extends RefCounted
## One reserved portion. Heat advances work; all game time advances spoilage.
## Age converts by fraction of shelf life at completion, never back to fresh.
static func create(input_id:String, output_id:String, seconds:float, age:float) -> Dictionary:
	return {"id":output_id,"remaining_s":seconds,"age_s":maxf(0,age),"shelf_s":Inventory.shelf_s(input_id)}

static func advance(p:Dictionary, game_s:float, burn_s:float) -> void:
	if p.is_empty() or p.id=="rotten_meat":return
	var elapsed:=maxf(0,game_s)
	var left:=maxf(0,float(p.get("remaining_s",0)))
	var shelf:=float(p.get("shelf_s",Inventory.shelf_s(String(p.id))))
	var age:=maxf(0,float(p.get("age_s",0)))
	var active:=minf(left,clampf(burn_s,0,elapsed))
	if left>0 and active>=left:
		age+=active
		if shelf>0 and age>=shelf:
			_spoil(p);return
		var output_shelf:=Inventory.shelf_s(String(p.id))
		age=age/shelf*output_shelf if shelf>0 else 0.0
		shelf=output_shelf
		age+=elapsed-active
	else:age+=elapsed
	p.remaining_s=maxf(0,left-active);p.age_s=age;p.shelf_s=shelf
	if shelf>0 and age>=shelf:_spoil(p)

static func _spoil(p:Dictionary) -> void:
	p.id="rotten_meat";p.remaining_s=0.0;p.age_s=0.0;p.shelf_s=0.0

static func collect(p:Dictionary, inv:Inventory) -> bool:
	if p.is_empty() or float(p.get("remaining_s",0))>0:return false
	if not inv.can_add(String(p.id)):return false
	inv.add_aged(String(p.id),1,float(p.get("age_s",0)));return true
