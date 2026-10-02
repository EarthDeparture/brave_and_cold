class_name ItemSpawner
extends Control
## Dev tool: every item in the game on the right side of the screen while the dev menu is open.
## Search box, category filter, icon grid. Left click gives the chosen quantity, right click a full stack.
## Destination: your pack, or dropped on the ground at your feet (for testing pickups / chests / world items).

const COLS := 4
const CELL_W := 88.0
const CELL_H := 92.0
const PANEL_W := 410.0
const QTYS := [1, 5, 10, 25]

var world: Node
var player: Player
var qty := 1
var category := "all"          # all | weapon | tool | ... (Inventory.KIND_ORDER)
var at_feet := false
var last_msg := ""
var given_log: Array = []      # [{id, n, feet}] for tests

var _panel: PanelContainer
var _search: LineEdit
var _grid: GridContainer
var _scroll: ScrollContainer
var _status: Label
var _count_lbl: Label
var _cat_btns: Dictionary = {}
var _qty_btns: Dictionary = {}
var _prev_frozen := false


func setup(w: Node, p: Player) -> void:
	world = w
	player = p
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	rebuild()


func _build() -> void:
	_panel = UiKit.panel(10.0)
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 5)
	_panel.add_child(outer)
	outer.add_child(UiKit.label("ITEM SPAWNER   (L click: give   R click: full stack)", 13, DZ.ACCENT))
	_search = LineEdit.new()
	_search.placeholder_text = "search name or id..."
	_search.clear_button_enabled = true
	_search.add_theme_font_override("font", DZ.font())
	_search.add_theme_font_size_override("font_size", 14)
	_search.text_changed.connect(func(_t: String) -> void: rebuild())
	_search.focus_entered.connect(_on_focus)
	_search.focus_exited.connect(_on_unfocus)
	outer.add_child(_search)
	var crow := HFlowContainer.new()
	crow.add_theme_constant_override("h_separation", 3)
	crow.add_theme_constant_override("v_separation", 3)
	outer.add_child(crow)
	var cats: Array = ["all"]
	cats.append_array(Inventory.KIND_ORDER)
	for c in cats:
		var cs: String = c
		_cat_btns[cs] = _btn(crow, cs.capitalize(), func() -> void: set_category(cs))
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 3)
	outer.add_child(qrow)
	qrow.add_child(UiKit.label("Qty", 13, DZ.DIM))
	for q in QTYS:
		var qv: int = q
		_qty_btns[qv] = _btn(qrow, "x%d" % qv, func() -> void: set_qty(qv))
	var cb := CheckBox.new()
	cb.text = "Drop at feet"
	cb.focus_mode = Control.FOCUS_NONE
	cb.add_theme_font_override("font", DZ.font())
	cb.add_theme_font_size_override("font_size", 13)
	cb.toggled.connect(func(v: bool) -> void: at_feet = v)
	qrow.add_child(cb)
	_count_lbl = UiKit.label("", 12, DZ.DIM)
	outer.add_child(_count_lbl)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(PANEL_W - 22.0, 500)
	outer.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_scroll.add_child(_grid)
	_status = UiKit.label("", 13, DZ.TEXT)
	_status.custom_minimum_size = Vector2(PANEL_W - 22.0, 0)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_status)
	get_viewport().size_changed.connect(fit)
	set_qty(1)
	set_category("all")
	fit()


func fit() -> void:
	if _panel == null:
		return
	var vs := get_viewport().get_visible_rect().size
	_panel.position = Vector2(vs.x - PANEL_W - 10.0, 10.0)
	_scroll.custom_minimum_size = Vector2(PANEL_W - 22.0, clampf(vs.y - 230.0, 200.0, 1000.0))


func _btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", DZ.font())
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", DZ.TEXT)
	b.add_theme_color_override("font_pressed_color", DZ.ACCENT)
	b.custom_minimum_size = Vector2(0, 24)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func set_category(c: String) -> void:
	category = c
	for k in _cat_btns.keys():
		(_cat_btns[k] as Button).set_pressed_no_signal(k == c)
	rebuild()


func set_qty(q: int) -> void:
	qty = q
	for k in _qty_btns.keys():
		(_qty_btns[k] as Button).set_pressed_no_signal(int(k) == q)


