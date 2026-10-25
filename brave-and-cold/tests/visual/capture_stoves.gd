extends SceneTree
## F5 stoves: hut box stove and store pot-belly, inside (lit) and outside (chimney smoke).
var w:Node3D
func _initialize()->void:call_deferred("run")
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func light(hour:float)->void:
	w.clock.hour=hour;w.sky_rig.apply_hour(hour)
	var night:float=w.sky_rig.gameplay_night_factor
	for il:Node in get_nodes_in_group("interior_lighting"):(il as InteriorLighting).update(1.0-night,w.weather.overcast,w.weather.precip)
func shot(owner:Node3D,eye:Vector3,target:Vector3,id:String,indoor:bool,frames:int=40)->void:
	w.player.position=owner.to_global(eye);w.player.cam.position=Vector3.ZERO
	w.player.cam.look_at(owner.to_global(target));w.player.cam.make_current()
	w._indoor_k=1.0 if indoor else 0.0
	if w.sky_rig is AtmosphereRig:(w.sky_rig as AtmosphereRig).apply_shelter(1.0 if indoor else 0.0)
	for frame in frames:await process_frame
	get_root().get_texture().get_image().save_png("res://shots/stoves/"+id+".png");print("STOVE_CAPTURE ",id)
func run()->void:
	root.size=Vector2i(1280,720);SaveGame.pending={};seed(20261004)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/stoves"))
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 700:
		await process_frame
		if w.opening!=null and w.hud!=null and w.collapse!=null:break
	freeze(w);w.hud.visible=false;w.viewmodel.visible=false;w.player.cam.fov=72
	w.weather.lock_state(Weather.S.CLOUDY);w.weather.advance(120,0)
	if w.town_life!=null:w.town_life.visible=false
	var store:Store=w.stores[0];var hut:Hut=w.huts[0]
	for st:Stove in [store.stove,hut.stove]:
		st.fire.set_fuel(4*3600);st.set_process(true)
		FireVisual.set_smoke(st.smoke, st.fire, w.weather.wind_dir)
	print("STORE detail=",store.detail_enabled," HX=",Store.HX," HZ=",Store.HZ," stove=",store.stove.position)
	light(17.5)
	var hf:=Hut.FLOOR_LOCAL_Y
	await shot(hut,Vector3(-.3,hf+1.55,-.6),Vector3(1.15,hf+.35,.85),"hut_stove_in",true)
	await shot(hut,Vector3(.4,hf+1.6,-.9),Vector3(1.1,hf+.3,.85),"hut_stove_in2",true)
	var sf:=Store.FLOOR_LOCAL_Y
	await shot(store,Vector3(.6,sf+1.6,1.4),Vector3(-1.87,sf+.6,-.45),"store_stove_in",true)
	await shot(store,Vector3(-1.2,sf+2.5,.4),Vector3(-1.87,sf,-.5),"store_stove_top",true)
	await shot(hut,Vector3(9,4,9),Vector3(1.2,3.5,.8),"hut_stove_out",false,90)
	await shot(store,Vector3(-7,4.5,6),Vector3(-1.8,4.0,-1.0),"store_stove_out",false,90)
	quit(0)
func freeze_except(n:Node)->void:
	if n==null:return
	n.set_process(true);n.process_mode=Node.PROCESS_MODE_ALWAYS
	if n is GPUParticles3D:(n as GPUParticles3D).emitting=true
