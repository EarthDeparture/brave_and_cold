class_name Hud
extends CanvasLayer
## Arma 2 / DayZ-mod style HUD: status pictograms bottom-right (white -> yellow -> red), debug-monitor bottom-left,
## system messages, scroll-wheel action menu left of centre, weapon readout, damage desaturation/vignette.
## F3 toggles the monitor, F4 the developer overlay.

const MSG_LIFE := 8.0
const MAX_MSGS := 6
const SCREEN_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float sat = 1.0;
uniform float dark = 0.0;
uniform float cold = 0.0;
uniform float flash = 0.0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(g), c, sat);
	vec2 q = (SCREEN_UV - 0.5) * vec2(1.0, 0.85);
	float v = smoothstep(0.22, 0.80, length(q));
	c = mix(c, vec3(0.0), v * dark);
	c = mix(c, vec3(0.62, 0.78, 0.98), v * cold * 0.55);
	c = mix(c, vec3(0.55, 0.0, 0.0), flash * (0.2 + 0.7 * v));
	COLOR = vec4(c, 1.0);
}
"""

var prompt := ""          # kept for tests: text of the selected action
var info := ""            # developer overlay extra line
var player: Player
var body: BodyTemperature
var snow: SnowField
var clock: GameClock
var weather: Weather
var needs: Needs
var inv: Inventory
var actions: Array = []   # action-menu lines
var action_sel := 0
var action_t := -1.0       # hold-to-act progress 0..1, -1 = none
var action_label := ""
var rifle_up := false
var kills := 0
var show_monitor := true
var show_dev := false
var hide_ui := false   # gear screen covers everything

var _ui: Control
var _fx: ColorRect
var _fx_mat: ShaderMaterial
var _msgs: Array = []     # [{t, text}]
var _flash := 0.0
var _last_hp := 100.0
var _t := 0.0


func setup(p: Player, b: BodyTemperature, s: SnowField, c: GameClock) -> void:
	player = p
	body = b
	snow = s
	clock = c
	_last_hp = p.health
	_fx = ColorRect.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SCREEN_SHADER
	_fx_mat = ShaderMaterial.new()
	_fx_mat.shader = sh
	_fx.material = _fx_mat
	add_child(_fx)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_ui)
	add_child(_ui)


func say(msg: String) -> void:
	_msgs.append({"t": 0.0, "text": msg})
	while _msgs.size() > MAX_MSGS:
		_msgs.pop_front()


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_F3:
			show_monitor = not show_monitor
		elif e.keycode == KEY_F4:
			show_dev = not show_dev


func _process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	for m in _msgs:
		m["t"] += delta
	while not _msgs.is_empty() and float(_msgs[0]["t"]) > MSG_LIFE:
		_msgs.pop_front()
	if player.health < _last_hp - 0.4:
		_flash = minf(1.0, _flash + (_last_hp - player.health) / 25.0)
	_last_hp = player.health
	_flash = maxf(0.0, _flash - delta * 1.6)
	var h := clampf(player.health / 100.0, 0.0, 1.0)
	_fx_mat.set_shader_parameter("sat", lerpf(0.25, 1.0, smoothstep(0.0, 0.65, h)))
	_fx_mat.set_shader_parameter("dark", (1.0 - smoothstep(0.0, 0.7, h)) * 0.85)
	_fx_mat.set_shader_parameter("cold", clampf((36.0 - body.core) / 3.0, 0.0, 1.0))
	_fx_mat.set_shader_parameter("flash", _flash)
	_ui.queue_redraw()


# ---------------------------------------------------------------- drawing

func _frac_blood() -> float:
	return clampf(player.health / 100.0, 0.0, 1.0)


func _frac_food() -> float:
	return clampf(needs.calories / 1500.0, 0.0, 1.0) if needs != null else 1.0


func _frac_water() -> float:
	return clampf(needs.water / 70.0, 0.0, 1.0) if needs != null else 1.0


func _frac_temp() -> float:
	return clampf((body.core - 32.0) / 4.5, 0.0, 1.0)


func _draw_ui() -> void:
	if player == null:
		return
	if hide_ui:
		return
	var sz := _ui.size
	var k := sz.y / 900.0
	_draw_status(sz, k)
	_draw_weapon(sz, k)
	if show_monitor:
		_draw_monitor(sz, k)
	_draw_messages(sz, k)
	_draw_actions(sz, k)
	_draw_crosshair(sz, k)
	_draw_action(sz, k)
	if player.struggling:
		_draw_struggle(sz, k)
	if show_dev:
		_draw_dev(k)
	if player.dead:
		_draw_death(sz, k)


func _draw_status(sz: Vector2, k: float) -> void:
	var s := 56.0 * k
	var gap := 12.0 * k
	var kinds := ["blood", "food", "water", "temp"]
	var fr := [_frac_blood(), _frac_food(), _frac_water(), _frac_temp()]
	var x0 := sz.x - 28.0 * k - 4.0 * s - 3.0 * gap
	var y := sz.y - 28.0 * k - s
	for i in 4:
		var col := DZ.status_color(fr[i])
		if fr[i] < 0.3:
			col.a = 0.55 + 0.45 * absf(sin(_t * (3.0 + (0.3 - fr[i]) * 12.0)))
		if i == 0 and player.injury.bleeding():
			col = Color(0.85, 0.14, 0.12, 0.65 + 0.35 * absf(sin(_t * 4.0)))   # bleeding: red pulse
		DZ.status_icon(_ui, kinds[i], Rect2(x0 + i * (s + gap), y, s, s), col)
	if player.stamina < 99.0:
		var w := 4.0 * s + 3.0 * gap
		_ui.draw_rect(Rect2(x0, y + s + 6.0 * k, w, 4.0 * k), Color(0, 0, 0, 0.55))
		var sc := Color(0.80, 0.82, 0.72) if not player.exhausted else DZ.WARN
		_ui.draw_rect(Rect2(x0, y + s + 6.0 * k, w * player.stamina / 100.0, 4.0 * k), sc)


func _draw_weapon(sz: Vector2, k: float) -> void:
	if inv == null:
		return
	var right := sz.x - 28.0 * k
	var y := sz.y - 28.0 * k - 56.0 * k - 18.0 * k
	var line := ""
	if rifle_up and inv.count("rifle") > 0:
		line = "HUNTING RIFLE    %d" % inv.count("ammo")
	elif inv.count("axe") > 0:
		line = "HATCHET"
	if line != "":
		DZ.text(_ui, line, Vector2(right - 400.0 * k, y), int(21.0 * k), DZ.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 400.0 * k)
		y -= 26.0 * k
	var q := ""
	if inv.count("flare") > 0:
		q += "[V] Flare x%d    " % inv.count("flare")
	if inv.count("matches") > 0 and inv.count("wood") > 0:
		q += "[B] Campfire"
	if q != "":
		DZ.text(_ui, q.strip_edges(), Vector2(right - 400.0 * k, y), int(14.0 * k), DZ.DIM, HORIZONTAL_ALIGNMENT_RIGHT, 400.0 * k)


func _draw_monitor(sz: Vector2, k: float) -> void:
	var lines: Array[String] = []
	lines.append("Blood: %d" % int(player.health * 120.0))
	for il in player.injury.status_lines():
		lines.append(il)
	if needs != null:
		lines.append("Food: %d kcal" % int(needs.calories))
		lines.append("Water: %d%%" % int(needs.water))
	lines.append("Temperature: %.1f C" % body.core)
	if weather != null:
		lines.append("Air: %.0f C   Feels: %.0f C" % [clock.ambient_c(), body.feels_like])
		lines.append("%s   Wind: %.0f m/s" % [weather.state_name(), weather.wind])
	lines.append("Zombies killed: %d" % kills)
	var hrs := clock.total_game_s / 3600.0
	lines.append("Survived: %d d %d h" % [int(hrs / 24.0), int(fmod(hrs, 24.0))])
	lines.append("Time: %s" % clock.time_string())
	var fs := int(15.0 * k)
	var lh := 19.0 * k
	var y := sz.y - 22.0 * k - lh * (lines.size() - 1)
	for i in lines.size():
		DZ.text(_ui, lines[i], Vector2(24.0 * k, y + i * lh), fs, Color(0.80, 0.82, 0.76, 0.92))


func _draw_messages(sz: Vector2, k: float) -> void:
	var lh := 20.0 * k
	var base := sz.y - 22.0 * k - 19.0 * k * 8.0 - 26.0 * k
	if not show_monitor:
		base = sz.y - 30.0 * k
	var n := _msgs.size()
	for i in n:
		var m: Dictionary = _msgs[n - 1 - i]
		var a := clampf((MSG_LIFE - float(m["t"])) / 2.0, 0.0, 1.0)
		DZ.text(_ui, String(m["text"]), Vector2(24.0 * k, base - i * lh), int(16.0 * k), Color(0.95, 0.85, 0.45, a))


func _draw_actions(sz: Vector2, k: float) -> void:
	if actions.is_empty() or player.dead:
		return
	var x := 54.0 * k
	var y := sz.y * 0.46
	var lh := 26.0 * k
	var fs := int(20.0 * k)
	for i in actions.size():
		var sel: bool = i == action_sel
		var col := DZ.ACCENT if sel else Color(0.78, 0.80, 0.74, 0.78)
		if sel:
			_ui.draw_colored_polygon(PackedVector2Array([Vector2(x - 26.0 * k, y + i * lh - 14.0 * k), Vector2(x - 26.0 * k, y + i * lh + 2.0 * k), Vector2(x - 12.0 * k, y + i * lh - 6.0 * k)]), DZ.ACCENT)
		DZ.text(_ui, String(actions[i]), Vector2(x, y + i * lh), fs, col)
	if actions.size() > 1:
		DZ.text(_ui, "Mouse wheel: select     E: do", Vector2(x, y + actions.size() * lh + 6.0 * k), int(12.0 * k), DZ.DIM)
	else:
		DZ.text(_ui, "E: do", Vector2(x, y + lh + 2.0 * k), int(12.0 * k), DZ.DIM)


func _draw_crosshair(sz: Vector2, k: float) -> void:
	var c := sz * 0.5
	var col := Color(0.9, 0.92, 0.86, 0.6)
	if rifle_up and inv != null and inv.count("rifle") > 0:
		var g := 7.0 * k
		var l := 9.0 * k
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			_ui.draw_line(c + d * g, c + d * (g + l), col, 2.0)
		_ui.draw_circle(c, 1.5, col)
	else:
		_ui.draw_circle(c, 1.6 * maxf(k, 1.0), col)


func _draw_action(sz: Vector2, k: float) -> void:
	if action_t < 0.0:
		return
	var c := sz * 0.5
	var r := 30.0 * k
	_ui.draw_arc(c, r, 0.0, TAU, 48, Color(0, 0, 0, 0.55), 7.0 * k, true)
	_ui.draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * clampf(action_t, 0.0, 1.0), 48, DZ.ACCENT, 5.0 * k, true)
	DZ.text(_ui, action_label, Vector2(c.x - 160.0 * k, c.y + r + 26.0 * k), int(20.0 * k), DZ.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 320.0 * k)


func _draw_struggle(sz: Vector2, k: float) -> void:
	var w := 320.0 * k
	var x := sz.x * 0.5 - w * 0.5
	var y := sz.y * 0.5 + 70.0 * k
	DZ.text(_ui, "STRUGGLE!   mash SPACE / E", Vector2(x, y - 14.0 * k), int(24.0 * k), DZ.ACCENT, HORIZONTAL_ALIGNMENT_CENTER, w)
	_ui.draw_rect(Rect2(x, y, w, 14.0 * k), Color(0, 0, 0, 0.65))
	_ui.draw_rect(Rect2(x, y, w * player.struggle_prog, 14.0 * k), DZ.ACCENT)
	_ui.draw_rect(Rect2(x, y, w, 14.0 * k), DZ.EDGE, false, 1.5)


func _draw_dev(k: float) -> void:
	var tier: int = snow.tier_at(player.position.x, player.position.z)
	var t := "%s   Air %.0f C   Feels %.0f C\n" % [clock.time_string(), clock.ambient_c(), body.feels_like]
	t += "Core %.1f C  %s\n" % [body.core, body.state_name()]
	t += "Snow: %s  (x%.2f speed)\n" % [SnowField.TIER_NAMES[tier], SnowField.PLAYER_SPEED[tier]]
	t += "Noise radius %.0f m%s" % [player.noise_radius(), "   [FIRE]" if player.fire_w > 0.0 else ""]
	if info != "":
		t += "\n" + info
	var y := 28.0 * k
	for line in t.split("\n"):
		DZ.text(_ui, line, Vector2(24.0 * k, y), int(14.0 * k), Color(0.7, 0.9, 0.7))
		y += 18.0 * k


func _draw_death(sz: Vector2, k: float) -> void:
	_ui.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.62))
	var cx := sz.x * 0.5
	DZ.text(_ui, "YOU ARE DEAD", Vector2(cx - 400.0 * k, sz.y * 0.42), int(58.0 * k), Color(0.80, 0.80, 0.76), HORIZONTAL_ALIGNMENT_CENTER, 800.0 * k)
	DZ.text(_ui, player.death_cause, Vector2(cx - 400.0 * k, sz.y * 0.42 + 44.0 * k), int(22.0 * k), DZ.ACCENT, HORIZONTAL_ALIGNMENT_CENTER, 800.0 * k)
	var hrs := clock.total_game_s / 3600.0
	DZ.text(_ui, "You survived %d d %d h.   Zombies killed: %d" % [int(hrs / 24.0), int(fmod(hrs, 24.0)), kills], Vector2(cx - 400.0 * k, sz.y * 0.42 + 80.0 * k), int(18.0 * k), DZ.DIM, HORIZONTAL_ALIGNMENT_CENTER, 800.0 * k)
	DZ.text(_ui, "R: respawn from last save       M: main menu", Vector2(cx - 400.0 * k, sz.y * 0.42 + 130.0 * k), int(18.0 * k), DZ.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 800.0 * k)
