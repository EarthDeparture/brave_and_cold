class_name AnimalTracks
extends Node3D
## Alive L2 + plan A1: traces in the snow. Everything that walks leaves crumbs in a TrackLog - anywhere on the map,
## seen or not - and this node materializes the crumbs near the player as pooled projected decals:
##  * prints (deer / wolf / bear / hare, boot, shuffle = a dragging infected): walk = alternating line, run =
##    bounding groups of four; normal-mapped hollows with a thrown-snow rim; deep snow adds drag marks;
##  * blood splatters (Carcass.blood routes here);
##  * trail bands: a faint long band every 6 m of a trail, visible to BAND_R, so a line of tracks reads across a
##    meadow like TLD's trenches while the prints themselves fade out at ~32 m; a horde leaves a wide trample band;
##  * beds: where a wounded deer bedded down or died.
## Effective age (snow cover) fades everything; read_at() turns crumbs under the crosshair into a hint line.

const POOL := 520
const BLOOD_POOL := 180
const BAND_POOL := 160
const MAT_R := 70.0
const BAND_R := 120.0
const REFRESH_S := 0.4
const PRINT_R := 48.0     # prints fade out by 32 + 15 m: no point placing them further
const BLOOD_R := 66.0
const FAR_PRINTS := 180.0 # beyond this, people / zombies log only their trail band (they are many; animals keep prints)
const KINDS := {
	"deer": {"size": Vector2(0.10, 0.13), "stride": 0.62, "run_stride": 2.8, "run_v": 3.5, "lat": 0.09, "band_w": 0.35},
	"wolf": {"size": Vector2(0.11, 0.13), "stride": 0.70, "run_stride": 2.3, "run_v": 4.5, "lat": 0.05, "band_w": 0.30},
	"bear": {"size": Vector2(0.20, 0.28), "stride": 0.85, "run_stride": 2.0, "run_v": 4.5, "lat": 0.17, "band_w": 0.60},
	"hare": {"size": Vector2(0.06, 0.12), "stride": 0.50, "run_stride": 1.4, "run_v": 2.5, "lat": 0.05, "band_w": 0.18},
	"boot": {"size": Vector2(0.12, 0.30), "stride": 0.72, "run_stride": 1.3, "run_v": 3.0, "lat": 0.12, "band_w": 0.40},
	"shuffle": {"size": Vector2(0.14, 0.36), "stride": 0.55, "run_stride": 0.9, "run_v": 3.0, "lat": 0.14, "band_w": 0.45},
}
const KIND_ID := {"deer": TrackLog.K.DEER, "wolf": TrackLog.K.WOLF, "bear": TrackLog.K.BEAR, "hare": TrackLog.K.HARE,
	"boot": TrackLog.K.BOOT, "shuffle": TrackLog.K.SHUFFLE}
const PRINT_K := [TrackLog.K.DEER, TrackLog.K.WOLF, TrackLog.K.BEAR, TrackLog.K.HARE, TrackLog.K.BOOT, TrackLog.K.SHUFFLE]
const BAND_K := [TrackLog.K.BAND, TrackLog.K.TRAMPLE, TrackLog.K.DRAG, TrackLog.K.BED]
const GROUP := [[0.30, -1.0], [0.30, 1.0], [-0.05, 0.15], [-0.32, -0.15]]
const BAND_EVERY := 6.0
const TRAMPLE_EVERY := 8.0

static var instance: AnimalTracks

var world: Node
var log := TrackLog.new()
var stamped := 0                       # tests / debug: prints logged
var _tex: Dictionary = {}              # kind name -> albedo
var _nrm: Dictionary = {}              # kind name -> normal
var _blood_tex: Array = []
var _band_tex: Dictionary = {}         # band / trample / drag / bed
var _pools: Dictionary = {}            # "p" / "b" / "n" -> {decals, sid, slot}
var _at: Dictionary = {}               # crumb sid -> [pool, index]
var _state: Dictionary = {}
var _refresh := 0.0
var _prune_t := 30.0
var _cycle := 0
var _queue: Array = []
var _dirty := false
var _rng := RandomNumberGenerator.new()   # own stream: never perturbs the game's global randf() sequence


