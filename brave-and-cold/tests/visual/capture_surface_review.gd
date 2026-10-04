extends SceneTree
## Full-world hand, equipment and movement review. No player saves.
var options:Dictionary={}
var output:String
func _initialize()->void:call_deferred("run")
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func run()->void:
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.split("=",true,1);options[pair[0].trim_prefix("--")]=pair[1] if pair.size()>1 else "1"
	output=String(options.get("capture_out","res://shots/walk-surfaces/review"));DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);DisplayServer.window_set_size(Vector2i(1600,900));AudioServer.set_bus_mute(0,true);SaveGame.pending={};seed(20261003)
	var world:Node3D=load("res://world/game_world.gd").new();root.add_child(world)
	for i in 600:
		await process_frame
		if world.hud!=null:break
	if world.hud==null:push_error("World failed to become ready");quit(1);return
	freeze(world);world.hud.hide();world.player.frozen=false;world.snowfall.hide();world.weather_presentation.hide()
	world.weather.lock_state(Weather.S.CLOUDY);world.weather.advance(120,0);world.clock.hour=12;world.sky_rig.set_cloud_offset(Vector2(.17,.08));world.sky_rig.apply_hour(12)
	var p:Player=world.player;var vm:Viewmodel=world.viewmodel;var camera:Camera3D=p.cam;var records:Array=[]
	if options.has("normal_off"):
		for hand in [vm._right,vm._left]:
			for mesh in [hand.bare,hand.glove]:
				(mesh.get_surface_override_material(0) as StandardMaterial3D).normal_enabled=false
	p.position=Vector3(-120,8.44652,133);camera.position=Vector3.ZERO;camera.look_at(Vector3(-160,10.74652,50))
	for gloves in ["","hide_mitts"]:
		for item in [{"id":"rifle-hip","mode":"rifle","aim":0.0,"fire":-1.0,"swing":-1.0},{"id":"rifle-aim","mode":"rifle","aim":1.0,"fire":-1.0,"swing":-1.0},{"id":"rifle-bolt","mode":"rifle","aim":0.0,"fire":.62,"swing":-1.0},{"id":"axe-rest","mode":"axe","aim":0.0,"fire":-1.0,"swing":-1.0},{"id":"axe-strike","mode":"axe","aim":0.0,"fire":-1.0,"swing":.4},{"id":"fists","mode":"fists","aim":0.0,"fire":-1.0,"swing":-1.0},{"id":"jab","mode":"fists","aim":0.0,"fire":-1.0,"swing":.18}]:
			p.aim_k=item.aim;camera.fov=lerpf(70,36,item.aim)
			vm.mode=item.mode;vm._cur=item.mode;vm._equip=1;vm._clock=0;vm.freeze_t=0;vm._swing_t=-1;vm._fire_t=-1;vm.glove_item=gloves;vm.show()
			if item.fire>=0:vm.fire();vm.freeze_t=item.fire
			if item.swing>=0:vm.swing(item.mode=="axe");vm.freeze_t=item.swing
			vm._process(0)
			for i in 8:await process_frame;await RenderingServer.frame_post_draw
			var id:String=item.id+("-gloves" if gloves!="" else "-bare");var path:=output.path_join(id+".png");root.get_texture().get_image().save_png(path)
			records.append({"id":id,"file":path,"sha256":FileAccess.get_sha256(path)})
	if options.has("hands_only"):
		print("HAND_REVIEW_COMPLETE shots=",records.size());quit();return
	vm.hide();camera.fov=70
	var tower:FireLookout=world.fire_lookout;p.position=tower.to_global(Vector3(.60,FireLookout.DECK_Y+1.4,-.7));camera.look_at(tower.to_global(Vector3(0,FireLookout.DECK_Y+.45,-2.08)));world.sky_rig.apply_shelter(1)
	for i in 12:await process_frame;await RenderingServer.frame_post_draw
	var panelpath:=output.path_join("lookout-maintenance.png");root.get_texture().get_image().save_png(panelpath);records.append({"id":"lookout-maintenance","file":panelpath,"sha256":FileAccess.get_sha256(panelpath)})
	world.sky_rig.apply_shelter(0);vm.mode="fists";vm._cur="fists";vm._swing_t=-1;vm._fire_t=-1;vm.freeze_t=0;vm._equip=1;vm.glove_item="hide_mitts";vm.show();vm._process(0)
	p.reset_jump();p.position=Vector3(-595,400,-72);p.position.y=p.ground_at(-595,-72)+p.eye_h;p._ready_ground=true;p._vel=Vector2.ZERO;p.yaw=PI*.5;p.pitch=-.08;p.aim_k=0;camera.position=Vector3.ZERO
	var key:=InputEventKey.new();key.keycode=KEY_W;key.physical_keycode=KEY_W;key.pressed=true;Input.parse_input_event(key);p.sim_on=false
	var film:Array=[];var last_dy:=0.0;var max_bump:=0.0;var costs:Array[float]=[]
	for frame in 840:
		var old_y:=p.position.y+camera.position.y;var start:=Time.get_ticks_usec();p._move(1.0/60);p._update_aim(1.0/60);p._footsteps(1.0/60);costs.append((Time.get_ticks_usec()-start)/1000.0)
		var dy:=p.position.y+camera.position.y-old_y;max_bump=maxf(max_bump,absf(dy-last_dy));last_dy=dy;vm.freeze_t=-1;vm._process(1.0/60)
		await process_frame;await RenderingServer.frame_post_draw
		if frame%10==0:
			var path:=output.path_join("walk-%03d.png"%frame);root.get_texture().get_image().save_png(path);film.append({"frame":frame,"file":path,"eye":[p.position.x,p.position.y+camera.position.y,p.position.z]})
	key.pressed=false;Input.parse_input_event(key);costs.sort()
	var manifest:Dictionary={"resolution":[root.size.x,root.size.y],"seed":20261003,"gpu":RenderingServer.get_video_adapter_name(),"captures":records,"film":film,"walk_metres":-595-p.position.x,"camera_step_change_max_m":max_bump,"controller_median_ms":costs[420],"controller_p99_ms":costs[831],"hand_sha256":FileAccess.get_sha256("res://assets/models/viewmodel/survivor_hand_rig.glb")}
	var f:=FileAccess.open(output.path_join("manifest.json"),FileAccess.WRITE);f.store_string(JSON.stringify(manifest,"\t"));f.close();print("SURFACE_REVIEW_COMPLETE ",JSON.stringify({"shots":records.size(),"frames":film.size(),"walk_metres":manifest.walk_metres,"bump_m":max_bump,"controller_median_ms":manifest.controller_median_ms,"controller_p99_ms":manifest.controller_p99_ms}));quit()
