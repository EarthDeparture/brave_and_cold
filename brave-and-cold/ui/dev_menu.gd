class_name DevMenu
extends CanvasLayer
## Developer menu (backtick key, enabled in Options) (left side). World keeps running while it is open.
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
var _item_opt: OptionButton


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
	var ua := OS.get_cmdline_user_args()
	if "devtest=1" in ua or "devmenu=1" in ua:
		Settings.dev_menu = true
	if "devtest=1" in ua:
		_selftest()
	if "choptest=1" in ua:
		_choptest()
	if "carcasstest=1" in ua:
		_carcasstest()


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
	# --- ActionRunner
	var done := [false]
	var cand := {"text": "Test", "hold": 0.5, "act": func() -> void: done[0] = true}
	world.call("_act_begin", cand)
	for i in range(10):
		world.call("_act_update", 0.1, true)
	ok = done[0]
	print("DEVTEST action completes=", ok)
	fails += 0 if ok else 1
	done[0] = false
	world.call("_act_begin", cand)
	world.call("_act_update", 0.2, true)
	world.call("_act_update", 0.1, false)
	ok = (not done[0]) and (world.get("_act") as Dictionary).is_empty()
	print("DEVTEST action cancels on release=", ok)
	fails += 0 if ok else 1
	world.call("_act_begin", cand)
	world.call("_act_update", 0.1, true)
	player.position.x += 2.0
	world.call("_act_update", 0.1, true)
	ok = (not done[0]) and (world.get("_act") as Dictionary).is_empty()
	print("DEVTEST action cancels on move=", ok)
	fails += 0 if ok else 1
	var hp0 := player.health
	var god0 := player.god
	player.god = false
	world.call("_act_begin", cand)
	world.call("_act_update", 0.1, true)
	player.hurt(5.0, "test")
	world.call("_act_update", 0.1, true)
	ok = (not done[0]) and (world.get("_act") as Dictionary).is_empty()
	player.health = hp0
	player.god = god0
	print("DEVTEST action cancels on damage=", ok)
	fails += 0 if ok else 1
	# --- weight + condition
	var iv2 := Inventory.new()
	iv2.add("rifle", 1)
	iv2.add("wood", 20)
	var w_ok := absf(iv2.total_weight() - (3.6 + 24.0)) < 0.01 and iv2.speed_mult() == 1.0
	iv2.add("wood", 10)
	w_ok = w_ok and iv2.speed_mult() < 1.0 and iv2.speed_mult() > 0.6
	iv2.add("wood", 20)
	w_ok = w_ok and not iv2.can_add("wood", 1) and iv2.can_add("rifle", 1)
	print("DEVTEST weight/encumbrance=", w_ok, " w=", iv2.total_weight(), " mult=", iv2.speed_mult())
	fails += 0 if w_ok else 1
	iv2.add("axe", 1)
	var c_ok := iv2.condition("axe") == 1.0 and absf(iv2.wear("axe", 0.4) - 0.6) < 0.001 and absf(iv2.condition("axe") - 0.6) < 0.001
	iv2.remove("axe", 1)
	c_ok = c_ok and iv2.condition("axe") == 1.0
	print("DEVTEST condition=", c_ok)
	fails += 0 if c_ok else 1
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
	if e.keycode == KEY_QUOTELEFT:
		if not Settings.dev_menu:
			return
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
	outer.add_child(UiKit.label("DEV MENU   ` close   Tab mouse-look", 14, DZ.ACCENT))
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
	var irow2 := _flow(box)
	_item_opt = OptionButton.new()
	_item_opt.focus_mode = Control.FOCUS_NONE
	_item_opt.add_theme_font_override("font", DZ.font())
	_item_opt.add_theme_font_size_override("font_size", 13)
	var ids: Array = Inventory.ITEMS.keys()
	ids.sort()
	for id in ids:
		_item_opt.add_item(String(id))
	irow2.add_child(_item_opt)
	_btn(irow2, "Give +1", func() -> void: _give(_item_opt.get_item_text(_item_opt.selected), 1))
	_btn(irow2, "+5", func() -> void: _give(_item_opt.get_item_text(_item_opt.selected), 5))
	_btn(irow2, "Dull axe", func() -> void:
		var iv: Inventory = world.get("inv")
		if iv != null:
			iv.wear("axe", 0.25))

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
	if visible and not Settings.dev_menu:
		close()
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
	var iv: Inventory = world.get("inv")
	if iv != null:
		s += "Weight %.1f / %d kg (max %d)  axe cond %d%%\n" % [iv.total_weight(), int(Inventory.WEIGHT_SOFT), int(Inventory.WEIGHT_HARD), int(iv.condition("axe") * 100.0)]
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
	for pr in [["rifle", 1], ["ammo", 40], ["axe", 1], ["knife", 1], ["parka", 1], ["sweater", 1], ["matches", 8], ["wood", 10], ["beans", 4], ["flare", 3]]:
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


