class_name GunsmithScreen
extends CanvasLayer
## Gunsmith (weapon kit v3, W5): the rifle turning on a cloth in a small 3D view, its four slots
## (adapter mount, optic, light, muzzle) with what is fitted and what in the pack would fit, and the
## zero. Fitting is a timed action in the world (GameWorld.gunsmith_fit); scopes and mounts need a
## screwdriver unless at a workbench, and a sight fitted in the field loses its zero.
## Realism rules live in the data: only parts the rifle can take, no tactical fantasy parts.

const VW := 1600.0
const VH := 900.0
const PANEL_R := Rect2(110, 60, 1380, 780)
const VIEW_R := Rect2(140, 176, 760, 420)
const SLOT_LABEL := {"mount": "MOUNT", "optic": "SIGHT", "light": "LIGHT", "muzzle": "MUZZLE"}

var world: Node
var inv: Inventory
var player: Player
var hud: Hud
var rid := ""
var bench := false
var is_open := false

var _bg: Control
var _c: Control
var _vc: SubViewportContainer
var _vp: SubViewport
var _cam: Camera3D
var _gun: WeaponPresentation
var _pivot: Node3D
var _hits: Array = []
var _mouse := Vector2.ZERO
var _yaw := 1.22      # from the right side, a touch from the front
var _pitch := -0.22
var _dist := 1.30
var _drag := false
var _drag_from := Vector2.ZERO
var _msg := ""
var action_open := false    # inspect with the bolt drawn back / lever open (extractor, jewelled bolt, chamber)
var _scroll := 0.0          # slot column scroll (wheel over the column)
var _content_h := 0.0
var _tab_cmp := ""          # rifle tab under the mouse: compared with the selected rifle
const SLOT_R := Rect2(918, 150, 556, 620)
var _preview: Dictionary = {}   # {fit, label, loses_zero}: the change under the mouse, for the stat compare
var _msg_t := 0.0
var _prev_mouse := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 21
	visible = false
	_bg = Control.new(); _bg.set_anchors_preset(Control.PRESET_FULL_RECT); _bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.draw.connect(_draw_bg); add_child(_bg)
	_vc = SubViewportContainer.new(); _vc.stretch = true; _vc.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(_vc)
	_vp = SubViewport.new(); _vp.own_world_3d = true; _vp.msaa_3d = Viewport.MSAA_4X; _vp.size = Vector2i(760, 420)
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_vc.add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.11, 0.115, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.55, 0.57, 0.6); env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new(); we.environment = env; _vp.add_child(we)
	var key := DirectionalLight3D.new(); key.light_energy = 1.25; key.light_color = Color(1.0, 0.95, 0.88)
	key.rotation = Vector3(deg_to_rad(-48), deg_to_rad(28), 0); _vp.add_child(key)
	var fill := DirectionalLight3D.new(); fill.light_energy = 0.35; fill.light_color = Color(0.72, 0.8, 0.95)
	fill.rotation = Vector3(deg_to_rad(-20), deg_to_rad(-140), 0); _vp.add_child(fill)
	# a worn canvas cloth under the rifle
	var cloth := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(0.9, 1.6); cloth.mesh = pm
	var cm := StandardMaterial3D.new(); cm.albedo_color = Color(0.13, 0.125, 0.11); cm.roughness = 0.98; cloth.material_override = cm
	cloth.position = Vector3(0, -0.17, 0.0); _vp.add_child(cloth)
	_pivot = Node3D.new(); _vp.add_child(_pivot)
	_cam = Camera3D.new(); _cam.fov = 30.0; _cam.near = 0.02; _vp.add_child(_cam)
	_c = Control.new(); _c.set_anchors_preset(Control.PRESET_FULL_RECT); _c.mouse_filter = Control.MOUSE_FILTER_STOP
	_c.draw.connect(_draw_all); _c.gui_input.connect(_on_gui); add_child(_c)


func open_for(w: Node, i: Inventory, p: Player, h: Hud, rifle: String, at_bench: bool) -> void:
	world = w; inv = i; player = p; hud = h; rid = rifle; bench = at_bench
	if not is_open:
		is_open = true; visible = true
		_prev_mouse = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player.ui_open = true; hud.hide_ui = true
	_rebuild_gun()


func close() -> void:
	if not is_open: return
	is_open = false; visible = false
	player.ui_open = false; hud.hide_ui = false
	Input.mouse_mode = _prev_mouse