func _ready() -> void:
	instance = self
	_rng.seed = 7117
	for k in KINDS:
		_tex[k] = _make_print(k)
		_nrm[k] = _make_normal(_tex[k])
	for i in 4:
		_blood_tex.append(_make_blood(i))
	for k in ["band", "trample", "drag", "bed"]:
		_band_tex[k] = _make_band(k)
	_pools["p"] = _new_pool(POOL, 32.0)
	_pools["b"] = _new_pool(BLOOD_POOL, 50.0)
	_pools["n"] = _new_pool(BAND_POOL, BAND_R - 15.0)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _new_pool(n: int, fade_begin: float) -> Dictionary:
	var ds: Array[Decal] = []
	for i in n:
		var d := Decal.new()
		d.upper_fade = 0.3
		d.lower_fade = 0.3
		d.cull_mask = 1
		d.visible = false
		d.distance_fade_enabled = true
		d.distance_fade_begin = fade_begin
		d.distance_fade_length = 15.0
		add_child(d)
		ds.append(d)
	var sid := PackedInt64Array(); sid.resize(n); sid.fill(0)
	var slot := PackedInt32Array(); slot.resize(n); slot.fill(-1)
	var alast := PackedFloat32Array(); alast.resize(n); alast.fill(-1.0)
	return {"decals": ds, "sid": sid, "slot": slot, "alast": alast}


# ------------------------------------------------------------------ logging
## One print (or a bounding group when `group`) of `kind` at ground position p heading `yaw`.
func stamp(kind: String, p: Vector3, yaw: float, left: bool, group := false, owner := 0) -> void:
	var k: Dictionary = KINDS[kind]
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var lat: float = k.lat
	var offs: Array = GROUP if group else [[0.0, 1.0 if left else -1.0]]
	for o in offs:
		var q: Vector3 = p + fwd * (float(o[0]) * (2.4 if kind == "bear" else 1.0)) + right * (float(o[1]) * lat)
		log.add(KIND_ID[kind], q.x, q.z, yaw + _rng.randf_range(-0.12, 0.12), 1.0, 1 if group else 0, owner)
		stamped += 1
	_dirty = true


## A blood splatter. size ~ diameter in metres.
func blood(p: Vector3, size: float) -> void:
	log.add(TrackLog.K.BLOOD, p.x, p.z, _rng.randf() * TAU, size * _rng.randf_range(0.8, 1.25))
	_dirty = true


func _ground(x: float, z: float) -> float:
	return float(world.call("_ground_y", x, z)) if world != null and world.has_method("_ground_y") else 0.0


func _indoors(p: Vector3) -> bool:
	if world == null or not world.has_method("_building_list"): return false
	for b in world.call("_building_list"):
		if b.has_method("contains_xz") and b.contains_xz(p.x, p.z): return true
	return false


func _walkers() -> Array:
	var out: Array = []
	if world == null:
		return out
	for pair in [["deer", "deer"], ["wolves", "wolf"], ["bears", "bear"], ["rabbits", "hare"]]:
		var arr = world.get(pair[0])
		if arr == null:
			continue
		for a in arr:
			if is_instance_valid(a):
				out.append([a, pair[1]])
	var zs = world.get("zombies")
	if zs != null:
		for zb in zs:
			if is_instance_valid(zb) and (zb as Node3D).visible:
				out.append([zb, "shuffle"])
	var tl = world.get("town_life")
	if tl != null:
		for a in (tl.actors as Dictionary).values():
			if is_instance_valid(a) and not a.infected and a.visible and a.mode == "work":
				out.append([a, "boot"])
	return out


func _process(delta: float) -> void:
	if world == null:
		return
	var clock: GameClock = world.get("clock")
	var weather: Weather = world.get("weather")
	log.advance(delta * (clock.time_scale if clock != null else 48.0), weather.precip if weather != null else 0.0)
	_log_walkers(delta)
	_log_hordes()
	_refresh -= delta
	if _refresh <= 0.0 or (_dirty and _refresh < REFRESH_S - 0.12):   # new crumbs show within ~0.12 s, never every frame
		_refresh = REFRESH_S
		_dirty = false
		_cycle += 1
		_queue = ["p", "b"] if _cycle % 3 else ["p", "b", "n"]   # far bands change slowly: every third pass
	if not _queue.is_empty():   # one pool per frame: a dense ring never costs one big hitch
		_materialize_pool(_queue.pop_front())
	_prune_t -= delta
	if _prune_t <= 0.0:   # walkers that despawned / freed: drop their stride state
		_prune_t = 30.0
		var live := {}
		for e in _walkers(): live[(e[0] as Node).get_instance_id()] = true
		var pop = world.get("pop")
		if pop != null and pop.get("hordes") != null:
			for h in pop.hordes: live[h.get_instance_id()] = true
		for id in _state.keys():
			if not live.has(id): _state.erase(id)


