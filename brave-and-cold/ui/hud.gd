class_name Hud
extends CanvasLayer
## Minimal survival HUD (placeholder styling): time, temperatures, stamina, snow depth, noise.

var _label: Label
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
	_label.text = txt
	_stam_frac = player.stamina / 100.0
	_core_frac = clampf((body.core - 30.0) / 7.0, 0.0, 1.0)
	_warn = body.core < BodyTemperature.SHIVER
	_bars.queue_redraw()


func _draw_bars() -> void:
	var sz := _bars.size
	var w := 220.0
	var x := 24.0
	var y := sz.y - 60.0
	_bars.draw_rect(Rect2(x, y, w, 8), Color(0, 0, 0, 0.5))
	_bars.draw_rect(Rect2(x, y, w * _stam_frac, 8), Color(0.85, 0.9, 0.7) if not player.exhausted else Color(0.9, 0.4, 0.3))
	_bars.draw_rect(Rect2(x, y + 16, w, 8), Color(0, 0, 0, 0.5))
	_bars.draw_rect(Rect2(x, y + 16, w * _core_frac, 8), Color(0.55, 0.75, 1.0) if not _warn else Color(0.4, 0.55, 1.0))
	# crosshair dot
	_bars.draw_circle(sz * 0.5, 1.5, Color(1, 1, 1, 0.6))
