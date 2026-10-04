class_name LookoutAssignment
extends RefCounted
## Saved world-time state; no node, rendering or inventory dependencies.
const DATA := "res://data/lookout_broadcasts.json"
const BATTERY_CAP_WH := 144.0
var enabled := true
var grid_fail_s := 60.0 * 3600.0
var source_end_s := 104.0 * 3600.0
var last_s := 0.0
var battery_wh := BATTERY_CAP_WH
var backup_on := false
var auto_transfer_on := false
var relay_enabled := true
var lamp_on := true
var receiver_on := false
var channel := "work"
var repair_stage := 0 # inspect -> install -> verify
var parts_claimed := false
var zombies_seeded := false
var depot_visited := false
var seed_value := 0
var broadcasts: Array = []
func _init() -> void:
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	broadcasts=data.get("broadcasts",[])
func new_run(seed_id:int) -> void:
	seed_value=seed_id
	var rng:=RandomNumberGenerator.new();rng.seed=seed_id
	grid_fail_s=rng.randf_range(48,72)*3600
	source_end_s=grid_fail_s+rng.randf_range(36,60)*3600
func grid_alive(at:float=-1) -> bool:
	return (last_s if at<0 else at)<grid_fail_s
func powered() -> bool:
	return grid_alive() or (backup_on and battery_wh>.0001)
func advance_to(now:float) -> void:
	now=maxf(last_s,now)
	var grid_delta:=maxf(0,minf(now,grid_fail_s)-minf(last_s,grid_fail_s))
	battery_wh=minf(BATTERY_CAP_WH,battery_wh+grid_delta/3600*24)
	if last_s<grid_fail_s and now>=grid_fail_s and repair_stage==3 and relay_enabled and auto_transfer_on:backup_on=true
	var reserve_delta:=maxf(0,now-maxf(last_s,grid_fail_s))
	var watts:float=(7.0 if lamp_on else 0.0)+(3.0 if receiver_on else 0.0)+(12.0 if repair_stage==3 and relay_enabled else 0.0)
	if backup_on:battery_wh=maxf(0,battery_wh-reserve_delta/3600*watts)
	last_s=now
func phase() -> String:
	if last_s>=source_end_s:return "Self-sufficiency"
	if not grid_alive():return "Abandonment"
	if last_s>=20*3600:return "Disruption"
	return "Assignment"
func broadcast_at(now:float) -> Dictionary:
	if not enabled or not receiver_on or not (grid_alive(now) or (backup_on and battery_wh>.0001)) or now>=source_end_s:return {}
	if channel=="work" and (now>=grid_fail_s+8*3600 or (now>=20*3600 and (repair_stage!=3 or not relay_enabled))):return {}
	for entry:Dictionary in broadcasts:
		if entry.channel!=channel:continue
		var anchor:float=grid_fail_s if entry.anchor=="grid" else (source_end_s if entry.anchor=="source_end" else 0.0)
		var start:float=anchor+float(entry.offset_h)*3600
		if now>=start and now<start+float(entry.window_game_s):
			var result:=entry.duplicate();result["start_s"]=start;return result
	return {}
func inspect() -> bool:
	if repair_stage!=0:return false
	repair_stage=1;return true
func install() -> bool:
	if repair_stage!=1:return false
	repair_stage=2;return true
func verify() -> bool:
	if repair_stage!=2 or not powered():return false
	repair_stage=3;auto_transfer_on=true;relay_enabled=true;return true
func to_dict() -> Dictionary:
	return {"schema":1,"enabled":enabled,"seed":seed_value,"grid_fail_s":grid_fail_s,"source_end_s":source_end_s,"last_s":last_s,"battery_wh":battery_wh,"backup_on":backup_on,"auto_transfer_on":auto_transfer_on,"relay_enabled":relay_enabled,"lamp_on":lamp_on,"receiver_on":receiver_on,"channel":channel,"repair_stage":repair_stage,"parts_claimed":parts_claimed,"zombies_seeded":zombies_seeded,"depot_visited":depot_visited}
func restore(d:Dictionary) -> void:
	enabled=bool(d.get("enabled",true));seed_value=int(d.get("seed",0))
	grid_fail_s=float(d.get("grid_fail_s",grid_fail_s));source_end_s=maxf(grid_fail_s,float(d.get("source_end_s",source_end_s)))
	last_s=float(d.get("last_s",0));battery_wh=clampf(float(d.get("battery_wh",BATTERY_CAP_WH)),0,BATTERY_CAP_WH)
	auto_transfer_on=bool(d.get("auto_transfer_on",false));relay_enabled=bool(d.get("relay_enabled",true))
	backup_on=bool(d.get("backup_on",false));lamp_on=bool(d.get("lamp_on",true));receiver_on=bool(d.get("receiver_on",false))
	channel="public" if d.get("channel","work")=="public" else "work"
	repair_stage=clampi(int(d.get("repair_stage",0)),0,3);parts_claimed=bool(d.get("parts_claimed",false));zombies_seeded=bool(d.get("zombies_seeded",false));depot_visited=bool(d.get("depot_visited",false))