func _log_walkers(delta: float) -> void:
	var snow: SnowField = world.get("snow")
	var pl = world.get("player")
	var ppos: Vector3 = (pl as Node3D).global_position if pl != null else Vector3.ZERO
	for e in _walkers():
		var a: Node3D = e[0]
		var kind: String = e[1]
		var id := a.get_instance_id()
		var dead: bool = a.call("is_dead") if a.has_method("is_dead") else false
		var pos := a.global_position
		if not _state.has(id):
			_state[id] = {"last": pos, "acc": 0.0, "band": 0.0, "band_from": pos, "left": false, "last_print": Vector3.INF, "still": 0.0, "bed": false, "dead_bed": false}
			continue
		var st: Dictionary = _state[id]
		if dead:
			if kind == "deer" and not st.dead_bed:   # where it fell: a pressed hollow under the carcass
				st.dead_bed = true
				log.add(TrackLog.K.BED, pos.x, pos.z, float(a.rotation.y), 1.0)
				_dirty = true
			continue
		var mv: Vector3 = pos - st.last
		mv.y = 0.0
		st.last = pos
		var dist := mv.length()
		var spd := float(a.get("speed_now")) if a.get("speed_now") != null else 0.0
		if kind == "deer" and bool(a.get("bleed")):   # a wounded deer that stops long enough beds down
			st.still = float(st.still) + delta if spd < 0.2 else 0.0
			if st.still > 6.0 and not st.bed:
				st.bed = true
				log.add(TrackLog.K.BED, pos.x, pos.z, float(a.rotation.y), 1.0)
				_dirty = true
		if dist < 0.0001 or dist > 5.0:   # teleported / respawned: no streak of prints
			continue
		st.acc += dist
		st.band += dist
		var k: Dictionary = KINDS[kind]
		var run := spd > float(k.run_v)
		var stride: float = k.run_stride if run else k.stride
		var yaw := atan2(-mv.x, -mv.z)
		var tier := snow.tier_at(pos.x, pos.z) if snow != null else 1
		if st.band >= BAND_EVERY:
			var from: Vector3 = st.band_from
			var mid := (from + pos) * 0.5
			var seg := Vector2(pos.x - from.x, pos.z - from.z)
			if tier > 0 and seg.length() > 1.0:
				log.add(TrackLog.K.BAND, mid.x, mid.z, atan2(-seg.x, -seg.y), seg.length(), int(float(k.band_w) * 100.0), int(KIND_ID[kind]))
			st.band = 0.0
			st.band_from = pos
		if st.acc < stride:
			continue
		st.acc = 0.0
		if tier <= 0:
			continue
		if kind == "shuffle" or kind == "boot":
			if Vector2(pos.x - ppos.x, pos.z - ppos.z).length() > FAR_PRINTS or _indoors(pos):
				continue
		st.left = not st.left
		stamp(kind, pos, yaw, st.left, run, id % 100000)
		# deep snow: the legs plough a furrow between prints
		if tier >= 3 and not run and kind in ["deer", "wolf", "bear", "shuffle"] and st.last_print != Vector3.INF:
			var lp: Vector3 = st.last_print
			var d2 := Vector2(pos.x - lp.x, pos.z - lp.z)
			if d2.length() > 0.2 and d2.length() < 2.0:
				var m := (lp + pos) * 0.5
				log.add(TrackLog.K.DRAG, m.x, m.z, atan2(-d2.x, -d2.y), d2.length(), 12 if kind != "bear" else 22)
		st.last_print = pos