## Ids matching the current search + category, sorted by kind then name.
func matches() -> Array:
	var out: Array = []
	var needle := (_search.text if _search != null else "").strip_edges().to_lower()
	for id in Inventory.ITEMS.keys():
		var d: Dictionary = Inventory.ITEMS[id]
		var kind := String(d.get("kind", "misc"))
		if category != "all" and kind != category:
			continue
		if needle != "" and not (String(id).to_lower().contains(needle) or String(d.get("name", "")).to_lower().contains(needle)):
			continue
		out.append(String(id))
	out.sort_custom(func(a, b) -> bool:
		var ka := Inventory.KIND_ORDER.find(Inventory.kind_of(String(a)))
		var kb := Inventory.KIND_ORDER.find(Inventory.kind_of(String(b)))
		if ka != kb:
			return ka < kb
		return String(Inventory.ITEMS[a]["name"]) < String(Inventory.ITEMS[b]["name"]))
	return out


func rebuild() -> void:
	if _grid == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	var ids := matches()
	for id in ids:
		var cell := _Cell.new()
		cell.id = String(id)
		cell.owner_ui = self
		_grid.add_child(cell)
	_count_lbl.text = "%d of %d items" % [ids.size(), Inventory.ITEMS.size()]


func give(id: String, n: int) -> void:
	if not Inventory.ITEMS.has(id) or n <= 0:
		return
	if at_feet:
		var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
		var p: Vector3 = player.position + fwd * 1.2
		var terrain: Terrain3D = world.get("terrain")
		var h: float = terrain.data.get_height(p) if terrain != null else player.position.y - player.eye_h
		p.y = (h if not is_nan(h) else player.position.y - player.eye_h)
		ItemPickup.spawn(world, id, n, p)
	else:
		world.call("_ensure_gear")
		var inv: Inventory = world.get("inv")
		if inv == null:
			return
		inv.add(id, n)
	var nm := String(Inventory.ITEMS[id]["name"])
	last_msg = "%s %d x %s" % ["Dropped" if at_feet else "Gave", n, nm]
	given_log.append({"id": id, "n": n, "feet": at_feet})
	if _status != null:
		_status.text = last_msg
	world.call("_say", last_msg)


func _on_focus() -> void:
	_prev_frozen = player.frozen
	player.frozen = true   # typing in the search box must not walk the player around


func _on_unfocus() -> void:
	player.frozen = _prev_frozen


func _input(e: InputEvent) -> void:
	if _search != null and _search.has_focus() and e is InputEventKey and e.pressed:
		if e.keycode == KEY_QUOTELEFT or e.keycode == KEY_ESCAPE:
			_search.release_focus()   # lets the backtick reach the dev menu toggle / Esc leave the box


## One item in the grid: icon + name, click to give.
class _Cell extends Control:
	var id := ""
	var owner_ui: ItemSpawner
	var _hover := false

	func _init() -> void:
		custom_minimum_size = Vector2(ItemSpawner.CELL_W, ItemSpawner.CELL_H)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		var d: Dictionary = Inventory.ITEMS[id]
		tooltip_text = "%s  [%s]\n%s\nstack %d" % [String(d["name"]), id, String(d.get("desc", "")), int(d.get("stack", 1))]
		mouse_entered.connect(func() -> void:
			_hover = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			queue_redraw())

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_LEFT:
				owner_ui.give(id, owner_ui.qty)
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				owner_ui.give(id, maxi(1, int(Inventory.ITEMS[id].get("stack", 1))))

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.15, 0.17, 0.14, 0.95) if _hover else Color(0.09, 0.10, 0.09, 0.92))
		draw_rect(r, DZ.ACCENT if _hover else Color(0.30, 0.32, 0.27, 0.9), false, 1.0)
		DZ.item_icon(self, id, Rect2(Vector2(size.x * 0.5 - 22.0, 6.0), Vector2(44, 44)))
		var nm := String(Inventory.ITEMS[id]["name"])
		DZ.text(self, nm, Vector2(4, 64), 11, DZ.TEXT, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8.0)
		DZ.text(self, id, Vector2(4, 84), 10, DZ.DIM, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8.0)
