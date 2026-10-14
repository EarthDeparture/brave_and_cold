extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func freeze(n: Node) -> void:
	n.set_process(false);n.set_physics_process(false)
	for child: Node in n.get_children():freeze(child)
func build(saved: Dictionary={}) -> Node3D:
	SaveGame.pending=saved;seed(20261004)
	var w: Node3D=load("res://world/game_world.gd").new();root.add_child(w)
	for f in 700:
		await process_frame
		if w.town_life!=null and w.gear!=null:break
	freeze(w);w.out_path="test-no-autosave";return w
func when(w: Node3D,day: int,hour: float) -> void:
	w.clock.day=day;w.clock.hour=hour;w.town_life.update(0)
func run() -> void:
	create_timer(200).timeout.connect(func() -> void:print("FAIL timeout");quit(2))
	var h:=TownResidentState.new()
	for beat: Array in [[1,12,0],[2,12,1],[3,10.5,1],[3,11,2],[3,18,3],[3,21,4],[8,5,4]]:
		check(h.phase("rowan",beat[0],beat[1])==beat[2],"calendar phase "+str(beat))
	h.killed("rowan");check(h.phase("rowan",8,12)==TownResidentState.Phase.DEAD,"early death is terminal, never an infection respawn")
	var w: Node3D=await build();var life: TownLife=w.town_life;var a: TownResident=life.actors.rowan
	check(life.actors.size()==3 and not a.is_in_group("hostile") and a.is_in_group("resident"),"three living residents, separate hostile registration")
	check(not w.zombies.has(a) and not a.from_pop,"named resident is outside anonymous pooling")
	check(life.ledger!=null and not life.closed_sign.visible,"ordinary shop has physical issue ledger and no closed sign")
	var baseline: Zombie=w._new_zombie(life.store.global_position+Vector3(12,0,0),194);baseline.set_process(false)
	check(a._contact_templates.size()==9 and baseline._contact_templates.size()==7,"modular civilian corpse support cannot contaminate the pooled worker geometry cache")
	check(a._skin.get_bone_count()==45 and baseline._skin.get_bone_count()==13 and a._finger_frames.size()==30,"modular civilians retain articulated fingers without changing pooled worker rigs")
	check(a._health_materials.size()==2 and a._health_materials[0]!=life.actors.sam._health_materials[0],"skin deterioration uses private head and hand materials")
	baseline.queue_free()
	w.player.position=life.store.to_global(Vector3(.65,Store.FLOOR_LOCAL_Y+w.player.eye_h,-.65))
	var start:=a.global_position
	for i in 1200:a._process(1.0/60)
	check(start.distance_to(a.global_position)>.15,"shopkeeper really walks between work positions")
	check(life.store.to_local(a.global_position).x>2.25,"routine stays in the clear aisle behind the counter")
	var stock: Array=life.store.looted.duplicate();var parts: bool=w.opening.state.parts_claimed
	life.conversation.open(a)
	check(life.conversation.is_open and w.player.ui_open and not paused,"conversation is optional live UI, without world pause")
	life.conversation.choose("relay");check(life.history.record("rowan").topics.has("relay"),"topic history is saved")
	check(life.store.looted==stock and w.opening.state.parts_claimed==parts,"talking does not issue parts or regenerate loot")
	life.conversation.close();check(not w.player.ui_open,"leaving restores player input")
	life.conversation.open(a);w.player.health-=1;life.conversation._process(.01)
	check(not life.conversation.is_open and not w.player.ui_open,"player damage interrupts live conversation")
	w.player.health+=1
	life.conversation.open(a);var esc:=InputEventKey.new();esc.pressed=true;esc.keycode=KEY_ESCAPE;life.conversation._input(esc)
	check(not life.conversation.is_open and not w.player.ui_open,"Escape closes conversation safely")
	var contact:=a.global_position+Vector3(.10,0,0)
	var q:=life.resolve_at(contact,contact+Vector3.RIGHT,.35)
	var again:=life.resolve_at(Vector3(q.x,contact.y,q.y),contact,.35)
	check(q.distance_to(again)<.0001 and Vector2(a.global_position.x,a.global_position.z).distance_to(q)>.599,"resident clearance is stable, height-aware and idempotent")
	check(life.resolve_at(contact+Vector3.UP*3,contact,.35)==Vector2(contact.x,contact.z),"resident clearance does not affect surfaces above the actor")
	var lin: TownResident=life.actors.lin;w.player.position=lin.global_position+Vector3(0,w.player.eye_h,3)
	when(w,3,8);check(lin.leaving and lin.visible,"observed supporting worker leaves by walking rather than disappearing")
	w.player.position=life.store.to_global(Vector3(.65,Store.FLOOR_LOCAL_Y+w.player.eye_h,-.65))
	when(w,2,14) # fixture calendar positioning; real game only advances forward
	a.hit(17,w.player.position);check(a.hp==83 and not a.is_in_group("hostile"),"injuring a civilian does not activate the infected brain")
	when(w,2,14);check(life.line_for(a,"delivery").contains("held"),"delivery account agrees with dispatch")
	when(w,3,11);check(a.phase==TownResidentState.Phase.ILL and life.closed_sign.visible and life.line_for(a,"greeting").contains("Sunday"),"illness has a prior exposure rather than an unseen trip while watched")
	check(a._health_materials[0].albedo_color.r<.9 and life.actors.sam._health_materials[0].albedo_color==Color.WHITE,"ill owner develops pallor without altering the clinic worker")
	life.conversation.open(a);when(w,3,18)
	check(not life.conversation.is_open and not w.player.ui_open,"deterioration safely ends an active conversation")
	var body_id:=a.get_instance_id();var point:=a.global_position
	for i in 120:a._process(1.0/60)
	check(a._model.rotation.x>.15 and a.hp==83,"same injured body visibly slumps without restoring health")
	when(w,3,21)
	check(a.get_instance_id()==body_id and a.global_position==point and a.infected and a.is_in_group("hostile"),"observed transformation retains identity and position")
	for i in 120:a._process(1.0/60)
	check(a._attack_windup<0 and a.hp==83,"recognition interval gives no immediate attack and keeps damage")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(w._save_data()))
	check(saved.town_life.residents.rowan.hp==83 and saved.town_life.residents.rowan.topics.has("relay"),"world save includes injury and conversation history")
	check(not saved.zombies.any(func(p: Dictionary)->bool:return Vector2(p.x,p.z).distance_to(Vector2(a.global_position.x,a.global_position.z))<.01),"named infection is not duplicated into anonymous zombie save")
	w.queue_free();await process_frame;await process_frame;w=await build(saved);life=w.town_life;a=life.actors.rowan
	check(a.infected and a.hp==83 and life.history.record("rowan").met,"actual reload keeps identity, injury and meeting history")
	# A real pursuit must get around the store's original counter, not ghost through it.
	a.turn_s=3;w.player.position=life.store.to_global(Vector3(.1,Store.FLOOR_LOCAL_Y+w.player.eye_h,1.6));a._target=w.player.position
	for i in 1800:a._move(.85,1.0/60)
	check(life.store.to_local(a.global_position).x<1.0,"infected owner can navigate around the front of the counter")
	a.hit(200,w.player.position);check(life.history.record("rowan").dead,"infected death is permanently recorded")
	var terminal: Dictionary=JSON.parse_string(JSON.stringify(w._save_data()))
	w.queue_free();await process_frame;await process_frame;w=await build(terminal);life=w.town_life;a=life.actors.rowan
	check(a.is_dead() and not a.is_in_group("hostile") and life.history.record("rowan").dead,"reload cannot resurrect the killed owner")
	check(a.infected and a._health_materials[0].albedo_color.r<.7,"infected corpse retains its skin deterioration on reload")
	check(life.actions().any(func(it: Dictionary)->bool:return it.text=="Read Rowan's issue ledger"),"ledger survives death independently of NPC service")
	check(life.history.record("lin").departed or (life.actors.has("lin") and life.actors.lin.leaving),"supporting worker departure survives reload")
	# The existing reserved item transaction must still work after the owner's death.
	w.inv.counts.clear();w.opening.claim_parts();check(w.inv.count("power_relay")==1,"reserved relay remains obtainable after owner death")
	w.opening.claim_parts();check(w.inv.count("power_relay")==1,"repeat collection still cannot duplicate the relay")
	a._dead_t=301;a._process(.1);await process_frame
	check(not life.actors.has("rowan") and life.history.record("rowan").dead,"corpse cleanup releases the actor without losing terminal history")
	var cleared: Dictionary=JSON.parse_string(JSON.stringify(w._save_data()))
	w.queue_free();await process_frame;await process_frame;w=await build(cleared);life=w.town_life
	check(not life.actors.has("rowan") and life.history.record("rowan").dead,"a cleared corpse does not reappear on a real reload")
	var old: Dictionary=JSON.parse_string(JSON.stringify(w._save_data()));old.erase("town_life");old.clock.day=4;old.clock.hour=12
	old.player.x=life.store.global_position.x;old.player.z=life.store.global_position.z;old.erase("lookout_location")
	w.queue_free();await process_frame;await process_frame;w=await build(old);life=w.town_life
	check(life._legacy_wait and not life.actors.has("rowan"),"late legacy save never inserts an unseen infected beside the loaded player")
	var pending: Dictionary=JSON.parse_string(JSON.stringify(w._save_data()))
	check(pending.town_life.arrival_pending,"autosave preserves deferred legacy arrival")
	w.queue_free();await process_frame;await process_frame;w=await build(pending);life=w.town_life
	check(life._legacy_wait and not life.actors.has("rowan"),"reloading pending arrival cannot bypass the proximity guard")
	w.player.position=life.store.global_position+Vector3(50,2,0);life.update(0)
	check(not life._legacy_wait and life.actors.has("rowan") and life.actors.rowan.infected,"departing the area establishes the legacy owner's calendar-correct encounter")
	var count:=life.actors.size();life.update(0);check(life.actors.size()==count,"repeated updates cannot duplicate the named arrival")
	w.queue_free();await process_frame;await process_frame;SaveGame.pending={}
	print("TOWN_LIFE_TEST checks=",checks," failures=",failures);quit(1 if failures else 0)
