extends SceneTree
var w: Node3D
var options: Dictionary={}
func _initialize() -> void:call_deferred("run")
func freeze(n: Node) -> void:
	n.set_process(false);n.set_physics_process(false)
	for c: Node in n.get_children():freeze(c)
func shot(id: String) -> void:
	for i in 6:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://shots/town-life/"+id+".png");print("TOWN_CAPTURE ",id)
func look(host: Node3D,eye: Vector3,target: Vector3) -> void:
	w.player.cam.global_position=host.to_global(eye);w.player.cam.look_at(host.to_global(target))
func run() -> void:
	create_timer(150).timeout.connect(func() -> void:quit(2));root.size=Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/town-life"))
	SaveGame.pending={};seed(20261004);w=load("res://world/game_world.gd").new();root.add_child(w)
	for i in 700:
		await process_frame
		if w.town_life!=null and w.gear!=null:break
	freeze(w);w.out_path="capture-no-autosave";w.hud.visible=false
	w.weather.lock_state(Weather.S.CLOUDY);w.weather.advance(120,0);w.clock.hour=12;w.sky_rig.apply_hour(12)
	var life: TownLife=w.town_life;var a: TownResident=life.actors.rowan
	w.player.position=life.store.to_global(Vector3(.50,Store.FLOOR_LOCAL_Y+w.player.eye_h,-.55));a.global_position=life.store.to_global(Vector3(2.52,Store.FLOOR_LOCAL_Y,.32))
	for i in 180:a._process(1.0/60)
	look(life.store,Vector3(.25,1.85,1.30),Vector3(2.50,1.25,.32));await shot("ordinary-counter")
	look(life.store,Vector3(1.08,1.9,.66),Vector3(2.50,1.67,.32));await shot("ordinary-face")
	w.clock.day=2;w.clock.hour=14;life.update(0)
	w.player.position=life.store.to_global(Vector3(.8,Store.FLOOR_LOCAL_Y+w.player.eye_h,.32))
	life.conversation.open(a);life.conversation.choose("delivery");await shot("conversation");life.conversation.close()
	look(life.store,Vector3(.25,1.85,1.30),Vector3(2.50,1.25,.32))
	w.clock.day=3;w.clock.hour=11;life.update(0)
	for i in 180:a._process(1.0/60)
	await shot("ill-counter")
	w.clock.hour=18;life.update(0)
	for i in 180:a._process(1.0/60)
	await shot("unresponsive")
	w.clock.hour=21;life.update(0)
	w.player.god=true
	for i in 205:a._process(1.0/60)
	await shot("infected-counter")
	look(life.store,Vector3(-.20,1.8,5.5),Vector3(.6,1.4,Store.HZ));await shot("closed-shop")
	look(life.store,Vector3(.70,1.85,-1.17),Vector3(1.60,1.416,-1.17));await shot("physical-ledger")
	a.hit(200,w.player.position)
	for i in 90:a._process(1.0/60)
	look(life.store,Vector3(.3,1.9,1.7),Vector3(2.50,.65,.32));await shot("terminal-owner")
	var lin: TownResident=life.actors.lin;lin.visible=true;lin.phase=TownResidentState.Phase.ORDINARY;lin.leaving=false;lin.set_process(false)
	look(life.store,Vector3(-2.2,1.75,8.5),Vector3(-.8,1.05,5.5));await shot("supply-runner")
	var sam: TownResident=life.actors.sam;sam.visible=true;sam.phase=TownResidentState.Phase.ORDINARY;sam.leaving=false;sam.set_process(false)
	look(w.collapse.clinic,Vector3(-3.1,1.8,10.5),Vector3(-1.1,1.05,7));await shot("clinic-worker")
	w.queue_free();await process_frame;SaveGame.pending={};print("TOWN_CAPTURE_COMPLETE");quit()
