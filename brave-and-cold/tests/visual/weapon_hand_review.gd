extends Node3D
## Standalone art review. No inventory, saves or world state are created.
var player:Player
var hands:Viewmodel
var title:Label
func _ready() -> void:
	var env:=WorldEnvironment.new();env.environment=Environment.new();add_child(env)
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.075,.095,.115)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.8,.87,1);env.environment.ambient_light_energy=.65
	env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var sun:=DirectionalLight3D.new();add_child(sun);sun.rotation_degrees=Vector3(-50,-20,0)
	player=Player.new();add_child(player);player.set_process(false);player.set_physics_process(false)
	player.cam=Camera3D.new();player.add_child(player.cam);player.cam.current=true;player.cam.near=.015
	hands=Viewmodel.new();hands.player=player;hands.detail_enabled=true;player.cam.add_child(hands)
	hands.mode="fists";hands._cur="fists";hands._equip=1
	var layer:=CanvasLayer.new();add_child(layer);title=Label.new();layer.add_child(title);title.position=Vector2(20,16)
	title.add_theme_font_size_override("font_size",18);refresh()
func refresh() -> void:
	title.text="%s\n0 empty hands • 1–8 weapon variants • 9 hatchet\nLeft click / Space: strike or fire • Right click: guard / aim\nR: magazine reload • E: empty reload • I: inspect • G: gloves • Hold T: watch" % (hands.weapon_id.replace("_"," ") if hands.mode=="rifle" else hands.mode)
func _process(delta:float) -> void:
	player.aim_k=move_toward(player.aim_k,1.0 if hands.mode=="rifle" and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else 0.0,delta*5)
	player.cam.fov=lerpf(70,36,player.aim_k);hands.watch_override=Input.is_physical_key_pressed(KEY_T)
func strike() -> void:
	if hands.weapon_busy():return
	if hands.mode=="rifle":hands.fire()
	else:hands.swing(hands.mode=="axe")
func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:strike()
	if not (event is InputEventKey and event.pressed and not event.echo):return
	if event.keycode>=KEY_1 and event.keycode<=KEY_8:
		hands.equip_weapon(WeaponPresentation.IDS[event.keycode-KEY_1]);hands.mode="rifle";hands._fire_t=-1
	elif event.keycode==KEY_0:hands.mode="fists"
	elif event.keycode==KEY_9:hands.mode="axe"
	elif event.keycode==KEY_SPACE:strike()
	elif event.keycode==KEY_G:hands.glove_item="hide_mitts" if hands.glove_item=="" else ""
	elif event.keycode==KEY_R:hands.play_weapon_clip("reload_insert" if hands._rifle.is_lever_action() else "reload_tactical")
	elif event.keycode==KEY_E:hands.play_weapon_clip("reload_insert" if hands._rifle.is_lever_action() else "reload_empty")
	elif event.keycode==KEY_I:hands.play_weapon_clip("inspect")
	elif event.keycode==KEY_ESCAPE:get_tree().quit()
	refresh()
