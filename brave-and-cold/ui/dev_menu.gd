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
	if "huntest=1" in ua:
		_huntest()
	if "gathertest=1" in ua:
		_gathertest()
	if "crafttest=1" in ua:
		_crafttest()
	if "weartest=1" in ua:
		_weartest()
	if "p6test=1" in ua:
		_p6test()
	if "zperf=1" in ua:
		_zperftest()


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
	for pr in [["rifle", 1], ["ammo", 40], ["axe", 1], ["knife", 1], ["cordage", 6], ["deer_hide", 2], ["bow_drill", 1], ["tinder", 3], ["kindling", 4], ["parka", 1], ["sweater", 1], ["matches", 8], ["wood", 10], ["beans", 4], ["flare", 3]]:
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


func _huntest() -> void:
	await get_tree().create_timer(2.5).timeout
	var fails := 0
	var tg: Terrain3D = world.get("terrain")
	var pp: Vector3 = player.position
	player.god = true
	# --- hit zones (deer faces -Z at yaw 0)
	var base := Vector3(pp.x + 12.0, tg.data.get_height(Vector3(pp.x + 12.0, 0, pp.z)), pp.z)
	var d1: Deer = world.call("_add_deer", base, 41)
	d1.rotation.y = 0.0
	var want := {"head": 2.5, "chest": 1.0, "hind": 0.35}
	for row: Array in HitZones.SPECS["deer"]:
		var c := HitZones.center_of(d1, row)
		var r := HitZones.ray(d1, c + Vector3(6, 0, 0), Vector3(-1, 0, 0), 50.0)
		var ok: bool = not r.is_empty() and r["zone"] == row[0] and absf(float(r["mult"]) - float(want[row[0]])) < 0.01
		print("HUNTEST zone ", row[0], "=", ok, " ", r)
		fails += 0 if ok else 1
	var miss := HitZones.ray(d1, d1.global_position + Vector3(6, 4.5, 0), Vector3(-1, 0, 0), 50.0)
	print("HUNTEST over-the-top miss=", miss.is_empty())
	fails += 0 if miss.is_empty() else 1
	d1.hit(9999.0, pp)
	# --- wounded deer bleeds out, leaves trail
	var b0 := get_tree().get_nodes_in_group("blood").size()
	var p2 := Vector3(pp.x - 20.0, tg.data.get_height(Vector3(pp.x - 20.0, 0, pp.z)), pp.z)
	var d2: Deer = world.call("_add_deer", p2, 42)
	d2.hit(35.0, Vector3(pp.x, 0, pp.z))
	var okb: bool = d2.bleed and d2.state == Deer.State.FLEE and d2.hp > 0.0
	print("HUNTEST wound bleeds=", okb)
	fails += 0 if okb else 1
	for i in range(30):
		await get_tree().create_timer(1.0).timeout
		if d2.is_dead():
			break
	var trail := get_tree().get_nodes_in_group("blood").size() - b0
	okb = d2.is_dead() and trail >= 4 and d2.is_in_group("carcasses")
	print("HUNTEST bleeds out dead=", d2.is_dead(), " blood decals=", trail)
	fails += 0 if okb else 1
	# --- scent
	var far := Vector3(pp.x + 150.0, 0, pp.z + 150.0)
	_tp(far.x, far.z)
	await get_tree().create_timer(1.0).timeout
	var cpos := Vector3(far.x + 40.0, tg.data.get_height(Vector3(far.x + 40.0, 0, far.z)), far.z)
	var carc: Deer = world.call("_add_deer", cpos, 43)
	carc.hit(9999.0, cpos)
	var wx := Vector3(cpos.x + 18.0, tg.data.get_height(Vector3(cpos.x + 18.0, 0, cpos.z)), cpos.z)
	var wu := Vector3(cpos.x - 30.0, tg.data.get_height(Vector3(cpos.x - 30.0, 0, cpos.z)), cpos.z)
	var w_down: Wolf = world.call("_add_wolf", wx, 50, false)
	var w_up: Wolf = world.call("_add_wolf", wu, 51, false)
	for i in range(5):
		Carcass.wind_dir = Vector2(1, 0)
		await get_tree().create_timer(1.0).timeout
	var ok2: bool = w_down._carcass == carc and w_down.state == Wolf.State.INVESTIGATE
	print("HUNTEST downwind wolf smells carcass=", ok2)
	fails += 0 if ok2 else 1
	ok2 = w_up._carcass == null
	print("HUNTEST upwind wolf does not=", ok2)
	fails += 0 if ok2 else 1
	var saved: Array = world.call("_carcass_list")
	var found := false
	for e in saved:
		if String(e["sp"]) == "deer" and absf(float(e["x"]) - cpos.x) < 1.0:
			found = true
	print("HUNTEST carcass in save list=", found)
	fails += 0 if found else 1
	for i in range(30):
		Carcass.wind_dir = Vector2(1, 0)
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(carc) or not Carcass.has_meat(carc):
			break
	ok2 = not is_instance_valid(carc) or not Carcass.has_meat(carc)
	print("HUNTEST wolf scavenged meat=", ok2)
	fails += 0 if ok2 else 1
	print("HUNTEST failures=", fails)
	get_tree().quit()


