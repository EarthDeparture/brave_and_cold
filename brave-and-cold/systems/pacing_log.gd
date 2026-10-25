class_name PacingLog
extends Node
## Playtest pacing log for the story opening. One CSV per session in
## user://pacing/, one row per real minute: where the player is in the story,
## what the work order says next, how far they walked, how many interactions
## they made and how long it has been since the last one (the idle streak).
## Target for days 1-2: no idle streak above 300 real seconds.
const INTERVAL := 60.0
var world: Node3D
var path := ""
var _t := 0.0
var _real := 0.0
var _idle := 0.0
var _worst_idle := 0.0
var _metres := 0.0
var _last_pos := Vector3.INF
var _seen_interactions := 0
var _row_interactions := 0

func start(w: Node3D, directory: String = "user://pacing") -> void:
	world = w
	DirAccess.make_dir_recursive_absolute(directory)
	path = directory.path_join("pacing_%d.csv" % int(Time.get_unix_time_from_system()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: path = ""; return
	f.store_line("real_min,day,time,phase,work_done,work_total,next_task,metres,interactions,idle_s,worst_idle_s,infected_alive")
	_seen_interactions = int(world.interaction_count)

func _process(delta: float) -> void:
	if world == null or path == "" or world.player == null: return
	if get_tree().paused: return
	_real += delta; _t += delta; _idle += delta
	var p: Vector3 = world.player.position
	if _last_pos.is_finite(): _metres += Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length()
	_last_pos = p
	var n := int(world.interaction_count)
	if n != _seen_interactions:
		_row_interactions += n - _seen_interactions; _seen_interactions = n; _idle = 0.0
	_worst_idle = maxf(_worst_idle, _idle)
	if _t >= INTERVAL:
		_t = 0.0; _write()

func _write() -> void:
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null: return
	f.seek_end()
	var done := Vector2i.ZERO; var next := ""
	if world.opening != null and world.opening.shift != null:
		done = world.opening.shift.progress(); next = world.opening.shift.next_task_title().replace(",", ";")
	var phase := String(world.opening_state.phase()) if world.opening_state != null else ""
	var alive: int = world.pop.count_alive() if world.pop != null else 0
	f.store_line("%.1f,%d,%s,%s,%d,%d,%s,%.0f,%d,%.0f,%.0f,%d" % [_real / 60.0, world.clock.day, world.clock.time_string().split("  ")[-1], phase, done.x, done.y, next, _metres, _row_interactions, _idle, _worst_idle, alive])
	_metres = 0.0; _row_interactions = 0
