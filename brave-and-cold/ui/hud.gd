class_name Hud
extends CanvasLayer
## Minimal survival HUD (placeholder styling): time, temperatures, stamina, snow depth, noise.

var _label: Label
var _prompt: Label
var prompt := ""
var info := ""
var toast := ""
var inv_text := ""
var _toast_l: Label
var _death_l: Label
var _inv_l: Label
var _bars: Control
var player: Player
var body: BodyTemperature
var snow: SnowField
var clock: GameClock
var _stam_frac := 1.0
var _core_frac := 1.0
var _warn := false


func setup(p: Player, b: BodyTemperature, s: SnowField, c: GameClock) -> void:
	player = p
	body = b
	snow = s
	clock = c
	_label = Label.new()
	_label.position = Vector2(24, 20)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 5)
	add_child(_label)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-200, -140)
	_prompt.size = Vector2(400, 30)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("outline_size", 6)
	add_child(_prompt)
	_toast_l = Label.new()
	_toast_l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_l.position = Vector2(-300, -190)
	_toast_l.size = Vector2(600, 30)
	_toast_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_l.add_theme_font_size_override("font_size", 18)
	_toast_l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	_toast_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_toast_l.add_theme_constant_override("outline_size", 6)
	add_child(_toast_l)
	_inv_l = Label.new()
	_inv_l.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_inv_l.position = Vector2(-420, -100)
	_inv_l.add_theme_font_size_override("font_size", 18)
	_inv_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_inv_l.add_theme_constant_override("outline_size", 5)
	add_child(_inv_l)
	_death_l = Label.new()
	_death_l.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_l.add_theme_font_size_override("font_size", 40)
	_death_l.add_theme_color_override("font_color", Color(0.9, 0.85, 0.85))
	_death_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_death_l.add_theme_constant_override("outline_size", 10)
	add_child(_death_l)
	_bars = Control.new()
	_bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.draw.connect(_draw_bars)
	add_child(_bars)


func _process(_d: float) -> void:
	if player == null:
		return
	var tier: int = snow.tier_at(player.position.x, player.position.z)
	var trampled := snow.is_trampled(player.position.x, player.position.z)
	var txt := clock.time_string() + "\n"
	txt += "Air %.0f C   Feels %.0f C\n" % [clock.ambient_c(), body.feels_like]
	txt += "Core %.1f C  %s\n" % [body.core, body.state_name()]
	txt += "Snow: %s%s  (x%.2f speed)\n" % [SnowField.TIER_NAMES[tier], " (packed)" if trampled else "", SnowField.PLAYER_SPEED[tier]]
	txt += "Noise radius %.0f m%s" % [player.noise_radius(), "   [FIRE]" if player.fire_w > 0.0 else ""]
	if info != "":
		txt += "\n" + info
	_label.text = txt
	_prompt.text = ("[E] " + prompt) if prompt != "" else ""
	_stam_frac = player.stamina / 100.0
	_core_frac = clampf((body.core - 30.0) / 7.0, 0.0, 1.0)
	_warn = body.core < BodyTemperature.SHIVER
	_death_l.text = ("YOU DIED\n" + player.death_cause + "\n\nPress R to try again") if player.dead else ""
	_toast_l.text = toast
	_inv_l.text = inv_text
	_bars.queue_redraw()


func _draw_bars() -> void:
	var sz := _bars.size
	var w := 220.0
	var x := 24.0
	var y := sz.y - 70.0
	_bars.draw_rect(Rect2(x, y, w, 8), Color(0, 0, 0, 0.5))
	_bars.draw_rect(Rect2(x, y, w * _stam_frac, 8), Color(0.85, 0.9, 0.7) if not player.exhausted else Color(0.9, 0.4, 0.3))
	_bars.draw_rect(Rect2(x, y + 16, w, 8), Color(0, 0, 0, 0.5))
	_bars.draw_rect(Rect2(x, y + 16, w * _core_frac, 8), Color(0.55, 0.75, 1.0) if not _warn else Color(0.4, 0.55, 1.0))
	_bars.draw_rect(Rect2(x, y + 32, w, 8), Color(0, 0, 0, 0.5))
	_bars.draw_rect(Rect2(x, y + 32, w * clampf(player.health / 100.0, 0.0, 1.0), 8), Color(0.85, 0.25, 0.22))
	if player.dead:
		_bars.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.3, 0.0, 0.0, 0.45))
	# crosshair dot
	_bars.draw_circle(sz * 0.5, 1.5, Color(1, 1, 1, 0.6))
