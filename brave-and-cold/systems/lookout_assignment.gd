class_name LookoutAssignment
extends RefCounted
## Saved world-time state; no node, rendering or inventory dependencies.
const DATA := "res://data/lookout_broadcasts.json"
const BATTERY_CAP_WH := 144.0
var enabled := true
var grid_fail_s := 60.0 * 3600.0
const DAY_S := 86400.0
const START_HOUR := 5.5
var calendar_origin_s := START_HOUR*3600.0
var source_end_s := 5*DAY_S+1800-START_HOUR*3600
var public_window_s := 1800.0
var dispatch_guard_s := 120.0
var audio_clock_rate := 48.0
var public_days := 5
var last_s := 0.0
var battery_wh := BATTERY_CAP_WH
var backup_on := false
var auto_transfer_on := false
var relay_enabled := true
var lamp_on := true
var receiver_on := false
var repair_stage := 0 # inspect -> install -> verify
var parts_claimed := false
var zombies_seeded := false
var depot_visited := false
var seed_value := 0
var broadcasts: Array = []
var audio_clips: Dictionary = {}
func _init() -> void:
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	broadcasts=data.get("broadcasts",[])
	public_window_s=float(data.get("public_window_game_s",1800))
	dispatch_guard_s=float(data.get("dispatch_guard_game_s",120))
	audio_clock_rate=float(data.get("audio_game_seconds_per_second",48))
	public_days=int(data.get("public_days",5))
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/radio_bulletins/manifest.json"))
	audio_clips=manifest.get("clips",{})
func new_run(seed_id:int) -> void:
	seed_value=seed_id
	var rng:=RandomNumberGenerator.new();rng.seed=seed_id
	grid_fail_s=rng.randf_range(48,72)*3600
	source_end_s=public_days*DAY_S+public_window_s-calendar_origin_s
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
## Clock calendar, not hours since the player happened to start or load.
func align_calendar(day: int, hour: float, elapsed: float, new_start := false) -> void:
	calendar_origin_s=(day-1)*DAY_S+hour*3600-elapsed
	if new_start: source_end_s=public_days*DAY_S+public_window_s-calendar_origin_s
func entry_start(entry: Dictionary) -> float:
	return (int(entry.day)-1)*DAY_S+float(entry.hour)*3600-calendar_origin_s
## Reserve station windows globally, even if the desk receiver is off/unpowered.
## Guards also stop a malformed call from spilling into a scheduled bulletin.
func public_reserved(now: float) -> bool:
	var absolute := now+calendar_origin_s
	for hour: float in [0.0,6.0,12.0,17.0]:
		var distance := fposmod(absolute-hour*3600+dispatch_guard_s,DAY_S)
		if distance<public_window_s+dispatch_guard_s*2: return true
	return false
func _live_entry(device: String, now: float) -> Dictionary:
	for entry: Dictionary in broadcasts:
		if String(entry.device)!=device: continue
		var start := entry_start(entry)
		var duration := float(entry.window_game_s)
		var clip: Dictionary=audio_clips.get(String(entry.get("audio","")).get_file(),{})
		if not clip.is_empty(): duration=minf(duration,float(clip.seconds)*audio_clock_rate)
		if now>=start and now<start+duration:
			var result := entry.duplicate(); result["start_s"]=start; return result
	return {}
func public_broadcast_at(now: float) -> Dictionary:
	if not enabled or not receiver_on or not (grid_alive(now) or (backup_on and battery_wh>.0001)) or now>=source_end_s: return {}
	return _live_entry("public",now)
func dispatch_at(now: float) -> Dictionary:
	# The personal set is always listening and independent of desk/mains/relay.
	if not enabled or public_reserved(now): return {}
	return _live_entry("dispatch",now)
## Compatibility for public-receiver callers; dispatch has a separate API.
func broadcast_at(now: float) -> Dictionary: return public_broadcast_at(now)
func next_dispatch_start(after: float, through: float) -> float:
	if not enabled: return INF
	var next := INF
	for entry: Dictionary in broadcasts:
		if String(entry.device)!="dispatch": continue
		var start := entry_start(entry)
		if start>after and start<=through and not public_reserved(start): next=minf(next,start)
	return next
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
	return {"schema":2,"enabled":enabled,"seed":seed_value,"grid_fail_s":grid_fail_s,"source_end_s":source_end_s,"last_s":last_s,"battery_wh":battery_wh,"backup_on":backup_on,"auto_transfer_on":auto_transfer_on,"relay_enabled":relay_enabled,"lamp_on":lamp_on,"receiver_on":receiver_on,"calendar_origin_s":calendar_origin_s,"repair_stage":repair_stage,"parts_claimed":parts_claimed,"zombies_seeded":zombies_seeded,"depot_visited":depot_visited}
func restore(d:Dictionary) -> void:
	enabled=bool(d.get("enabled",true));seed_value=int(d.get("seed",0))
	grid_fail_s=float(d.get("grid_fail_s",grid_fail_s));source_end_s=maxf(grid_fail_s,float(d.get("source_end_s",source_end_s)))
	last_s=float(d.get("last_s",0));battery_wh=clampf(float(d.get("battery_wh",BATTERY_CAP_WH)),0,BATTERY_CAP_WH)
	auto_transfer_on=bool(d.get("auto_transfer_on",false));relay_enabled=bool(d.get("relay_enabled",true))
	backup_on=bool(d.get("backup_on",false));lamp_on=bool(d.get("lamp_on",true));receiver_on=bool(d.get("receiver_on",false))
	calendar_origin_s=float(d.get("calendar_origin_s",START_HOUR*3600))
	# Schema-one channel selection is retired. Receiver on/off and every power
	# deadline remain intact; GameWorld aligns old saves to their actual calendar.
	repair_stage=clampi(int(d.get("repair_stage",0)),0,3);parts_claimed=bool(d.get("parts_claimed",false));zombies_seeded=bool(d.get("zombies_seeded",false));depot_visited=bool(d.get("depot_visited",false))
