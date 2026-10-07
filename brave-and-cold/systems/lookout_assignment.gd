class_name LookoutAssignment
extends RefCounted
## Saved world-time state; no node, rendering or inventory dependencies.
const DATA := "res://data/lookout_broadcasts.json"
const BATTERY_CAP_WH := 144.0
const RECOVERY_RESUME_WH := 12.0 # Hold outputs off until an empty pack has a usable reserve.
const WALKIE_CAP_WH := 12.0
const WALKIE_MONITOR_W := 0.5
const WALKIE_CHARGER_W := 6.0
const WALKIE_CHARGER_EFFICIENCY := 0.8
var walkie_carried := true # compatibility default for prior always-carried saves
var walkie_wh := WALKIE_CAP_WH
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
var recovery_lock := false
var solar := SolarSupply.new()
var solar_overcast := .55 # Transient current weather; the Weather save is authoritative.
var field_load_w:=0.0
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
	solar.enabled=true
	walkie_carried=false; walkie_wh=WALKIE_CAP_WH
	var rng:=RandomNumberGenerator.new();rng.seed=seed_id
	grid_fail_s=rng.randf_range(48,72)*3600
	source_end_s=public_days*DAY_S+public_window_s-calendar_origin_s
func grid_alive(at:float=-1) -> bool:
	return (last_s if at<0 else at)<grid_fail_s
func powered() -> bool:
	return grid_alive() or (backup_on and not recovery_lock and battery_wh>.0001)
func solar_watts() -> float:
	return solar.watts(last_s+calendar_origin_s,solar_overcast) if repair_stage==3 else 0.0
func house_load_w() -> float:
	return field_load_w+(7.0 if lamp_on else 0.0)+(3.0 if receiver_on else 0.0)+(12.0 if repair_stage==3 and relay_enabled else 0.0)
func _recovery_boundary() -> void:
	if battery_wh<=.0001:recovery_lock=true
	elif battery_wh>=RECOVERY_RESUME_WH-.000001:recovery_lock=false
func advance_to(now:float, overcast:float=.55, precipitation:float=0.0) -> void:
	now=maxf(last_s,now)
	solar_overcast=clampf(overcast,0,1)
	var grid_h:=maxf(0,minf(now,grid_fail_s)-minf(last_s,grid_fail_s))/3600
	battery_wh=minf(BATTERY_CAP_WH,battery_wh+grid_h*24)
	_recovery_boundary()
	solar.accumulate_snow(grid_h*3600,precipitation)
	if walkie_carried: walkie_wh=maxf(0,walkie_wh-grid_h*WALKIE_MONITOR_W)
	else: walkie_wh=minf(WALKIE_CAP_WH,walkie_wh+grid_h*(WALKIE_CHARGER_W*WALKIE_CHARGER_EFFICIENCY-WALKIE_MONITOR_W))
	if last_s<grid_fail_s and now>=grid_fail_s and repair_stage==3 and relay_enabled and auto_transfer_on:backup_on=true
	var cursor:=maxf(last_s,grid_fail_s)
	# Solar changes across dawn/dusk even through long sleep. Integrate exact
	# daylight energy in bounded five-game-minute slices, with snow progression.
	while cursor<now-.000001:
		var end:=minf(now,cursor+300)
		var hours:float=(end-cursor)/3600
		var input_w:=solar.energy_wh(cursor,end,calendar_origin_s,solar_overcast)/hours if repair_stage==3 else 0.0
		_advance_backup(hours,input_w)
		solar.accumulate_snow(end-cursor,precipitation)
		cursor=end
	last_s=now
func _advance_backup(remaining:float,input_w:float) -> void:
	var base_w:=house_load_w()
	# Split at portable-full and home-empty boundaries. A long sleep/skip cannot
	# overcharge the handset or draw from a home supply after it is exhausted.
	while remaining>0.00000001:
		_recovery_boundary()
		var supplied:=backup_on and not recovery_lock and battery_wh>.0001
		var dock_power:=not walkie_carried and supplied
		var charging:=dock_power and walkie_wh<WALKIE_CAP_WH-.000001
		var net_w:=WALKIE_CHARGER_W*WALKIE_CHARGER_EFFICIENCY-WALKIE_MONITOR_W
		var charger_w:float=(WALKIE_CHARGER_W if charging else WALKIE_MONITOR_W/WALKIE_CHARGER_EFFICIENCY) if dock_power else 0.0
		var watts:=base_w+charger_w
		var net_w_home:=input_w-(watts if supplied else 0.0)
		var hours:=remaining
		if net_w_home<0:hours=minf(hours,battery_wh/-net_w_home)
		if recovery_lock and net_w_home>0:hours=minf(hours,(RECOVERY_RESUME_WH-battery_wh)/net_w_home)
		if charging:hours=minf(hours,(WALKIE_CAP_WH-walkie_wh)/net_w)
		battery_wh=clampf(battery_wh+hours*net_w_home,0,BATTERY_CAP_WH)
		if dock_power:walkie_wh=minf(WALKIE_CAP_WH,walkie_wh+(net_w*hours if charging else 0.0))
		else:walkie_wh=maxf(0,walkie_wh-hours*WALKIE_MONITOR_W)
		remaining=maxf(0,remaining-hours)
	_recovery_boundary()
