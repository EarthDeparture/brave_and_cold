class_name UiKit
extends RefCounted
## Menu widgets in the shared Arma 2 / DayZ look (see DZ): desaturated olive panels, Tahoma bold, ochre hover.

const FG := DZ.TEXT
const DIM := DZ.DIM


static func button(text: String, width: float = 300.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", DZ.font())
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", FG)
	b.add_theme_color_override("font_hover_color", DZ.ACCENT)
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.55))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_stylebox_override("normal", _btn(Color(0.05, 0.055, 0.05, 0.55), Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("hover", _btn(Color(0.12, 0.12, 0.08, 0.85), DZ.ACCENT))
	b.add_theme_stylebox_override("pressed", _btn(Color(0.17, 0.16, 0.09, 0.95), DZ.ACCENT))
	return b


static func label(text: String, size: int = 20, color: Color = FG) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", DZ.font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	return l


static func panel(margin: float = 28.0) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = DZ.PANEL
	s.border_color = DZ.EDGE
	s.set_border_width_all(1)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.8
	s.content_margin_bottom = margin * 0.8
	p.add_theme_stylebox_override("panel", s)
	return p


## Same flat colours as the gear screen, no rounded corners: left ochre bar on hover like an Arma list entry.
static func _btn(bg: Color, bar: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = bar
	s.border_width_left = 4
	s.content_margin_left = 18
	s.content_margin_right = 16
	return s


static func slider_row(title: String, min_v: float, max_v: float, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var t := label(title, 18, DIM)
	t.custom_minimum_size = Vector2(170, 0)
	row.add_child(t)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = (max_v - min_v) / 100.0
	s.value = value
	s.custom_minimum_size = Vector2(260, 24)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.02, 0.02, 0.02, 0.8)
	track.border_color = DZ.EDGE
	track.set_border_width_all(1)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.62, 0.52, 0.2)
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.value_changed.connect(on_change)
	row.add_child(s)
	return row
