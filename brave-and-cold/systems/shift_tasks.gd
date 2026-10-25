class_name ShiftTasks
extends RefCounted
## Quiet-day work orders (data/shift_tasks.json). Pure state: no nodes.
## - "check" tasks latch the first time their world condition is true, and an
##   unfinished one carries over to the next day's order.
## - "kind" tasks (weather, smoke) count only inside their hour window on their
##   own day; a missed window is simply missed (the next day has its own).
## Completion stores the elapsed game second, so a save keeps the real history.
const DATA := "res://data/shift_tasks.json"
var data: Dictionary = {}
var done: Dictionary = {}      # task id -> elapsed game s
var field_log: Array = []      # [[elapsed_s, "Day 1 08:12", text], ...]
var reports: Dictionary = {}   # "1" -> {"done":n,"total":m,"reply":text}
var announced_day := 0
var suspend_noted := false

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA))

func day_name(day: int) -> String:
	return String(data.get("day_names", {}).get(str(day), "Day %d" % day))

func tasks_for(day: int) -> Array:
	return data.get("days", {}).get(str(day), [])

func last_day() -> int:
	var n := 0
	for k: String in data.get("days", {}).keys(): n = maxi(n, int(k))
	return n

func suspended_at(state: LookoutAssignment) -> float:
	var s: Dictionary = data.get("suspend", {})
	return state.calendar_s(int(s.get("day", 3)), float(s.get("hour", 8)))

## Today's order: the day's own tasks plus unfinished check-tasks from earlier days.
func order_for(day: int) -> Array:
	var out: Array = []
	for earlier in range(1, mini(day, last_day() + 1)):
		for t: Dictionary in tasks_for(earlier):
			if t.has("check") and not done.has(String(t.id)):
				var carried := t.duplicate(); carried["carried"] = true; out.append(carried)
	for t: Dictionary in tasks_for(day): out.append(t)
	return out

func is_done(id: String) -> bool: return done.has(id)

func _mark(id: String, now: float) -> bool:
	if done.has(id): return false
	done[id] = now; return true

## Latch check-tasks whose condition holds now. checks: check id -> Callable(task)->bool.
func poll(checks: Dictionary, day: int, now: float) -> Array:
	var newly: Array = []
	for t: Dictionary in order_for(day):
		if not t.has("check") or done.has(String(t.id)): continue
		var c: Callable = checks.get(String(t.check), Callable())
		if c.is_valid() and bool(c.call(t)) and _mark(String(t.id), now): newly.append(t)
	return newly

## A logged observation (kind = "weather" / "smoke") at calendar day/hour.
func observe(kind: String, day: int, hour: float, now: float) -> Array:
	var newly: Array = []
	for t: Dictionary in tasks_for(day):
		if String(t.get("kind", "")) != kind or done.has(String(t.id)): continue
		var w: Array = t.get("window", [0.0, 24.0])
		if hour >= float(w[0]) and hour <= float(w[1]) and _mark(String(t.id), now): newly.append(t)
	return newly

func add_log(now: float, stamp: String, text: String) -> void:
	field_log.append([now, stamp, text])
	if field_log.size() > 60: field_log.pop_front()

func smoke_today(day: int, hour: float) -> Dictionary:
	for s: Dictionary in data.get("smoke", []):
		if int(s.day) == day and hour >= float(s.get("from", 0)) and hour <= float(s.get("to", 24)): return s
	return {}

## End-of-shift report, issued once per day.
func report(day: int) -> Dictionary:
	if reports.has(str(day)): return {}
	var order := order_for(day)
	var n := 0
	for t: Dictionary in order:
		if done.has(String(t.id)): n += 1
	var r: Dictionary = data.get("reports", {})
	var key := "all" if n == order.size() else ("most" if n * 2 >= order.size() and n > 0 else ("some" if n > 0 else "none"))
	var result := {"done": n, "total": order.size(), "reply": String(r.get(key, ""))}
	reports[str(day)] = result
	return result

func to_dict() -> Dictionary:
	return {"schema": 1, "done": done.duplicate(), "log": field_log.duplicate(true), "reports": reports.duplicate(true), "announced_day": announced_day, "suspend_noted": suspend_noted}

func restore(d: Dictionary) -> void:
	done = d.get("done", {}).duplicate(); field_log = d.get("log", []).duplicate(true); reports = d.get("reports", {}).duplicate(true)
	announced_day = int(d.get("announced_day", 0)); suspend_noted = bool(d.get("suspend_noted", false))
