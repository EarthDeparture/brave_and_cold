class_name DZ
extends RefCounted
## Shared look for the Arma 2 / DayZ-mod style UI: desaturated olive greys, ochre highlight, Tahoma bold.
## All widgets are immediate-mode drawn (CanvasItem._draw) so icons are vector primitives, no art assets.

const TEXT := Color(0.84, 0.85, 0.80)
const DIM := Color(0.56, 0.57, 0.52)
const PANEL := Color(0.045, 0.05, 0.045, 0.86)
const PANEL_LIGHT := Color(0.10, 0.11, 0.10, 0.88)
const EDGE := Color(0.36, 0.38, 0.31, 0.95)
const ACCENT := Color(0.90, 0.76, 0.30)      # Arma action-menu ochre
const WARN := Color(0.86, 0.22, 0.16)
const GOOD := Color(0.78, 0.82, 0.70)
const SHADOW := Color(0, 0, 0, 0.9)

static var _font: Font


static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Tahoma", "Verdana", "Segoe UI", "Arial"])
		f.font_weight = 700
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font = f
	return _font


static func text(ci: CanvasItem, s: String, pos: Vector2, size: int, col: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	ci.draw_string_outline(font(), pos, s, align, width, size, 4, SHADOW)
	ci.draw_string(font(), pos, s, align, width, size, col)


static func text_w(s: String, size: int) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x


## 0..1 condition fraction -> white (fine) / yellow / red (critical), like the DayZ status icons.
static func status_color(f: float) -> Color:
	if f >= 0.6:
		return Color(0.92, 0.93, 0.90)
	if f >= 0.3:
		return Color(0.92, 0.93, 0.90).lerp(Color(0.95, 0.78, 0.25), (0.6 - f) / 0.3)
	return Color(0.95, 0.78, 0.25).lerp(Color(0.88, 0.14, 0.10), clampf((0.3 - f) / 0.3, 0.0, 1.0))


static func panel(ci: CanvasItem, r: Rect2, fill: Color = PANEL, edge: Color = EDGE) -> void:
	ci.draw_rect(r, fill)
	ci.draw_rect(r, edge, false, 1.5)


static func item_color(id: String) -> Color:
	match id:
		"wood": return Color(0.55, 0.36, 0.18)
		"matches": return Color(0.80, 0.64, 0.30)
		"flare": return Color(0.85, 0.12, 0.08)
		"axe": return Color(0.66, 0.68, 0.70)
		"rifle": return Color(0.50, 0.36, 0.22)
		"ammo": return Color(0.80, 0.66, 0.30)
		"beans": return Color(0.72, 0.30, 0.16)
		"venison_raw": return Color(0.72, 0.22, 0.20)
		"venison_cooked": return Color(0.52, 0.30, 0.16)
		"sweater": return Color(0.40, 0.46, 0.52)
		"parka": return Color(0.28, 0.40, 0.30)
	return Color(0.6, 0.6, 0.6)


static func _rot(p: Vector2, c: Vector2, a: float) -> Vector2:
	return c + (p - c).rotated(a)


static func _quad(ci: CanvasItem, c: Vector2, w: float, h: float, a: float, col: Color) -> void:
	var hw := w * 0.5
	var hh := h * 0.5
	ci.draw_colored_polygon(PackedVector2Array([
		_rot(c + Vector2(-hw, -hh), c, a), _rot(c + Vector2(hw, -hh), c, a),
		_rot(c + Vector2(hw, hh), c, a), _rot(c + Vector2(-hw, hh), c, a)]), col)


## Pictogram for an item inside rect r.
static func item_icon(ci: CanvasItem, id: String, r: Rect2, dim: float = 1.0) -> void:
	var col := item_color(id) * Color(dim, dim, dim, 1.0)
	var dark := col.darkened(0.45)
	var lite := col.lightened(0.3)
	var c := r.get_center()
	var u := minf(r.size.x, r.size.y) * 0.5   # half extent
	match id:
		"wood":
			for k in 3:
				var off := Vector2((k - 1) * u * 0.42, (0.22 if k == 1 else -0.12) * u)
				_quad(ci, c + off + Vector2(0, -u * 0.05), u * 0.36, u * 1.25, 0.0, col)
				ci.draw_circle(c + off + Vector2(0, u * 0.55), u * 0.18, lite)
		"matches":
			for k in 3:
				var a0 := -0.55 + k * 0.22
				var base_p := c + Vector2(-u * 0.2 + k * u * 0.22, u * 0.05)
				var tip := base_p + Vector2(sin(a0), -cos(a0)) * u * 1.0
				ci.draw_line(base_p, tip, Color(0.78, 0.62, 0.36) * Color(dim, dim, dim, 1), 3.0)
				ci.draw_circle(tip, u * 0.12, Color(0.82, 0.12, 0.08))
			_quad(ci, c + Vector2(0, u * 0.45), u * 1.4, u * 0.6, 0.0, Color(0.38, 0.24, 0.14))
			_quad(ci, c + Vector2(0, u * 0.45), u * 1.4, u * 0.18, 0.0, Color(0.85, 0.72, 0.3))
		"flare":
			_quad(ci, c + Vector2(0, u * 0.12), u * 0.42, u * 1.3, 0.6, col)
			_quad(ci, c + Vector2(u * 0.3, -u * 0.2), u * 0.36, u * 0.25, 0.6, Color(0.95, 0.9, 0.8))
			ci.draw_circle(c + Vector2(-u * 0.62, -u * 0.55), u * 0.14, Color(1.0, 0.85, 0.4))
		"axe":
			ci.draw_line(c + Vector2(-u * 0.55, u * 0.8), c + Vector2(u * 0.45, -u * 0.7), Color(0.5, 0.34, 0.2), 4.0)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(u * 0.1, -u * 0.95), c + Vector2(u * 0.85, -u * 0.55), c + Vector2(u * 0.7, -u * 0.0), c + Vector2(u * 0.25, -u * 0.35)]), col)
		"rifle":
			ci.draw_line(c + Vector2(-u * 0.95, u * 0.35), c + Vector2(u * 0.95, -u * 0.35), Color(0.22, 0.22, 0.23), 3.0)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.98, u * 0.15), c + Vector2(-u * 0.25, -u * 0.05), c + Vector2(-u * 0.2, u * 0.3), c + Vector2(-u * 0.85, u * 0.6)]), col)
			ci.draw_line(c + Vector2(-u * 0.1, u * 0.0), c + Vector2(u * 0.05, u * 0.35), dark, 2.0)
		"ammo":
			for k in 3:
				var x := (k - 1) * u * 0.42
				_quad(ci, c + Vector2(x, u * 0.2), u * 0.3, u * 0.7, 0.0, col)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(x - u * 0.15, -u * 0.15), c + Vector2(x + u * 0.15, -u * 0.15), c + Vector2(x, -u * 0.6)]), Color(0.7, 0.45, 0.25))
		"beans":
			_quad(ci, c, u * 0.95, u * 1.25, 0.0, Color(0.62, 0.64, 0.66) * Color(dim, dim, dim, 1))
			_quad(ci, c + Vector2(0, u * 0.05), u * 0.95, u * 0.6, 0.0, col)
			ci.draw_line(c + Vector2(-u * 0.47, -u * 0.62), c + Vector2(u * 0.47, -u * 0.62), lite, 2.0)
		"venison_raw", "venison_cooked":
			var pts := PackedVector2Array()
			for k in 14:
				var a := TAU * k / 14.0
				pts.append(c + Vector2(cos(a) * u * (0.85 + 0.12 * sin(a * 3.0)), sin(a) * u * (0.6 + 0.1 * cos(a * 2.0))))
			ci.draw_colored_polygon(pts, col)
			ci.draw_arc(c + Vector2(-u * 0.15, 0), u * 0.3, 0.3, 4.6, 12, lite, 2.0)
			ci.draw_circle(c + Vector2(u * 0.35, u * 0.05), u * 0.12, Color(0.9, 0.85, 0.78))
		"sweater", "parka":
			var w := 1.0 if id == "parka" else 0.85
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-u * 0.45, -u * 0.8), c + Vector2(u * 0.45, -u * 0.8), c + Vector2(u * 1.0 * w, -u * 0.3),
				c + Vector2(u * 0.85 * w, u * 0.15), c + Vector2(u * 0.5, -u * 0.05), c + Vector2(u * 0.5, u * 0.85),
				c + Vector2(-u * 0.5, u * 0.85), c + Vector2(-u * 0.5, -u * 0.05), c + Vector2(-u * 0.85 * w, u * 0.15), c + Vector2(-u * 1.0 * w, -u * 0.3)]), col)
			ci.draw_line(c + Vector2(0, -u * 0.8), c + Vector2(0, u * 0.85), dark, 2.0 if id == "parka" else 1.0)
			ci.draw_arc(c + Vector2(0, -u * 0.8), u * 0.25, 0.0, PI, 10, dark, 3.0)
		_:
			ci.draw_rect(Rect2(c - Vector2(u, u) * 0.6, Vector2(u, u) * 1.2), col)


