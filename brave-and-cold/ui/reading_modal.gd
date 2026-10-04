class_name ReadingModal
extends CanvasLayer
## Focused reading pauses the world and restores its previous input state.
var is_open := false
var player: Player
var hud: Hud
var _panel: Panel
var _body: RichTextLabel
var _title: Label
var _close: Button
var _hint: Label
var _prior_paused := false
var _prior_ui := false
var _prior_hide := false
var _prior_mouse := Input.MOUSE_MODE_CAPTURED

func _init() -> void:
	layer=60;process_mode=Node.PROCESS_MODE_ALWAYS;visible=false

func _ready() -> void:
	var dim:=ColorRect.new();dim.color=Color(.015,.018,.021,.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT);dim.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(dim)
	_panel=Panel.new();add_child(_panel)
	var paper:=StyleBoxFlat.new();paper.bg_color=Color(.84,.80,.68);paper.border_color=Color(.33,.36,.29)
	paper.set_border_width_all(2);paper.content_margin_left=28;paper.content_margin_right=28;paper.content_margin_top=22;paper.content_margin_bottom=22
	_panel.add_theme_stylebox_override("panel",paper)
	_title=UiKit.label("",26,Color(.12,.16,.14));_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_title.add_theme_constant_override("outline_size",0);_panel.add_child(_title)
	_close=UiKit.button("X",44);_close.alignment=HORIZONTAL_ALIGNMENT_CENTER;_close.tooltip_text="Close service log (Esc)"
	_close.pressed.connect(close);_panel.add_child(_close)
	_body=RichTextLabel.new();_body.bbcode_enabled=false;_body.scroll_active=true;_body.selection_enabled=true
	_body.size_flags_vertical=Control.SIZE_EXPAND_FILL;_body.custom_minimum_size=Vector2(0,120)
	_body.add_theme_font_override("normal_font",DZ.font());_body.add_theme_font_size_override("normal_font_size",21)
	_body.add_theme_color_override("default_color",Color(.10,.13,.12));_panel.add_child(_body)
	_hint=UiKit.label("Esc or X to close • play is paused while reading",15,Color(.30,.34,.29));_hint.add_theme_constant_override("outline_size",0)
	_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_panel.add_child(_hint)
	get_viewport().size_changed.connect(_layout);_layout()

func _layout() -> void:
	var screen:=get_viewport().get_visible_rect().size
	var extent:=Vector2(minf(840,screen.x-40),minf(650,screen.y-40))
	_panel.size=extent;_panel.position=(screen-extent)*.5
	_title.position=Vector2(28,22);_title.size=Vector2(extent.x-112,52)
	_close.position=Vector2(extent.x-72,18);_close.size=Vector2(44,44)
	_body.position=Vector2(28,82);_body.size=Vector2(extent.x-56,extent.y-144)
	_hint.position=Vector2(28,extent.y-48);_hint.size=Vector2(extent.x-56,26)

func open(title: String, text: String, actor: Player, overlay: Hud) -> void:
	if is_open or actor.dead or actor.struggling or actor.ui_open:return
	player=actor;hud=overlay
	_prior_paused=get_tree().paused;_prior_mouse=Input.mouse_mode;_prior_ui=player.ui_open;_prior_hide=hud.hide_ui
	_title.text=title;_body.text=text;_body.scroll_to_line(0)
	is_open=true;visible=true;player.ui_open=true;hud.hide_ui=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;get_tree().paused=true;_layout();_layout.call_deferred()

func close() -> void:
	if not is_open:return
	is_open=false;visible=false
	if is_instance_valid(player):player.ui_open=_prior_ui
	if is_instance_valid(hud):hud.hide_ui=_prior_hide
	Input.mouse_mode=_prior_mouse;get_tree().paused=_prior_paused

func _input(event: InputEvent) -> void:
	if not is_open:return
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode==KEY_ESCAPE:close()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if is_open:close()