func _choptest() -> void:
	await get_tree().create_timer(2.5).timeout
	var fails := 0
	var forest: ForestScatter = world.get("forest")
	world.call("_ensure_gear")
	var inv: Inventory = world.get("inv")
	inv.add("axe", 1)
	world.set("rifle_up", false)
	var t0 := forest.nearest_tree(player.position, Vector3.FORWARD, 80.0, false)
	var ok := not t0.is_empty()
	print("CHOPTEST found tree=", ok, " ", t0)
	fails += 0 if ok else 1
	if not ok:
		print("CHOPTEST failures=", fails)
		get_tree().quit()
		return
	var tx := float(t0["x"])
	var tz := float(t0["z"])
	_tp(tx + 1.8, tz, Vector3(tx, 0.0, tz))
	await get_tree().create_timer(1.0).timeout
	var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
	var t1 := forest.nearest_tree(player.position, fwd, 2.4, true)
	ok = not t1.is_empty() and absf(float(t1["x"]) - tx) < 0.3 and absf(float(t1["z"]) - tz) < 0.3
	print("CHOPTEST facing detect=", ok, " ", t1)
	fails += 0 if ok else 1
	var back := forest.nearest_tree(player.position, -fwd, 2.4, true)
	ok = back.is_empty() or absf(float(back["x"]) - tx) > 0.3
	print("CHOPTEST behind not chopped=", ok)
	fails += 0 if ok else 1
	world.call("_update_prompt")
	var txt := ""
	for c in world.get("_cands_cache"):
		txt += String(c["text"]) + " | "
	ok = txt.contains("Chop tree")
	print("CHOPTEST prompt=", ok, " ", txt)
	fails += 0 if ok else 1
	var key := ForestScatter.tree_key(tx, tz)
	var total := ForestScatter.hits_total(float(t0["h"]))
	var hits := 0
	while hits < 80 and not forest.felled.has(key):
		var tr := forest.nearest_tree(player.position, fwd, 3.0, true)
		if tr.is_empty():
			break
		world.call("_chop_hit", tr)
		hits += 1
	ok = forest.felled.has(key) and hits >= int(total / 1.0 - 1.0) and hits <= int(total / 0.55) + 2
	print("CHOPTEST felled=", ok, " hits=", hits, " total=", total)
	fails += 0 if ok else 1
	ok = inv.condition("axe") < 1.0
	print("CHOPTEST axe wear=", ok, " cond=", inv.condition("axe"))
	fails += 0 if ok else 1
	var gone := forest.nearest_tree(player.position, fwd, 2.4, true)
	ok = gone.is_empty() or absf(float(gone["x"]) - tx) > 0.3 or absf(float(gone["z"]) - tz) > 0.3
	print("CHOPTEST trunk removed=", ok)
	fails += 0 if ok else 1
	await get_tree().create_timer(4.0).timeout
	var logs := get_tree().get_nodes_in_group("logs")
	ok = logs.size() == 1
	print("CHOPTEST log landed=", ok, " n=", logs.size())
	fails += 0 if ok else 1
	if ok and "chopshot=1" in OS.get_cmdline_user_args():
		var lc: Vector3 = (logs[0] as WoodLog).center()
		_tp(lc.x + 7.0, lc.z + 5.0, lc)
		await get_tree().create_timer(1.5).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://chop_log.png")
		print("CHOPSHOT ", ProjectSettings.globalize_path("user://chop_log.png"))
	if ok:
		var wl: WoodLog = logs[0]
		var w0 := inv.count("wood")
		var s0 := inv.count("stick")
		world.call("_split_log", wl)
		ok = inv.count("wood") - w0 == wl.firewood and inv.count("stick") - s0 == 3
		print("CHOPTEST split=", ok, " wood+", inv.count("wood") - w0, " sticks+", inv.count("stick") - s0)
		fails += 0 if ok else 1
		await get_tree().process_frame
		ok = get_tree().get_nodes_in_group("logs").is_empty()
		print("CHOPTEST log removed=", ok)
		fails += 0 if ok else 1
	var t2 := forest.nearest_tree(player.position, fwd, 80.0, false)
	var k2 := ForestScatter.tree_key(float(t2["x"]), float(t2["z"]))
	var infos := forest.apply_felled([k2])
	var again := forest.apply_felled([k2])
	ok = infos.size() == 1 and again.size() == 0 and forest.felled.has(k2)
	print("CHOPTEST apply_felled=", ok)
	fails += 0 if ok else 1
	print("CHOPTEST failures=", fails)
	get_tree().quit()


func _steps_texts() -> String:
	world.call("_update_prompt")
	var s := ""
	for c in world.get("_cands_cache"):
		s += String(c["text"]) + " | "
	return s


func _run_acts(prefixes: Array) -> int:
	var n := 0
	for c in (world.get("_cands_cache") as Array).duplicate():
		for p in prefixes:
			if String(c["text"]).begins_with(p) and c.has("act"):
				(c["act"] as Callable).call()
				n += 1
				break
	return n