func _log_hordes() -> void:
	var pop = world.get("pop")
	if pop == null or pop.get("hordes") == null:
		return
	var snow: SnowField = world.get("snow")
	for h in pop.hordes:
		var id: int = h.get_instance_id()
		var c: Vector2 = h.center
		if not _state.has(id):
			_state[id] = {"from": c}
			continue
		var st: Dictionary = _state[id]
		var from: Vector2 = st.from
		var seg := c - from
		if seg.length() > 40.0:
			st.from = c
		elif seg.length() >= TRAMPLE_EVERY:
			var m := (from + c) * 0.5
			if snow == null or snow.tier_at(m.x, m.y) > 0:
				log.add(TrackLog.K.TRAMPLE, m.x, m.y, atan2(-seg.x, -seg.y), seg.length(), 600)
			st.from = c


# ------------------------------------------------------------------ materialize
func materialize() -> void:
	var p = world.get("player") if world != null else null
	if p == null:
		return
	for id in ["p", "b", "n"]:
		_materialize_pool(id)
	_queue.clear()


func _materialize_pool(id: String) -> void:
	var p = world.get("player") if world != null else null
	if p == null:
		return
	var pp: Vector3 = (p as Node3D).global_position
	match id:
		"p": _assign("p", pp, log.query(pp.x, pp.z, PRINT_R, PRINT_K))
		"b": _assign("b", pp, log.query(pp.x, pp.z, BLOOD_R, [TrackLog.K.BLOOD]))
		_: _assign("n", pp, log.query(pp.x, pp.z, BAND_R, BAND_K))


func _assign(pool_id: String, pp: Vector3, cands: PackedInt32Array) -> void:
	var pool: Dictionary = _pools[pool_id]
	var ds: Array[Decal] = pool.decals
	var n := ds.size()
	# nearest n: native sort of the distances for a cut-off (a lambda sort over row arrays cost ~3 ms at 800 crumbs)
	var nc := cands.size()
	var d2 := PackedFloat32Array(); d2.resize(nc)
	for j in nc:
		var s: int = cands[j]
		var dx: float = log.x[s] - pp.x
		var dz: float = log.z[s] - pp.z
		d2[j] = dx * dx + dz * dz
	var cut_r2 := INF
	if nc > n:
		var srt := d2.duplicate(); srt.sort()
		cut_r2 = srt[n - 1]
	var want := {}
	for j in nc:
		if d2[j] <= cut_r2 and want.size() < n:
			want[log.sid[cands[j]]] = cands[j]
	var free: Array = []
	var sids: PackedInt64Array = pool.sid
	var slots: PackedInt32Array = pool.slot
	var alast: PackedFloat32Array = pool.alast
	for i in n:   # release what is no longer wanted (out of range, expired or recycled)
		var sd: int = sids[i]
		if sd != 0 and not want.has(sd):
			_at.erase(sd)
			sids[i] = 0; slots[i] = -1
			ds[i].visible = false
		if sids[i] == 0:
			free.append(i)
	for sd in want:
		var s: int = want[sd]
		if not _at.has(sd):
			if free.is_empty(): break
			var i: int = free.pop_back()
			sids[i] = sd; slots[i] = s; alast[i] = -1.0
			_at[sd] = [pool_id, i]
			_configure(ds[i], s)
	pool.sid = sids
	pool.slot = slots
	for i in n:   # fade everything shown by its effective age (and bands by distance: they take over from prints)
		var s: int = slots[i]
		if s < 0: continue
		var d := ds[i]
		var k: int = log.kind[s]
		var f := clampf(log.eff_age(s) / TrackLog.life_s(k), 0.0, 1.0)
		var a: float = float(d.get_meta("base_a", 0.8)) * (1.0 - pow(f, 1.5 if k != TrackLog.K.BLOOD else 2.0))
		if k == TrackLog.K.BAND:
			var dist := Vector2(log.x[s] - pp.x, log.z[s] - pp.z).length()
			a *= smoothstep(9.0, 24.0, dist)
		if absf(alast[i] - a) > 0.012:   # node property writes are the cost: only push real changes
			alast[i] = a
			d.modulate.a = a
	pool.alast = alast


