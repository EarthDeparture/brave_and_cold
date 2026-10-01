class_name DevMenu
extends CanvasLayer
## F8 developer menu (left side). World keeps running while it is open.
## Tab (while open) toggles mouse-look so you can fly around with the menu still on screen; F8 closes it.
## Sections: weather, time of day, player cheats (god / noclip / stay warm...), teleports, creatures, items, render toggles, readout.

var world: Node
var player: Player
var clock: GameClock
var weather: Weather

var freeze_time := false
var freeze_creatures := false
var instant_weather := true
var infinite_stamina := false
var stay_warm := false
var stay_fed := false

var _frozen_hour := 0.0
var _panel: PanelContainer
var _scroll: ScrollContainer
var _info: Label
var _hour_slider: HSlider
var _hour_lbl: Label
var _wx_lbl: Label
var _speed_lbl: Label
var _dragging := false
var _info_t := 0.0
var _look := false
var _wx_btns: Array[Button] = []


func _init() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func setup(w: Node) -> void:
	world = w
	player = world.get("player")
	clock = world.get("clock")
	weather = world.get("weather")
	_build()
	if "devtest=1" in OS.get_cmdline_user_args():
		_selftest()


func _selftest() -> void:
	await get_tree().create_timer(2.0).timeout
	var fails := 0
	_set_weather(Weather.S.BLIZZARD)
	await get_tree().process_frame
	var ok := weather.state == Weather.S.BLIZZARD and weather.precip > 0.99 and weather.locked
	print("DEVTEST weather blizzard instant=", ok)
	fails += 0 if ok else 1
	_set_hour(2.0)
	await get_tree().process_frame
	ok = absf(clock.hour - 2.0) < 0.1
	print("DEVTEST hour set=", ok, " hour=", clock.hour)
	fails += 0 if ok else 1
	freeze_time = true
	_frozen_hour = clock.hour
	var h0 := clock.hour
	await get_tree().create_timer(0.6).timeout
	ok = absf(clock.hour - h0) < 0.01
	print("DEVTEST freeze=", ok)
	fails += 0 if ok else 1
	freeze_time = false
	player.god = true
	player.hurt(60.0, "test")
	ok = player.health >= 99.9 and not player.dead
	print("DEVTEST god=", ok)
	fails += 0 if ok else 1
	player.god = false
	_set_noclip(true)
	var y0 := player.position.y + 60.0
	player.position.y = y0
	await get_tree().create_timer(0.5).timeout
	ok = absf(player.position.y - y0) < 1.0
	print("DEVTEST noclip hover=", ok)
	fails += 0 if ok else 1
	_set_noclip(false)
	await get_tree().create_timer(1.5).timeout
	var g: float = player.ground_at(player.position.x, player.position.z)
	ok = absf(player.position.y - (g + player.eye_h)) < 1.0
	print("DEVTEST noclip off regrounded=", ok)
	fails += 0 if ok else 1
	_tp_hut(0)
	await get_tree().create_timer(0.6).timeout
	var huts: Array = world.get("huts")
	if huts.is_empty():
		ok = false
	else:
		ok = player.position.distance_to((huts[0] as Node3D).global_position) < 9.0
	print("DEVTEST tp hut=", ok)
	fails += 0 if ok else 1
	var zs: Array = world.get("zombies")
	var n0 := zs.size()
	_spawn("zombie", 2)
	ok = zs.size() == n0 + 2
	print("DEVTEST spawn zombies=", ok)
	fails += 0 if ok else 1
	_kill_hostile()
	await get_tree().create_timer(0.3).timeout
	var alive := 0
	for z in zs:
		if is_instance_valid(z) and not z.is_dead():
			alive += 1
	ok = alive == 0
	print("DEVTEST kill all=", ok, " alive=", alive)
	fails += 0 if ok else 1
	_kit()
	var inv: Inventory = world.get("inv")
	ok = inv != null and inv.count("rifle") > 0
	print("DEVTEST kit=", ok)
	fails += 0 if ok else 1
	print("DEVTEST failures=", fails)
	get_tree().quit()


