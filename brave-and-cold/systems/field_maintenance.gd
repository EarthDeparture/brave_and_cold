class_name FieldMaintenance
extends RefCounted
## Costs are rechecked at completion; interrupted work spends nothing.
static func repairable(id:String)->bool:return id in ["axe","knife","hammer"] or Inventory.kind_of(id)=="clothing"
static func reason(inv:Inventory,id:String)->String:
 if not repairable(id) or inv.count(id)==0:return "No maintainable item"
 if inv.condition(id)>=.98:return "Condition is already good"
 if id in ["axe","knife"]:
  if inv.count("whetstone")==0 or inv.condition("whetstone")<.08:return "Need a usable whetstone"
  if inv.count("rag")<1:return "Need one rag"
 elif id=="hammer":
  if inv.count("service_kit")<1:return "Need your service kit"
  if inv.count("stick")<1 or inv.count("nails")<2:return "Need one stick and two nails"
 else:
  if inv.count("sewing_kit")==0 or inv.condition("sewing_kit")<.08:return "Need a usable sewing kit"
  if inv.count("rag")<2 or inv.count("cordage")<1:return "Need two rags and one cordage"
 return ""
static func complete(inv:Inventory,id:String)->String:
 var why:=reason(inv,id)
 if why!="":return why
 if id in ["axe","knife"]:
  inv.remove("rag");inv.wear("whetstone",.08)
 elif id=="hammer":inv.remove("stick");inv.remove("nails",2)
 else:inv.remove("rag",2);inv.remove("cordage");inv.wear("sewing_kit",.08)
 inv.cond[id]=minf(1,inv.condition(id)+.25);inv._recompute()
 return "%s maintained • %d%% condition"%[inv.name_of(id),roundi(inv.condition(id)*100)]