func _gathertest() -> void:
	await get_tree().create_timer(2.5).timeout
	var fails := 0
	var pf: PlantField = world.get("plants")
	var clock_ref = world.get("clock")
	world.call("_ensure_gear")
	var inv: Inventory = world.get("inv")
	inv.counts.erase("knife")
	inv.counts.erase("axe")
	var ok: bool = pf != null
	print("GATHERTEST counts=", pf.counts if pf != null else {})
	for kind: String in PlantField.KINDS.keys():
		ok = ok and int(pf.counts.get(kind, 0)) > 0
	print("GATHERTEST all kinds present=", ok)
	fails += 0 if ok else 1
	for kind: String in PlantField.KINDS.keys():
		var key := pf.first_of(kind)
		if key == "":
			fails += 1
			print("GATHERTEST no ", kind)
			continue
		var pp := pf.pos_of(key)
		_tp(pp.x, pp.z + 1.2, pp)
		await get_tree().create_timer(1.0).timeout
		if "plantshot=1" in OS.get_cmdline_user_args():
			_tp(pp.x, pp.z + 2.4, pp)
			player.pitch = deg_to_rad(-14.0)
			await get_tree().create_timer(1.0).timeout
			get_viewport().get_texture().get_image().save_png("user://plant_%s.png" % kind)
			print("PLANTSHOT ", kind)
			_tp(pp.x, pp.z + 1.2, pp)
			await get_tree().create_timer(0.5).timeout
		var kd: Dictionary = PlantField.KINDS[kind]
		var iid: String = kd["item"]
		var n0 := inv.count(iid)
		world.call("_update_prompt")
		var cand := {}
		for c in world.get("_cands_cache"):
			if String(c["text"]).begins_with("Gather"):
				cand = c
				break
		var okp: bool = not cand.is_empty()
		if okp:
			okp = absf(float(cand["hold"]) - float(kd["hold"])) < 0.01
			(cand["act"] as Callable).call()
		var got := inv.count(iid) - n0
		okp = okp and got == int(kd["n"]) and pf.picked.has(key) and pf.is_hidden(key)
		print("GATHERTEST ", kind, " gather=", okp, " got ", got, " cand ", cand.get("text", "none"))
		fails += 0 if okp else 1
		world.call("_update_prompt")
		var again := false
		for c in world.get("_cands_cache"):
			if String(c["text"]).begins_with("Gather") and String(c["text"]).contains(String(kd["label"])):
				again = true
		print("GATHERTEST ", kind, " not offered again=", not again)
		fails += 1 if again else 0
		if kind == "reed":
			inv.add("knife")
			var key2 := ""
			for kk in pf._plants.keys():
				if pf._plants[kk]["kind"] == "reed" and not pf.picked.has(kk) and kk != key:
					key2 = kk
					break
			var p2 := pf.pos_of(key2)
			_tp(p2.x, p2.z + 1.2, p2)
			await get_tree().create_timer(1.0).timeout
			world.call("_update_prompt")
			var kh := -1.0
			for c in world.get("_cands_cache"):
				if String(c["text"]).begins_with("Gather"):
					kh = float(c["hold"])
			print("GATHERTEST reed knife hold=", kh)
			fails += 0 if absf(kh - 2.0) < 0.01 else 1
			inv.counts.erase("knife")
	var saved: Dictionary = pf.picked.duplicate()
	var any_key: String = saved.keys()[0]
	pf.update_regrow(float(clock_ref.total_game_s) + 200.0 * 3600.0)
	var okr: bool = pf.picked.is_empty() and not pf.is_hidden(any_key)
	print("GATHERTEST regrow=", okr)
	fails += 0 if okr else 1
	pf.apply_picked(saved)
	okr = pf.picked.size() == saved.size() and pf.is_hidden(any_key)
	print("GATHERTEST save/restore picked=", okr)
	fails += 0 if okr else 1
	print("GATHERTEST failures=", fails)
	get_tree().quit()