func _configure(d: Decal, s: int) -> void:
	var k: int = log.kind[s]
	var q := Vector3(log.x[s], _ground(log.x[s], log.z[s]), log.z[s])
	d.global_position = q
	d.rotation = Vector3(0.0, log.yaw[s], 0.0)
	d.texture_normal = null
	var base_a := 0.8
	match k:
		TrackLog.K.BLOOD:
			var sz: float = log.size[s]
			d.texture_albedo = _blood_tex[int(log.sid[s]) % _blood_tex.size()]
			d.size = Vector3(sz, 1.0, sz * (0.75 + 0.45 * fposmod(float(log.sid[s]) * 0.618, 1.0)))
			base_a = 0.95
		TrackLog.K.BAND, TrackLog.K.TRAMPLE:
			var w := float(log.gait[s]) / 100.0
			d.texture_albedo = _band_tex["trample" if k == TrackLog.K.TRAMPLE else "band"]
			var bw := maxf(w * 1.7, 0.5) if k == TrackLog.K.BAND else w
			d.size = Vector3(bw, 1.4 + maxf(bw, log.size[s]) * 0.55, log.size[s] + 0.8)   # tall enough for a slope across it
			base_a = 0.58 if k == TrackLog.K.BAND else 0.85
		TrackLog.K.DRAG:
			d.texture_albedo = _band_tex["drag"]
			d.size = Vector3(float(log.gait[s]) / 100.0 * 1.4, 1.2, log.size[s] + 0.45)
			base_a = 0.55
		TrackLog.K.BED:
			d.texture_albedo = _band_tex["bed"]
			d.size = Vector3(0.80, 1.4, 1.35)
			base_a = 0.7
		_:
			var name: String = TrackLog.NAMES[k]
			var kd: Dictionary = KINDS[name]
			var sz2: Vector2 = kd.size
			var snow: SnowField = world.get("snow") if world != null else null
			var deep := snow != null and snow.tier_at(q.x, q.z) >= 3
			d.texture_albedo = _tex[name]
			d.texture_normal = _nrm[name]
			d.size = Vector3(sz2.x * (1.15 if deep else 1.0), 1.2, sz2.y * (1.45 if deep else 1.0))   # deep snow: postholes
			base_a = 0.85 if log.gait[s] == 1 else 0.78
	d.set_meta("base_a", base_a)
	d.visible = true


## How many prints / blood decals / bands are showing (tests).
func visible_counts() -> Vector3i:
	var c := Vector3i.ZERO
	for d in (_pools["p"].decals as Array): if d.visible: c.x += 1
	for d in (_pools["b"].decals as Array): if d.visible: c.y += 1
	for d in (_pools["n"].decals as Array): if d.visible: c.z += 1
	return c


func prints_of(kind: String) -> Array:
	var out: Array = []
	var pool: Dictionary = _pools["p"]
	for i in POOL:
		var s: int = (pool.slot as PackedInt32Array)[i]
		if s >= 0 and TrackLog.NAMES[log.kind[s]] == kind:
			out.append(pool.decals[i])
	return out


# ------------------------------------------------------------------ reading
## The hint line for what lies at p (the snow under the crosshair): "Deer tracks · fresh · running",
## "Blood · fresh, bright red · it is bleeding badly", "Many feet · a horde passed · a few hours ago". "" = nothing.
func read_at(p: Vector3) -> String:
	var near := log.query(p.x, p.z, 1.2)
	if near.is_empty():
		return ""
	var blood_n := 0
	var newest_blood := -1
	var counts := {}
	var newest := {}
	var running := false
	for s in near:
		var k: int = log.kind[s]
		if k == TrackLog.K.BLOOD:
			blood_n += 1
			if newest_blood < 0 or log.sid[s] > log.sid[newest_blood]: newest_blood = s
			continue
		counts[k] = int(counts.get(k, 0)) + 1
		if not newest.has(k) or log.sid[s] > log.sid[newest[k]]: newest[k] = s
		if log.gait[s] == 1 and k in PRINT_K: running = true
	if blood_n > 0:
		var fresh := log.real_age(newest_blood) < 3600.0
		var trail := log.query(p.x, p.z, 6.0, [TrackLog.K.BLOOD]).size()
		var t := "Blood · " + ("fresh, bright red" if fresh else ("dark, frozen" if log.eff_age(newest_blood) < 6.0 * 3600.0 else "old, nearly buried"))
		if fresh and trail >= 4: t += " · it is bleeding badly"
		return t
	if counts.has(TrackLog.K.TRAMPLE):
		return "Many feet · a horde passed · " + _ago(newest[TrackLog.K.TRAMPLE])
	var best := -1
	var best_n := 0
	for k in counts:
		if k in PRINT_K and int(counts[k]) > best_n:
			best = k; best_n = counts[k]
	if best < 0:
		if counts.has(TrackLog.K.BED):
			return "A bed pressed into the snow · " + _cond(newest[TrackLog.K.BED])
		if counts.has(TrackLog.K.BAND):
			var s0: int = newest[TrackLog.K.BAND]
			return _label(log.owner[s0]) + " · " + _cond(s0)
		return ""
	var t2 := _label(best) + " · " + _cond(newest[best])
	if running: t2 += " · running"
	if best == TrackLog.K.WOLF:   # several animals: more than one wolf line within 4 m in the last two hours
		var owners := {}
		for s in log.query(p.x, p.z, 4.0, [TrackLog.K.WOLF]):
			if log.real_age(s) < 7200.0: owners[log.owner[s]] = true
		if owners.size() >= 2: t2 += " · several animals"
	return t2


