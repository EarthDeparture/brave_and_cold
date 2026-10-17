class_name MenuStyle
extends RefCounted
## Shared look of the title screen, options and pause pages (TLD-style): letter-spaced
## serif headings, a condensed sans for items, plain text buttons with an ochre tick on
## hover/focus, soft shadows instead of hard outlines, thin muted sliders.
## Fonts are SystemFont fallbacks (nothing bundled): Constantia/Georgia, Bahnschrift/Segoe UI.
const TEXT := Color(0.86, 0.86, 0.82)
const BRIGHT := Color(1.0, 0.97, 0.90)
const MUTED := Color(0.62, 0.63, 0.60)
const OCHRE := Color(0.80, 0.64, 0.36)
const HEAD := Color(0.92, 0.91, 0.87)
static var _cache := {}

static func font(names: Array, weight: int, spacing: int) -> Font:
	var key := "%s|%d|%d" % [",".join(names), weight, spacing]
	if _cache.has(key): return _cache[key]
	var sf := SystemFont.new(); sf.font_names = PackedStringArray(names); sf.font_weight = weight
	sf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	var fv := FontVariation.new(); fv.base_font = sf; fv.spacing_glyph = spacing
	_cache[key] = fv
	return fv

static func title_font() -> Font: return font(["Constantia", "Georgia", "Cambria", "Times New Roman", "serif"], 400, 9)
static func item_font() -> Font: return font(["Bahnschrift", "Segoe UI", "Arial Narrow", "Arial", "sans-serif"], 400, 3)
static func body_font() -> Font: return font(["Bahnschrift", "Segoe UI", "Arial", "sans-serif"], 300, 1)

static func text(s: String, f: Font, size: int, col: Color) -> Label:
	var l := Label.new(); l.text = s
	l.add_theme_font_override("font", f); l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0); l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)
	return l

static func heading(s: String, size: int = 44) -> Label: return text(s, title_font(), size, HEAD)

static func rule(width: float) -> ColorRect:
	var r := ColorRect.new(); r.color = Color(OCHRE, 0.75); r.custom_minimum_size = Vector2(width, 2)
	r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return r

## Plain text menu item; an ochre tick slides in on hover / keyboard focus.
static func item(s: String, act: Callable, size: int = 26) -> Button:
	var b := Button.new(); b.text = s.to_upper(); b.flat = true; b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL; b.custom_minimum_size = Vector2(420, size + 18)
	b.add_theme_font_override("font", item_font()); b.add_theme_font_size_override("font_size", size)
	for k in ["font_color", "font_focus_color"]: b.add_theme_color_override(k, TEXT)
	for k in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]: b.add_theme_color_override(k, BRIGHT)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5)); b.add_theme_constant_override("outline_size", 3)
	var empty := StyleBoxEmpty.new(); empty.content_margin_left = 26.0
	for k in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]: b.add_theme_stylebox_override(k, empty)
	var tick := ColorRect.new(); tick.color = OCHRE; tick.size = Vector2(12, 2); tick.position = Vector2(2, (size + 18) * 0.5)
	tick.modulate.a = 0.0; tick.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(tick)
	var on := func(v: bool) -> void:
		var tw := b.create_tween().set_parallel(true)
		tw.tween_property(tick, "modulate:a", 1.0 if v else 0.0, 0.18)
		tw.tween_property(tick, "size:x", 16.0 if v else 8.0, 0.18)
		b.add_theme_color_override("font_focus_color", BRIGHT if v else TEXT)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.focus_entered.connect(on.bind(true)); b.focus_exited.connect(on.bind(false))
	b.pressed.connect(act)
	return b

## Thin track, muted ochre fill, small pale grabber.
static func slider(s: HSlider) -> void:
	var track := StyleBoxFlat.new(); track.bg_color = Color(1, 1, 1, 0.16); track.content_margin_top = 1; track.content_margin_bottom = 1
	var fill := StyleBoxFlat.new(); fill.bg_color = Color(OCHRE, 0.85); fill.content_margin_top = 1; fill.content_margin_bottom = 1
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill); s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var g := GradientTexture2D.new(); var gr := Gradient.new(); gr.colors = PackedColorArray([BRIGHT, Color(BRIGHT, 0.0)])
	gr.offsets = PackedFloat32Array([0.55, 0.62]); g.gradient = gr; g.width = 14; g.height = 14
	g.fill = GradientTexture2D.FILL_RADIAL; g.fill_from = Vector2(0.5, 0.5); g.fill_to = Vector2(0.5, 0.0)
	s.add_theme_icon_override("grabber", g); s.add_theme_icon_override("grabber_highlight", g)