func _rebuild_gun() -> void:
	if _gun == null:
		_gun = WeaponPresentation.new(); _pivot.add_child(_gun)
	_gun.set_weapon(rid)
	_gun.position = Vector3(0, -0.07, 0.19)   # rifle centred on the pivot (trigger origin, -Z forward)


func _input(e: InputEvent) -> void:
	if not is_open: return
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_ESCAPE or e.keycode == KEY_TAB: close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open: return
	if player.dead or player.struggling: close(); return
	_msg_t -= delta
	var s := _scale(); var o := _origin()
	_vc.position = o + VIEW_R.position * s; _vc.size = VIEW_R.size * s
	_cam.position = Vector3(sin(_yaw) * cos(_pitch), -sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	_cam.look_at(Vector3.ZERO, Vector3.UP)
	if _gun != null and _gun.fit_sig != RifleDB.fit_sig(rid): _rebuild_gun()
	if _gun != null: _pose_action()
	_bg.queue_redraw(); _c.queue_redraw()


func drag_held() -> bool: return _drag


## Bolt rifles and the lever: the cycle clip held at its open point; self-loaders: the empty-reload clip with
## the charging handle held back.
func _pose_action() -> void:
	var clip := "idle"; var t := 0.0
	if action_open:
		if RifleDB.action(rid) in ["bolt", "lever"]: clip = "cycle"; t = 0.45
		else: clip = "reload_empty"; t = 2.2
	if _gun.animation_player != null and _gun.animation_player.has_animation(clip): _gun.sample(clip, t)


func _scale() -> float: return minf(_c.size.x / VW, _c.size.y / VH)
func _origin() -> Vector2: return (_c.size - Vector2(VW, VH) * _scale()) * 0.5
func _to_v(p: Vector2) -> Vector2: return (p - _origin()) / _scale()


func _on_gui(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_mouse = _to_v(e.position)
		if _drag:
			var d: Vector2 = _mouse - _drag_from; _drag_from = _mouse
			_yaw -= d.x * 0.008; _pitch = clampf(_pitch - d.y * 0.006, -1.2, 0.6)
		return
	if not (e is InputEventMouseButton): return
	_mouse = _to_v(e.position)
	if e.pressed and SLOT_R.has_point(_mouse) and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_scroll = clampf(_scroll + (-42.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 42.0), 0.0, maxf(0.0, _content_h - (SLOT_R.end.y - 182.0))); return
	if e.pressed and VIEW_R.has_point(_mouse) and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_dist = clampf(_dist * (0.9 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.11), 0.35, 2.2); return
	if e.button_index != MOUSE_BUTTON_LEFT: return
	if not e.pressed: _drag = false; return
	for i in range(_hits.size() - 1, -1, -1):
		if (_hits[i]["r"] as Rect2).has_point(_mouse):
			(_hits[i]["act"] as Callable).call(); return
	if VIEW_R.has_point(_mouse): _drag = true; _drag_from = _mouse


func _say(s: String) -> void:
	_msg = s; _msg_t = 4.0


# ------------------------------------------------------------ actions
func _fit(slot: String, aid: String) -> void:
	var why: String = world.gunsmith_fit(rid, slot, aid, bench)
	if why != "": _say(why)


func _zero() -> void:
	var why: String = world.gunsmith_zero(rid)
	if why != "": _say(why)


# ------------------------------------------------------------ drawing
func _draw_bg() -> void:
	var s := _scale()
	_bg.draw_rect(Rect2(Vector2.ZERO, _bg.size), Color(0, 0, 0, 0.62))
	_bg.draw_set_transform(_origin(), 0.0, Vector2(s, s))
	DZ.panel(_bg, PANEL_R)
	# slot column backing + a thin rule under the title
	_bg.draw_rect(Rect2(918, 150, 556, 676), Color(0.05, 0.055, 0.05, 0.55))
	_bg.draw_line(Vector2(140, 160), Vector2(900, 160), DZ.EDGE, 1.0)
	_bg.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _button(r: Rect2, label: String, act: Callable, enabled := true, size := 17) -> bool:
	var hv := enabled and r.has_point(_mouse)
	_c.draw_rect(r, Color(0.16, 0.18, 0.14, 0.95) if hv else Color(0.09, 0.10, 0.09, 0.95))
	_c.draw_rect(r, DZ.ACCENT if hv else (DZ.EDGE if enabled else Color(0.25, 0.26, 0.23)), false, 1.5)
	DZ.text(_c, label, r.position + Vector2(0, r.size.y * 0.5 + size * 0.36), size, (DZ.ACCENT if hv else DZ.TEXT) if enabled else DZ.DIM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if enabled: _hits.append({"r": r, "act": act})
	return hv


## A pack-part row: icon, name, minutes or the reason it won't go on. Returns true when hovered.
func _part_button(r: Rect2, aid: String, label: String, note: String, act: Callable, enabled: bool) -> bool:
	var hv := r.has_point(_mouse)
	_c.draw_rect(r, Color(0.16, 0.18, 0.14, 0.95) if (hv and enabled) else Color(0.09, 0.10, 0.09, 0.95))
	_c.draw_rect(r, DZ.ACCENT if (hv and enabled) else (DZ.EDGE if enabled else Color(0.25, 0.26, 0.23)), false, 1.5)
	DZ.item_icon(_c, aid, Rect2(r.position + Vector2(4, 3), Vector2(r.size.y * 1.6 - 6, r.size.y - 6)), 1.0 if enabled else 0.45)
	var tx := r.position.x + r.size.y * 1.6 + 6
	if enabled or note.length() < 22:
		DZ.text(_c, label, Vector2(tx, r.position.y + r.size.y * 0.5 + 6), 17, (DZ.ACCENT if hv else DZ.TEXT) if enabled else DZ.DIM)
		DZ.text(_c, note, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 6), 15, DZ.DIM if enabled else DZ.WARN, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 10)
	else:   # a long reason goes under the name instead of over it
		DZ.text(_c, label, Vector2(tx, r.position.y + 16), 16, DZ.DIM)
		DZ.text(_c, note, Vector2(tx, r.position.y + 32), 13, DZ.WARN)
	if enabled: _hits.append({"r": r, "act": act})
	return hv


func _draw_all() -> void:
	if inv == null: return
	_hits.clear()
	var s := _scale()
	_c.draw_set_transform(_origin(), 0.0, Vector2(s, s))
	var spec := RifleDB.spec(rid)
	DZ.text(_c, "GUNSMITH", Vector2(140, 112), 36, DZ.TEXT)
	DZ.text(_c, String(spec.get("name", rid)).to_upper(), Vector2(345, 112), 26, DZ.ACCENT)
	DZ.text(_c, "At the workbench: every tool to hand, sights keep their zero." if bench else "In the field: scopes and mounts need a screwdriver, and a sight fitted here loses its zero.",
		Vector2(140, 146), 17, DZ.GOOD if bench else DZ.DIM)
	# rifles carried (v3); "x2" when two of the same are in the pack
	var x := 930.0
	_tab_cmp = ""
	for r: String in Inventory.RIFLE_IDS:
		var n := inv.count(r)
		if n < 1 or not RifleDB.is_v3(r): continue
		var rr := Rect2(Vector2(x, 80), Vector2(132, 36))
		var sel := r == rid
		_c.draw_rect(rr, Color(0.20, 0.19, 0.12, 0.95) if sel else Color(0.09, 0.10, 0.09, 0.9))
		_c.draw_rect(rr, DZ.ACCENT if sel or rr.has_point(_mouse) else DZ.EDGE, false, 1.2)
		var nm := String(RifleDB.spec(r).get("name", r)).split(" ")[0] + ("  x%d" % n if n > 1 else "")
		DZ.text(_c, nm, rr.position + Vector2(0, 24), 17, DZ.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 132)
		var pick := r
		_hits.append({"r": rr, "act": func() -> void: rid = pick; _scroll = 0.0; _rebuild_gun()})
		if rr.has_point(_mouse) and r != rid: _tab_cmp = r
		x += 138.0
		if x > 1340: break
	_c.draw_rect(VIEW_R, DZ.EDGE, false, 1.5)
	_button(Rect2(VIEW_R.end - Vector2(176, 44), Vector2(166, 34)), "CLOSE ACTION" if action_open else "OPEN ACTION", func() -> void: action_open = not action_open, true, 15)
	DZ.text(_c, "drag: turn     wheel: closer", VIEW_R.position + Vector2(10, VIEW_R.size.y - 10), 15, DZ.DIM)
	_preview = {}
	_draw_slots(Vector2(934, 182))
	_draw_stats(Vector2(140, VIEW_R.end.y + 34))
	_button(Rect2(Vector2(1300, 790), Vector2(160, 38)), "CLOSE", close)
	if _msg_t > 0.0:
		DZ.text(_c, _msg, Vector2(934, 815), 17, DZ.WARN)
	DZ.text(_c, "Esc: close", Vector2(1300, 780), 15, DZ.DIM)
	_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _att_weight(f: Dictionary) -> float:
	var w := 0.0
	for slot: String in RifleDB.SLOTS:
		w += float(RifleDB.attachment(String(f.get(slot, ""))).get("weight", 0.0))
	return w


## Everything the stats panel shows, for fit `f` (the current fit, or the one under the mouse).
func _stats(f: Dictionary) -> Dictionary:
	var spec := RifleDB.spec(rid)
	var o := RifleDB.optic_for(rid, f)
	var mags: Array = o.get("mag", [1.0])
	var mag := ("%.0f-%.0fx" % [mags[0], mags[1]]) if mags.size() > 1 else ("%.0fx" % float(mags[0]) if float(mags[0]) >= 1.5 else "1x")
	var mz := RifleDB.muzzle_for(rid, f)
	var lt := RifleDB.light_for(rid, f)
	return {
		"sight": "%s  (%s)" % [String(o.get("label", "iron sights")), mag],
		"mag": float(mags[mags.size() - 1]),
		"weight": float(spec.get("weight", 3.5)) + _att_weight(f),
		"parts": _att_weight(f),
		"noise": RifleDB.value(rid, "noise", 1.0) * float(mz.get("noise_mult", 1.0)),
		"spread": RifleDB.value(rid, "spread", 1.0) * float(mz.get("spread_mult", 1.0)),
		"light": float(lt.get("range_m", 0.0)) if not lt.is_empty() else 0.0,
		"light_off": float(lt.get("offset_mrad", 0.0)),
		"length": float(mz.get("length_m", 0.0)),
	}


func _delta(v: float, fmt: String, lower_good: bool) -> Array:
	if absf(v) < 0.005: return ["", DZ.DIM]
	var good := (v < 0.0) == lower_good
	return [("  " + fmt) % [("+" if v > 0 else ""), v], DZ.GOOD if good else DZ.WARN]


## Hovering another rifle's tab: the two rifles side by side (each with what is fitted to it now).
func _draw_compare(p: Vector2) -> void:
	var o := _tab_cmp
	var a := _stats(RifleDB.fitted(rid)); var b := _stats_for(o)
	DZ.text(_c, "%s  vs  %s" % [String(RifleDB.spec(rid).get("name", rid)).to_upper(), String(RifleDB.spec(o).get("name", o)).to_upper()], Vector2(p.x, p.y - 8), 16, DZ.ACCENT)
	var rows := [
		["Sight", String(a["sight"]), String(b["sight"]), 0.0],
		["Weight", "%.2f kg" % a["weight"], "%.2f kg" % b["weight"], float(b["weight"]) - float(a["weight"])],
		["Damage", "%d" % roundi(RifleDB.value(rid, "damage", 100.0)), "%d" % roundi(RifleDB.value(o, "damage", 100.0)), -(RifleDB.value(o, "damage", 100.0) - RifleDB.value(rid, "damage", 100.0))],
		["Rounds", "%d (%s)" % [RifleDB.mag(rid), RifleDB.action(rid)], "%d (%s)" % [RifleDB.mag(o), RifleDB.action(o)], -float(RifleDB.mag(o) - RifleDB.mag(rid))],
		["Report", "%d %%" % roundi(float(a["noise"]) * 100.0), "%d %%" % roundi(float(b["noise"]) * 100.0), float(b["noise"]) - float(a["noise"])],
		["Spread", "x%.2f" % a["spread"], "x%.2f" % b["spread"], float(b["spread"]) - float(a["spread"])],
	]
	var y := p.y + 18.0
	for r in rows:
		DZ.text(_c, String(r[0]).to_upper(), Vector2(p.x, y), 15, DZ.DIM)
		DZ.text(_c, String(r[1]), Vector2(p.x + 100, y), 17, DZ.TEXT)
		var d: float = r[3]
		DZ.text(_c, String(r[2]), Vector2(p.x + 330, y), 17, DZ.TEXT if absf(d) < 0.005 else (DZ.GOOD if d < 0 else DZ.WARN))
		y += 26.0


func _stats_for(other: String) -> Dictionary:
	var keep := rid; rid = other
	var s := _stats(RifleDB.fitted(other))
	rid = keep
	return s


func _draw_stats(p: Vector2) -> void:
	if _tab_cmp != "": _draw_compare(p); return
	var f := RifleDB.fitted(rid)
	var cur := _stats(f)
	var pv: Dictionary = {}
	if not _preview.is_empty(): pv = _stats(_preview["fit"])
	var z: Vector2 = inv.zero_of(rid)
	var zl := "zeroed" if z.length() < 0.05 else "off ~%d cm at 100 m - zero it at a bench" % roundi(z.length() * 10.0)
	var zcol := DZ.WARN if z.length() >= 0.05 else DZ.TEXT
	if not _preview.is_empty() and bool(_preview.get("loses_zero", false)):
		zl = "zero will be lost (fitted in the field)"; zcol = DZ.WARN
	var rows := []
	var sight_d := ["", DZ.DIM]
	if not pv.is_empty() and pv["sight"] != cur["sight"]: sight_d = ["  ->  " + String(pv["sight"]), DZ.ACCENT]
	rows.append(["Sight", cur["sight"], sight_d, DZ.TEXT])
	rows.append(["Zero", zl, ["", DZ.DIM], zcol])
	rows.append(["Weight", "%.2f kg  (parts %.2f)" % [cur["weight"], cur["parts"]], _delta(pv["weight"] - cur["weight"], "%s%.2f kg", true) if not pv.is_empty() else ["", DZ.DIM], DZ.TEXT])
	var mod := "  (moderated)" if String(f.get("muzzle", "")) == "muzzle_moderator" else ""
	rows.append(["Report", "%d %% of a hunting rifle%s" % [roundi(cur["noise"] * 100.0), mod], _delta((pv["noise"] - cur["noise"]) * 100.0, "%s%.0f %%", true) if not pv.is_empty() else ["", DZ.DIM], DZ.TEXT])
	rows.append(["Spread", "x%.2f" % cur["spread"], _delta(pv["spread"] - cur["spread"], "%s%.2f", true) if not pv.is_empty() else ["", DZ.DIM], DZ.TEXT])
	rows.append(["Action", "%s, %d rounds" % [RifleDB.action(rid), RifleDB.mag(rid)], ["", DZ.DIM], DZ.TEXT])
	var lt := RifleDB.light(rid)
	var lrow := "none"
	if not lt.is_empty():
		lrow = "%d m beam, battery %d %%" % [roundi(cur["light"]), roundi(100.0 * float(f.get("light_h", 0.0)) / maxf(0.1, float(lt.get("battery_h", 6.0))))]
	var ld := ["", DZ.DIM]
	if not pv.is_empty() and absf(pv["light"] - cur["light"]) > 0.1:
		ld = ["  ->  %s" % ("%d m beam%s" % [roundi(pv["light"]), "  (off the bore)" if pv["light_off"] > 1.0 else ""] if pv["light"] > 0 else "no light"), DZ.ACCENT]
	rows.append(["Light", lrow, ld, DZ.TEXT if lrow != "none" else DZ.DIM])
	if not _preview.is_empty():
		DZ.text(_c, "IF YOU " + String(_preview["label"]).to_upper(), Vector2(p.x, p.y - 8), 16, DZ.ACCENT)
		p.y += 18.0
	var y := p.y
	for r in rows:
		DZ.text(_c, String(r[0]).to_upper(), Vector2(p.x, y), 15, DZ.DIM)
		var vs := String(r[1])
		DZ.text(_c, vs, Vector2(p.x + 100, y), 18, r[3])
		var d: Array = r[2]
		if String(d[0]) != "":
			DZ.text(_c, String(d[0]), Vector2(p.x + 100 + DZ.text_w(vs, 18), y), 18, d[1])
		y += 26.0
	# right of the stats: zero + next rifle of this type
	var bx := 700.0
	var zr := Rect2(Vector2(bx, VIEW_R.end.y + 16), Vector2(200, 40))
	var can_zero: bool = bench and z.length() >= 0.05
	_button(zr, "ZERO (3 ROUNDS)" if bench else "ZERO: NEEDS BENCH", _zero, can_zero, 16)
	var sp := inv.spare_count(rid)
	if sp > 0:
		var nr := Rect2(Vector2(bx, zr.end.y + 10), Vector2(200, 40))
		_button(nr, "NEXT RIFLE  (%d CARRIED)" % (sp + 1), func() -> void: inv.cycle_spare(rid); _rebuild_gun(), true, 16)
		DZ.text(_c, "each keeps its own parts and zero", Vector2(bx, nr.end.y + 20), 14, DZ.DIM, HORIZONTAL_ALIGNMENT_CENTER, 200)


func _preview_fit(slot: String, aid: String) -> Dictionary:
	var f: Dictionary = RifleDB.fitted(rid).duplicate()
	f[slot] = aid
	if slot == "mount" and aid == "": f["optic"] = ""
	return f


func _vis_y(y: float, h: float) -> bool: return y >= SLOT_R.position.y + 8.0 and y + h <= SLOT_R.end.y


func _draw_slots(p: Vector2) -> void:
	var mounts: Dictionary = RifleDB.spec(rid).get("mounts", {})
	var f := RifleDB.fitted(rid)
	var y := p.y - _scroll
	for slot: String in RifleDB.SLOTS:
		var have := RifleDB.mount_for(rid, slot)
		if slot == "mount" and String(mounts.get("mount", "none")) == "none": continue
		var cur := String(f.get(slot, ""))
		if _vis_y(y - 16.0, 16.0):
			DZ.text(_c, SLOT_LABEL[slot], Vector2(p.x, y), 18, DZ.DIM)
			var takes := "takes " + RifleDB._mount_words(have) if have != "none" else ("takes nothing" if slot != "light" else "taped light only")
			DZ.text(_c, takes, Vector2(p.x, y), 15, DZ.DIM, HORIZONTAL_ALIGNMENT_RIGHT, 530)
		y += 10.0
		var row := Rect2(Vector2(p.x, y), Vector2(530, 46))
		if _vis_y(row.position.y, row.size.y):
			_c.draw_rect(row, Color(0.07, 0.08, 0.07, 0.9)); _c.draw_rect(row, DZ.EDGE, false, 1.0)
			if cur != "":
				DZ.item_icon(_c, cur, Rect2(row.position + Vector2(5, 4), Vector2(61, 38)))
			var label := String(RifleDB.attachment(cur).get("name", cur)) if cur != "" else (String(RifleDB.optic_for(rid, {}).get("label", "iron sights")) if slot == "optic" else "empty")
			DZ.text(_c, label, row.position + Vector2(76 if cur != "" else 12, 29), 18, DZ.TEXT if cur != "" else DZ.DIM)
			if cur != "":
				if _button(Rect2(row.position + Vector2(420, 8), Vector2(102, 30)), "REMOVE", func() -> void: _fit(slot, ""), true, 15):
					_preview = {"fit": _preview_fit(slot, ""), "label": "remove the " + String(RifleDB.attachment(cur).get("name", cur)).to_lower(), "loses_zero": false}
		y += 50.0
		# what in the pack could go here
		for aid: String in RifleDB.attachments():
			var a := RifleDB.attachment(aid)
			if String(a.get("kind", "")) != slot or inv.count(aid) < 1: continue
			var ok := RifleDB.fits(rid, aid)
			var r := Rect2(Vector2(p.x + 18, y), Vector2(512, 38))
			var tools: Array = a.get("tools", [])
			var tool_note := ""
			if ok and not bench and not tools.is_empty():
				for t in tools:
					if inv.count(String(t)) < 1: tool_note = "needs a %s" % inv.name_of(String(t)).to_lower()
			var note := (("%d min" % int(a.get("fit_min", 5))) if tool_note == "" else tool_note) if ok else RifleDB.fit_reason(rid, aid)
			var pick := aid
			var can := ok and tool_note == ""
			if _vis_y(r.position.y, r.size.y):
				if _part_button(r, aid, ("Fit " if ok else "") + String(a.get("name", aid)), note, func() -> void: _fit(slot, pick), can) and ok:
					_preview = {"fit": _preview_fit(slot, aid), "label": "fit the " + String(a.get("name", aid)).to_lower(),
						"loses_zero": not bench and slot in ["optic", "mount"]}
			y += 42.0
		y += 22.0
	_content_h = y + _scroll - p.y
	var room := SLOT_R.end.y - p.y
	if _content_h > room:   # scroll bar + hint
		var bar := Rect2(Vector2(1466, SLOT_R.position.y + 30), Vector2(4, SLOT_R.size.y - 40))
		_c.draw_rect(bar, Color(0.2, 0.21, 0.19, 0.8))
		var k := room / _content_h
		var off := (_scroll / maxf(1.0, _content_h - room)) * bar.size.y * (1.0 - k)
		_c.draw_rect(Rect2(bar.position + Vector2(0, off), Vector2(4, bar.size.y * k)), DZ.ACCENT)
		if _scroll < _content_h - room - 1.0: DZ.text(_c, "wheel: more parts below", Vector2(p.x, SLOT_R.end.y + 18), 14, DZ.DIM)
