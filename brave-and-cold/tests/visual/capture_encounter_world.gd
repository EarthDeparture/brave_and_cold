extends SceneTree
var w:Node3D
var out:="res://shots/encounter-polish/world"
func _initialize()->void:call_deferred("run")
func freeze(n:Node)->void:
	n.set_process(false);n.set_physics_process(false)
	for child:Node in n.get_children():freeze(child)
func shot(id:String,eye:Vector3,target:Vector3)->void:
	w.player.position=eye;var dir:Vector3=(target-eye).normalized()
	w.player.yaw=atan2(-dir.x,-dir.z);w.player.pitch=asin(dir.y)
	w.player.rotation.y=w.player.yaw;w.player.cam.rotation.x=w.player.pitch
	for i in 6:await process_frame
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/"+id+".png")
func run()->void:
	create_timer(150).timeout.connect(func()->void:quit(2))
	root.size=Vector2i(1600,900);seed(20261004);SaveGame.pending={}
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for i in 800:
		await process_frame
		if w.collapse!=null and w.reading!=null:break
	if w.collapse==null:quit(1);return
	freeze(w);w.out_path="test-no-autosave";w._frames=100;w.hud.hide();w.viewmodel.hide();w.player.noclip=true;w.player.cam.position=Vector3.ZERO;w.player.cam.fov=60
	w.clock.hour=11;w.weather.lock_state(Weather.S.CLOUDY);w.weather.advance(120,0);w.sky_rig.apply_hour(11)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var c:Clinic=w.collapse.clinic;var q:=c.to_global(Vector3(0,0,7.3));var p:Vector3=w._ground(q.x,q.z)
	var z:Zombie=w._add_zombie(p,78);z.set_process(false);z.rotation.y=c.rotation.y
	z.state=Zombie.State.CHASE;z.speed_now=1.4;z._attack_windup=.1;z._animate(.1);z._die()
	var eye:=p-z.basis.z*2.5+z.basis.x*1.25+Vector3.UP*1.8;var target:=p-z.basis.z*.7+Vector3.UP*.30
	z._death_pose(.35);await shot("clinic-collapse",eye,target)
	z._death_pose(1);await shot("clinic-settled",eye,target)
	var probes:Array=[]
	for v:Vector3 in [Vector3.ZERO,Vector3(0,0,-.5),Vector3(0,0,-1),Vector3(0,0,-1.5)]:
		var loc:=z.to_global(v);probes.append({"point":[loc.x,loc.y,loc.z],"terrain":w.terrain.data.get_height(loc),"support":z._corpse_floor(loc),"clinic_local":str(c.to_local(loc))})
	print("CORPSE_SUPPORT_TRACE ",JSON.stringify({"model_offset":z._model.position.y,"pitch":z._death_ground_pitch,"roll":z._death_ground_roll,"probes":probes}))
	for child:Node in c.get_children():
		if child is MeshInstance3D:print("CLINIC_RAMP_TRACE ",child.global_transform," bounds=",child.get_aabb())
	w.sky_rig.apply_shelter(1)
	await shot("clinic-stock-full",c.to_global(Vector3(-2.5,1.9,-1.0)),c.to_global(Vector3(-4.15,1.2,-2.65)))
	c.stock[0].remove("bandage",3);c.stock[1].remove("antiseptic",1);c.stock[1].remove("antibiotics",1)
	await shot("clinic-stock-withdrawn",c.to_global(Vector3(-2.5,1.9,-1.0)),c.to_global(Vector3(-4.15,1.2,-2.65)))
	w.sky_rig.apply_shelter(0);var route:FirstWeekRoute=w.first_week;route.cache.want_open=true
	for i in 25:route._process(.02)
	await shot("crew-cache-open",route.points[1]+route.models[1].basis.z*1.5+Vector3.UP*1.3,route.points[1]+Vector3.UP*.35)
	print("ENCOUNTER_WORLD_CAPTURE_COMPLETE");quit()
