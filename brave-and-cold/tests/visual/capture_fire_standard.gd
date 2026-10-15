extends SceneTree
## Fire standard look check: cabin stove with the shared drying rack + pans, and a
## campfire lit vs on embers at dusk.
var w:Node3D
func _initialize()->void:call_deferred("run")
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func shot(eye:Vector3,target:Vector3,id:String,frames:int=20)->void:
	w.player.position=eye;w.player.cam.position=Vector3.ZERO
	w.player.cam.look_at(target);w.player.cam.make_current()
	for frame in frames:await process_frame
	get_root().get_texture().get_image().save_png("res://shots/fire-standard/"+id+".png");print("FIRE_CAPTURE ",id)
func run()->void:
	root.size=Vector2i(1280,720);SaveGame.pending={};seed(20261004)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/fire-standard"))
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.hud!=null:break
	freeze(w);w.hud.visible=false;w.viewmodel.visible=false;w.player.cam.fov=72
	w.clock.hour=11;w.sky_rig.apply_hour(11)
	var cb:Cabin=w.cabins[0];cb.set_process(true);cb.stove_fuel_s=4*3600
	var inv:=Inventory.new();inv.add("knife");inv.add("venison_cooked",4);cb.fire.rack.begin(inv)
	var raw:=Inventory.new();raw.add("trout_raw",2);cb.fire.cooking.begin(raw,true);cb.fire.cooking.begin(raw,true);cb.refresh_fire()
	var f:=Cabin.FLOOR_LOCAL_Y
	await shot(cb.to_global(Vector3(.6,f+1.6,1.2)),cb.to_global(Vector3(-2.4,f+.6,-1.0)),"cabin_stove_rack",40)
	await shot(cb.to_global(Vector3(-1.2,f+1.5,.4)),cb.to_global(Vector3(-2.8,f+.65,-.55)),"cabin_rack_close",30)
	var cf:=Campfire.new();w.add_child(cf);w.campfires.append(cf)
	var site:Vector3=w._ground(cb.global_position.x+9,cb.global_position.z+9);cf.global_position=site
	w.clock.hour=19.2;w.sky_rig.apply_hour(19.2)
	cf.fuel_s=3*3600
	await shot(site+Vector3(2.4,1.6,2.4),site+Vector3(0,.3,0),"campfire_lit",40)
	cf.fuel_s=0;cf.fire.ember_s=1800
	await shot(site+Vector3(2.4,1.6,2.4),site+Vector3(0,.3,0),"campfire_embers",150)
	cf.fire.ember_s=0
	await shot(site+Vector3(2.4,1.6,2.4),site+Vector3(0,.3,0),"campfire_cold_ash",30)
	w.clock.hour=11;w.sky_rig.apply_hour(11);cb.stove_fuel_s=4*3600
	cb.smoke.set_process(true);FireVisual.set_smoke(cb.smoke,cb.fire,Vector2(.6,.2))
	await shot(cb.to_global(Vector3(9,2.2,9)),cb.to_global(Vector3(-2.35,4.6,-1.75)),"cabin_chimney_smoke",200)
	await shot(cb.to_global(Vector3(-1.6,f+1.0,-.6)),cb.to_global(Vector3(-2.35,f+.42,-1.46)),"cabin_ember_window",30)
	quit(0)
