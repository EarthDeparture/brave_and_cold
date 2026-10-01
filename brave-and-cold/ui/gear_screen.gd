class_name GearScreen
extends CanvasLayer
## DayZ-mod style Gear screen (Tab). Real-time: the world keeps running while it is open.
##  - Backpack: 24 cells, one stack per cell (stack sizes differ per item), sorted by kind.
##  - Equipment: BODY (clothing), PRIMARY (rifle), TOOL (hatchet). Worn / held items leave the pack cells.
##  - Nearby: items lying within 3.5 m; click or drag them into the pack to take them.
##  - Click selects, double-click = default action, right-click = option menu, drag to move / drop / wear.

const VW := 1600.0
const VH := 900.0
const PANEL_R := Rect2(110, 60, 1380, 780)
const CELL := 96.0
const GAP := 8.0
const COLS := 8
const PACK_O := Vector2(520, 196)
const GROUND_O := Vector2(520, 560)
const GROUND_N := 8
const NEAR_R := 3.5
const DOUBLE_S := 0.35

var world: Node
var inv: Inventory
var player: Player
var needs: Needs
var body: BodyTemperature
var clock: GameClock
var hud: Hud

var is_open := false

var _c: Control
var _hits: Array = []
var _mouse := Vector2.ZERO          # virtual coords
var _sel: Dictionary = {}           # {id, from, slot?, node?}
var _press: Dictionary = {}
var _drag: Dictionary = {}
var _dragging := false
var _menu: Dictionary = {}          # {pos, entries}
var _last_click_t := -10.0
var _last_click_key := ""
var _prev_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _time := 0.0
var _craft_mode := false


func setup(w: Node, i: Inventory, p: Player, n: Needs, b: BodyTemperature, c: GameClock, h: Hud) -> void:
	world = w
	inv = i
	player = p
	needs = n
	body = b
	clock = c
	hud = h
	layer = 20
	visible = false
	if _c != null:
		return
	_c = Control.new()
	_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_STOP
	_c.draw.connect(_draw_all)
	_c.gui_input.connect(_on_gui)
	add_child(_c)


# ------------------------------------------------------------ open / close

func open() -> void:
	if is_open or player.dead or player.struggling:
		return
	is_open = true
	visible = true
	hud.hide_ui = true
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.ui_open = true
	_sel = {}
	_menu = {}
	_drag = {}
	_dragging = false


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	hud.hide_ui = false
	player.ui_open = false
	_menu = {}
	_dragging = false
	Input.mouse_mode = _prev_mouse_mode


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo or get_tree().paused:
		return
	if e.keycode == KEY_TAB:
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and e.keycode == KEY_ESCAPE:
		if not _menu.is_empty():
			_menu = {}
		else:
			close()
		get_viewport().set_input_as_handled()
	elif is_open:
		get_viewport().set_input_as_handled()   # no gameplay keys while the screen is up


func _process(delta: float) -> void:
	if not is_open:
		return
	_time += delta
	if player.dead or player.struggling:
		close()
		return
	_validate_sel()
	_c.queue_redraw()


# ------------------------------------------------------------ helpers

func _scale() -> float:
	var sz := _c.size
	return minf(sz.x / VW, sz.y / VH)


func _origin() -> Vector2:
	return (_c.size - Vector2(VW, VH) * _scale()) * 0.5


func _to_v(p: Vector2) -> Vector2:
	return (p - _origin()) / _scale()


func _nearby() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("pickups"):
		var p := n as ItemPickup
		if p == null:
			continue
		var d := Vector2(p.global_position.x - player.position.x, p.global_position.z - player.position.z).length()
		if d <= NEAR_R:
			out.append({"d": d, "node": p})
	out.sort_custom(func(a, b) -> bool: return a["d"] < b["d"])
	return out.slice(0, GROUND_N)


func _pack_rect(i: int) -> Rect2:
	return Rect2(PACK_O + Vector2((i % COLS) * (CELL + GAP), (i / COLS) * (CELL + GAP)), Vector2(CELL, CELL))


func _ground_rect(i: int) -> Rect2:
	return Rect2(GROUND_O + Vector2(i * (CELL + GAP), 0), Vector2(CELL, CELL))


func _slot_rect(slot: String) -> Rect2:
	var i := {"body": 0, "primary": 1, "tool": 2}[slot] as int
	return Rect2(Vector2(140 + i * 112, 196), Vector2(CELL, CELL))


