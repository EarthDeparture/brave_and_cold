class_name UiKit
extends RefCounted
## Tiny shared styling helpers for menus (placeholder look: flat, cold, low-contrast).

const FG := Color(0.9, 0.94, 1.0)
const DIM := Color(0.62, 0.7, 0.82)


static func button(text: String, width: float = 280.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 46)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", FG)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_stylebox_override("normal", _box(Color(0.08, 0.11, 0.16, 0.72), Color(0.45, 0.58, 0.75, 0.35)))
	b.add_theme_stylebox_override("hover", _box(Color(0.16, 0.24, 0.34, 0.9), Color(0.75, 0.88, 1.0, 0.8)))
	b.add_theme_stylebox_override("pressed", _box(Color(0.22, 0.32, 0.44, 0.95), Color(1, 1, 1, 0.9)))
	return b


static func label(text: String, size: int = 20, color: Color = FG) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	return l


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.content_margin_left = 16
	s.content_margin_right = 16
	return s


static func slider_row(title: String, min_v: float, max_v: float, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var t := label(title, 18, DIM)
	t.custom_minimum_size = Vector2(150, 0)
	row.add_child(t)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = (max_v - min_v) / 100.0
	s.value = value
	s.custom_minimum_size = Vector2(240, 24)
	s.value_changed.connect(on_change)
	row.add_child(s)
	return row
