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
const VIEW_R := Rect2(140, 170, 760, 470)
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
var _dist := 1.85
var _drag := false
var _drag_from := Vector2.ZERO
var _msg := ""
var _msg_t := 0.0
var _prev_mouse := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 21
	visible = false
	_bg = Control.new(); _bg.set_anchors_preset(Control.PRESET_FULL_RECT); _bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.draw.connect(_draw_bg); add_child(_bg)
	_vc = SubViewportContainer.new(); _vc.stretch = true; _vc.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(_vc)
	_vp = SubViewport.new(); _vp.own_world_3d = true; _vp.msaa_3d = Viewport.MSAA_4X; _vp.size = Vector2i(760, 470)
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
	_bg.queue_redraw(); _c.queue_redraw()


func drag_held() -> bool: return _drag


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
	_bg.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _button(r: Rect2, label: String, act: Callable, enabled := true, size := 15) -> void:
	var hv := enabled and r.has_point(_mouse)
	_c.draw_rect(r, Color(0.16, 0.18, 0.14, 0.95) if hv else Color(0.09, 0.10, 0.09, 0.95))
	_c.draw_rect(r, DZ.ACCENT if hv else (DZ.EDGE if enabled else Color(0.25, 0.26, 0.23)), false, 1.5)
	DZ.text(_c, label, r.position + Vector2(0, r.size.y * 0.5 + size * 0.36), size, (DZ.ACCENT if hv else DZ.TEXT) if enabled else DZ.DIM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if enabled: _hits.append({"r": r, "act": act})


func _draw_all() -> void:
	if inv == null: return
	_hits.clear()
	var s := _scale()
	_c.draw_set_transform(_origin(), 0.0, Vector2(s, s))
	var spec := RifleDB.spec(rid)
	DZ.text(_c, "GUNSMITH", Vector2(140, 112), 34, DZ.TEXT)
	DZ.text(_c, String(spec.get("name", rid)).to_upper(), Vector2(330, 112), 24, DZ.ACCENT)
	DZ.text(_c, "At the workbench: every tool to hand, sights keep their zero." if bench else "In the field: scopes and mounts need a screwdriver, and a sight fitted here loses its zero.",
		Vector2(140, 146), 15, DZ.GOOD if bench else DZ.DIM)
	# rifles carried (v3)
	var x := 900.0
	for r: String in Inventory.RIFLE_IDS:
		if inv.count(r) < 1 or not RifleDB.is_v3(r): continue
		var rr := Rect2(Vector2(x, 84), Vector2(110, 30))
		var sel := r == rid
		_c.draw_rect(rr, Color(0.20, 0.19, 0.12, 0.95) if sel else Color(0.09, 0.10, 0.09, 0.9))
		_c.draw_rect(rr, DZ.ACCENT if sel or rr.has_point(_mouse) else DZ.EDGE, false, 1.2)
		DZ.text(_c, String(RifleDB.spec(r).get("name", r)).split(" ")[0], rr.position + Vector2(0, 20), 13, DZ.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 110)
		var pick := r
		_hits.append({"r": rr, "act": func() -> void: rid = pick; _rebuild_gun()})
		x += 116.0
		if x > 1400: break
	_c.draw_rect(VIEW_R, DZ.EDGE, false, 1.5)
	DZ.text(_c, "drag: turn     wheel: closer", VIEW_R.position + Vector2(10, VIEW_R.size.y - 10), 13, DZ.DIM)
	_draw_stats(Vector2(140, 668))
	_draw_slots(Vector2(930, 160))
	_button(Rect2(Vector2(1300, 784), Vector2(160, 36)), "CLOSE", close)
	if _msg_t > 0.0:
		DZ.text(_c, _msg, Vector2(930, 800), 16, DZ.WARN)
	DZ.text(_c, "Esc: close", Vector2(140, 824), 15, DZ.DIM)
	_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _att_weight(f: Dictionary) -> float:
	var w := 0.0
	for slot: String in RifleDB.SLOTS:
		w += float(RifleDB.attachment(String(f.get(slot, ""))).get("weight", 0.0))
	return w


func _draw_stats(p: Vector2) -> void:
	var spec := RifleDB.spec(rid)
	var f := RifleDB.fitted(rid)
	var o := RifleDB.optic(rid)
	var mags: Array = o.get("mag", [1.0])
	var mag := ("%.0f-%.0fx" % [mags[0], mags[1]]) if mags.size() > 1 else ("%.1fx" % float(mags[0]) if float(mags[0]) >= 1.5 else "1x")
	var noise := RifleDB.value(rid, "noise", 1.0) * float(RifleDB.muzzle(rid).get("noise_mult", 1.0))
	var z: Vector2 = inv.zero_of(rid)
	var zl := "zeroed" if z.length() < 0.05 else "off ~%d cm at 100 m - zero it at a bench" % roundi(z.length() * 10.0)
	var rows := [
		["Sight", "%s  (%s)" % [String(o.get("label", "iron sights")), mag]],
		["Zero", zl],
		["Weight", "%.1f kg  (rifle %.1f + parts %.2f)" % [float(spec.get("weight", 3.5)) + _att_weight(f), float(spec.get("weight", 3.5)), _att_weight(f)]],
		["Report", "%d %% of a hunting rifle%s" % [roundi(noise * 100.0), "  (moderated)" if String(f.get("muzzle", "")) == "muzzle_moderator" else ""]],
		["Action", "%s, %d rounds" % [RifleDB.action(rid), RifleDB.mag(rid)]],
	]
	var lt := RifleDB.light(rid)
	if not lt.is_empty():
		rows.append(["Light", "%d m beam, battery %d %%" % [roundi(float(lt.get("range_m", 30))), roundi(100.0 * float(f.get("light_h", 0.0)) / maxf(0.1, float(lt.get("battery_h", 6.0))))]])
	var y := p.y
	for r in rows:
		DZ.text(_c, String(r[0]).to_upper(), Vector2(p.x, y), 14, DZ.DIM)
		DZ.text(_c, String(r[1]), Vector2(p.x + 90, y), 16, DZ.WARN if (r[0] == "Zero" and z.length() >= 0.05) else DZ.TEXT)
		y += 24.0
	var zr := Rect2(Vector2(560, p.y - 18), Vector2(320, 34))
	var can_zero: bool = bench and z.length() >= 0.05
	_button(zr, "ZERO AT THE BENCH (3 ROUNDS)" if bench else "ZERO: NEEDS A WORKBENCH", _zero, can_zero, 14)


func _draw_slots(p: Vector2) -> void:
	var mounts: Dictionary = RifleDB.spec(rid).get("mounts", {})
	var f := RifleDB.fitted(rid)
	var y := p.y
	for slot: String in RifleDB.SLOTS:
		var have := RifleDB.mount_for(rid, slot)
		if slot == "mount" and String(mounts.get("mount", "none")) == "none": continue
		var cur := String(f.get(slot, ""))
		DZ.text(_c, SLOT_LABEL[slot], Vector2(p.x, y), 15, DZ.DIM)
		var takes := "takes: " + RifleDB._mount_words(have) if have != "none" else ("takes: nothing" if slot != "light" else "takes: taped light only")
		DZ.text(_c, takes, Vector2(p.x + 330, y), 13, DZ.DIM, HORIZONTAL_ALIGNMENT_RIGHT, 200)
		y += 26.0
		var row := Rect2(Vector2(p.x, y - 18), Vector2(530, 30))
		_c.draw_rect(row, Color(0.07, 0.08, 0.07, 0.9)); _c.draw_rect(row, DZ.EDGE, false, 1.0)
		var label := String(RifleDB.attachment(cur).get("name", cur)) if cur != "" else ("iron sights" if slot == "optic" else "-")
		DZ.text(_c, label, row.position + Vector2(10, 21), 16, DZ.TEXT if cur != "" else DZ.DIM)
		if cur != "":
			_button(Rect2(row.position + Vector2(430, 3), Vector2(94, 24)), "REMOVE", func() -> void: _fit(slot, ""), true, 13)
		y += 20.0
		# what in the pack could go here
		for aid: String in RifleDB.attachments():
			var a := RifleDB.attachment(aid)
			if String(a.get("kind", "")) != slot or inv.count(aid) < 1: continue
			y += 6.0
			var ok := RifleDB.fits(rid, aid)
			var r := Rect2(Vector2(p.x + 20, y), Vector2(510, 26))
			var tools: Array = a.get("tools", [])
			var tool_note := ""
			if not bench and not tools.is_empty():
				for t in tools:
					if inv.count(String(t)) < 1: tool_note = "  - needs a %s" % inv.name_of(String(t)).to_lower()
			var txt := ("Fit " + String(a.get("name", aid))) if ok else (String(a.get("name", aid)) + ": " + RifleDB.fit_reason(rid, aid))
			txt += ("  (%d min)" % int(a.get("fit_min", 5))) if ok and tool_note == "" else tool_note
			var pick := aid
			_button(r, txt, func() -> void: _fit(slot, pick), ok and tool_note == "", 13)
			y += 26.0
		y += 18.0
		if y > 760: break
