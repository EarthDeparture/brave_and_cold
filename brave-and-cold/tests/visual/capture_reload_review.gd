extends SceneTree
## Matched before/after reload captures with fixed camera, weather and timing.
func _initialize()->void:call_deferred("run")
func freeze(n:Node)->void:
 n.set_process(false);n.set_physics_process(false);n.set_process_input(false)
 for child in n.get_children():freeze(child)
func run()->void:
 var options:Dictionary={}
 for arg in OS.get_cmdline_user_args():
  var pair:=arg.split("=",true,1);options[pair[0]]=pair[1] if pair.size()>1 else "1"
 var folder:String=options.get("capture_out","res://shots/grip-route-followup/reload-after");DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);DisplayServer.window_set_size(Vector2i(1280,720));AudioServer.set_bus_mute(0,true);SaveGame.pending={};seed(20261003)
 var world:Node3D=load("res://world/game_world.gd").new();root.add_child(world)
 for i in 600:
  await process_frame
  if world.hud!=null:break
 if world.hud==null:quit(1);return
 freeze(world);world.hud.hide();world.snowfall.hide();world.weather_presentation.hide();world.weather.lock_state(Weather.S.CLOUDY);world.weather.advance(120,0);world.clock.hour=12;world.sky_rig.apply_hour(12)
 var p:Player=world.player;var vm:Viewmodel=world.viewmodel
 if options.has("baseline"):
  vm.hide();vm=load("res://tests/visual/fixtures/pre_clearance_viewmodel.gd").new();vm.player=p;vm.detail_enabled=true;p.cam.add_child(vm);vm.set_process(false)
 p.position=Vector3(-120,8.44652,133);p.cam.position=Vector3.ZERO;p.cam.look_at(Vector3(-160,10.74652,50));p.aim_k=0;p.cam.fov=70
 vm.mode="rifle";vm._cur="rifle";vm._equip=1;vm._clock=0;vm.glove_item="hide_mitts";vm.fire()
 for i in 37:
  vm.freeze_t=.36+i*.02;vm._process(0)
  for frame in 2:await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(folder.path_join("%03d.png"%i))
 print("RELOAD_CAPTURE_COMPLETE frames=37");quit()
