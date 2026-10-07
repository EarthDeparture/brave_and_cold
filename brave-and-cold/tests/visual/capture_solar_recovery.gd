extends SceneTree
const OUT:="res://shots/solar-recovery-2026-10-06/"
var w:Node3D
func _initialize() -> void:call_deferred("run")
func freeze(n:Node) -> void:
	n.set_process(false);n.set_physics_process(false)
	for child:Node in n.get_children():freeze(child)
func view(position:Vector3,target:Vector3) -> void:
	w.player.position=position;w.player.cam.position=Vector3.ZERO;w.player.cam.look_at(target)
func shot(id:String) -> void:
	for frame in 10:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+id+".png");print("SOLAR_CAPTURE ",id)
func run() -> void:
	create_timer(120).timeout.connect(func()->void:quit(2))
	root.size=Vector2i(1600,900);DirAccess.make_dir_recursive_absolute(OUT)
	SaveGame.pending={};seed(20261004)
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.gear!=null and w.reading!=null:break
	freeze(w);w.out_path="capture-no-autosave";w._frames=100;w.hud.hide();w.viewmodel.hide()
	w.weather.lock_state(Weather.S.CLEAR);w.clock.hour=12;w.clock.total_game_s=6.5*3600
	var s:LookoutAssignment=w.opening_state;s.grid_fail_s=0;s.last_s=w.clock.total_game_s;s.solar_overcast=0;s.repair_stage=3;s.backup_on=true;s.recovery_lock=true;s.battery_wh=0
	w.sky_rig.apply_hour(12);w.opening.update_presentation()
	var site:LookoutSolar=w.opening.solar_site
	view(site.to_global(Vector3(-.2,1.7,3.1)),site.to_global(Vector3(0,1.18,0)));await shot("solar-array-clear")
	s.solar.snow_cover=.7;site.update_presentation();await shot("solar-array-snow")
	s.solar.clear_snow();w.clock.advance(60);w.opening.advance(1800)
	view(w.fire_lookout.to_global(Vector3(0,FireLookout.DECK_Y+Player.EYE,.35)),w.opening.home_point(Vector3(0,1,-2.07)));await shot("desk-recovered")
	w.opening.read_power_status();await shot("power-status-modal");w.reading.close()
	s.grid_fail_s=0;s.battery_wh=0;s.recovery_lock=true;w.clock.hour=0;s.last_s=18.5*3600;w.sky_rig.apply_hour(0);w.opening.update_presentation();w.opening.read_power_status();await shot("night-zero-status")
	print("SOLAR_CAPTURE_DONE gpu=",RenderingServer.get_video_adapter_name())
	w.queue_free();await process_frame;SaveGame.pending={};quit()
