class_name LensFlare
extends CanvasLayer
## Screen-space glare for bright sources in view: the low sun, lit campfires, road flares. A soft bloom at the
## source, a short horizontal streak and 3-4 very faint ghosts on the line through the screen centre. Subtle on
## purpose (TLD has glare, not sci-fi flares); stronger through a scope's glass. Occlusion is a real trace
## (terrain, trunks, buildings) every few frames, faded so a trunk passing over the sun does not pop.

const MAX_SOURCES := 6
const FIRE_R := 60.0
const FLARE_R := 90.0
const GHOSTS := [[0.55, 0.060, Color(0.55, 0.75, 1.0)], [1.25, 0.035, Color(1.0, 0.85, 0.55)], [1.6, 0.095, Color(0.6, 1.0, 0.75)], [2.1, 0.050, Color(0.9, 0.6, 1.0)]]

var world: Node
var _c: Control
var _glow: Texture2D
var _hex: Texture2D        # aperture ghost: a 6-blade iris, soft edge, slightly brighter rim
var _dirt: Texture2D       # lens grime: soft smudges + specks, lit only by a bright source in view
var dirt_k := 0.0          # last frame's dirt strength (tests / debug)
var _dirt_rect: ColorRect  # W9: grime lit brightest around the source (radial falloff), not flat across the glass
const DIRT_SHADER := """shader_type canvas_item;
render_mode blend_add;
uniform sampler2D dirt : filter_linear;
uniform vec2 src = vec2(0.5);
uniform float aspect = 1.78;
uniform float k = 0.0;
uniform vec3 col : source_color = vec3(1.0);
void fragment() {
	float a = texture(dirt, UV).a;
	vec2 d = (UV - src) * vec2(aspect, 1.0);
	float m = 0.12 + 0.88 * exp(-dot(d, d) / 0.10);
	COLOR = vec4(col, a * k * m);
}"""
var _vis: Dictionary = {}      # source key -> smoothed visibility 0..1
var _occ: Dictionary = {}      # source key -> last traced visibility (0 hidden / 1 clear)
var _frame := 0
var sources: Array = []        # last frame: [{key, screen, k, col, size}] (tests / debug)


func _ready() -> void:
	layer = 4
	_c = Control.new(); _c.set_anchors_preset(Control.PRESET_FULL_RECT); _c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := CanvasItemMaterial.new(); m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; _c.material = m
	_c.draw.connect(_draw); add_child(_c)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0)); g.add_point(0.18, Color(1, 1, 1, 0.55)); g.add_point(0.5, Color(1, 1, 1, 0.12))
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(1.0, 0.5); gt.width = 128; gt.height = 128
	_glow = gt
	_hex = _make_hex(96)
	_dirt = _make_dirt(480, 270)
	_dirt_rect = ColorRect.new(); _dirt_rect.set_anchors_preset(Control.PRESET_FULL_RECT); _dirt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dsh := Shader.new(); dsh.code = DIRT_SHADER
	var dm := ShaderMaterial.new(); dm.shader = dsh; dm.set_shader_parameter("dirt", _dirt); _dirt_rect.material = dm
	add_child(_dirt_rect)


static func _make_hex(n: int) -> Texture2D:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var nrm: Array[Vector2] = []
	for k in 6: nrm.append(Vector2.from_angle(deg_to_rad(15.0 + 60.0 * k)))
	for y in n:
		for x in n:
			var p := (Vector2(x, y) + Vector2(0.5, 0.5)) / float(n) * 2.0 - Vector2.ONE
			var d := 0.0
			for v in nrm: d = maxf(d, p.dot(v))
			var a := (1.0 - smoothstep(0.80, 0.92, d)) * (0.55 + 0.45 * smoothstep(0.35, 0.86, d))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