func _carcasstest() -> void:
	await get_tree().create_timer(2.5).timeout
	var fails := 0
	world.call("_ensure_gear")
	var inv: Inventory = world.get("inv")
	inv.counts.erase("knife")
	inv.counts.erase("axe")
	var pp: Vector3 = player.position
	var tg: Terrain3D = world.get("terrain")
	for sp: String in ["wolf", "bear"]:
		var pos := Vector3(pp.x + 3.0, tg.data.get_height(Vector3(pp.x + 3.0, 0, pp.z)), pp.z)
		var w: Wolf = world.call("_add_wolf", pos, 77, sp == "bear")
		w.hit(9999.0, pp)
		await get_tree().create_timer(0.8).timeout
		var ok: bool = w.is_in_group("carcasses") and Carcass.species_of(w) == sp
		print("CARCASSTEST ", sp, " carcass group+species=", ok)
		fails += 0 if ok else 1
		_tp(pos.x + 1.2, pos.z, pos)
		await get_tree().create_timer(0.8).timeout
		var tx := _steps_texts()
		ok = tx.contains("needs a knife")
		print("CARCASSTEST ", sp, " no tool -> ", tx)
		fails += 0 if ok else 1
		inv.add("axe")
		tx = _steps_texts()
		ok = tx.begins_with("Quarter") or tx.contains("Quarter")
		var m0 := inv.count(Carcass.SPECIES[sp]["meat"])
		_run_acts(["Quarter"])
		var half := inv.count(Carcass.SPECIES[sp]["meat"]) - m0
		ok = ok and half == int(ceil(float(Carcass.SPECIES[sp]["meat_n"]) * 0.5))
		print("CARCASSTEST ", sp, " hatchet half yield=", ok, " got ", half)
		fails += 0 if ok else 1
		inv.add("knife")
		tx = _steps_texts()
		ok = not tx.contains("Quarter") and tx.contains("Skin") and tx.contains("Gut")
		print("CARCASSTEST ", sp, " knife steps left=", ok, " ", tx)
		fails += 0 if ok else 1
		_run_acts(["Skin", "Gut", "Render"])
		var hid := inv.count(Carcass.SPECIES[sp]["hide"])
		ok = hid == 1 and inv.count("gut") >= 1 and inv.condition("knife") < 1.0
		await get_tree().process_frame
		await get_tree().process_frame
		ok = ok and (not is_instance_valid(w) or w.is_queued_for_deletion())
		print("CARCASSTEST ", sp, " fully butchered + carcass gone=", ok)
		fails += 0 if ok else 1
		inv.counts.erase("axe")
		inv.counts.erase("knife")
	var zpos := Vector3(pp.x - 3.0, tg.data.get_height(Vector3(pp.x - 3.0, 0, pp.z)), pp.z)
	var z: Zombie = world.call("_add_zombie", zpos, 900)
	z.hit(9999.0, pp)
	await get_tree().create_timer(0.6).timeout
	_tp(zpos.x + 1.2, zpos.z, zpos)
	await get_tree().create_timer(0.8).timeout
	var tx2 := _steps_texts()
	var ok2 := tx2.contains("Search body")
	print("CARCASSTEST zombie search prompt=", ok2)
	fails += 0 if ok2 else 1
	var w0 := 0
	for id in inv.counts.keys():
		w0 += int(inv.counts[id])
	var ex := Carcass.body_loot(int(zpos.x * 7.0) * 31 + int(zpos.z * 13.0))
	_run_acts(["Search body"])
	var w1 := 0
	for id in inv.counts.keys():
		w1 += int(inv.counts[id])
	var exn := 0
	for id in ex.keys():
		exn += int(ex[id])
	ok2 = (w1 - w0) == exn and z.get_meta("searched", false) and not _steps_texts().contains("Search body")
	print("CARCASSTEST zombie loot=", ok2, " expected ", ex, " got +", w1 - w0)
	fails += 0 if ok2 else 1
	# loot path with a body whose roll is non-empty
	var zp2 := zpos
	for i in range(1, 40):
		zp2 = Vector3(zpos.x + float(i) * 0.37, tg.data.get_height(Vector3(zpos.x + float(i) * 0.37, 0, zpos.z)), zpos.z)
		if not Carcass.body_loot(int(zp2.x * 7.0) * 31 + int(zp2.z * 13.0)).is_empty():
			break
	var z2: Zombie = world.call("_add_zombie", zp2, 901)
	z2.hit(9999.0, pp)
	await get_tree().create_timer(0.6).timeout
	var ex2 := Carcass.body_loot(int(z2.global_position.x * 7.0) * 31 + int(z2.global_position.z * 13.0))
	var before := inv.total_weight()
	world.call("_search_body", z2)
	ok2 = not ex2.is_empty() and inv.total_weight() > before and z2.get_meta("searched", false)
	print("CARCASSTEST zombie nonempty loot=", ok2, " ", ex2)
	fails += 0 if ok2 else 1
	print("CARCASSTEST failures=", fails)
	get_tree().quit()
