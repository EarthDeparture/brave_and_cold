class_name PreparedWater
extends RefCounted
## A four-bottle kettle; containers stay reserved until the finished water is collected.
const CAP := 4
const BATCH_S := 1200.0
var batch := 0
var remaining_s := 0.0
var ready := 0
func begin(inv: Inventory) -> String:
	if batch>0 or ready>0:return "Collect the kettle's previous batch first"
	var n:=mini(CAP,mini(inv.count("snow_portion"),inv.count("empty_bottle")))
	if n==0:return "Bring snow portions and empty bottles to the stove"
	inv.remove("snow_portion",n);inv.remove("empty_bottle",n)
	batch=n;remaining_s=BATCH_S
	return "Boiling %.1f L; containers reserved in the kettle"%(n*.5)
func advance(burn_s: float) -> void:
	if batch<=0:return
	remaining_s=maxf(0,remaining_s-maxf(0,burn_s))
	if remaining_s==0:ready=batch;batch=0
func collect(inv: Inventory) -> int:
	var n:=0
	while ready>0 and inv.can_add("clean_water"):
		inv.add("clean_water");ready-=1;n+=1
	return n
func status() -> String:
	if ready>0:return "Take boiled water • %.1f L ready"%(ready*.5)
	if batch>0:return "Boiling %.1f L • %d min remaining"%[batch*.5,ceili(remaining_s/60)]
	return "Boil snow • up to 2 L / 20 min"
func to_dict() -> Dictionary:return {"batch":batch,"remaining_s":remaining_s,"ready":ready}
func restore(d: Dictionary) -> void:
	batch=clampi(int(d.get("batch",0)),0,CAP);ready=clampi(int(d.get("ready",0)),0,CAP-batch)
	remaining_s=clampf(float(d.get("remaining_s",0)),0,BATCH_S)
	if batch>0 and remaining_s==0:ready=batch;batch=0