func _label(k: int) -> String:
	match k:
		TrackLog.K.DEER: return "Deer tracks"
		TrackLog.K.WOLF: return "Wolf tracks"
		TrackLog.K.BEAR: return "Bear tracks"
		TrackLog.K.HARE: return "Hare tracks"
		TrackLog.K.BOOT: return "Boot prints"
		TrackLog.K.SHUFFLE: return "Dragging footprints"
	return "Tracks"


func _cond(s: int) -> String:   # how filled-in the snow makes it look
	var e := log.eff_age(s)
	if e < 3600.0: return "fresh"
	if e < 4.0 * 3600.0: return "a few hours old"
	return "old, half filled with snow"


func _ago(s: int) -> String:
	var a := log.real_age(s)
	if a < 3600.0: return "within the hour"
	if a < 4.0 * 3600.0: return "a few hours ago"
	return "a while ago"


# ------------------------------------------------------------------ textures
## 64x64 print, top of the image = forward. A shadowed hollow (cool blue-grey) with a thin lighter rim of thrown snow.
static func _make_print(kind: String) -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0   # -1 = forward
			var a := 0.0
			var rim := 0.0
			match kind:
				"deer":   # two cloven halves, pointed forward, a narrow gap between; heels rounded
					for s: float in [-1.0, 1.0]:
						var cu: float = (u - s * 0.30) / 0.36
						var cv: float = (v + 0.05) / 0.80
						var taper := 1.0 - 0.45 * clampf(-cv, 0.0, 1.0)
						var dd: float = cu * cu / (taper * taper) + cv * cv
						a = maxf(a, 1.0 - smoothstep(0.75, 1.0, dd))
						rim = maxf(rim, smoothstep(0.95, 1.1, dd) * (1.0 - smoothstep(1.1, 1.45, dd)))
					if absf(u) < 0.06: a *= 0.3
				"wolf":   # lobed heel pad + four oval toes, claw marks ahead of the front pair
					var pad := pow(u / 0.46, 2.0) + pow((v - 0.42) / 0.34, 2.0)
					a = 1.0 - smoothstep(0.7, 1.0, pad)
					rim = smoothstep(1.0, 1.15, pad) * (1.0 - smoothstep(1.15, 1.5, pad))
					for t in [[-0.52, -0.05], [0.52, -0.05], [-0.20, -0.48], [0.20, -0.48]]:
						var td := pow((u - t[0]) / 0.20, 2.0) + pow((v - t[1]) / 0.25, 2.0)
						a = maxf(a, 1.0 - smoothstep(0.7, 1.0, td))
					for c in [[-0.22, -0.84], [0.22, -0.84]]:
						var cd := pow((u - c[0]) / 0.06, 2.0) + pow((v - c[1]) / 0.09, 2.0)
						a = maxf(a, 0.8 * (1.0 - smoothstep(0.6, 1.0, cd)))
				"bear":   # broad pad and five toes in an arc, claws well ahead
					var pad := pow(u / 0.70, 2.0) + pow((v - 0.30) / 0.52, 2.0)
					a = 1.0 - smoothstep(0.75, 1.0, pad)
					rim = smoothstep(1.0, 1.12, pad) * (1.0 - smoothstep(1.12, 1.35, pad))
					for i in 5:
						var ang := lerpf(-0.95, 0.95, i / 4.0)
						var tu := sin(ang) * 0.62
						var tv := -0.30 - cos(ang) * 0.30
						var td := pow((u - tu) / 0.15, 2.0) + pow((v - tv) / 0.15, 2.0)
						a = maxf(a, 1.0 - smoothstep(0.7, 1.0, td))
						var cd := pow((u - tu * 1.08) / 0.05, 2.0) + pow((v - tv + 0.27) / 0.08, 2.0)
						a = maxf(a, 0.75 * (1.0 - smoothstep(0.6, 1.0, cd)))
				"hare":   # long hind foot, furred and soft-edged
					var hd := pow(u / 0.55, 2.0) + pow(v / 0.92, 2.0)
					a = 1.0 - smoothstep(0.45, 1.0, hd)
				"boot":   # lugged sole: forefoot, narrow arch, heel
					var w1 := 0.78 * sqrt(maxf(1.0 - pow((v + 0.42) / 0.5, 2.0), 0.0))
					var w2 := 0.62 * sqrt(maxf(1.0 - pow((v - 0.6) / 0.34, 2.0), 0.0))
					var ww := maxf(maxf(w1, w2), 0.42 if (v > -0.1 and v < 0.3) else 0.0)
					a = (1.0 - smoothstep(ww * 0.8, ww, absf(u))) if ww > 0.0 else 0.0
					a *= 0.88 + 0.12 * sin(y * 1.9)
				"shuffle":   # a dragged foot: the toe scuffs a groove forward, the heel barely lifts
					var sole := pow(u / 0.62, 2.0) + pow((v - 0.25) / 0.62, 2.0)
					a = 1.0 - smoothstep(0.6, 1.0, sole)
					var groove := (1.0 - smoothstep(0.18, 0.34, absf(u))) * smoothstep(-1.0, -0.2, v) * (1.0 - smoothstep(-0.2, 0.1, v))
					a = maxf(a, 0.7 * groove)
			var shade := 0.88 + 0.12 * v   # the forward wall of the hollow is in shadow, the heel is shallow
			var col := Color(0.40 * shade, 0.47 * shade, 0.68 * shade, clampf(a, 0.0, 1.0))
			if rim > a:   # thrown snow catches the light
				col = Color(0.97, 0.98, 1.0, rim * 0.35)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## Hollow relief from the print's alpha (walls facing in), like the boot prints' compression lip.