func open() -> void:
	visible = true
	_look = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	_look = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if e.keycode == KEY_F8:
		var pm = world.get("pause_menu")
		if pm != null and pm.visible:
			return
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif e.keycode == KEY_TAB and visible:
		_look = not _look
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _look else Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- build
func _build() -> void:
	_panel = UiKit.panel(10.0)
	_panel.position = Vector2(10, 10)
	_panel.custom_minimum_size = Vector2(372, 0)
	add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	_panel.add_child(outer)
	outer.add_child(UiKit.label("DEV MENU   F8 close   Tab mouse-look", 14, DZ.ACCENT))
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(350, 560)
	outer.add_child(_scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.custom_minimum_size = Vector2(340, 0)
	_scroll.add_child(box)
	get_viewport().size_changed.connect(_fit)
	_fit()

	_head(box, "READOUT")
	_info = UiKit.label("", 13, DZ.TEXT)
	box.add_child(_info)

	_head(box, "WEATHER")
	_wx_lbl = UiKit.label("", 13, DZ.DIM)
	box.add_child(_wx_lbl)
	var wrow := _flow(box)
	for i in range(Weather.NAMES.size()):
		var idx := i
		var b := _btn(wrow, Weather.NAMES[i], func() -> void: _set_weather(idx))
		_wx_btns.append(b)
	var wrow2 := _flow(box)
	_btn(wrow2, "Auto weather", func() -> void: weather.locked = false)
	_check(wrow2, "Instant", instant_weather, func(v: bool) -> void: instant_weather = v)

	_head(box, "TIME OF DAY")
	_hour_lbl = UiKit.label("", 13, DZ.TEXT)
	box.add_child(_hour_lbl)
	_hour_slider = HSlider.new()
	_hour_slider.min_value = 0.0
	_hour_slider.max_value = 24.0
	_hour_slider.step = 0.05
	_hour_slider.focus_mode = Control.FOCUS_NONE
	_hour_slider.custom_minimum_size = Vector2(320, 22)
	_hour_slider.drag_started.connect(func() -> void: _dragging = true)
	_hour_slider.drag_ended.connect(func(_c: bool) -> void: _dragging = false)
	_hour_slider.value_changed.connect(func(v: float) -> void:
		if _dragging:
			_set_hour(v))
	box.add_child(_hour_slider)
	var trow := _flow(box)
	for pr in [["Dawn", 6.0], ["Noon", 12.0], ["Dusk", 17.0], ["Night", 22.0], ["Midnight", 0.0]]:
		var hv: float = pr[1]
		_btn(trow, pr[0], func() -> void: _set_hour(hv))
	var frow := _flow(box)
	_check(frow, "Freeze time", false, func(v: bool) -> void:
		freeze_time = v
		_frozen_hour = clock.hour)
	_speed_lbl = UiKit.label("", 13, DZ.DIM)
	box.add_child(_speed_lbl)
	var srow := _flow(box)
	for sp in [["Real 1x", 1.0], ["Default", 48.0], ["x200", 200.0], ["x1000", 1000.0]]:
		var sv: float = sp[1]
		_btn(srow, sp[0], func() -> void: _set_speed(sv))

	_head(box, "PLAYER")
	var prow := _flow(box)
	_check(prow, "God mode", false, func(v: bool) -> void: player.god = v)
	_check(prow, "No clip (fly)", false, func(v: bool) -> void: _set_noclip(v))
	var prow2 := _flow(box)
	_check(prow2, "Inf. stamina", false, func(v: bool) -> void: infinite_stamina = v)
	_check(prow2, "Stay warm", false, func(v: bool) -> void: stay_warm = v)
	_check(prow2, "Stay fed", false, func(v: bool) -> void: stay_fed = v)
	var fly := HBoxContainer.new()
	fly.add_child(UiKit.label("Fly speed", 13, DZ.DIM))
	var fs := HSlider.new()
	fs.min_value = 2.0
	fs.max_value = 80.0
	fs.step = 1.0
	fs.value = player.noclip_speed
	fs.focus_mode = Control.FOCUS_NONE
	fs.custom_minimum_size = Vector2(200, 20)
	fs.value_changed.connect(func(v: float) -> void: player.noclip_speed = v)
	fly.add_child(fs)
	box.add_child(fly)
	box.add_child(UiKit.label("Fly: WASD + Space up, C/Ctrl down, Shift x4", 12, DZ.DIM))
	var prow3 := _flow(box)
	_btn(prow3, "Heal", func() -> void: _heal())
	_btn(prow3, "Revive", func() -> void: _revive())
	_btn(prow3, "Warm up", func() -> void: _warm())
	_btn(prow3, "Eat/drink", func() -> void: _feed())

	_head(box, "TELEPORT")
	var trow2 := _flow(box)
	_btn(trow2, "Cabin", func() -> void: _tp_cabin())
	var huts: Array = world.get("huts")
	for i in range(huts.size()):
		var hi := i
		_btn(trow2, "Hut %d" % (i + 1), func() -> void: _tp_hut(hi))
	var trow3 := _flow(box)
	_btn(trow3, "Road W", func() -> void: _tp_road(0.02))
	_btn(trow3, "Road mid", func() -> void: _tp_road(0.5))
	_btn(trow3, "Road E", func() -> void: _tp_road(0.97))
	_btn(trow3, "Bridge", func() -> void: _tp_bridge())
	_btn(trow3, "Drop to ground", func() -> void: _drop())

	_head(box, "CREATURES")
	var crow := _flow(box)
	_check(crow, "Freeze AI", false, func(v: bool) -> void: _freeze_creatures(v))
	_btn(crow, "Kill all hostile", func() -> void: _kill_hostile())
	var crow2 := _flow(box)
	_btn(crow2, "+Zombie", func() -> void: _spawn("zombie", 1))
	_btn(crow2, "+Horde 6", func() -> void: _spawn("zombie", 6))
	_btn(crow2, "+Wolf", func() -> void: _spawn("wolf", 1))
	_btn(crow2, "+Bear", func() -> void: _spawn("bear", 1))

	_head(box, "ITEMS")
	var irow := _flow(box)
	_btn(irow, "Survival kit", func() -> void: _kit())
	_btn(irow, "+10 wood", func() -> void: _give("wood", 10))
	_btn(irow, "+30 ammo", func() -> void: _give("ammo", 30))
	_btn(irow, "+Matches", func() -> void: _give("matches", 6))

	_head(box, "RENDER / DEBUG")
	var rrow := _flow(box)
	_check(rrow, "Hide HUD", false, func(v: bool) -> void: world.get("hud").visible = not v)
	_check(rrow, "Hide trees", false, func(v: bool) -> void: world.get("forest").visible = not v)
	_check(rrow, "Shadows", true, func(v: bool) -> void: world.get("sun").shadow_enabled = v)
	_check(rrow, "Fog", true, func(v: bool) -> void: world.get("env").fog_enabled = v)
	_check(rrow, "Wireframe", false, func(v: bool) -> void:
		get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME if v else Viewport.DEBUG_DRAW_DISABLED)
	_check(rrow, "Unshaded", false, func(v: bool) -> void:
		get_viewport().debug_draw = Viewport.DEBUG_DRAW_UNSHADED if v else Viewport.DEBUG_DRAW_DISABLED)
	var drow := _flow(box)
	_btn(drow, "Screenshot", func() -> void: _shot())
	_btn(drow, "Copy coords", func() -> void: _copy_coords())


func _fit() -> void:
	if _scroll == null:
		return
	var h := get_viewport().get_visible_rect().size.y - 90.0
	_scroll.custom_minimum_size = Vector2(350, clampf(h, 200.0, 900.0))


func _head(parent: Node, text: String) -> void:
	var l := UiKit.label(text, 14, DZ.ACCENT)
	parent.add_child(l)
	var r := ColorRect.new()
	r.color = DZ.EDGE
	r.custom_minimum_size = Vector2(0, 1)
	parent.add_child(r)


func _flow(parent: Node) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 4)
	f.add_theme_constant_override("v_separation", 4)
	parent.add_child(f)
	return f