func _slot_item(slot: String) -> String:
	match slot:
		"body":
			return inv.equipped_body
		"primary":
			return "rifle" if inv.count("rifle") > 0 else ""
		"tool":
			return "axe" if inv.count("axe") > 0 else ""
	return ""


func _in_hand(slot: String) -> bool:
	if slot == "primary":
		return world.rifle_up and inv.count("rifle") > 0
	if slot == "tool":
		return (not world.rifle_up or inv.count("rifle") == 0) and inv.count("axe") > 0
	return false


func _validate_sel() -> void:
	if _sel.is_empty():
		return
	var id: String = _sel["id"]
	var from: String = _sel["from"]
	var ok := false
	match from:
		"pack":
			ok = inv.count(id) - (1 if id == inv.equipped_body else 0) > 0
		"equip":
			ok = _slot_item(_sel["slot"]) == id
		"ground":
			ok = is_instance_valid(_sel.get("node")) and not (_sel["node"] as Node).is_queued_for_deletion()
	if not ok:
		_sel = {}


func _is_sel(id: String, from: String, slot: String = "", node: Node = null) -> bool:
	if _sel.is_empty() or _sel["id"] != id or _sel["from"] != from:
		return false
	if from == "equip":
		return _sel["slot"] == slot
	if from == "ground":
		return _sel.get("node") == node
	return true


# ------------------------------------------------------------ actions

func _entries(id: String, from: String, n: int, node: Node = null) -> Array:
	var out: Array = []
	var kind := Inventory.kind_of(id)
	if from == "ground":
		out.append({"label": "Take", "act": func() -> void: _take(node)})
		return out
	match kind:
		"food":
			out.append({"label": "Eat", "act": func() -> void: world.gear_use(id)})
		"clothing":
			var worn: bool = inv.equipped_body == id
			out.append({"label": "Take off" if worn else "Wear", "act": func() -> void: world.gear_use(id)})
		"tool":
			if id == "flare":
				out.append({"label": "Light flare", "act": func() -> void: world.gear_use(id)})
			elif id == "axe":
				out.append({"label": "Hold hatchet", "act": func() -> void: world.gear_hands(false)})
		"weapon":
			var up: bool = world.rifle_up
			out.append({"label": "Lower rifle" if up else "Raise rifle", "act": func() -> void: world.gear_hands(not up)})
	if inv.count(id) - (1 if from == "pack" and id == inv.equipped_body else 0) >= 1 or from == "equip":
		out.append({"label": "Drop one" if n > 1 else "Drop", "act": func() -> void: world.drop_item(id, 1)})
		if n > 1:
			out.append({"label": "Drop all (%d)" % n, "act": func() -> void: world.drop_item(id, n)})
	return out


func _take(node: Node) -> void:
	if is_instance_valid(node):
		world.take_pickup(node)


func _primary(id: String, from: String, n: int, node: Node) -> void:
	var e := _entries(id, from, n, node)
	if not e.is_empty():
		(e[0]["act"] as Callable).call()


func _tk(h: Dictionary) -> String:
	if h.is_empty():
		return "blank" if PANEL_R.has_point(_mouse) else "drop"
	var k: String = h["k"]
	return "drop" if (k == "dropzone" or k == "ground") else k


func _drop_on(target: Dictionary) -> void:
	# resolve a drag release
	var id: String = _drag["id"]
	var from: String = _drag["from"]
	var n: int = _drag.get("n", 1)
	var tk := _tk(target)
	var to_ground := tk == "drop"
	match from:
		"pack":
			if tk == "equip" and target["slot"] == "body" and Inventory.kind_of(id) == "clothing" and inv.equipped_body != id:
				world.gear_use(id)
			elif to_ground:
				world.drop_item(id, n)
		"equip":
			var slot: String = _drag["slot"]
			if slot == "body":
				if tk == "pack":
					world.gear_use(id)   # take off
				elif to_ground:
					world.drop_item(id, 1)
			else:
				if tk == "equip" and target["slot"] != slot:
					world.gear_hands(target["slot"] == "primary")
				elif to_ground:
					world.drop_item(id, 1)
		"ground":
			if tk == "pack" or (tk == "equip" and target["slot"] == "body"):
				_take(_drag["node"])
				if tk == "equip" and Inventory.kind_of(id) == "clothing":
					world.gear_use(id)


# ------------------------------------------------------------ input

func _hit_at(v: Vector2) -> Dictionary:
	for i in range(_hits.size() - 1, -1, -1):
		if (_hits[i]["r"] as Rect2).has_point(v):
			return _hits[i]
	return {}


