extends Control
## Title screen: Start / Options / Quit. Loads the game world after a "loading" frame (world build is heavy).

const GAME := "res://world/game_world.tscn"

var _main: VBoxContainer
var _options: OptionsPanel
var _loading: Label
var _wind: AudioStreamPlayer
var _starting := false


func _ready() -> void:
	Settings.load_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.03, 0.035, 0.03), Color(0.16, 0.18, 0.16)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(tr)
	_add_backdrop()
	_add_snow()
	_main = VBoxContainer.new()
	_main.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_main.offset_left = 110.0
	_main.grow_horizontal = Control.GROW_DIRECTION_END
	_main.grow_vertical = Control.GROW_DIRECTION_BOTH
	_main.alignment = BoxContainer.ALIGNMENT_CENTER
	_main.add_theme_constant_override("separation", 14)
	add_child(_main)
	var title := UiKit.label("BRAVE AND COLD", 64, Color(0.88, 0.89, 0.84))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_main.add_child(title)
	var sub := UiKit.label("survive the cold.  survive the dead.", 20, DZ.ACCENT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_main.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	_main.add_child(gap)
	var specs: Array = [["New Game", _new_game], ["Options", _show_options], ["Quit", _quit]]
	if SaveGame.exists():
		specs.push_front(["Continue", _continue])
	for spec in specs:
		var b := UiKit.button(spec[0])
		b.pressed.connect(spec[1])
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_main.add_child(b)
	var hint := UiKit.label("WASD move   Shift sprint   C crouch   Wheel + E actions   LMB / F attack   X rifle   V flare   B campfire   Tab gear   Esc pause", 14, UiKit.DIM)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.position.y -= 24
	add_child(hint)
	_options = OptionsPanel.new()
	_options.set_anchors_preset(Control.PRESET_CENTER)
	_options.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_options.grow_vertical = Control.GROW_DIRECTION_BOTH
	_options.visible = false
	_options.closed.connect(_show_main)
	add_child(_options)
	_loading = UiKit.label("Loading the valley...", 36)
	_loading.set_anchors_preset(Control.PRESET_CENTER)
	_loading.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_loading.grow_vertical = Control.GROW_DIRECTION_BOTH
	_loading.visible = false
	add_child(_loading)
	_wind = AudioStreamPlayer.new()
	_wind.stream = Sfx.get_stream("wind")
	_wind.volume_db = -16.0
	add_child(_wind)
	_wind.play()
	for a in OS.get_cmdline_user_args():
		if a.begins_with('menushot='):
			await get_tree().create_timer(1.0).timeout
			get_viewport().get_texture().get_image().save_png(a.substr(9))
			print('MENU_SHOT')
			get_tree().quit()
		elif a == 'autostart':
			_new_game()
		elif a == 'autocontinue':
			_continue()


func _add_backdrop() -> void:
	if not ResourceLoader.exists('res://assets/ui/menu_bg.png'):
		return
	var bg := TextureRect.new()
	bg.texture = load('res://assets/ui/menu_bg.png')
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.pivot_offset = get_viewport_rect().size * 0.5
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ vec4 c = texture(TEXTURE, UV); float g = dot(c.rgb, vec3(0.299,0.587,0.114)); vec3 d = mix(vec3(g), c.rgb, 0.45) * vec3(1.02,1.0,0.94); COLOR = vec4(d, c.a); }"
	var smat := ShaderMaterial.new()
	smat.shader = sh
	bg.material = smat
	add_child(bg)
	var tw := create_tween().set_loops()
	tw.tween_property(bg, 'scale', Vector2(1.07, 1.07), 30.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(bg, 'scale', Vector2(1.0, 1.0), 30.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.01, 0.012, 0.01, 0.1), Color(0.01, 0.012, 0.01, 0.7)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.35)
	gt.fill_to = Vector2(0.5, 1.0)
	var shade := TextureRect.new()
	shade.texture = gt
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(shade)


func _add_snow() -> void:
	var p := CPUParticles2D.new()
	p.amount = 220
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1400, 10)
	p.position = Vector2(960, -20)
	p.direction = Vector2(0.35, 1.0)
	p.spread = 12.0
	p.gravity = Vector2(20, 0)
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 150.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 4.0
	p.color = Color(0.9, 0.95, 1.0, 0.7)
	add_child(p)


func _show_options() -> void:
	_main.visible = false
	_options.visible = true


func _show_main() -> void:
	_options.visible = false
	_main.visible = true


func _new_game() -> void:
	SaveGame.pending = {}
	_start()


func _continue() -> void:
	SaveGame.pending = SaveGame.read()
	_start()


func _start() -> void:
	if _starting:
		return
	_starting = true
	_main.visible = false
	_loading.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file(GAME)


func _quit() -> void:
	get_tree().quit()