func _btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", DZ.font())
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", DZ.TEXT)
	b.add_theme_color_override("font_hover_color", DZ.ACCENT)
	b.custom_minimum_size = Vector2(0, 26)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _check(parent: Node, text: String, on: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_override("font", DZ.font())
	c.add_theme_font_size_override("font_size", 13)
	c.add_theme_color_override("font_color", DZ.TEXT)
	c.toggled.connect(cb)
	parent.add_child(c)
	return c


# ---------------------------------------------------------------- per frame
func _process(delta: float) -> void:
	if player == null:
		return
	# persistent cheats run even with the menu closed
	if freeze_time:
		clock.hour = _frozen_hour
	if infinite_stamina:
		player.stamina = 100.0
		player.exhausted = false
	if stay_warm:
		var body: BodyTemperature = world.get("body")
		body.core = BodyTemperature.NORMAL
		body.wetness = 0.0
	if stay_fed:
		var needs: Needs = world.get("needs")
		needs.calories = Needs.MAX_CAL
		needs.water = 100.0
	if player.god and not player.dead:
		player.health = 100.0
	if not visible:
		return
	if not _dragging:
		_hour_slider.set_value_no_signal(clock.hour)
	_hour_lbl.text = "%s%s" % [clock.time_string(), "   FROZEN" if freeze_time else ""]
	_speed_lbl.text = "Time scale: %.0fx" % clock.time_scale
	_info_t -= delta
	if _info_t <= 0.0:
		_info_t = 0.2
		_refresh_info()


func _refresh_info() -> void:
	var body: BodyTemperature = world.get("body")
	var needs: Needs = world.get("needs")
	var p := player.position
	var hostile := get_tree().get_nodes_in_group("hostile").size()
	var s := "FPS %d   pos %.0f, %.0f, %.0f\n" % [Engine.get_frames_per_second(), p.x, p.y, p.z]
	s += "Air %.1f C  feels %.1f C  core %.1f C\n" % [clock.ambient_c(), body.feels_like, body.core]
	s += "Weather %s  wind %.1f m/s  precip %.2f\n" % [weather.state_name(), weather.wind, weather.precip]
	s += "Health %.0f  Cal %d  Water %d%%  Stamina %d\n" % [player.health, int(needs.calories), int(needs.water), int(player.stamina)]
	s += "Hostile alive %d   god %s  noclip %s" % [hostile, "ON" if player.god else "off", "ON" if player.noclip else "off"]
	_info.text = s
	_wx_lbl.text = "%s%s" % [weather.state_name(), "  (locked)" if weather.locked else "  (auto)"]
	for i in range(_wx_btns.size()):
		_wx_btns[i].add_theme_color_override("font_color", DZ.ACCENT if i == weather.state else DZ.TEXT)


# ---------------------------------------------------------------- actions
func _set_weather(i: int) -> void:
	if instant_weather:
		weather.lock_state(i)
	else:
		weather.locked = true
		weather.set_state(i, false)


func _set_hour(h: float) -> void:
	clock.hour = h
	_frozen_hour = h


func _set_speed(s: float) -> void:
	clock.time_scale = s
	Cabin.game_scale = s


func _set_noclip(v: bool) -> void:
	player.noclip = v
	if not v:
		player.position.y = player.ground_at(player.position.x, player.position.z) + player.eye_h


func _heal() -> void:
	if not player.dead:
		player.health = 100.0


func _revive() -> void:
	player.dead = false
	player.frozen = false
	player.health = 100.0
	player.death_cause = ""
	_warm()
	_feed()


func _warm() -> void:
	var body: BodyTemperature = world.get("body")
	body.core = BodyTemperature.NORMAL
	body.wetness = 0.0


func _feed() -> void:
	var needs: Needs = world.get("needs")
	needs.calories = Needs.MAX_CAL
	needs.water = 100.0


func _tp(x: float, z: float, face: Vector3 = Vector3.INF) -> void:
	player.place(x, z)
	if player.noclip:
		player.position.y = player.ground_at(x, z) + 4.0
		player._ready_ground = true
	if face != Vector3.INF:
		var d := face - Vector3(x, 0.0, z)
		player.yaw = atan2(-d.x, -d.z)
		player.pitch = deg_to_rad(-4.0)


func _tp_cabin() -> void:
	var cabins: Array = world.get("cabins")
	if cabins.is_empty():
		return
	var c: Node3D = cabins[0]
	var p := c.to_global(Vector3(0.0, 0.0, 6.0))
	_tp(p.x, p.z, c.global_position)


func _tp_hut(i: int) -> void:
	var huts: Array = world.get("huts")
	if i >= huts.size():
		return
	var h: Node3D = huts[i]
	var p := h.to_global(Vector3(0.0, 0.0, 6.0))
	_tp(p.x, p.z, h.global_position)


func _tp_road(f: float) -> void:
	var road: RoadNet = world.get("road")
	if road == null or road.points.size() < 3:
		return
	var i := clampi(int(f * float(road.points.size() - 1)), 0, road.points.size() - 2)
	var a: Vector2 = road.points[i]
	var b: Vector2 = road.points[i + 1]
	_tp(a.x, a.y, Vector3(b.x, 0.0, b.y))


func _tp_bridge() -> void:
	var road: RoadNet = world.get("road")
	if road == null or road.bridges.is_empty():
		return
	var br: Array = road.bridges[0]
	var a: Vector2 = road.points[maxi(int(br[0]) - 8, 0)]
	var b: Vector2 = road.points[mini(int(br[0]) - 7, road.points.size() - 1)]
	_tp(a.x, a.y, Vector3(b.x, 0.0, b.y))


func _drop() -> void:
	_tp(player.position.x, player.position.z)


func _freeze_creatures(v: bool) -> void:
	freeze_creatures = v
	for key in ["zombies", "wolves", "bears", "deer"]:
		var arr: Array = world.get(key)
		for c in arr:
			if is_instance_valid(c):
				(c as Node).process_mode = Node.PROCESS_MODE_DISABLED if v else Node.PROCESS_MODE_INHERIT


func _kill_hostile() -> void:
	for h in get_tree().get_nodes_in_group("hostile"):
		if is_instance_valid(h) and h.has_method("hit"):
			h.call("hit", 9999.0, player.position)


func _spawn(kind: String, n: int) -> void:
	var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
	var terrain: Terrain3D = world.get("terrain")
	for k in range(n):
		var side := Vector3(fwd.z, 0.0, -fwd.x) * (float(k) - float(n) * 0.5) * 2.0
		var p := player.position + fwd * 14.0 + side
		var h: float = terrain.data.get_height(Vector3(p.x, 0.0, p.z))
		if is_nan(h):
			continue
		p.y = h
		var idx := randi() % 90000 + 9000
		match kind:
			"zombie":
				world.call("_add_zombie", p, idx)
			"wolf":
				world.call("_add_wolf", p, idx, false)
			"bear":
				world.call("_add_wolf", p, idx, true)


func _give(id: String, n: int) -> void:
	world.call("_ensure_gear")
	var inv: Inventory = world.get("inv")
	if inv != null:
		inv.add(id, n)
		world.call("_say", "+%d %s" % [n, id])


func _kit() -> void:
	world.call("_ensure_gear")
	var inv: Inventory = world.get("inv")
	if inv == null:
		return
	for pr in [["rifle", 1], ["ammo", 40], ["axe", 1], ["parka", 1], ["sweater", 1], ["matches", 8], ["wood", 10], ["beans", 4], ["flare", 3]]:
		inv.add(pr[0], pr[1])
	world.call("_say", "Dev kit added")


func _shot() -> void:
	_panel.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var path := "user://devshot_%d.png" % Time.get_ticks_msec()
	img.save_png(path)
	print("DEV_SHOT ", ProjectSettings.globalize_path(path))
	_panel.visible = true
	world.call("_say", "Saved " + path.get_file())


func _copy_coords() -> void:
	var p := player.position
	DisplayServer.clipboard_set("pos=%.1f,%.1f yaw=%.1f pitch=%.1f hour=%.2f" % [p.x, p.z, rad_to_deg(player.yaw), rad_to_deg(player.pitch), clock.hour])
