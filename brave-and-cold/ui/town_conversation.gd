class_name TownConversation
extends CanvasLayer
## Optional live exchange. No pause, quest gate or inventory transaction.
var life: Node3D
var actor: TownResident
var is_open := false
var _panel: Panel
var _title: Label
var _line: Label
var _topics: GridContainer
var _close: Button
var _hint: Label
var _prior_ui := false
var _prior_mouse := Input.MOUSE_MODE_CAPTURED
var _health := 0.0
var _phase := 0

func _ready() -> void:
	layer=58; visible=false
	_panel=Panel.new(); add_child(_panel)
	var style:=StyleBoxFlat.new();style.bg_color=Color(.035,.05,.06,.96);style.border_color=Color(.38,.43,.40)
	style.set_border_width_all(1);style.content_margin_left=22;style.content_margin_right=22;style.content_margin_top=16;style.content_margin_bottom=16
	_panel.add_theme_stylebox_override("panel",style)
	_title=UiKit.label("",23);_title.clip_text=true;_panel.add_child(_title)
	_close=UiKit.button("X",40);_close.tooltip_text="Leave conversation (Esc)";_close.pressed.connect(close);_panel.add_child(_close)
	_line=UiKit.label("",21);_line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_line.clip_text=true;_panel.add_child(_line)
	_topics=GridContainer.new();_topics.add_theme_constant_override("h_separation",12);_panel.add_child(_topics)
	_hint=UiKit.label("Esc / X to leave • time continues",14,Color(.65,.70,.67));_panel.add_child(_hint)
	get_viewport().size_changed.connect(_layout);_layout()

func _layout() -> void:
	var size:=get_viewport().get_visible_rect().size
	var width:=minf(940,size.x-36);_topics.columns=3 if width>=880 else 1
	var height:=270.0 if _topics.columns==3 else 370.0
	_panel.size=Vector2(width,height);_panel.position=Vector2((size.x-width)/2,maxf(12,size.y-height-28))
	_title.position=Vector2(22,16);_title.size=Vector2(width-100,34)
	_close.position=Vector2(width-62,12);_close.size=Vector2(40,40)
	_line.position=Vector2(22,60);_line.size=Vector2(width-44,110)
	_topics.position=Vector2(22,178);_topics.size=Vector2(width-44,44 if _topics.columns==3 else 140)
	_hint.position=Vector2(22,height-34);_hint.size=Vector2(width-44,22)

func open(resident: TownResident) -> void:
	if not is_instance_valid(resident):return
	if is_open or life.world.player.ui_open or life.world.player.dead or resident.phase>=TownResidentState.Phase.UNRESPONSIVE: return
	actor=resident;_phase=actor.phase;_health=life.world.player.health
	_prior_ui=life.world.player.ui_open;_prior_mouse=Input.mouse_mode
	life.world.player.ui_open=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;actor.talking=true
	var data: Dictionary=life.dialogue[actor.resident_id]
	_title.text=String(data.name)+" • "+String(data.role)
	_line.text=life.line_for(actor,"greeting")
	for child: Node in _topics.get_children():_topics.remove_child(child);child.queue_free()
	for topic: Dictionary in data.topics:
		var id:=String(topic.id);var button:=UiKit.button(String(topic.label),0)
		button.pressed.connect(func() -> void: choose(id));_topics.add_child(button)
	life.history.remember(actor.resident_id,"greeting")
	actor.acknowledge("greeting")
	is_open=true;visible=true;_layout();_layout.call_deferred()

func choose(topic: String) -> void:
	if not is_open or not is_instance_valid(actor): return
	_line.text=life.line_for(actor,topic);life.history.remember(actor.resident_id,topic);_layout.call_deferred()
	actor.acknowledge(topic)

func close() -> void:
	if not is_open:return
	is_open=false;visible=false
	if is_instance_valid(actor):actor.talking=false;actor.end_exchange()
	if is_instance_valid(life) and is_instance_valid(life.world.player):life.world.player.ui_open=_prior_ui
	Input.mouse_mode=_prior_mouse

func _process(_delta: float) -> void:
	if not is_open:return
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.is_dead() or not actor.talking or actor.phase!=_phase or actor._stagger>0 or life.world.player.dead or life.world.player.health<_health-.01 or actor.global_position.distance_to(life.world.player.position)>4.0:close()

func _input(event: InputEvent) -> void:
	if is_open and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		close();get_viewport().set_input_as_handled()
func _exit_tree() -> void:close()