func _on_gui(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_mouse = _to_v(e.position)
		if not _press.is_empty() and not _dragging and (_mouse - _press["v"]).length() > 8.0:
			_dragging = true
			_drag = _press
			_menu = {}
		return
	if not (e is InputEventMouseButton):
		return
	_mouse = _to_v(e.position)
	var h := _hit_at(_mouse)
	if e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		if not _menu.is_empty():
			if h.get("k", "") == "menu":
				(h["act"] as Callable).call()
			_menu = {}
			return
		var k: String = h.get("k", "")
		if k == "btn":
			(h["act"] as Callable).call()
		elif k in ["pack", "equip", "ground"] and h.get("id", "") != "":
			_sel = {"id": h["id"], "from": k, "slot": h.get("slot", ""), "node": h.get("node"), "n": h.get("n", 1)}
			_press = {"id": h["id"], "from": k, "slot": h.get("slot", ""), "node": h.get("node"), "n": h.get("n", 1), "v": _mouse}
			var key := "%s/%s/%d" % [k, h["id"], h.get("idx", 0)]
			var now := Time.get_ticks_msec() / 1000.0
			if key == _last_click_key and now - _last_click_t < DOUBLE_S:
				_primary(h["id"], k, h.get("n", 1), h.get("node"))
				_press = {}
				_last_click_key = ""
			else:
				_last_click_key = key
				_last_click_t = now
		else:
			_sel = {}
	elif e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		if _dragging:
			_drop_on(h)
		_dragging = false
		_press = {}
		_drag = {}
	elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
		var k2: String = h.get("k", "")
		if k2 in ["pack", "equip", "ground"] and h.get("id", "") != "":
			_sel = {"id": h["id"], "from": k2, "slot": h.get("slot", ""), "node": h.get("node"), "n": h.get("n", 1)}
			_menu = {"pos": _mouse, "entries": _entries(h["id"], k2, h.get("n", 1), h.get("node"))}
		else:
			_menu = {}


# ------------------------------------------------------------ drawing

func _draw_all() -> void:
	if inv == null:
		return
	_hits.clear()
	_hits.append({"k": "dropzone", "r": Rect2(GROUND_O - Vector2(8, 34), Vector2(GROUND_N * (CELL + GAP) + 8, CELL + 50))})
	var s := _scale()
	_c.draw_rect(Rect2(Vector2.ZERO, _c.size), Color(0.0, 0.0, 0.0, 0.58))
	_c.draw_set_transform(_origin(), 0.0, Vector2(s, s))
	DZ.panel(_c, PANEL_R)
	DZ.text(_c, "GEAR", Vector2(140, 122), 34, DZ.TEXT)
	DZ.text(_c, "Tab / Esc: close     click: select     double-click: use     right-click: options     drag: move, wear, drop", Vector2(140, 812), 15, DZ.DIM)
	_draw_equipment()
	_draw_condition()
	_draw_pack()
	_draw_tab_button()
	if _craft_mode:
		_draw_craft()
	else:
		_draw_ground()
		_draw_info()
	if _dragging:
		_draw_drag()
	elif not _menu.is_empty():
		_draw_menu()
	else:
		_draw_tooltip()
	_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_tab_button() -> void:
	var br := Rect2(Vector2(1230, 84), Vector2(230, 40))
	var hv := br.has_point(_mouse)
	_c.draw_rect(br, Color(0.16, 0.18, 0.14, 0.95) if hv else Color(0.09, 0.10, 0.09, 0.95))
	_c.draw_rect(br, DZ.ACCENT if hv else DZ.EDGE, false, 1.5)
	DZ.text(_c, "BACK TO GEAR" if _craft_mode else "CRAFTING", br.position + Vector2(0, 26), 16, DZ.ACCENT if hv else DZ.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 230.0)
	_hits.append({"k": "btn", "r": br, "act": func() -> void:
		_craft_mode = not _craft_mode
		_sel = {}})


func _draw_craft() -> void:
	var recs := RecipeDB.all()
	var near: bool = world._near_fire()
	var job: Dictionary = world.craft_job
	DZ.text(_c, "CRAFTING   (click a recipe)", Vector2(PACK_O.x, 548), 16, DZ.DIM)
	var col_w := 408.0
	var hover_r := {}
	var hover_why := ""
	for i in recs.size():
		var r: Dictionary = recs[i]
		var rr := Rect2(Vector2(PACK_O.x + (i / 6) * (col_w + 8.0), 560 + (i % 6) * 34), Vector2(col_w, 30))
		var why := RecipeDB.blocked(inv, r, near)
		var ok := why == "" and job.is_empty()
		var hv := rr.has_point(_mouse)
		_c.draw_rect(rr, Color(0.16, 0.18, 0.14, 0.95) if (hv and ok) else Color(0.09, 0.10, 0.09, 0.92))
		_c.draw_rect(rr, DZ.ACCENT if ok else Color(0.30, 0.32, 0.27, 0.9), false, 1.0)
		DZ.text(_c, String(r["name"]), rr.position + Vector2(10, 21), 16, DZ.TEXT if ok else DZ.DIM)
		var tm := "%ds" % int(r["time_s"])
		DZ.text(_c, tm, rr.position + Vector2(col_w - 10 - DZ.text_w(tm, 14), 21), 14, DZ.DIM)
		if hv:
			hover_r = r
			hover_why = why
		var rid: String = r["id"]
		_hits.append({"k": "btn", "r": rr, "act": func() -> void: world.craft_start(rid)})
	var dr := Rect2(Vector2(PACK_O.x, 768), Vector2(824, 38))
	if not job.is_empty():
		var jr: Dictionary = job["r"]
		var f := clampf(float(job["t"]) / float(jr["time_s"]), 0.0, 1.0)
		_c.draw_rect(dr, Color(0, 0, 0, 0.6))
		_c.draw_rect(Rect2(dr.position, Vector2(dr.size.x * f, dr.size.y)), Color(0.45, 0.40, 0.18, 0.9))
		_c.draw_rect(dr, DZ.EDGE, false, 1.0)
		DZ.text(_c, "Crafting: %s   (click to cancel)" % String(jr["name"]), dr.position + Vector2(12, 25), 17, DZ.TEXT)
		_hits.append({"k": "btn", "r": dr, "act": func() -> void: world.craft_cancel("Cancelled")})
	elif not hover_r.is_empty():
		var ins: Array = []
		for id in hover_r["inputs"].keys():
			ins.append("%s x%d" % [inv.name_of(String(id)), int(hover_r["inputs"][id])])
		var outs: Array = []
		for id in hover_r["out"].keys():
			outs.append("%s x%d" % [inv.name_of(String(id)), int(hover_r["out"][id])])
		var tl := ""
		for t in hover_r.get("tools", []):
			tl += "   Tool: " + inv.name_of(String(t))
		if String(hover_r.get("station", "")) == "fire":
			tl += "   Near fire"
		DZ.text(_c, String(hover_r["desc"]), dr.position + Vector2(0, 14), 14, DZ.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 824.0)
		DZ.text(_c, "%s  ->  %s%s" % [", ".join(ins), ", ".join(outs), tl], dr.position + Vector2(0, 34), 14, DZ.ACCENT if hover_why == "" else DZ.WARN, HORIZONTAL_ALIGNMENT_LEFT, 824.0)
		if hover_why != "":
			DZ.text(_c, hover_why, dr.position + Vector2(824 - DZ.text_w(hover_why, 14), 14), 14, DZ.WARN)


func _cell_bg(r: Rect2, hover: bool, selected: bool, dim_fill: bool = false) -> void:
	var fill := Color(0.09, 0.10, 0.09, 0.92) if not hover else Color(0.15, 0.17, 0.14, 0.95)
	if dim_fill:
		fill = Color(0.06, 0.065, 0.06, 0.85)
	_c.draw_rect(r, fill)
	_c.draw_rect(r, DZ.ACCENT if selected else Color(0.30, 0.32, 0.27, 0.9), false, 2.0 if selected else 1.0)


func _draw_item_cell(r: Rect2, id: String, n: int, selected: bool, hit: Dictionary, dim: float = 1.0) -> void:
	var hover := r.has_point(_mouse) and not _dragging
	_cell_bg(r, hover, selected)
	DZ.item_icon(_c, id, r.grow(-16), dim)
	if n > 1:
		var cnt := "x%d" % n
		DZ.text(_c, cnt, r.position + Vector2(CELL - 8 - DZ.text_w(cnt, 18), CELL - 8), 18, DZ.TEXT)
	hit["r"] = r
	_hits.append(hit)


func _draw_equipment() -> void:
	DZ.text(_c, "EQUIPMENT", Vector2(140, 178), 16, DZ.DIM)
	var names := {"body": "BODY", "primary": "PRIMARY", "tool": "TOOL"}
	for slot in ["body", "primary", "tool"]:
		var r := _slot_rect(slot)
		var id := _slot_item(slot)
		if id == "":
			_cell_bg(r, false, false, true)
			_hits.append({"k": "equip", "slot": slot, "id": "", "r": r})
		else:
			_draw_item_cell(r, id, 1, _is_sel(id, "equip", slot), {"k": "equip", "slot": slot, "id": id, "n": 1})
		var lab := String(names[slot])
		var col := DZ.DIM
		if _in_hand(slot):
			lab += "  (in hands)"
			col = DZ.ACCENT
		DZ.text(_c, lab, Vector2(r.position.x, r.end.y + 20), 13, col)


func _bar(pos: Vector2, w: float, label: String, frac: float, value: String) -> void:
	DZ.text(_c, label, pos, 16, DZ.TEXT)
	var r := Rect2(pos + Vector2(120, -12), Vector2(w - 120, 10))
	_c.draw_rect(r, Color(0, 0, 0, 0.6))
	_c.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), DZ.status_color(frac))
	_c.draw_rect(r, DZ.EDGE, false, 1.0)
	DZ.text(_c, value, pos + Vector2(w + 12, 0), 16, DZ.DIM)


