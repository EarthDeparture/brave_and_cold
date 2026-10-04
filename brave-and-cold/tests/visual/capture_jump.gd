extends SceneTree
## Actual Spacebar event in a complete world, plus a short rendered jump film.
var world:Node3D
func _initialize()->void:call_deferred("run")
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func run()->void:
	seed(20261003);SaveGame.pending={};AudioServer.set_bus_mute(0,true)
	world=load("res://world/game_world.gd").new();root.add_child(world)
	for i in 600:
		await process_frame
		if world.hud!=null:break
	if world.hud==null:push_error("World did not start");quit(1);return
	freeze(world);world.hud.hide();DisplayServer.window_set_size(Vector2i(1600,900));await process_frame
	var p:Player=world.player;var road:RoadNet=world.road;var index:=180
	var point:Vector2=road.points[index];var tangent:Vector2=(road.points[index+1]-road.points[index-1]).normalized()
	p.reset_jump();p.position=Vector3(point.x,p._eye_ground(point.x,point.y)+p.eye_h,point.y)
	p.yaw=atan2(-tangent.x,-tangent.y);p.pitch=-.08;p.sim_on=true;p.sim_dir=Vector3(tangent.x,0,tangent.y)
	p._ready_ground=true;p.frozen=false;p._vel=Vector2(tangent.x,tangent.y)*Player.WALK;p.stamina=100
	world.weather.lock_state(Weather.S.CLEAR);world.weather.advance(120,0);world.clock.hour=11
	world.sky_rig.apply_hour(11);world.sky_rig.apply_shelter(0);world.snowfall.hide()
	p._update_aim(0);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var event:=InputEventKey.new();event.keycode=KEY_SPACE;event.physical_keycode=KEY_SPACE;event.pressed=true
	Input.parse_input_event(event);await process_frame
	var start_ok:=p.airborne
	var protected_save:bool=not world._safe_to_save() and not world.save_game()
	var directory:="res://shots/roads-jump/jump-film";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var manifest:Array[Dictionary]=[]
	for frame in 42:
		p._move(1.0/60.0);p._update_aim(1.0/60.0);p._footsteps(1.0/60.0)
		world.viewmodel._process(1.0/60.0)
		await process_frame;await RenderingServer.frame_post_draw
		var path:=directory.path_join("%03d.png"%frame)
		root.get_texture().get_image().save_png(path)
		manifest.append({"frame":frame,"airborne":p.airborne,"eye_y":p.position.y,"floor_y":p._eye_ground(p.position.x,p.position.z),"stamina":p.stamina,"file":path,"sha256":FileAccess.get_sha256(path)})
	var landed:=not p.airborne
	var file:=FileAccess.open(directory.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"space_event_started_jump":start_ok,"save_protected_while_airborne":protected_save,"landed":landed,"captures":manifest},"\t"));file.close()
	print("JUMP_WORLD spacebar=",start_ok," save_guard=",protected_save," landed=",landed)
	quit(0 if start_ok and protected_save and landed else 1)
