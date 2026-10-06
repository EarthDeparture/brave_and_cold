extends SceneTree
var failures:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func freeze(n:Node)->void:
	n.set_process(false);n.set_physics_process(false)
	for child:Node in n.get_children():freeze(child)
func at(w:Node3D,elapsed:float)->void:
	var s:LookoutAssignment=w.opening.state
	var absolute:=elapsed+s.calendar_origin_s;w.clock.total_game_s=elapsed
	w.clock.day=int(floor(absolute/86400))+1;w.clock.hour=fposmod(absolute,86400)/3600
	s.last_s=elapsed;w.opening.update_presentation();w.opening._radio_update()
func aim(w:Node3D,pos:Vector3,target:Vector3)->void:
	w.player.position=pos;var d:=target-pos
	w.player.yaw=atan2(-d.x,-d.z);w.player.pitch=atan2(d.y,Vector2(d.x,d.z).length())
func key(code:Key)->void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true
	Input.parse_input_event(e);await process_frame;e.pressed=false;Input.parse_input_event(e);await process_frame
func run()->void:
	create_timer(150).timeout.connect(func()->void:print("FAIL timeout");quit(2))
	SaveGame.pending={};seed(20261004)
	var w:Node3D=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.gear!=null:break
	freeze(w);w.out_path="test-no-autosave"
	var op:LookoutOpening=w.opening;var s:=op.state;var t:FireLookout=w.fire_lookout;var p:Player=w.player
	check(not s.walkie_carried and op.dock_handset.visible,"fresh handset is visibly docked")
	check(op.charger_model!=null and op.charger_lens!=null,"original charger and charge indicator build")
	await key(KEY_TAB)
	check(w.gear.is_open and not paused and w.gear.watch_text()=="WRISTWATCH • Day 1  05:30","Tab opens inventory with permanent watch at world time")
	w.clock.advance(60/w.clock.time_scale);w.gear._process(0)
	check(w.gear.watch_text().ends_with("05:31"),"watch updates while inventory remains open")
	w.clock.day=2;w.clock.hour=23+59.5/60;w.clock.advance(60/w.clock.time_scale)
	check(w.gear.watch_text().ends_with("Day 3  00:00"),"watch handles midnight and day rollover")
	w.gear._craft_mode=true;w.gear._c.queue_redraw();await process_frame
	check(w.gear.is_open and w.gear.watch_text().contains("Day 3"),"watch remains available in crafting view")
	await key(KEY_ESCAPE);check(not w.gear.is_open and not p.ui_open,"Escape returns from watch inventory to play")
	w.gear._craft_mode=false
	w.gear.open_chest(op.pantry);w.gear._c.queue_redraw();await process_frame
	check(w.gear._tab=="chest" and w.gear.watch_text().contains("Day 3"),"watch remains visible when accessing home storage")
	w.gear.close()
	var old_opening:LookoutOpening=w.opening;w.opening=null;w.gear.open();w.gear._c.queue_redraw();await process_frame
	check(w.gear.watch_text().contains("Day 3"),"legacy survival without lookout still has watch")
	w.gear.close();w.opening=old_opening
	p.position=op.charger_model.global_position+Vector3(250,1,0);at(w,9000+96)
	check(not op.walkie.playing and op.dock_speaker.playing and w.hud.radio_heading=="","leaving docked walkie behind loses remote dispatch")
	check(op.next_dispatch_wake(8999,9001)==INF and op.dispatch_for_player(9096).is_empty(),"remote docked walkie cannot cause sleep wake")
	op.toggle_walkie_dock();check(not s.walkie_carried,"walkie cannot be collected remotely")
	at(w,23400+96);s.receiver_on=true;op._radio_update()
	check(not op.walkie.playing and w.hud.radio_heading=="","docked handset cannot provide public captions remotely")
	# Collect via the actual aim/action/input path, not just the helper.
	var stance:=t.to_global(Vector3(2.10,FireLookout.DECK_Y+p.eye_h,-.30))
	aim(w,stance,op.charger_model.global_position+Vector3.UP*.1);w._update_prompt()
	var offered:=false
	for c:Dictionary in w._cands_cache:offered=offered or String(c.text).begins_with("Take walkie")
	check(offered,"desk offers aimed Take walkie action")
	check(String(w._cur.get("text","")).begins_with("Take walkie"),"aiming handset selects it ahead of nearby desk props")
	await key(KEY_E)
	check(s.walkie_carried and not op.dock_handset.visible,"E takes unique handset and leaves empty cradle")
	p.position+=Vector3(250,0,0);at(w,23400+s.audio_clock_rate*2)
	check(op.walkie.playing and w.hud.radio_device=="public" and w.hud.radio_heading.begins_with("PERSONAL WALKIE"),"carried handset receives public bulletin away from home")
	check(absf(op.walkie.get_playback_position()-2)<.2,"pickup during live bulletin seeks remaining speech")
	s.receiver_on=false;op._radio_update()
	check(op.walkie.playing and not op.speaker.playing,"desk off never turns off portable public monitoring")
	s.last_s=s.grid_fail_s+3600;s.battery_wh=0;s.backup_on=false;s.walkie_wh=3
	var entry:Dictionary=s.broadcasts.filter(func(e:Dictionary)->bool:return e.id=="public_d4_12")[0]
	at(w,s.entry_start(entry)+96)
	check(op.walkie.playing and not s.powered(),"portable public news survives complete home blackout")
	s.walkie_wh=0;op._radio_update()
	check(not op.walkie.playing and w.hud.radio_heading=="","empty portable battery loses public reception")
	at(w,9000+96);check(op.dispatch_for_player(s.last_s).is_empty() and not op.walkie.playing,"empty portable battery also loses dispatch")
	check(op.next_dispatch_wake(8999,9001)==INF,"empty handset never caps accelerated sleep for inaudible call")
	s.walkie_wh=.0002;s.last_s=8990
	check(op.next_dispatch_wake(8990,9001)==INF,"battery that expires before next call does not cause phantom wake")
	s.walkie_wh=12;s.receiver_on=true;s.backup_on=false
	p.position=op.speaker.global_position+Vector3(0,.65,1);at(w,23400+96)
	check(op.speaker.playing and not op.walkie.playing and not op.dock_speaker.playing and w.hud.radio_heading.begins_with("DESK RADIO"),"nearby working desk owns public playback without doubled voices")
	s.receiver_on=false;op._radio_update()
	check(op.walkie.playing and not op.speaker.playing,"nearby handset takes over when desk receiver is off")
	op.toggle_walkie_dock()
	check(not s.walkie_carried and op.dock_handset.visible and op.dock_speaker.playing and not op.walkie.playing,"docking transfers ongoing monitoring to spatial desk handset")
	at(w,9000+96)
	check(not op.dispatch_for_player(s.last_s).is_empty() and w.hud.radio_heading.begins_with("DESK WALKIE"),"docked handset can deliver nearby dispatch")
	s.walkie_wh=0;op.update_presentation();op._radio_update()
	check(s.walkie_ready() and op.dock_speaker.playing,"empty docked handset still receives on mains")
	check(op.next_dispatch_wake(8999,9001)==9000,"nearby powered cradle can wake player even if battery initially empty")
	var cm:=op.charger_lens.material_override as StandardMaterial3D
	check(cm.emission_enabled and cm.albedo_color.r>cm.albedo_color.g,"empty powered cradle displays amber charge indicator")
	s.walkie_wh=12;op.update_presentation()
	check(cm.emission_enabled and cm.albedo_color.g>cm.albedo_color.r,"full powered cradle displays green indicator")
	s.last_s=s.grid_fail_s;s.backup_on=false;op.update_presentation()
	check(not cm.emission_enabled,"unpowered cradle charge indicator switches off")
	s.walkie_wh=4.7;s.backup_on=true;s.battery_wh=31
	var snap:Dictionary=JSON.parse_string(JSON.stringify(w._save_data()))
	# Door motion must work in occupied swing and never push an actor.
	t.restore_door({})
	var pivot:=t._door_pivot.global_position;var end:=t._door_pivot.to_global(Vector3(1.1,0,0))
	var embedded:Vector3=(pivot+end)*.5;embedded.y=t.global_position.y+FireLookout.DECK_Y
	p.position=embedded+Vector3.UP*p.eye_h;var old_pos:=p.position
	w._toggle_lookout_door()
	check(t.door_open and p.position==old_pos,"door opens while player occupies closed leaf without moving them")
	var away:=embedded+t.global_basis*Vector3(0,0,.8)
	check(t.resolve_door_at(away,embedded,.35)==Vector2(away.x,away.z),"moving leaf never pushes occupying capsule")
	await create_timer(.6).timeout
	w._toggle_lookout_door();await create_timer(.6).timeout
	check(not t.door_open and p.position==old_pos,"door closes through player without displacing them")
	for side:float in [-1.0,1.0]:
		away=embedded+t.global_basis*Vector3(0,0,.8*side)
		check(t.resolve_door_at(away,embedded,.35)==Vector2(away.x,away.z),"embedded capsule can step clear on side "+str(side))
	# Many small movement frames must remain blocked after normal leaf contact,
	# rather than being mistaken for the embedded-player escape exception.
	for side:float in [-1.0,1.0]:
		var foot:=embedded+t.global_basis*Vector3(0,0,.8*side)
		for frame in 120:
			var target:=foot+t.global_basis*Vector3(0,0,-.03*side)
			var q:=t.resolve_door_at(target,foot,.35);foot.x=q.x;foot.z=q.y
		var local:=t.to_local(foot);var middle:=t.to_local(embedded)
		check((local.z-middle.z)*side>.37,"ordinary repeated contact cannot pass closed leaf on side "+str(side))
	var start:=t.to_global(Vector3(0,FireLookout.DECK_Y,1.55));var finish:=t.to_global(Vector3(0,FireLookout.DECK_Y,2.7))
	check(t.resolve_door_at(finish,start,.35).distance_to(Vector2(finish.x,finish.z))>.4,"stationary closed door still blocks ordinary crossing")
	p.position=t.to_global(Vector3(0,FireLookout.DECK_Y+p.eye_h,.6))
	var proxy:=Node3D.new();w.add_child(proxy);proxy.add_to_group("hostile");proxy.global_position=embedded
	w._toggle_lookout_door();check(t.door_open,"actor in swing cannot veto door opening")
	await create_timer(.6).timeout;w._toggle_lookout_door();check(not t.door_open,"actor in swing cannot veto closing")
	proxy.queue_free();await create_timer(.6).timeout
	t.add_door_board();w._toggle_lookout_door();check(not t.door_open,"barricades still prevent opening until removed")
	w.queue_free();await process_frame;await process_frame
	SaveGame.pending=snap
	var loaded:Node3D=load("res://world/game_world.gd").new();root.add_child(loaded)
	for frame in 600:
		await process_frame
		if loaded.opening!=null and loaded.reading!=null:break
	freeze(loaded);var restored:LookoutOpening=loaded.opening
	check(not restored.state.walkie_carried and is_equal_approx(restored.state.walkie_wh,4.7) and restored.state.battery_wh==31 and restored.dock_handset.visible,"fresh world restores physical dock and exact charge without refill")
	loaded._ensure_gear();loaded.gear.open();loaded.gear._c.queue_redraw();await process_frame
	check(loaded.gear.watch_text()=="WRISTWATCH • "+loaded.clock.time_string(),"loaded inventory watch remains aligned to saved world calendar")
	loaded.gear.close();loaded.queue_free();await process_frame;await process_frame;SaveGame.pending={}
	print("WATCH_WALKIE_DOOR_TEST checks=",checks," failures=",failures);quit(1 if failures else 0)
