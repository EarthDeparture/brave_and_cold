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
		"cured_hide": return Color(0.70, 0.52, 0.30)
		"wolf_fur": return Color(0.62, 0.62, 0.64)
		"bear_fur": return Color(0.30, 0.20, 0.14)
		"toque": return Color(0.55, 0.20, 0.18)
		"hide_cap": return Color(0.62, 0.45, 0.26)
		"wolf_hat": return Color(0.58, 0.58, 0.60)
		"hide_mitts": return Color(0.62, 0.45, 0.26)
		"wolf_mitts": return Color(0.58, 0.58, 0.60)
		"hide_boots": return Color(0.55, 0.38, 0.22)
		"hide_leggings": return Color(0.60, 0.43, 0.25)
		"bear_coat": return Color(0.32, 0.22, 0.15)
		"stick": return Color(0.45, 0.32, 0.20)
		"kindling": return Color(0.62, 0.48, 0.28)
		"thatch": return Color(0.72, 0.62, 0.36)
		"tinder": return Color(0.66, 0.70, 0.52)
		"reed": return Color(0.48, 0.44, 0.26)
		"cordage": return Color(0.70, 0.62, 0.45)
		"knife": return Color(0.70, 0.72, 0.74)
		"bow_drill": return Color(0.52, 0.38, 0.22)
		"wolf_meat_raw": return Color(0.62, 0.24, 0.24)
		"wolf_meat_cooked": return Color(0.46, 0.28, 0.16)
		"bear_meat_raw": return Color(0.58, 0.20, 0.22)
		"bear_meat_cooked": return Color(0.44, 0.26, 0.14)
		"jerky": return Color(0.40, 0.22, 0.14)
		"fat": return Color(0.92, 0.88, 0.76)
		"gut": return Color(0.80, 0.62, 0.60)
		"deer_hide": return Color(0.60, 0.46, 0.30)
		"wolf_pelt": return Color(0.52, 0.52, 0.54)
		"bear_pelt": return Color(0.30, 0.20, 0.14)
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
		"venison_raw", "venison_cooked", "wolf_meat_raw", "wolf_meat_cooked", "bear_meat_raw", "bear_meat_cooked", "jerky":
			var pts := PackedVector2Array()
			for k in 14:
				var a := TAU * k / 14.0
				pts.append(c + Vector2(cos(a) * u * (0.85 + 0.12 * sin(a * 3.0)), sin(a) * u * (0.6 + 0.1 * cos(a * 2.0))))
			ci.draw_colored_polygon(pts, col)
			ci.draw_arc(c + Vector2(-u * 0.15, 0), u * 0.3, 0.3, 4.6, 12, lite, 2.0)
			ci.draw_circle(c + Vector2(u * 0.35, u * 0.05), u * 0.12, Color(0.9, 0.85, 0.78))
		"sweater", "parka", "bear_coat":
			var w := 1.0 if (id == "parka" or id == "bear_coat") else 0.85
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-u * 0.45, -u * 0.8), c + Vector2(u * 0.45, -u * 0.8), c + Vector2(u * 1.0 * w, -u * 0.3),
				c + Vector2(u * 0.85 * w, u * 0.15), c + Vector2(u * 0.5, -u * 0.05), c + Vector2(u * 0.5, u * 0.85),
				c + Vector2(-u * 0.5, u * 0.85), c + Vector2(-u * 0.5, -u * 0.05), c + Vector2(-u * 0.85 * w, u * 0.15), c + Vector2(-u * 1.0 * w, -u * 0.3)]), col)
			ci.draw_line(c + Vector2(0, -u * 0.8), c + Vector2(0, u * 0.85), dark, 2.0 if id == "parka" else 1.0)
			ci.draw_arc(c + Vector2(0, -u * 0.8), u * 0.25, 0.0, PI, 10, dark, 3.0)
		"stick", "kindling":
			for k in (4 if id == "kindling" else 3):
				var a2 := -0.5 + k * 0.28
				var b0 := c + Vector2(-u * 0.5 + k * u * 0.3, u * 0.8)
				ci.draw_line(b0, b0 + Vector2(sin(a2), -cos(a2)) * u * (1.5 if id == "stick" else 1.1), col, 4.0 if id == "stick" else 3.0)
		"thatch", "reed", "tinder":
			for k in 7:
				var a3 := -0.5 + k * 0.17
				var b1 := c + Vector2(-u * 0.5 + k * u * 0.17, u * 0.85)
				var tip2 := b1 + Vector2(sin(a3), -cos(a3)) * u * (1.4 - 0.15 * (k % 3))
				ci.draw_line(b1, tip2, col if k % 2 == 0 else dark, 2.5)
				if id == "reed" and k % 3 == 0:
					ci.draw_line(tip2 - Vector2(0, u * 0.1), tip2 + Vector2(0, u * 0.3), Color(0.3, 0.17, 0.08), 6.0)
			if id == "tinder":
				ci.draw_circle(c + Vector2(0, u * 0.2), u * 0.45, lite)
		"cordage":
			for k in 3:
				ci.draw_arc(c, u * (0.35 + k * 0.17), 0.0, TAU, 20, col if k % 2 == 0 else dark, 3.0)
		"knife":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.2, -u * 0.95), c + Vector2(u * 0.25, -u * 0.3), c + Vector2(u * 0.1, u * 0.2), c + Vector2(-u * 0.2, u * 0.2)]), col)
			_quad(ci, c + Vector2(-u * 0.05, u * 0.6), u * 0.3, u * 0.75, 0.0, Color(0.40, 0.26, 0.16))
		"bow_drill":
			ci.draw_arc(c + Vector2(-u * 0.2, 0), u * 0.9, -1.2, 1.2, 14, col, 4.0)
			ci.draw_line(c + Vector2(u * 0.3, -u * 0.8), c + Vector2(u * 0.3, u * 0.8), dark, 2.0)
			ci.draw_line(c + Vector2(u * 0.0, u * 0.9), c + Vector2(u * 0.0, -u * 0.9), lite, 3.0)
		"fat", "gut":
			var pts2 := PackedVector2Array()
			for k in 12:
				var a4 := TAU * k / 12.0
				pts2.append(c + Vector2(cos(a4) * u * (0.7 + 0.15 * sin(a4 * 2.0)), sin(a4) * u * (0.55 + 0.12 * cos(a4 * 3.0))))
			ci.draw_colored_polygon(pts2, col)
			if id == "gut":
				ci.draw_arc(c, u * 0.35, 0.0, TAU, 12, dark, 3.0)
		"deer_hide", "wolf_pelt", "bear_pelt", "cured_hide", "wolf_fur", "bear_fur":
			var pts3 := PackedVector2Array()
			for k in 16:
				var a5 := TAU * k / 16.0
				var rr := 0.95 if k % 2 == 0 else 0.78
				pts3.append(c + Vector2(cos(a5) * u * rr, sin(a5) * u * rr * 0.8))
			ci.draw_colored_polygon(pts3, col)
			ci.draw_arc(c, u * 0.5, 0.2, 3.0, 10, lite, 2.0)
		"toque", "hide_cap", "wolf_hat":
			ci.draw_arc(c + Vector2(0, u * 0.15), u * 0.75, PI, TAU, 14, col, u * 0.7)
			ci.draw_rect(Rect2(c + Vector2(-u * 0.8, u * 0.1), Vector2(u * 1.6, u * 0.4)), lite)
			if id != "hide_cap":
				ci.draw_circle(c + Vector2(0, -u * 0.7), u * 0.2, dark)
		"hide_mitts", "wolf_mitts":
			_quad(ci, c + Vector2(0, u * 0.15), u * 0.9, u * 1.2, 0.0, col)
			ci.draw_circle(c + Vector2(-u * 0.5, -u * 0.15), u * 0.28, col)
			_quad(ci, c + Vector2(0, u * 0.85), u * 1.0, u * 0.3, 0.0, lite)
		"hide_boots":
			_quad(ci, c + Vector2(-u * 0.2, -u * 0.2), u * 0.6, u * 1.2, 0.0, col)
			_quad(ci, c + Vector2(u * 0.15, u * 0.6), u * 1.2, u * 0.45, 0.0, dark)
			_quad(ci, c + Vector2(-u * 0.2, -u * 0.85), u * 0.7, u * 0.25, 0.0, lite)
		"hide_leggings":
			_quad(ci, c + Vector2(-u * 0.32, 0), u * 0.5, u * 1.8, 0.0, col)
			_quad(ci, c + Vector2(u * 0.32, 0), u * 0.5, u * 1.8, 0.0, col)
			_quad(ci, c + Vector2(0, -u * 0.8), u * 1.15, u * 0.25, 0.0, lite)
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