func _craft_run(secs: float) -> void:
	var t := 0.0
	while t < secs + 0.2:
		world.call("_craft_update", 0.1)
		t += 0.1


func _crafttest() -> void:
	await get_tree().create_timer(2.5).timeout
	var fails := 0
	world.call("_ensure_gear")
	var inv: Inventory = world.get("inv")
	player.god = false
	var bad := RecipeDB.validate()
	var ok: bool = RecipeDB.all().size() >= 8 and bad.is_empty()
	print("CRAFTTEST recipes=", RecipeDB.all().size(), " bad refs=", bad, " ok=", ok)
	fails += 0 if ok else 1
	# insufficient inputs
	inv.counts.erase("reed")
	inv.add("reed", 2)
	var why: String = world.call("craft_start", "cordage_reed")
	ok = why != "" and (world.get("craft_job") as Dictionary).is_empty()
	print("CRAFTTEST blocked w/o inputs=", ok, " ", why)
	fails += 0 if ok else 1
	inv.add("reed", 1)
	why = world.call("craft_start", "cordage_reed")
	ok = why == "" and not (world.get("craft_job") as Dictionary).is_empty()
	fails += 0 if ok else 1
	var c0 := inv.count("cordage")
	_craft_run(7.0)
	ok = inv.count("cordage") == c0 and not (world.get("craft_job") as Dictionary).is_empty()
	print("CRAFTTEST not done early=", ok)
	fails += 0 if ok else 1
	_craft_run(2.0)
	ok = inv.count("cordage") == c0 + 1 and inv.count("reed") == 0 and (world.get("craft_job") as Dictionary).is_empty()
	print("CRAFTTEST cordage from reed=", ok)
	fails += 0 if ok else 1
	# tool requirement + wear
	inv.counts.erase("knife")
	inv.cond.erase("knife")
	inv.add("gut", 1)
	why = world.call("craft_start", "cordage_gut")
	ok = why.contains("Knife")
	print("CRAFTTEST tool required=", ok, " ", why)
	fails += 0 if ok else 1
	inv.add("knife", 1)
	c0 = inv.count("cordage")
	world.call("craft_start", "cordage_gut")
	_craft_run(7.0)
	ok = inv.count("cordage") == c0 + 2 and inv.condition("knife") < 1.0
	print("CRAFTTEST gut cordage + knife wear=", ok)
	fails += 0 if ok else 1
	# interruption by damage keeps inputs
	inv.add("reed", 3)
	world.call("craft_start", "cordage_reed")
	_craft_run(1.0)
	var god0 := player.god
	player.god = false
	player.hurt(4.0, "test")
	_craft_run(0.3)
	ok = (world.get("craft_job") as Dictionary).is_empty() and inv.count("reed") == 3
	player.god = god0
	print("CRAFTTEST interrupt keeps inputs=", ok)
	fails += 0 if ok else 1
	# station recipe
	inv.add("venison_raw", 2)
	why = world.call("craft_start", "dry_meat")
	ok = why.contains("fire")
	print("CRAFTTEST fire station required=", ok, " ", why)
	fails += 0 if ok else 1
	# kindling + sticks
	inv.counts.erase("stick")
	inv.counts.erase("thatch")
	inv.counts.erase("kindling")
	inv.add("stick", 3)
	inv.add("thatch", 1)
	world.call("craft_start", "kindling")
	_craft_run(5.5)
	ok = inv.count("kindling") == 2 and inv.count("stick") == 0 and inv.count("thatch") == 0
	print("CRAFTTEST kindling=", ok)
	fails += 0 if ok else 1
	# campfire: kindling variant with a match
	inv.counts.erase("wood")
	inv.counts.erase("matches")
	inv.add("wood", 1)
	inv.add("matches", 1)
	var fires: Array = world.get("campfires")
	var f0 := fires.size()
	world.call("_build_campfire")
	ok = fires.size() == f0 + 1 and inv.count("wood") == 0 and inv.count("kindling") == 0 and inv.count("matches") == 0
	var cf: Campfire = fires[fires.size() - 1]
	ok = ok and absf(cf.fuel_s - Campfire.LOG_BURN_S * 2.0) < 1.0
	print("CRAFTTEST campfire 1 wood + 2 kindling + match=", ok, " fuel ", cf.fuel_s)
	fails += 0 if ok else 1
	# bow drill: success + failure (move so the site is free)
	for attempt in ["fail", "ok"]:
		_tp(player.position.x + 6.0, player.position.z, Vector3.INF)
		await get_tree().create_timer(0.8).timeout
		inv.counts.erase("wood")
		inv.counts.erase("matches")
		inv.counts.erase("tinder")
		inv.add("wood", 2)
		inv.add("tinder", 1)
		inv.counts.erase("bow_drill")
		inv.cond.erase("bow_drill")
		inv.add("bow_drill", 1)
		world.set("drill_chance", 0.0 if attempt == "fail" else 1.0)
		var n0 := fires.size()
		world.call("_build_campfire")
		for i in range(130):
			world.call("_act_update", 0.1, true)
		var built := fires.size() - n0
		if attempt == "fail":
			ok = built == 0 and inv.count("tinder") == 0 and inv.count("wood") == 2 and inv.condition("bow_drill") < 1.0
		else:
			ok = built == 1 and inv.count("tinder") == 0 and inv.count("wood") == 0 and inv.condition("bow_drill") < 1.0
		print("CRAFTTEST bow drill ", attempt, "=", ok)
		fails += 0 if ok else 1
	world.set("drill_chance", 0.7)
	# timed cooking at the fire just built
	var cf2: Campfire = fires[fires.size() - 1]
	_tp(cf2.global_position.x + 1.0, cf2.global_position.z, cf2.global_position)
	await get_tree().create_timer(0.8).timeout
	inv.counts.erase("venison_raw")
	inv.counts.erase("venison_cooked")
	inv.add("venison_raw", 2)
	var started: int = world.call("_cook_start", cf2)
	ok = started == 2 and inv.count("venison_raw") == 0 and cf2.cooking_count() == 2
	print("CRAFTTEST cook starts=", ok)
	fails += 0 if ok else 1
	cf2.advance(600.0)
	ok = cf2.cooking_count() == 2 and cf2.done_count() == 0
	cf2.advance(700.0)
	ok = ok and cf2.done_count() == 2
	print("CRAFTTEST cook timing=", ok)
	fails += 0 if ok else 1
	world.call("_take_cooked", cf2)
	ok = inv.count("venison_cooked") == 2 and cf2.cooking.is_empty()
	print("CRAFTTEST take cooked=", ok)
	fails += 0 if ok else 1
	# dry meat with fire nearby (fire still lit? relight)
	cf2.fuel_s = 3000.0
	inv.add("venison_raw", 2)
	world.call("_update_prompt")
	var jr: String = world.call("craft_start", "dry_meat")
	_craft_run(21.0)
	ok = jr == "" and inv.count("jerky") == 2 and inv.count("venison_raw") == 0
	print("CRAFTTEST dry meat at fire=", ok, " ", jr)
	fails += 0 if ok else 1
	# save list includes cooking
	cf2.start_cook("venison_cooked")
	var found := false
	var gw = world
	var data: Array = []
	for cfx in fires:
		data.append({"cook": cfx.cooking})
	found = (data[data.size() - 1]["cook"] as Array).size() == 1
	print("CRAFTTEST cooking state present for save=", found)
	fails += 0 if found else 1
	print("CRAFTTEST failures=", fails)
	get_tree().quit()


