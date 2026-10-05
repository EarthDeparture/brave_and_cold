extends SceneTree
## Calendar slots, portable dispatch, missed audio, migration and actual sleep clock.
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func freeze(node: Node) -> void:
	node.set_process(false);node.set_physics_process(false)
	for child: Node in node.get_children(): freeze(child)
func build_world() -> Node3D:
	var w: Node3D=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.reading!=null: break
	freeze(w);return w
func at(w: Node3D, elapsed: float) -> void:
	var absolute: float=elapsed+w.opening.state.calendar_origin_s
	w.clock.total_game_s=elapsed;w.clock.day=int(floor(absolute/86400))+1
	w.clock.hour=fposmod(absolute,86400)/3600
	w.opening.state.last_s=elapsed;w.opening._radio_update()
func run() -> void:
	create_timer(150).timeout.connect(func()->void:print("FAIL diagnostic timeout");quit(2))
	var s:=LookoutAssignment.new();s.receiver_on=true;s.backup_on=true
	check(s.broadcasts.size()==30,"five public days and ten dispatch calls are authored")
	for day in range(1,6):
		for hour in [6,12,17,24]:
			var start: float=(day-1)*86400+hour*3600-s.calendar_origin_s
			var id: String="public_d%d_%02d"%[day,hour]
			check(s.public_broadcast_at(start).get("id","")==id,"calendar slot "+id)
			check(s.public_reserved(start-120) and s.public_reserved(start+1919.99) and not s.public_reserved(start+1920),"guard covers both edges "+id)
			check(s.dispatch_at(start).is_empty(),"dispatch silent at public slot "+id)
			check(s.public_broadcast_at(start+1800).is_empty(),"missed public slot cannot replay "+id)
	for entry: Dictionary in s.broadcasts:
		if entry.device!="dispatch":continue
		var start:=s.entry_start(entry)
		var safe:=true
		for step in range(0,int(entry.window_game_s)+1,30): safe=safe and not s.public_reserved(start+step)
		check(safe,"full dispatch window avoids every public reservation "+String(entry.id))
		check(s.next_dispatch_start(start-1,start+1)==start,"sleep finds call boundary "+String(entry.id))
		var duration: float=s.audio_clips[String(entry.audio).get_file()].seconds*s.audio_clock_rate
		check(s.dispatch_at(start+duration).is_empty(),"finished speech cannot cause a phantom wake "+String(entry.id))
	# Runtime defence if future authored data accidentally overlaps a public slot.
	s.broadcasts.push_front({"id":"bad","device":"dispatch","day":1,"hour":6,"window_game_s":1800})
	check(s.dispatch_at(1800).is_empty() and s.next_dispatch_start(1799,1801)==INF,"overlapping dispatch is rejected with desk powered off too")
	s.receiver_on=false;check(s.dispatch_at(1800).is_empty(),"reservation does not depend on desk switch")
	s.broadcasts.pop_front();s.enabled=false
	check(s.dispatch_at(9000).is_empty() and s.next_dispatch_start(8999,9001)==INF,"disabled opening has no wake calls")
	var alternate:=LookoutAssignment.new();alternate.receiver_on=true;alternate.align_calendar(1,9,0,true)
	check(alternate.public_broadcast_at(3*3600).get("id","")=="public_d1_12","debug start at 09:00 still broadcasts noon at noon")
	check(alternate.public_broadcast_at(0).is_empty(),"debug start cannot replay missed morning")
	SaveGame.pending={};seed(20261004)
	var w: Node3D=await build_world();var op: LookoutOpening=w.opening
	check(absf(w.clock.hour-5.5)<.1,"fresh assignment starts before first 06:00 bulletin")
	check(op.walkie is AudioStreamPlayer and op.walkie.get_parent()==w.player,"walkie is a portable non-spatial player-owned receiver")
	var tuning:=false
	for action: Dictionary in op.actions(): tuning=tuning or String(action.text).contains("Tune")
	check(not tuning and op._channel_label.text=="PUBLIC","desk is public-only with no channel action")
	op.state.receiver_on=false
	w.player.position+=Vector3(250,0,0);at(w,9000+96)
	check(op.walkie.playing and not op.speaker.playing and w.hud.radio_device=="dispatch","dispatch reaches a distant player with desk off")
	check(absf(op.walkie.get_playback_position()-2)<.2,"late live dispatch seeks elapsed audio")
	at(w,op.state.entry_start(op.state.broadcasts.filter(func(e:Dictionary)->bool:return e.id=="dispatch_d4_08")[0])+96)
	op.state.battery_wh=0;op.state.backup_on=false;op.state.relay_enabled=false;op._radio_update()
	check(op.walkie.playing and not op.state.powered(),"personal dispatch survives exhausted site power and disabled repeater")
	op.state.receiver_on=true;at(w,23400+96)
	check(op.speaker.playing and not op.walkie.playing and w.hud.radio_text=="","distant public audio stays at desk and has no remote captions")
	w.player.position=op.speaker.global_position+Vector3(0,.65,1);op._radio_update()
	check(w.hud.radio_device=="public" and absf(op.speaker.get_playback_position()-2)<.2,"approaching desk hears only remaining noon transmission")
	op.read_log();var before: float=w.clock.total_game_s
	check(w.reading._title.text.contains("•") and not w.reading._body.text.contains("â") and w.reading._body.text.contains("06:00, 12:00, 17:00 and 00:00"),"service log clearly labels both devices and bulletin times without broken encoding")
	await create_timer(.05,true).timeout
	check(paused and before==w.clock.total_game_s,"reading pauses live broadcast timeline")
	w.reading.close()
	at(w,23400+800)
	check(w.hud.radio_text!="" and not w.hud.radio_text.begins_with("It is noon") and w.hud.radio_text.length()<op.state.public_broadcast_at(w.clock.total_game_s).text.length(),"late arrival captions only current spoken chunk, not full missed script")
	at(w,23400+1700)
	check(not op.speaker.playing and w.hud.radio_text=="","finished speech never loops inside reserved window")
	at(w,41400);check(op.speaker.playing and not op.walkie.playing,"17:00 starts its unique later-day bulletin")
	# Accelerated sleep crosses a public slot silently, but lands on dispatch.
	w.out_path="test-no-autosave";w.player.health=80;w.body.core=37
	w.player.position=w.fire_lookout.to_global(Vector3(0,FireLookout.DECK_Y+w.player.eye_h,0))
	at(w,1800-12);w._sleep_begin(w.fire_lookout,8);w._sleep_update(w.SLEEP_FADE)
	w._process(.02)
	check(w._sl_on and int(w._sl.phase)==1 and not op.speaker.playing and not op.walkie.playing,"sleeping through public bulletin stays asleep and misses it")
	at(w,9000-12);var hp: float=w.player.health
	w._process(.1)
	check(is_equal_approx(w.clock.total_game_s,9000) and int(w._sl.phase)==1,"accelerated sleep cannot step past dispatch start")
	check(w.player.health-hp<.011,"sleep health gain uses only time actually advanced to call")
	w._process(.1)
	check(int(w._sl.phase)==2 and w.clock.time_scale==48 and w.sleep_last.contains("walkie") and op.walkie.playing,"dispatch wakes player and restores normal clock with live audio")
	w._sl_on=false;w.player.sleeping=false;w.hud.sleep_fade=0
	at(w,9000+1790);w._sleep_begin(w.fire_lookout,8);w._sleep_update(w.SLEEP_FADE);w._process(.1)
	check(int(w._sl.phase)==1 and not op.walkie.playing,"going to bed after dispatch speech ends does not wake to silence")
	w._sleep_restore_clock();w._sl_on=false;w.player.sleeping=false;w.hud.sleep_fade=0
	# Schema-one save: same calendar/power/job/pantry, obsolete channel discarded.
	at(w,18.5*3600);op.state.receiver_on=true;op.state.parts_claimed=true
	var snapshot: Dictionary=JSON.parse_string(JSON.stringify(w._save_data()))
	var old: Dictionary=snapshot.opening.state;old.erase("calendar_origin_s");old.erase("schema");old.channel="work"
	var grid: float=old.grid_fail_s;var source: float=old.source_end_s
	w.queue_free();await process_frame;await process_frame
	SaveGame.pending=snapshot;w=await build_world();op=w.opening;op._radio_update()
	check(w.clock.day==2 and absf(w.clock.hour)<.01 and op.state.public_broadcast_at(w.clock.total_game_s).get("id","")=="public_d1_24","legacy save midnight aligns to closing first-day bulletin")
	check(op.state.grid_fail_s==grid and op.state.source_end_s==source and op.state.parts_claimed,"migration preserves outage dates and assignment progress")
	check(op.state.receiver_on and op._channel_label.text=="PUBLIC" and op.walkie.get_parent()==w.player,"old dispatch desk selection becomes public; portable dispatch supplied")
	check(op.pantry.count("beans")==4,"migration does not refill or consume pantry")
	var fresh: Dictionary=op.state.to_dict()
	check(fresh.schema==2 and not fresh.has("channel") and fresh.has("calendar_origin_s"),"new snapshot retires channels and keeps calendar anchor")
	at(w,23400+1700);var later: Dictionary=JSON.parse_string(JSON.stringify(w._save_data()))
	w.queue_free();await process_frame;await process_frame
	SaveGame.pending=later;w=await build_world();w.opening._radio_update()
	check(not w.opening.speaker.playing and not w.opening.walkie.playing,"load after audio ends does not replay buffered bulletin")
	w.queue_free();await process_frame;await process_frame;SaveGame.pending={}
	print("RADIO_BULLETINS_TEST failures=",failures);quit(1 if failures else 0)
