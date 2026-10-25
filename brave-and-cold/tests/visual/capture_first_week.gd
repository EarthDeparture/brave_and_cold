extends SceneTree
var w:Node3D
func _initialize()->void:call_deferred("run")
func freeze(n:Node)->void:
	n.set_process(false);n.set_physics_process(false)
	for c:Node in n.get_children():freeze(c)
func shot(name:String,eye:Vector3,target:Vector3)->void:
	w.player.position=eye;w.player.yaw=atan2(-(target-eye).x,-(target-eye).z);w.player.pitch=asin(clampf((target-eye).normalized().y,-1,1));w.player.rotation.y=w.player.yaw;w.player.cam.rotation.x=w.player.pitch
	for f in 8:await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://shots/first-week/"+name+".png")
func run()->void:
	DirAccess.make_dir_recursive_absolute("res://shots/first-week")
	root.size=Vector2i(1600,900);seed(20261004);SaveGame.pending={};w=load("res://world/game_world.gd").new();root.add_child(w)
	for f in 600:
		await process_frame
		if w.first_week!=null and w.reading!=null:break
	freeze(w);w.out_path="test-no-autosave";w.hud.hide();w.clock.hour=10;w.sky_rig.apply_hour(10);w.player.noclip=true
	for i in 3:
		var pt:Vector3=w.first_week.points[i]
		var eye:=Vector3.ZERO;var best:=INF
		for row:Array in w.fire_lookout.site.path.points_world_xyz:
			var v:=Vector3(row[0],row[1]+1.65,row[2]);var d:=Vector2(v.x,v.z).distance_to(Vector2(pt.x,pt.z))
			if d<best:best=d;eye=v
		await shot(["timber_stop","crew_cache","feeder_stop"][i],eye,pt+Vector3.UP*.8)
	w.first_week.cache.want_open=true
	for f in 20:w.first_week._process(.05)
	await shot("crew_cache_open",w.first_week.points[1]+w.first_week.models[1].basis.z*1.5+Vector3.UP*1.3,w.first_week.points[1]+Vector3.UP*.35)
	var t:Node3D=w.fire_lookout;await shot("water_stock",t.to_global(Vector3(1.3,FireLookout.DECK_Y+1.25,.3)),t.to_global(Vector3(1.9,FireLookout.DECK_Y+.8,1.7)))
	w.inv.add("snow_portion",4);w.opening.boil();await shot("kettle_boiling",t.to_global(Vector3(-.3,FireLookout.DECK_Y+1.4,.1)),t.to_global(w.opening.stove_point(Vector3(0,.6,.3))))
	w.opening.water.advance(1200);w.opening.update_presentation();await shot("kettle_ready",t.to_global(Vector3(-.3,FireLookout.DECK_Y+1.4,.1)),t.to_global(w.opening.stove_point(Vector3(0,.6,.3))))
	w.hud.show();w.gear.open();w.gear._process(0);for f in 6:await process_frame
	await RenderingServer.frame_post_draw;get_root().get_texture().get_image().save_png("res://shots/first-week/water_inventory.png")
	print("FIRST_WEEK_CAPTURE_DONE");quit()