func _weartest() -> void:
	await get_tree().create_timer(2.5).timeout
	var fails := 0
	world.call("_ensure_gear")
	var inv: Inventory = world.get("inv")
	var body: BodyTemperature = world.get("body")
	player.god = false
	for id in inv.worn_list():
		inv.use(String(id))
	var ok := is_equal_approx(body.warmth, 0.25) and is_equal_approx(body.windproof, 0.1) and inv.worn_list().is_empty()
	print("WEARTEST bare invariant=", ok)
	fails += 0 if ok else 1
	# recipes validate
	var bad := RecipeDB.validate()
	ok = RecipeDB.all().size() >= 18 and bad.is_empty()
	print("WEARTEST recipes=", RecipeDB.all().size(), " bad=", bad, " ok=", ok)
	fails += 0 if ok else 1
	# head slot adds on top of base
	inv.add("toque")
	inv.use("toque")
	ok = is_equal_approx(body.warmth, 0.33) and inv.extra.get("head", "") == "toque" and inv.equipped_body == ""
	print("WEARTEST toque on base warmth=", body.warmth, " ", ok)
	fails += 0 if ok else 1
	# worn item leaves its pack cell
	var cells0 := inv.slots_used()
	ok = inv.stacks().filter(func(s) -> bool: return s["id"] == "toque").is_empty() and cells0 >= 0
	print("WEARTEST worn leaves pack=", ok)
	fails += 0 if ok else 1
	# stacking with parka
	inv.add("parka")
	inv.use("parka")
	ok = is_equal_approx(body.warmth, 0.93) and inv.worn_list() == ["parka", "toque"]
	print("WEARTEST parka+toque=", body.warmth, " ", inv.worn_list(), " ", ok)
	fails += 0 if ok else 1
	# cap
	for id in ["hide_boots", "hide_leggings", "hide_mitts", "wolf_hat"]:
		inv.add(id)
		inv.use(id)
	ok = body.warmth <= 0.97 + 0.0001 and body.windproof <= 0.95 + 0.0001 and body.waterproof <= 0.95 + 0.0001 and inv.extra.size() == 4
	print("WEARTEST capped warmth=", body.warmth, " wind=", body.windproof, " water=", body.waterproof, " ", ok)
	fails += 0 if ok else 1
	# same slot replaces
	ok = inv.extra["head"] == "wolf_hat"
	print("WEARTEST slot replace=", ok)
	fails += 0 if ok else 1
	# take off one
	inv.use("hide_boots")
	ok = not inv.extra.has("feet") and inv.is_worn("wolf_hat") and not inv.is_worn("hide_boots")
	print("WEARTEST take off=", ok)
	fails += 0 if ok else 1
	# drop worn item: unequips
	world.call("drop_item", "hide_leggings", 1)
	ok = not inv.extra.has("legs") and inv.count("hide_leggings") == 0
	print("WEARTEST drop worn=", ok)
	fails += 0 if ok else 1
	# remove() of a worn extra clears it
	inv.remove("hide_mitts", 1)
	ok = not inv.extra.has("hands")
	print("WEARTEST remove clears slot=", ok)
	fails += 0 if ok else 1
	# bear coat replaces torso
	inv.add("bear_coat")
	inv.use("bear_coat")
	ok = inv.equipped_body == "bear_coat" and not inv.is_worn("parka")
	print("WEARTEST torso swap=", ok)
	fails += 0 if ok else 1
	# strip back to bare
	for id in inv.worn_list():
		inv.use(String(id))
	ok = is_equal_approx(body.warmth, 0.25) and inv.worn_list().is_empty()
	print("WEARTEST bare again=", ok, " ", body.warmth)
	fails += 0 if ok else 1
	# slot_of / drag-target logic
	ok = Inventory.slot_of("hide_cap") == "head" and Inventory.slot_of("hide_boots") == "feet" and Inventory.slot_of("beans") == ""
	print("WEARTEST slot_of=", ok)
	fails += 0 if ok else 1
	# cure + sew chain at a fire
	inv.counts.erase("deer_hide")
	inv.counts.erase("cordage")
	inv.counts.erase("knife")
	inv.cond.erase("knife")
	inv.add("knife")
	inv.add("deer_hide", 2)
	inv.add("cordage", 6)
	var why: String = world.call("craft_start", "cure_hide")
	ok = why.contains("fire")
	print("WEARTEST cure needs fire=", ok, " ", why)
	fails += 0 if ok else 1
	var fires: Array = world.get("campfires")
	var cf: Campfire = fires[0] if fires.size() > 0 else null
	if cf == null:
		inv.counts.erase("wood")
		inv.counts.erase("matches")
		inv.add("wood", 2)
		inv.add("matches", 1)
		world.call("_build_campfire")
		cf = fires[fires.size() - 1]
	_tp(cf.global_position.x + 1.0, cf.global_position.z, cf.global_position)
	await get_tree().create_timer(0.8).timeout
	cf.fuel_s = 3000.0
	world.call("_update_prompt")
	why = world.call("craft_start", "cure_hide")
	_craft_run(26.0)
	ok = why == "" and inv.count("cured_hide") == 1 and inv.count("deer_hide") == 1
	print("WEARTEST cure hide=", ok, " ", why)
	fails += 0 if ok else 1
	world.call("_update_prompt")
	why = world.call("craft_start", "cure_hide")
	_craft_run(26.0)
	ok = inv.count("cured_hide") == 2 and inv.count("deer_hide") == 0
	print("WEARTEST cure 2nd=", ok, " ", why, " near=", world.call("_near_fire"))
	fails += 0 if ok else 1
	var hb0 := inv.count("hide_boots")
	world.call("_update_prompt")
	why = world.call("craft_start", "hide_boots")
	_craft_run(26.0)
	ok = inv.count("hide_boots") == hb0 + 1 and inv.count("cured_hide") == 0 and inv.count("cordage") == 4
	print("WEARTEST sew boots=", ok, " ", why, " hide=", inv.count("cured_hide"), " cord=", inv.count("cordage"), " near=", world.call("_near_fire"))
	fails += 0 if ok else 1
	inv.use("hide_boots")
	ok = inv.extra.get("feet", "") == "hide_boots" and body.warmth > 0.25
	print("WEARTEST wear sewn boots=", ok)
	fails += 0 if ok else 1
	# wolf + bear pelts
	var wh0 := inv.count("wolf_hat")
	var bc0 := inv.count("bear_coat")
	inv.add("wolf_pelt")
	inv.add("bear_pelt")
	world.call("craft_start", "cure_wolf")
	_craft_run(26.0)
	world.call("craft_start", "wolf_hat")
	_craft_run(19.0)
	ok = inv.count("wolf_hat") == wh0 + 1 and inv.count("wolf_fur") == 0
	print("WEARTEST wolf pelt -> hat=", ok)
	fails += 0 if ok else 1
	inv.add("cordage", 1)
	world.call("craft_start", "cure_bear")
	_craft_run(41.0)
	world.call("craft_start", "bear_coat")
	_craft_run(41.0)
	ok = inv.count("bear_coat") == bc0 + 1 and inv.count("bear_fur") == 0 and inv.count("cordage") == 0
	print("WEARTEST bear pelt -> coat=", ok, " cordage=", inv.count("cordage"))
	fails += 0 if ok else 1
	# save/restore of extras via the world save dictionary shape
	inv.use("wolf_hat")
	var snap: Dictionary = inv.extra.duplicate()
	ok = snap.size() == 2 and snap["head"] == "wolf_hat"
	print("WEARTEST extra snapshot=", ok)
	fails += 0 if ok else 1
	print("WEARTEST failures=", fails)
	get_tree().quit()