## DayZ-style status pictograms: "blood", "food", "water", "temp".
static func status_icon(ci: CanvasItem, kind: String, r: Rect2, col: Color) -> void:
	var c := r.get_center()
	var u := minf(r.size.x, r.size.y) * 0.5
	var sh := Color(0, 0, 0, 0.75)
	ci.draw_circle(c, u * 1.12, Color(0.03, 0.04, 0.03, 0.42))
	for pass_i in 2:
		var cc := col if pass_i == 1 else sh
		var o := Vector2.ZERO if pass_i == 1 else Vector2(2, 2)
		match kind:
			"blood":
				var pts := PackedVector2Array([c + o + Vector2(0, -u * 0.95)])
				for k in range(0, 25):
					var a := lerpf(-PI * 0.5 + 0.72, -PI * 0.5 + TAU - 0.72, k / 24.0)
					pts.append(c + o + Vector2(0, u * 0.28) + Vector2(cos(a), sin(a)) * u * 0.62)
				ci.draw_colored_polygon(pts, cc)
			"food":
				# tin can
				ci.draw_rect(Rect2(c + o + Vector2(-u * 0.55, -u * 0.35), Vector2(u * 1.1, u * 1.05)), cc)
				ci.draw_rect(Rect2(c + o + Vector2(-u * 0.55, -u * 0.55), Vector2(u * 1.1, u * 0.22)), cc.lightened(0.15) if pass_i == 1 else cc)
				if pass_i == 1:
					ci.draw_rect(Rect2(c + Vector2(-u * 0.55, u * 0.0), Vector2(u * 1.1, u * 0.42)), Color(0.25, 0.27, 0.22, 0.75))
			"water":
				# bottle
				ci.draw_rect(Rect2(c + o + Vector2(-u * 0.22, -u * 0.95), Vector2(u * 0.44, u * 0.3)), cc)
				ci.draw_colored_polygon(PackedVector2Array([c + o + Vector2(-u * 0.22, -u * 0.65), c + o + Vector2(u * 0.22, -u * 0.65), c + o + Vector2(u * 0.52, -u * 0.25), c + o + Vector2(u * 0.52, u * 0.9), c + o + Vector2(-u * 0.52, u * 0.9), c + o + Vector2(-u * 0.52, -u * 0.25)]), cc)
				if pass_i == 1:
					ci.draw_line(c + Vector2(-u * 0.5, u * 0.1), c + Vector2(u * 0.5, u * 0.1), Color(0, 0, 0, 0.4), 2.0)
			"temp":
				ci.draw_rect(Rect2(c + o + Vector2(-u * 0.18, -u * 0.95), Vector2(u * 0.36, u * 1.3)), cc)
				ci.draw_circle(c + o + Vector2(0, u * 0.55), u * 0.42, cc)
				if pass_i == 1:
					ci.draw_line(c + Vector2(0, -u * 0.6), c + Vector2(0, u * 0.5), Color(0, 0, 0, 0.5), 3.0)
					ci.draw_circle(c + Vector2(0, u * 0.55), u * 0.22, Color(0, 0, 0, 0.5))
