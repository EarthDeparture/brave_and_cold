class_name TrackLog
extends RefCounted
## Plan A1: the snow's memory. Every trace is a crumb in 32 m chunks, logged wherever it happens (an animal 600 m away
## still leaves a trail to find later); AnimalTracks only materializes the crumbs near the player as decals.
##  * Ring of MAX crumbs (~1 MB). Crumb: kind, x, z, yaw, size, gait, owner, snow_t, game_t.
##  * Snow aging is O(1): snow_clock integrates (1 + 7 * precipitation) over game time, so a crumb's effective age
##    (how filled-in it looks) is snow_clock_now - snow_t; real age (how long ago) is game_clock_now - game_t.
##  * Save: crumbs near the player and under 12 effective hours, capped (older trails are lost on load).

const CHUNK := 32.0
const MAX := 40000
enum K { DEER, WOLF, BEAR, HARE, BOOT, SHUFFLE, BLOOD, BAND, TRAMPLE, DRAG, BED }
const NAMES := ["deer", "wolf", "bear", "hare", "boot", "shuffle", "blood", "band", "trample", "drag", "bed"]
const LIFE_H := {K.BLOOD: 12.0, K.BAND: 8.0, K.TRAMPLE: 10.0, K.BED: 14.0, K.DRAG: 6.0}
const PRINT_LIFE_H := 6.0
const SNOW_MULT := 7.0

var x := PackedFloat32Array()
var z := PackedFloat32Array()
var yaw := PackedFloat32Array()
var size := PackedFloat32Array()
var snow_t := PackedFloat32Array()
var game_t := PackedFloat32Array()
var kind := PackedInt32Array()
var gait := PackedInt32Array()
var owner := PackedInt32Array()
var ck := PackedInt64Array()
var sid := PackedInt64Array()
var head := 0
var count := 0
var serial := 0
var snow_clock := 0.0
var game_clock := 0.0
var _chunks: Dictionary = {}
var _life := PackedFloat32Array()   # per kind, seconds of effective age


func _init() -> void:
	# (packed arrays are values: resizing them through a loop variable resizes a copy)
	x.resize(MAX); z.resize(MAX); yaw.resize(MAX); size.resize(MAX); snow_t.resize(MAX); game_t.resize(MAX)
	kind.resize(MAX); gait.resize(MAX); owner.resize(MAX)
	ck.resize(MAX); sid.resize(MAX)
	ck.fill(-1); sid.fill(0)
	for k in NAMES.size(): _life.append(life_s(k))


static func key(px: float, pz: float) -> int:
	return (int(floor(px / CHUNK)) + 100000) * 1000003 + (int(floor(pz / CHUNK)) + 100000)


static func life_s(k: int) -> float:
	return float(LIFE_H.get(k, PRINT_LIFE_H)) * 3600.0


func advance(game_s: float, precip: float) -> void:
	game_clock += game_s
	snow_clock += game_s * (1.0 + SNOW_MULT * clampf(precip, 0.0, 1.0))


func add(k: int, px: float, pz: float, pyaw := 0.0, psize := 1.0, pgait := 0, pown := 0, eff_age := 0.0, real_age := 0.0) -> int:
	var i := head
	head = (head + 1) % MAX
	count = mini(count + 1, MAX)
	var kk := key(px, pz)
	x[i] = px; z[i] = pz; yaw[i] = pyaw; size[i] = psize
	kind[i] = k; gait[i] = pgait; owner[i] = pown
	snow_t[i] = snow_clock - eff_age; game_t[i] = game_clock - real_age
	ck[i] = kk
	serial += 1
	sid[i] = serial
	var lst: PackedInt32Array = _chunks.get(kk, PackedInt32Array())
	lst.append(i)
	if lst.size() > 1500:   # compact: drop slots that were recycled into other chunks
		var keep := PackedInt32Array()
		var seen := {}
		for s in lst:
			if ck[s] == kk and not seen.has(s):
				seen[s] = true; keep.append(s)
		lst = keep
	_chunks[kk] = lst
	return i


func eff_age(i: int) -> float:
	return snow_clock - snow_t[i]


func real_age(i: int) -> float:
	return game_clock - game_t[i]


func alive(i: int) -> bool:
	return sid[i] > 0 and eff_age(i) < life_s(kind[i])


## Live crumb slots within r of (px, pz); `kinds` empty = all. Hot path (materialize scans thousands of slots):
## kind bitmask + inlined age test, no per-slot dictionary (a slot listed twice in one chunk is rare and harmless).
func query(px: float, pz: float, r: float, kinds: Array = []) -> PackedInt32Array:
	var out := PackedInt32Array()
	var mask := 0
	if kinds.is_empty():
		mask = (1 << NAMES.size()) - 1
	else:
		for k in kinds: mask |= 1 << int(k)
	var r2 := r * r
	var c0x := int(floor((px - r) / CHUNK)); var c1x := int(floor((px + r) / CHUNK))
	var c0z := int(floor((pz - r) / CHUNK)); var c1z := int(floor((pz + r) / CHUNK))
	var sc := snow_clock
	for cx in range(c0x, c1x + 1):
		for cz in range(c0z, c1z + 1):
			var kk := (cx + 100000) * 1000003 + (cz + 100000)
			var lst = _chunks.get(kk)
			if lst == null: continue
			for s: int in (lst as PackedInt32Array):
				var kd := kind[s]
				if ((mask >> kd) & 1) == 0 or ck[s] != kk: continue
				if sc - snow_t[s] >= _life[kd]: continue
				var dx := x[s] - px; var dz := z[s] - pz
				if dx * dx + dz * dz <= r2:
					out.append(s)
	return out


func to_dict(center: Vector3, r := 400.0, max_age_h := 12.0, cap := 6000) -> Dictionary:
	var rows: Array = []
	for s in query(center.x, center.z, r):
		if eff_age(s) > max_age_h * 3600.0: continue
		rows.append(s)
	rows.sort_custom(func(a: int, b: int) -> bool: return sid[a] > sid[b])
	if rows.size() > cap: rows.resize(cap)
	rows.reverse()   # oldest first, so a reload re-adds them in order
	var flat := PackedFloat32Array()
	for s in rows:
		flat.append_array([float(kind[s]), x[s], z[s], yaw[s], size[s], float(gait[s]), float(owner[s]), eff_age(s), real_age(s)])
	return {"v": 1, "n": rows.size(), "crumbs": Array(flat), "snow_clock": snow_clock, "game_clock": game_clock}


func from_dict(d: Dictionary) -> void:
	if int(d.get("v", 0)) != 1: return
	var f: Array = d.get("crumbs", [])
	for i in range(0, f.size() - 8, 9):
		add(int(f[i]), float(f[i + 1]), float(f[i + 2]), float(f[i + 3]), float(f[i + 4]), int(f[i + 5]), int(f[i + 6]), float(f[i + 7]), float(f[i + 8]))