func _draw_condition() -> void:
	DZ.text(_c, "CONDITION", Vector2(140, 380), 16, DZ.DIM)
	var x := 140.0
	var w := 230.0
	_bar(Vector2(x, 414), w, "Blood", player.health / 100.0, "%d" % int(player.health * 120.0))
	_bar(Vector2(x, 446), w, "Food", needs.calories / 1500.0, "%d kcal" % int(needs.calories))
	_bar(Vector2(x, 478), w, "Water", needs.water / 70.0, "%d%%" % int(needs.water))
	_bar(Vector2(x, 510), w, "Temperature", (body.core - 32.0) / 4.5, "%.1f C" % body.core)
	DZ.text(_c, "WORN", Vector2(140, 566), 16, DZ.DIM)
	var worn := inv.equipped_body
	DZ.text(_c, inv.name_of(worn) if worn != "" else "Nothing over your base layer", Vector2(140, 594), 17, DZ.TEXT)
	var wt: float = body.warmth
	var wp: float = body.windproof
	var wa: float = body.waterproof
	_bar(Vector2(x, 630), w, "Warmth", wt, "%d%%" % int(wt * 100))
	_bar(Vector2(x, 660), w, "Windproof", wp, "%d%%" % int(wp * 100))
	_bar(Vector2(x, 690), w, "Waterproof", wa, "%d%%" % int(wa * 100))