func _p6test() -> void:
	await get_tree().create_timer(2.5).timeout
	var fails := 0
	world.call("_ensure_gear")
	var inv: Inventory = world.get("inv")
	var needs: Needs = world.get("needs")
	player.god = false
	for id in ["chop", "crash", "rustle", "slice"]:
		var st: AudioStreamWAV = Sfx.get_stream(id)
		var ok: bool = st != null and st.data.size() > 2000
		print("P6TEST sfx ", id, "=", ok, " bytes=", st.data.size())
		fails += 0 if ok else 1
	var ok2: bool = inv.freshness("beans") == 1.0 and Inventory.shelf_s("jerky") == 0.0 and Inventory.shelf_s("venison_raw") > 0.0
	print("P6TEST perishable table=", ok2)
	fails += 0 if ok2 else 1
	# raw meat: fresh at 29 h, rotten after 31 h
	inv.counts.erase("venison_raw")
	inv.age.erase("venison_raw")
	inv.add("venison_raw", 2)
	var sp: Array = inv.tick(29.0 * 3600.0)
	ok2 = sp.is_empty() and inv.count("venison_raw") == 2 and inv.freshness("venison_raw") < 0.1
	print("P6TEST raw fresh at 29h=", ok2, " fr=", inv.freshness("venison_raw"))
	fails += 0 if ok2 else 1
	sp = inv.tick(2.0 * 3600.0)
	ok2 = sp.size() == 1 and inv.count("venison_raw") == 0 and inv.count("rotten_meat") >= 2 and not inv.age.has("venison_raw")
	print("P6TEST raw rots at 31h=", ok2, " ", sp)
	fails += 0 if ok2 else 1
	# mixed stack averages age
	inv.counts.erase("wolf_meat_raw")
	inv.age.erase("wolf_meat_raw")
	inv.add("wolf_meat_raw", 1)
	inv.tick(10.0 * 3600.0)
	inv.add("wolf_meat_raw", 1)
	ok2 = absf(float(inv.age["wolf_meat_raw"]) - 5.0 * 3600.0) < 900.0
	print("P6TEST stack age average=", ok2, " age_h=", float(inv.age["wolf_meat_raw"]) / 3600.0)
	fails += 0 if ok2 else 1
	# cooked lasts longer; jerky never rots
	inv.counts.erase("bear_meat_cooked")
	inv.age.erase("bear_meat_cooked")
	inv.add("bear_meat_cooked", 1)
	inv.add("jerky", 2)
	sp = inv.tick(71.0 * 3600.0)
	ok2 = inv.count("bear_meat_cooked") == 1 and inv.count("jerky") == 2
	print("P6TEST cooked fine at 71h, jerky fine=", ok2)
	fails += 0 if ok2 else 1
	sp = inv.tick(2.0 * 3600.0)
	ok2 = inv.count("bear_meat_cooked") == 0 and inv.count("jerky") == 2 and not inv.age.has("jerky")
	print("P6TEST cooked rots at 73h, jerky still fine=", ok2)
	fails += 0 if ok2 else 1
	# rotten meat is not food
	var k0 := needs.calories
	var msg := inv.use("rotten_meat")
	ok2 = needs.calories <= k0 + 1.0 and inv.count("rotten_meat") > 0 and not msg.begins_with("Ate")
	print("P6TEST rotten not edible=", ok2, " ", msg)
	fails += 0 if ok2 else 1
	# cooking resets age (cooked is a new item)
	inv.counts.erase("venison_raw")
	inv.counts.erase("venison_cooked")
	inv.age.erase("venison_raw")
	inv.add("venison_raw", 1)
	inv.tick(20.0 * 3600.0)
	inv.cook_all()
	ok2 = inv.count("venison_cooked") == 1 and not inv.age.has("venison_raw") and inv.freshness("venison_cooked") > 0.95
	print("P6TEST cook resets=", ok2)
	fails += 0 if ok2 else 1
	# weight readout inputs sane
	ok2 = inv.total_weight() > 0.0 and inv.total_weight() < Inventory.WEIGHT_HARD + 20.0
	print("P6TEST weight=", inv.total_weight(), " ", ok2)
	fails += 0 if ok2 else 1
	print("P6TEST failures=", fails)
	get_tree().quit()