func walkie_ready() -> bool:
	return enabled and (walkie_wh>.0001 or (not walkie_carried and powered()))
func walkie_percent() -> int:
	return 0 if walkie_wh<=.0001 else mini(100,ceili(walkie_wh/WALKIE_CAP_WH*100))
func walkie_status() -> String:
	var percent:=walkie_percent()
	if walkie_carried:return "WALKIE • CARRIED • %d%% • %s"%[percent,"DISPATCH + PUBLIC" if walkie_ready() else "BATTERY EMPTY"]
	var status:="CHARGING" if powered() and walkie_wh<WALKIE_CAP_WH-.01 else ("FULL • ON EXTERNAL POWER" if powered() else ("MONITORING • NO CHARGER POWER" if walkie_ready() else "BATTERY EMPTY • NO CHARGER POWER"))
	return "WALKIE • ON DESK • %d%% • %s"%[percent,status]
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
func public_signal_at(now: float) -> Dictionary:
	if not enabled or now>=source_end_s:return {}
	return _live_entry("public",now)
func public_broadcast_at(now: float) -> Dictionary:
	if not receiver_on or not (grid_alive(now) or (backup_on and not recovery_lock and battery_wh>.0001)):return {}
	return public_signal_at(now)
func dispatch_at(now: float) -> Dictionary:
	# Signal availability is independent of receivers. LookoutOpening applies
	# carrying, battery, hearing range and sleep rules to the handset.
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
	# A service tester can commission continuity with a flat home battery.
	# This connects generation; it does not invent charge or restore the grid.
	if repair_stage!=2:return false
	repair_stage=3;auto_transfer_on=true;relay_enabled=true
	if not grid_alive():backup_on=true
	_recovery_boundary()
	return true
func to_dict() -> Dictionary:
	return {"schema":4,"solar":solar.to_dict(),"recovery_lock":recovery_lock,"walkie_carried":walkie_carried,"walkie_wh":walkie_wh,"enabled":enabled,"seed":seed_value,"grid_fail_s":grid_fail_s,"source_end_s":source_end_s,"last_s":last_s,"battery_wh":battery_wh,"backup_on":backup_on,"auto_transfer_on":auto_transfer_on,"relay_enabled":relay_enabled,"lamp_on":lamp_on,"receiver_on":receiver_on,"calendar_origin_s":calendar_origin_s,"repair_stage":repair_stage,"parts_claimed":parts_claimed,"zombies_seeded":zombies_seeded,"depot_visited":depot_visited}
func restore(d:Dictionary) -> void:
	enabled=bool(d.get("enabled",true));seed_value=int(d.get("seed",0))
	walkie_carried=bool(d.get("walkie_carried",true));walkie_wh=clampf(float(d.get("walkie_wh",WALKIE_CAP_WH)),0,WALKIE_CAP_WH)
	grid_fail_s=float(d.get("grid_fail_s",grid_fail_s));source_end_s=maxf(grid_fail_s,float(d.get("source_end_s",source_end_s)))
	last_s=float(d.get("last_s",0));battery_wh=clampf(float(d.get("battery_wh",BATTERY_CAP_WH)),0,BATTERY_CAP_WH)
	recovery_lock=bool(d.get("recovery_lock",battery_wh<=.0001))
	solar.restore(d.get("solar",{}),not d.has("solar"))
	auto_transfer_on=bool(d.get("auto_transfer_on",false));relay_enabled=bool(d.get("relay_enabled",true))
	backup_on=bool(d.get("backup_on",false));lamp_on=bool(d.get("lamp_on",true));receiver_on=bool(d.get("receiver_on",false))
	calendar_origin_s=float(d.get("calendar_origin_s",START_HOUR*3600))
	# Schema-one channel selection is retired. Receiver on/off and every power
	# deadline remain intact; GameWorld aligns old saves to their actual calendar.
	repair_stage=clampi(int(d.get("repair_stage",0)),0,3);parts_claimed=bool(d.get("parts_claimed",false));zombies_seeded=bool(d.get("zombies_seeded",false));depot_visited=bool(d.get("depot_visited",false))
