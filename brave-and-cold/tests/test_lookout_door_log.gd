extends SceneTree
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func freeze(node: Node) -> void:
	node.set_process(false);node.set_physics_process(false)
	for child:Node in node.get_children():freeze(child)
func aimed(world: Node3D, at: Vector3, target: Vector3) -> void:
	world.player.position=at
	var d:Vector3=target-at
	world.player.yaw=atan2(-d.x,-d.z);world.player.pitch=atan2(d.y,Vector2(d.x,d.z).length())
func run() -> void:
	SaveGame.pending={};seed(20261004)
	var w:Node3D=load("res://world/game_world.gd").new();root.add_child(w)
	for frame:int in 600:
		await process_frame
		if w.reading!=null and w.opening!=null:break
	if w.opening==null or w.reading==null:check(false,"opening compiles and builds");quit(1);return
	freeze(w)
	var t:FireLookout=w.fire_lookout
	var p:Player=w.player
	var leaf:=t._door_pivot.find_child("lookout_door",true,false) as MeshInstance3D
	check(leaf!=null and not t.door_open,"authored leaf is separate and starts closed")
	var start:=t.to_global(Vector3(0,FireLookout.DECK_Y,1.55))
	var finish:=t.to_global(Vector3(0,FireLookout.DECK_Y,2.70))
	var result:=t.resolve_at(finish,start,.35)
	check(result.distance_to(Vector2(finish.x,finish.z))>.4,"closed door stops both-direction tunneling")
	result=t.resolve_at(start,finish,.35)
	check(result.distance_to(Vector2(start.x,start.z))>.4,"closed door blocks entry from deck")
	var shared:=RoadNet.resolve_actor(finish,start,.35)
	check(shared.distance_to(Vector2(finish.x,finish.z))>.4,"shared creature resolver respects elevated door")
	var eye:=start+Vector3.UP
	var direction:Vector3=(finish-start).normalized()
	check(HitZones.building_block([t],eye,direction,3)<1,"closed door also blocks weapon traces")
	var lower:=Vector3(finish.x,t.global_position.y,finish.z)
	result=t.resolve_door_at(lower,Vector3(start.x,t.global_position.y,start.z),.35)
	check(result==Vector2(lower.x,lower.z),"door never blocks actors on ground beneath tower")
	t.restore_door({"open":true})
	result=t.resolve_at(finish,start,.35)
	check(result.distance_to(Vector2(finish.x,finish.z))<.001,"fully open door passes player capsule")
	check(HitZones.building_block([t],eye,direction,3)==INF,"open doorway passes weapon traces")
	aimed(w,t.to_global(Vector3(0,FireLookout.DECK_Y+p.eye_h,1.55)),t.door_world_pos())
	w._toggle_lookout_door();check(t.door_open,"closing refuses occupied swing rather than pushing player")
	aimed(w,t.to_global(Vector3(0,FireLookout.DECK_Y+p.eye_h,.60)),t.door_world_pos())
	w._toggle_lookout_door()
	check(not t.door_open,"clear swing permits close")
	await create_timer(.6).timeout
	check(absf(t._door_pivot.rotation.y)<.001,"leaf actually animates to closed hinge angle")
	w._toggle_lookout_door();await create_timer(.6).timeout
	check(t.door_open and absf(t._door_pivot.rotation.y-deg_to_rad(105))<.001,"leaf actually animates open")
	t.restore_door({})
	var cands:Array=[];w.inv.add("hammer");w.inv.add("plank",4);w.inv.add("nails",4)
	aimed(w,t.to_global(Vector3(0,FireLookout.DECK_Y+p.eye_h,.95)),t.door_inside_pos())
	w._door_cands(cands,t,Vector3.FORWARD)
	var board:Dictionary={}
	for c:Dictionary in cands:
		if String(c.text).begins_with("Barricade door ("):board=c;break
	check(not board.is_empty(),"same cabin barricade action offered inside lookout")
	var planks:int=w.inv.count("plank");var nails:int=w.inv.count("nails")
	w._act_begin(board);w._act_update(.5,false)
	check(t.door_boards==0 and w.inv.count("plank")==planks and w.inv.count("nails")==nails,"cancelled board task consumes nothing")
	w._act_begin(board);check(is_equal_approx(w._act_hold,3),"barricade retains existing halved action duration")
	w._act_update(3.01,true)
	check(t.door_boards==1 and w.inv.count("plank")==planks-1 and w.inv.count("nails")==nails-1,"completion consumes one plank and nail")
	check(t._door_planks.get_child_count()==1,"barricade is visible at door")
	t.toggle_door();check(not t.door_open,"barricaded door cannot open")
	t.bash_door(15);check(t.door_hp==100 and t.door_plank_hp==25,"boards absorb damage before door")
	var saved:Dictionary=JSON.parse_string(JSON.stringify(w._save_data()))
	t.restore_door({"open":true});w._apply_save(saved)
	check(not t.door_open and t.door_boards==1 and t.door_plank_hp==25,"save restores board count and partial damage")
	cands=[];w._door_cands(cands,t,Vector3.FORWARD)
	for c:Dictionary in cands:
		if String(c.text)=="Pull off door plank":(c.act as Callable).call();break
	check(t.door_boards==0 and w.inv.count("plank")==planks and w.inv.count("nails")==nails,"removal returns original materials")
	t.bash_door(100);check(t.door_broken and t.door_open,"unreinforced door breaks under damage")
	var broken:Dictionary=t.door_to_dict();t.restore_door({});t.restore_door(broken)
	check(t.door_broken and t.door_hp==0 and not t.add_door_board(),"broken-door state persists and cannot be boarded")
	var legacy:Dictionary=JSON.parse_string(JSON.stringify(w._save_data()));legacy.erase("lookout_door")
	t.restore_door({});w._apply_save(legacy)
	check(t.door_open,"pre-fix save retains its formerly open doorway")
	t.restore_door({})
	var facing:=Basis(Vector3.UP,FireLookout.STOVE_YAW)*Vector3.BACK
	var center:=(Vector3.ZERO-FireLookout.STOVE_CENTER).normalized()
	check(facing.dot(center)>.9999,"stove front points at living-space center")
	check((w.opening.ember.global_basis.z.normalized()).dot((t.global_basis*facing).normalized())>.9999,"ember front rotates with stove mesh")
	var old_mode:int=Input.mouse_mode;var hp:float=p.health;var clock:float=w.clock.total_game_s
	w.opening.read_log()
	check(w.reading.is_open and paused and p.ui_open and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"log opens focused modal and pauses play")
	check(w.reading._body.text.contains("Depot and access") and w.reading._body.text.contains("Field dispatch") and w.reading._body.text.contains("Overnight stock"),"whole log appears together, including directions and practical notes")
	await create_timer(.1,true).timeout
	check(w.reading._panel.get_global_rect().end.y<=root.get_visible_rect().end.y,"log panel never extends below viewport")
	var tab:=InputEventKey.new();tab.keycode=KEY_TAB;tab.pressed=true;Input.parse_input_event(tab);await process_frame
	check(w.reading.is_open and not w.gear.is_open,"reading consumes gear shortcut")
	tab.pressed=false;Input.parse_input_event(tab)
	check(p.health==hp and w.clock.total_game_s==clock,"reading never advances survival or broadcast time")
	var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
	Input.parse_input_event(escape);await process_frame
	check(not w.reading.is_open and not paused and not w.pause_menu.visible,"Escape closes reader without opening pause menu")
	check(not p.ui_open and Input.mouse_mode==old_mode and not w.hud.hide_ui,"reader restores gameplay and cursor state")
	escape.pressed=false;Input.parse_input_event(escape)
	w.opening.read_log();await process_frame
	var swings:int=w.swing_n
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.position=w.reading._close.get_global_rect().get_center();click.global_position=click.position
	var motion:=InputEventMouseMotion.new();motion.position=click.position;motion.global_position=click.position
	root.push_input(motion,true);await process_frame
	click.pressed=true;click.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(click,true);await process_frame
	click.pressed=false;click.button_mask=0;root.push_input(click,true);await process_frame
	check(not w.reading.is_open and not paused and w.swing_n==swings,"actual X click closes without attacking")
	w.queue_free();await process_frame;await process_frame
	check(FireLookout.instances.is_empty(),"door registry clears on scene exit")
	SaveGame.pending={}
	print("LOOKOUT_DOOR_LOG_TEST failures=",failures)
	quit(1 if failures>0 else 0)