## Benchmark: wall-clock frame times (Performance.TIME_PROCESS only refreshes ~1 Hz, so it is useless per frame).
## Engine.max_fps is lifted so the loop runs as fast as the work allows. Returns [mean, median, p95, max] ms.
func _zp_sample(frames: int) -> Array:
	var v: Array = []
	await get_tree().process_frame
	var last := Time.get_ticks_usec()
	for k in range(frames):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		v.append(float(now - last) / 1000.0)
		last = now
	var sum := 0.0
	for x in v:
		sum += float(x)
	v.sort()
	return [sum / float(v.size()), float(v[v.size() / 2]), float(v[int(v.size() * 0.95)]), float(v[v.size() - 1])]


func _zp_spawn(zs: Array, n: int, rmin: float, rspan: float, base: Vector3, seed0: int) -> void:
	var terr: Terrain3D = world.get("terrain")
	while zs.size() < n:
		var i := zs.size()
		var a := float(i) * 2.399963
		var r := rmin + rspan * sqrt(float(i + 1) / float(maxi(n, 1)))
		var x := base.x + cos(a) * r
		var zz := base.z + sin(a) * r
		var h: float = terr.data.get_height(Vector3(x, 0.0, zz))
		if is_nan(h):
			h = base.y - 1.6
		var nz: Zombie = world.call("_add_zombie", Vector3(x, h, zz), seed0 + i)
		nz.hit(0.0001, base)