static func _make_dirt(w: int, h: int) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var rng := RandomNumberGenerator.new(); rng.seed = 7731
	var acc := PackedFloat32Array(); acc.resize(w * h)
	for b in 46:   # smudges: big, faint, slightly oval
		var c := Vector2(rng.randf() * w, rng.randf() * h); var r := rng.randf_range(10.0, 46.0); var a := rng.randf_range(0.10, 0.32)
		var sq := rng.randf_range(0.6, 1.0)
		for y in range(maxi(0, int(c.y - r)), mini(h, int(c.y + r) + 1)):
			for x in range(maxi(0, int(c.x - r)), mini(w, int(c.x + r) + 1)):
				var d := Vector2((x - c.x), (y - c.y) / sq).length() / r
				if d < 1.0: acc[y * w + x] += a * (1.0 - d * d)
	for s in 520:  # specks
		var x2 := rng.randi_range(0, w - 1); var y2 := rng.randi_range(0, h - 1)
		acc[y2 * w + x2] += rng.randf_range(0.3, 0.9)
	for i in w * h: img.set_pixel(i % w, i / w, Color(1, 1, 1, clampf(acc[i], 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _cam() -> Camera3D: return get_viewport().get_camera_3d()


func _candidates(cam: Camera3D) -> Array:
	var out: Array = []
	var w = world
	var night: float = w.sky_rig.gameplay_night_factor if w.sky_rig != null else 0.0
	var sun: DirectionalLight3D = w.sky_rig.sun if w.sky_rig != null else null
	if sun != null and sun.visible and sun.light_energy > 0.05 and night < 0.85:
		var sd: Vector3 = sun.global_basis.z.normalized()      # towards the sun
		if sd.y > -0.02:
			var ov: float = w.weather.overcast if w.weather != null else 0.0
			var fog: float = w.weather.fog_mult if w.weather != null else 1.0
			var k := (1.0 - night) * (1.0 - 0.9 * ov) / (1.0 + maxf(0.0, fog - 1.0) * 0.25)
			# a low sun glares more (through more air it is orange, and it sits in the view)
			var low := 1.0 - clampf(sd.y / 0.6, 0.0, 1.0)
			out.append({"key": "sun", "pos": cam.global_position + sd * 3000.0, "dir": sd, "k": k * (0.55 + 0.45 * low), "col": Color(1.0, 0.86, 0.66).lerp(Color(1.0, 0.62, 0.36), low * 0.6), "size": 1.0})
	var dark := clampf(night * 1.2 + 0.15, 0.0, 1.0)
	for cf in w.campfires:
		if not is_instance_valid(cf) or not cf.is_lit(): continue
		var p: Vector3 = (cf as Node3D).global_position + Vector3(0, 0.35, 0)
		var d := p.distance_to(cam.global_position)
		if d < FIRE_R: out.append({"key": cf.get_instance_id(), "pos": p, "k": dark * 0.55 / (1.0 + d * 0.08), "col": Color(1.0, 0.62, 0.30), "size": 0.45})
	for fl in get_tree().get_nodes_in_group("flares"):
		var p2: Vector3 = (fl as Node3D).global_position + Vector3(0, 0.15, 0)
		var d2 := p2.distance_to(cam.global_position)
		if d2 < FLARE_R: out.append({"key": fl.get_instance_id(), "pos": p2, "k": (0.35 + 0.65 * dark) * 0.9 / (1.0 + d2 * 0.05), "col": Color(1.0, 0.25, 0.18), "size": 0.6})
	out.sort_custom(func(a, b) -> bool: return float(a["k"]) > float(b["k"]))
	return out.slice(0, MAX_SOURCES)


func _occluded(cam: Camera3D, s: Dictionary) -> bool:
	var w = world
	var eye := cam.global_position
	var to: Vector3 = (s["pos"] as Vector3) - eye
	var is_sun := s.has("dir")
	var dist := 600.0 if is_sun else to.length()
	var dir: Vector3 = (s["dir"] as Vector3) if is_sun else to.normalized()
	var r: Dictionary = HitZones.trace(get_tree(), w.terrain, w.forest, eye, dir, maxf(0.1, dist - 0.6), [], w._building_list())
	return not r.is_empty()


## 0 clear .. 1 hidden. A fire or a flare is a body, not a point: three rays (centre, a quarter metre either
## side) so one half behind a log glares half.
func _occlusion(cam: Camera3D, s: Dictionary) -> float:
	if s.has("dir"): return 1.0 if _occluded(cam, s) else 0.0
	var side := cam.global_basis.x * 0.25
	var hid := 0.0
	for o in [Vector3.ZERO, side, -side]:
		var s2 := s.duplicate(); s2["pos"] = (s["pos"] as Vector3) + o
		if _occluded(cam, s2): hid += 1.0
	return hid / 3.0


func _process(delta: float) -> void:
	if world == null or not is_instance_valid(world) or world.player == null: return
	var cam := _cam()
	if cam == null: return
	_frame += 1
	var cands := _candidates(cam)
	var seen := {}
	sources.clear()
	var fwd := -cam.global_basis.z
	var scoped: bool = world.hud != null and world.hud.scoped
	var vp := _c.size
	for s in cands:
		var key = s["key"]; seen[key] = true
		var p: Vector3 = s["pos"]
		var to := (p - cam.global_position).normalized()
		var facing := fwd.dot(to)
		if facing < 0.2 or cam.is_position_behind(p): _vis[key] = 0.0; continue
		if _frame % 3 == 0 or not _occ.has(key):
			_occ[key] = 1.0 - _occlusion(cam, s)
		var cur := float(_vis.get(key, 0.0))
		var tgt := float(_occ[key])
		cur = move_toward(cur, tgt, delta * 6.0)
		_vis[key] = cur
		var sp := cam.unproject_position(p)
		if sp.x < -vp.x * 0.2 or sp.x > vp.x * 1.2 or sp.y < -vp.y * 0.2 or sp.y > vp.y * 1.2: continue
		var centre := pow(clampf((facing - 0.6) / 0.4, 0.0, 1.0), 1.5)
		var k := float(s["k"]) * cur * (0.35 + 0.65 * centre) * (1.6 if scoped else 1.0)
		if k > 0.01: sources.append({"key": key, "screen": sp, "k": k, "col": s["col"], "size": float(s["size"])})
	for key in _vis.keys():
		if not seen.has(key): _vis.erase(key); _occ.erase(key)
	dirt_k = 0.0
	for s2 in sources: dirt_k += float(s2["k"]) * float(s2["size"])
	dirt_k = clampf(dirt_k, 0.0, 1.2)
	_c.queue_redraw()


func _draw() -> void:
	var vp := _c.size
	var centre := vp * 0.5
	var unit := vp.y
	for s in sources:
		var sp: Vector2 = s["screen"]; var k: float = s["k"]; var col: Color = s["col"]; var sz: float = s["size"]
		var r := unit * 0.22 * sz * (0.6 + 0.4 * k)
		_c.draw_texture_rect(_glow, Rect2(sp - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(col.r, col.g, col.b, 0.34 * k))
		var sw := Vector2(unit * 0.55 * sz, unit * 0.018 * sz)   # anamorphic streak
		_c.draw_texture_rect(_glow, Rect2(sp - sw, sw * 2.0), false, Color(col.r, col.g, col.b, 0.22 * k))
		var axis := centre - sp
		for g in GHOSTS:
			var gp: Vector2 = sp + axis * float(g[0])
			var gr: float = unit * float(g[1]) * (0.7 + 0.3 * sz)
			var gc: Color = g[2]
			_c.draw_texture_rect(_hex, Rect2(gp - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(gc.r * col.r, gc.g * col.g, gc.b * col.b, 0.075 * k))
	var dm := _dirt_rect.material as ShaderMaterial   # grime on the glass catches the light, tinted by the brightest source
	if dirt_k > 0.02 and not sources.is_empty():
		var c0: Color = sources[0]["col"]
		dm.set_shader_parameter("src", (sources[0]["screen"] as Vector2) / vp)
		dm.set_shader_parameter("aspect", vp.x / maxf(1.0, vp.y))
		dm.set_shader_parameter("col", Vector3(c0.r, c0.g, c0.b))
		dm.set_shader_parameter("k", 0.22 * dirt_k)
	else:
		dm.set_shader_parameter("k", 0.0)