func _draw_pack() -> void:
	var stacks := inv.stacks()
	DZ.text(_c, "BACKPACK", Vector2(PACK_O.x, PACK_O.y - 18), 16, DZ.DIM)
	var used := stacks.size()
	var cap := "%d / %d" % [used, Inventory.CAPACITY]
	DZ.text(_c, cap, Vector2(PACK_O.x + COLS * (CELL + GAP) - GAP - DZ.text_w(cap, 16), PACK_O.y - 18), 16, DZ.WARN if used >= Inventory.CAPACITY else DZ.DIM)
	for i in Inventory.CAPACITY:
		var r := _pack_rect(i)
		if i < stacks.size():
			var st: Dictionary = stacks[i]
			_draw_item_cell(r, st["id"], st["n"], _is_sel(st["id"], "pack"), {"k": "pack", "id": st["id"], "n": st["n"], "idx": i})
		else:
			_cell_bg(r, false, false, true)
			_hits.append({"k": "pack", "id": "", "r": r})


func _draw_ground() -> void:
	DZ.text(_c, "NEARBY  (within %.1f m)" % NEAR_R, Vector2(GROUND_O.x, GROUND_O.y - 18), 16, DZ.DIM)
	var near := _nearby()
	for i in GROUND_N:
		var r := _ground_rect(i)
		if i < near.size():
			var p: ItemPickup = near[i]["node"]
			_draw_item_cell(r, p.id, p.n, _is_sel(p.id, "ground", "", p), {"k": "ground", "id": p.id, "n": p.n, "node": p, "idx": i})
		else:
			_cell_bg(r, false, false, true)


