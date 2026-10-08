extends SceneTree
## Matched player-height views for one graphics preset (pass graphics=quality|balanced|performance).
## Writes res://shots/graphics_presets/<preset>_<view>.png
var w:Node3D
var options:Dictionary={}
func _initialize()->void:call_deferred("run")
func run()->void:
	create_timer(300).timeout.connect(func()->void:quit(2))
	for arg:String in OS.get_cmdline_user_args():
		var p:=arg.split("=",true,1);options[p[0]]=p[1] if p.size()>1 else "1"
	var preset:String=options.get("graphics","balanced")
	var out:="res://shots/graphics_presets"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	SaveGame.pending={};seed(20261004);w=load("res://world/game_world.gd").new();root.add_child(w)
	for i in 700:
		await process_frame
		if w.collapse!=null and w.reading!=null:break
	w._frames=100;w.out_path="benchmark-no-autosave";w._autosave_t=-10000
	w.player.sim_on=true;w.player.frozen=true;w.player.god=true;w.player.cam.fov=70
	root.content_scale_size=Vector2i(1920,1080);DisplayServer.window_set_size(Vector2i(1920,1080));root.size=Vector2i(1920,1080)
	w.hud.visible=false
	var path:Array=w.fire_lookout.site.path.points_world_xyz
	var views:=[["forest_noon",path[80],path[84],12.0,Weather.S.CLEAR],["forest_overcast",path[96],path[100],15.0,Weather.S.CLOUDY],["road_noon",[w.road.points[190].x,0,w.road.points[190].y],[w.road.points[194].x,0,w.road.points[194].y],13.0,Weather.S.CLEAR]]
	for view:Array in views:
		var a:Array=view[1];var b:Array=view[2]
		w.player.place(a[0],a[2]);w.clock.hour=view[3];w.weather.lock_state(view[4]);w.weather.advance(120,0)
		var to:=Vector2(b[0]-a[0],b[2]-a[2]).normalized()
		w.player.yaw=atan2(-to.x,-to.y);w.player.pitch=-.05;w.player.rotation.y=w.player.yaw;w.player.cam.rotation.x=w.player.pitch
		for f in 90:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+"/%s_%s.png"%[preset,view[0]])
		print("GFXSHOT ",preset," ",view[0])
	w.queue_free();await process_frame;quit()
