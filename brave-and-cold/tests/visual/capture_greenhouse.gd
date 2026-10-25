extends SceneTree
## Phase F greenhouse: outside at noon, inside with crops at several stages, inside at dusk with the stove lit.
var w:Node3D
func _initialize()->void:call_deferred("run")
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func light(hour:float)->void:
	w.clock.hour=hour;w.sky_rig.apply_hour(hour)
	var night:float=w.sky_rig.gameplay_night_factor
	for il:Node in get_nodes_in_group("interior_lighting"):(il as InteriorLighting).update(1.0-night,w.weather.overcast,w.weather.precip)
func shot(owner:Node3D,eye:Vector3,target:Vector3,id:String,indoor:bool)->void:
	w.player.position=owner.to_global(eye);w.player.cam.position=Vector3.ZERO
	w.player.cam.look_at(owner.to_global(target));w.player.cam.make_current()
	w._indoor_k=1.0 if indoor else 0.0
	if w.sky_rig is AtmosphereRig:(w.sky_rig as AtmosphereRig).apply_shelter(1.0 if indoor else 0.0)
	for frame in 40:await process_frame
	get_root().get_texture().get_image().save_png("res://shots/greenhouse/"+id+".png");print("GH_CAPTURE ",id)
func run()->void:
	root.size=Vector2i(1280,720);SaveGame.pending={};seed(20261004)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/greenhouse"))
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 700:
		await process_frame
		if w.opening!=null and w.hud!=null and w.collapse!=null:break
	freeze(w);w.hud.visible=false;w.viewmodel.visible=false;w.player.cam.fov=70
	w.weather.lock_state(Weather.S.CLOUDY);w.weather.advance(120,0)
	if w.town_life!=null:w.town_life.visible=false
	var gh:Greenhouse=w.greenhouses[0]
	var stages:=[["potato",.15],["potato",.55],["potato",1.0],["carrot",.4],["kale",.8],["kale",1.0],["carrot",.7],["",0.0]]
	for i in 8:
		gh.plots[i].crop=stages[i][0];gh.plots[i].growth=stages[i][1];gh.plots[i].water=.8
	gh.plots[6].dead=true;gh.refresh_all()
	gh.stove.fire.set_fuel(3*3600);gh.stove.set_process(true)
	FireVisual.set_smoke(gh.stove.smoke,gh.stove.fire,w.weather.wind_dir)
	light(12.5)
	await shot(gh,Vector3(5.5,2.4,7.5),Vector3(0,1.4,0),"outside_noon",false)
	await shot(gh,Vector3(0,1.75,2.0),Vector3(0,.5,-1.2),"inside_noon",true)
	await shot(gh,Vector3(-.2,1.6,-.8),Vector3(1.0,.55,.6),"beds_close",true)
	light(18.7)
	await shot(gh,Vector3(0,1.75,2.0),Vector3(0,.5,-1.6),"inside_dusk",true)
	await shot(gh,Vector3(6,2.6,8),Vector3(0,1.4,0),"outside_dusk",false)
	quit(0)