func _zp_clear(zs: Array) -> void:
	for z in zs:
		if is_instance_valid(z):
			z.queue_free()
	zs.clear()
	await get_tree().process_frame


func _zperftest() -> void:
	await get_tree().create_timer(3.0).timeout
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	player.god = true
	var zs: Array = world.get("zombies")
	await _zp_clear(zs)
	var base: Vector3 = player.position
	var s0: Array = await _zp_sample(300)
	var b0: float = s0[0]
	print("ZPERF baseline n=0 mean=%.2f med=%.2f p95=%.2f max=%.2f" % [s0[0], s0[1], s0[2], s0[3]])
	for n: int in [100, 400, 800, 1600]:
		_zp_spawn(zs, n, 4.0, 46.0, base, 700)
		await get_tree().create_timer(1.5).timeout
		var s: Array = await _zp_sample(300)
		print("ZPERF spread n=", n, " mean=%.2f med=%.2f p95=%.2f max=%.2f  us_per_zombie=%.1f" % [s[0], s[1], s[2], s[3], (s[0] - b0) * 1000.0 / float(n)])
	for n: int in [40, 160, 400]:
		await _zp_clear(zs)
		_zp_spawn(zs, n, 6.0, 9.0, base, 800)
		var s1: Array = await _zp_sample(60)
		var s2: Array = await _zp_sample(240)
		print("ZPERF near n=", n, " approach mean=%.2f med=%.2f max=%.2f | piled mean=%.2f med=%.2f max=%.2f  us_per_zombie(approach)=%.1f" % [s1[0], s1[1], s1[3], s2[0], s2[1], s2[3], (s1[0] - b0) * 1000.0 / float(n)])
	print("ZPERF done")
	get_tree().quit()