func _draw_info() -> void:
	var r := Rect2(Vector2(520, 690), Vector2(824, 100))
	DZ.panel(_c, r, DZ.PANEL_LIGHT)
	if _sel.is_empty():
		DZ.text(_c, "Select an item.", r.position + Vector2(16, 34), 18, DZ.DIM)
		return
	var id: String = _sel["id"]
	var d: Dictionary = Inventory.ITEMS[id]
	var n: int = _sel.get("n", 1)
	var title: String = d["name"] + ("  x%d" % n if n > 1 else "")
	DZ.text(_c, title, r.position + Vector2(16, 30), 22, DZ.ACCENT)
	var sub := String(d.get("desc", ""))
	if d.has("kcal"):
		sub += "   (%d kcal)" % int(d["kcal"])
	DZ.text(_c, sub, r.position + Vector2(16, 58), 14, DZ.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 560.0)
	DZ.text(_c, "Type: %s" % String(d.get("kind", "misc")).capitalize(), r.position + Vector2(16, 82), 13, DZ.DIM)
	# buttons
	var entries := _entries(id, _sel["from"], n, _sel.get("node"))
	var bx := r.end.x - 12.0
	for i in range(entries.size() - 1, -1, -1):
		var lab: String = entries[i]["label"]
		var w := DZ.text_w(lab, 15) + 30.0
		var br := Rect2(Vector2(bx - w, r.position.y + 30), Vector2(w, 40))
		var hv := br.has_point(_mouse)
		_c.draw_rect(br, Color(0.16, 0.18, 0.14, 0.95) if hv else Color(0.09, 0.10, 0.09, 0.95))
		_c.draw_rect(br, DZ.ACCENT if hv else DZ.EDGE, false, 1.5)
		DZ.text(_c, lab, br.position + Vector2(0, 26), 15, DZ.ACCENT if hv else DZ.TEXT, HORIZONTAL_ALIGNMENT_CENTER, w)
		_hits.append({"k": "btn", "r": br, "act": entries[i]["act"]})
		bx -= w + 10.0


func _draw_drag() -> void:
	if _drag.get("id", "") == "":
		return
	var r := Rect2(_mouse - Vector2(40, 40), Vector2(80, 80))
	_c.draw_rect(r, Color(0, 0, 0, 0.5))
	DZ.item_icon(_c, _drag["id"], r.grow(-8))
	var h := _hit_at(_mouse)
	var tip := ""
	var tk := _tk(h)
	var id: String = _drag["id"]
	var from: String = _drag["from"]
	if tk == "equip" and h.get("slot", "") == "body" and Inventory.kind_of(id) == "clothing" and from != "equip":
		tip = "Wear"
	elif tk == "drop" and from != "ground":
		tip = "Drop"
	elif tk == "pack" and from in ["ground", "equip"]:
		tip = "Take" if from == "ground" else "Put in pack"
	elif tk == "equip" and from == "equip" and h.get("slot", "") != _drag.get("slot", ""):
		tip = "Swap"
	if tip != "":
		DZ.text(_c, tip, _mouse + Vector2(50, 10), 16, DZ.ACCENT)


func _draw_menu() -> void:
	var entries: Array = _menu["entries"]
	var p: Vector2 = _menu["pos"]
	var w := 190.0
	var lh := 34.0
	var r := Rect2(p, Vector2(w, lh * entries.size() + 8.0))
	DZ.panel(_c, r, Color(0.04, 0.045, 0.04, 0.96))
	for i in entries.size():
		var er := Rect2(p + Vector2(4, 4 + i * lh), Vector2(w - 8, lh))
		var hv := er.has_point(_mouse)
		if hv:
			_c.draw_rect(er, Color(0.2, 0.2, 0.12, 0.9))
		DZ.text(_c, String(entries[i]["label"]), er.position + Vector2(10, 23), 16, DZ.ACCENT if hv else DZ.TEXT)
		_hits.append({"k": "menu", "r": er, "act": entries[i]["act"]})


func _draw_tooltip() -> void:
	var h := _hit_at(_mouse)
	var id: String = h.get("id", "")
	if id == "" or not (h.get("k", "") in ["pack", "equip", "ground"]):
		return
	var t: String = Inventory.ITEMS[id]["name"]
	var n: int = h.get("n", 1)
	if n > 1:
		t += "  x%d" % n
	var w := DZ.text_w(t, 15) + 20.0
	var r := Rect2(_mouse + Vector2(18, 18), Vector2(w, 30))
	DZ.panel(_c, r, Color(0.04, 0.045, 0.04, 0.96))
	DZ.text(_c, t, r.position + Vector2(10, 21), 15, DZ.TEXT)
