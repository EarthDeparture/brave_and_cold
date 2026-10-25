extends SceneTree
## Interior lighting standard: store, clinic, cabin (cold and lit), hut, at noon
## (cloudy) and the store/cabin at night.
var w:Node3D
func _initialize()->void:call_deferred("run")
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func light(hour:float)->void:
	w.clock.hour=hour;w.sky_rig.apply_hour(hour)
	var night:float=w.sky_rig.gameplay_night_factor
	for il:Node in get_nodes_in_group("interior_lighting"):(il as InteriorLighting).update(1.0-night,w.weather.overcast,w.weather.precip)
	for cb:Cabin in w.cabins:cb.set_night(night)
func shot(owner:Node3D,eye:Vector3,target:Vector3,id:String,frames:int=24)->void:
	w.player.position=owner.to_global(eye);w.player.cam.position=Vector3.ZERO
	w.player.cam.look_at(owner.to_global(target));w.player.cam.make_current()
	w._indoor_k=1.0;if w.sky_rig is AtmosphereRig:(w.sky_rig as AtmosphereRig).apply_shelter(1.0)
	for frame in frames:await process_frame
	get_root().get_texture().get_image().save_png("res://shots/interiors/"+id+".png");print("INTERIOR_CAPTURE ",id)
func run()->void:
	root.size=Vector2i(1280,720);SaveGame.pending={};seed(20261004)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/interiors"))
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 700:
		await process_frame
		if w.opening!=null and w.hud!=null and w.collapse!=null:break
	freeze(w);w.hud.visible=false;w.viewmodel.visible=false;w.player.cam.fov=72
	w.weather.lock_state(Weather.S.CLOUDY);w.weather.advance(120,0)
	var store:Store=w.stores[0];var cb:Cabin=w.cabins[0];var f:=Cabin.FLOOR_LOCAL_Y
	if w.town_life!=null:w.town_life.visible=false
	light(12)
	print("STORE_IL windows=",store.interior.window_count()," energy=",store.interior.light_energy_total()," night=",w.sky_rig.gameplay_night_factor," overcast=",w.weather.overcast," spot0=",store.interior._spots[0].global_position," vis=",store.interior._spots[0].visible," detail=",store.detail_enabled)
	await shot(store,Vector3(-2.5,Store.FLOOR_LOCAL_Y+1.6,1.6),Vector3(2.4,Store.FLOOR_LOCAL_Y+.8,-1.6),"store_noon")
	cb.stove_fuel_s=0;cb.set_process(true)
	await shot(cb,Vector3(.6,f+1.6,1.2),Vector3(-2.4,f+.6,-1.0),"cabin_noon_cold")
	if not w.huts.is_empty():
		var hut:Hut=w.huts[0];await shot(hut,Vector3(.9,Hut.FLOOR_LOCAL_Y+1.5,.75),Vector3(-1.2,Hut.FLOOR_LOCAL_Y+.6,-.9),"hut_noon")
	if w.collapse.clinic!=null:
		await shot(w.collapse.clinic,Vector3(3.6,1.9,2.9),Vector3(-3,1.0,-1.5),"clinic_noon")
	light(18.6)
	cb.stove_fuel_s=4*3600
	await shot(cb,Vector3(.6,f+1.6,1.2),Vector3(-2.4,f+.6,-1.0),"cabin_dusk_lit",40)
	light(23)
	await shot(store,Vector3(-2.5,Store.FLOOR_LOCAL_Y+1.6,1.6),Vector3(2.4,Store.FLOOR_LOCAL_Y+.8,-1.6),"store_night")
	await shot(cb,Vector3(.6,f+1.6,1.2),Vector3(-2.4,f+.6,-1.0),"cabin_night_lit",40)
	quit(0)
