extends SceneTree
var w:Node3D
func _initialize()->void:call_deferred("run")
func freeze(n:Node)->void:
 n.set_process(false);n.set_physics_process(false)
 for c:Node in n.get_children():freeze(c)
func shot(name:String)->void:
 for f in 12:await process_frame
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://shots/first-week/"+name+".png")
func run()->void:
 create_timer(150).timeout.connect(func()->void:quit(2))
 root.size=Vector2i(1600,900);SaveGame.pending={};seed(20261004);w=load("res://world/game_world.gd").new();root.add_child(w)
 for f in 600:
  await process_frame
  if w.opening!=null and w.gear!=null:break
 freeze(w);w.out_path="test-no-autosave";w.hud.hide();w.clock.hour=10.25;w.sky_rig.apply_hour(10.25);w.sky_rig.apply_shelter(0)
 w.player.position=w.opening.boundary.to_global(w.opening.boundary.ground_local(1.7,8)+Vector3.UP*w.player.eye_h)
 w.player.yaw=w.fire_lookout.rotation.y;w.player.pitch=0;w.player.rotation.y=w.player.yaw;w.player.cam.rotation.x=0;w.player.cam.fov=64
 w._update_viewmodel();w.viewmodel.watch_override=true;w.viewmodel._process(.5);await shot("wristwatch_glove")
 w.viewmodel.glove_item="";w.viewmodel._process(.01);await shot("wristwatch_bare")
 w.viewmodel.watch_override=false;w.viewmodel._process(.5);w.viewmodel.begin_work("treat",1.7);w.viewmodel.work_elapsed=.8;w.viewmodel._process(0);await shot("hand_treatment")
 w.viewmodel.end_work(false);w.viewmodel.begin_work("drink",1.7);w.viewmodel.work_elapsed=.8;w.viewmodel._process(0);await shot("hand_drink")
 w.viewmodel.end_work(false)
 w.viewmodel.watch_override=false;w.viewmodel._process(.5);w.needs.fatigue=70;w.body.wetness=.65;w.gear.open();await shot("field_inventory")
 w.gear.close();print("FIELD_CAPTURE_DONE");quit()
