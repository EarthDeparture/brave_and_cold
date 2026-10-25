class_name TownResidentState
extends RefCounted
## Named residents are history, not anonymous population spawn points.
enum Phase { ORDINARY, WORRIED, ILL, UNRESPONSIVE, INFECTED, DEAD, DEPARTED }
var records: Dictionary = {}
const IDS := ["rowan", "lin", "sam"]

static func calendar_phase(id: String, day: int, hour: float) -> Phase:
	if id != "rowan": return Phase.DEPARTED if day > 3 or (day == 3 and hour >= (14.0 if id == "sam" else 8.0)) else Phase.ORDINARY
	if day > 3 or (day == 3 and hour >= 21): return Phase.INFECTED
	if day == 3 and hour >= 18: return Phase.UNRESPONSIVE
	if day == 3 and hour >= 11: return Phase.ILL
	return Phase.WORRIED if day >= 2 else Phase.ORDINARY

func record(id: String) -> Dictionary:
	if not records.has(id): records[id] = {"dead":false,"hp":100.0,"met":false,"topics":[],"departed":false}
	return records[id]

func phase(id: String, day: int, hour: float) -> Phase:
	var r := record(id)
	if bool(r.dead): return Phase.DEAD
	if bool(r.departed) or bool(r.get("leaving",false)): return Phase.DEPARTED
	return calendar_phase(id, day, hour)

func killed(id: String) -> void:
	var r := record(id); r.dead = true; r.hp = 0.0

func remember(id: String, topic: String) -> void:
	var r := record(id); r.met = true
	if not r.topics.has(topic): r.topics.append(topic)

func to_dict() -> Dictionary: return {"schema":1,"residents":records.duplicate(true)}
func restore(saved: Dictionary) -> void:
	records.clear()
	for id: String in IDS:
		var src: Dictionary = saved.get("residents",{}).get(id,{})
		var r := record(id)
		for key: String in ["dead","met","departed","corpse_cleared"]: r[key] = bool(src.get(key,false))
		r.hp = clampf(float(src.get("hp",100.0)),0,100)
		if r.hp <= 0: r.dead = true
		r.topics = src.get("topics",[]).duplicate()
		for key: String in ["position","yaw","route_index","routine_s","leaving","exit_index","turn_s","dead_s"]:
			if src.has(key): r[key] = src[key]