static func _make_normal(tex: ImageTexture) -> ImageTexture:
	var src := tex.get_image()
	var n := src.get_width()
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx := src.get_pixel(mini(x + 1, n - 1), y).a - src.get_pixel(maxi(x - 1, 0), y).a
			var dy := src.get_pixel(x, mini(y + 1, n - 1)).a - src.get_pixel(x, maxi(y - 1, 0)).a
			var nv := Vector3(dx * 1.4, dy * 1.4, 1.0).normalized()
			img.set_pixel(x, y, Color(nv.x * 0.5 + 0.5, nv.y * 0.5 + 0.5, nv.z * 0.5 + 0.5, src.get_pixel(x, y).a))
	return ImageTexture.create_from_image(img)


## Irregular blood splatter: a main drop of overlapping blobs, ragged edge, satellite droplets thrown out in one
## direction; darker where it pooled.
static func _make_blood(seed_v: int) -> ImageTexture:
	var n := 64
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + seed_v * 17
	var blobs: Array = []
	for i in rng.randi_range(3, 5):
		blobs.append([rng.randf_range(-0.22, 0.22), rng.randf_range(-0.22, 0.22), rng.randf_range(0.16, 0.34)])
	var throw: float = rng.randf() * TAU
	for i in rng.randi_range(4, 9):
		var r: float = rng.randf_range(0.45, 0.9)
		var aa: float = throw + rng.randf_range(-0.7, 0.7)
		blobs.append([cos(aa) * r, sin(aa) * r, rng.randf_range(0.025, 0.07)])
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var a := 0.0
			var depth := 0.0
			for b in blobs:
				var d := Vector2(u - b[0], v - b[1]).length() / float(b[2])
				var ragged := 1.0 + 0.18 * sin(atan2(v - b[1], u - b[0]) * 7.0 + float(b[0]) * 13.0)
				a = maxf(a, 1.0 - smoothstep(0.80 * ragged, 1.0 * ragged, d))
				depth = maxf(depth, 1.0 - d)
			var c := Color(0.36, 0.015, 0.025).lerp(Color(0.20, 0.0, 0.01), clampf(depth, 0.0, 1.0))
			c.a = a
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## Long faint shapes: trail band (a worn line, soft edges, broken along its length), trample (wide churned
## band), drag (a narrow furrow), bed (an oval pressed hollow).
static func _make_band(k: String) -> ImageTexture:
	var w := 32 if k != "trample" else 96
	var h := 128 if k != "bed" else 64
	if k == "trample": h = 160
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 991 + k.length()
	var bumps: Array = []
	for i in (24 if k != "trample" else 150):   # trample: footholes punched all over a churned band
		bumps.append([rng.randf(), rng.randf_range(-0.85, 0.85), rng.randf_range(0.6, 1.4), rng.randf() * TAU])
	# trample holes splatted per bump over a small pixel box (evaluating 150 bumps at every pixel cost ~2.5 s at load)
	var holes_px := PackedFloat32Array()
	if k == "trample":
		holes_px.resize(w * h)
		for b in bumps:
			var sc: float = b[2]
			var an: float = float(b[3]) * 0.25
			var ca := cos(an); var sa := sin(an)
			var bx := (float(b[1]) + 1.0) * 0.5 * w
			var by := float(b[0]) * h
			var rx := int(ceil(2.8 / (7.5 * sc) * w * 0.5)) + 1
			var ry := int(ceil(2.8 / (30.0 * sc) * h)) + 1
			for py in range(maxi(0, int(by) - ry), mini(h, int(by) + ry + 1)):
				for px in range(maxi(0, int(bx) - rx), mini(w, int(bx) + rx + 1)):
					var du := (((px + 0.5) / w * 2.0 - 1.0) - float(b[1])) * 7.5 * sc
					var dv := (((py + 0.5) / h) - float(b[0])) * 30.0 * sc
					var r := du * ca + dv * sa
					var q := -du * sa + dv * ca
					holes_px[py * w + px] += exp(-r * r * 1.6 - q * q * 0.5)
	for y in h:
		for x in w:
			var u := (x + 0.5) / w * 2.0 - 1.0
			var v := (y + 0.5) / h
			var a := 0.0
			match k:
				"band":
					a = (1.0 - smoothstep(0.35, 1.0, absf(u))) * smoothstep(0.0, 0.12, v) * (1.0 - smoothstep(0.88, 1.0, v))
					a *= 0.75 + 0.25 * sin(v * 47.0 + sin(v * 13.0) * 2.0)
				"trample":
					a = (1.0 - smoothstep(0.6, 1.0, absf(u))) * smoothstep(0.0, 0.08, v) * (1.0 - smoothstep(0.92, 1.0, v))
					a *= clampf(0.42 + holes_px[y * w + x] * 0.7, 0.0, 1.0)   # elongated holes along travel (v)
				"drag":
					a = (1.0 - smoothstep(0.15, 1.0, absf(u))) * smoothstep(0.0, 0.18, v) * (1.0 - smoothstep(0.82, 1.0, v))
					a *= 0.8 + 0.2 * sin(v * 31.0 + u * 3.0)
				"bed":
					var e := pow(u / 0.92, 2.0) + pow((v - 0.52) / 0.46, 2.0)
					var side_k := clampf(0.5 - u * 0.8 + (v - 0.5) * 0.4, 0.0, 1.0)   # the lip toward the sun is in shadow
					var lip := smoothstep(0.3, 0.8, e) * (1.0 - smoothstep(0.8, 1.0, e)) * (0.25 + 0.75 * side_k)
					var floor_m := (1.0 - smoothstep(0.45, 0.9, e)) * (0.40 + 0.20 * sin(u * 9.0 + sin(v * 11.0) * 2.0) * sin(v * 7.0 + u * 4.0))
					a = clampf(lip * 0.6 + floor_m, 0.0, 1.0)
			var shade := 0.9 + 0.1 * u
			if k == "trample": shade *= 0.62   # churned snow: broken crust, holes full of shadow
			elif k == "band": shade *= 0.78
			img.set_pixel(x, y, Color(0.42 * shade, 0.49 * shade, 0.70 * shade, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
