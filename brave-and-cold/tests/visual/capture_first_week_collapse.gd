extends SceneTree
var w:Node3D
func _initialize()->void:call_deferred("run")
func freeze(n:Node)->void:
 n.set_process(false);n.set_physics_process(false)
 for c:Node in n.get_children():freeze(c)
func shot(name:String,eye:Vector3,target:Vector3)->void:
 w.player.position=eye;w.player.yaw=atan2(-(target-eye).x,-(target-eye).z);w.player.pitch=asin(clampf((target-eye).normalized().y,-1,1));w.player.rotation.y=w.player.yaw;w.player.cam.rotation.x=w.player.pitch
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://shots/first-week/"+name+".png")
func run()->void:
 root.size=Vector2i(1600,900);SaveGame.pending={};w=load("res://world/game_world.gd").new();root.add_child(w)
 for f in 700:
  await process_frame
  if w.collapse!=null and w.reading!=null:break
 freeze(w);w.out_path="test-no-autosave";w.hud.hide();w.player.noclip=true;w.viewmodel.hide();w.clock.hour=11;w.sky_rig.apply_hour(11)
 var c:Clinic=w.collapse.clinic
 if c==null:print("FAIL clinic unavailable");quit(1);return
 await shot("clinic_exterior",c.to_global(Vector3(5,1.7,12)),c.to_global(Vector3(0,1.7,2)))
 w.sky_rig.apply_shelter(1)
 await shot("clinic_waiting",c.to_global(Vector3(0,1.9,2.4)),c.to_global(Vector3(-3.0,1.2,.0)))
 await shot("clinic_exam",c.to_global(Vector3(1.5,1.9,2.3)),c.to_global(Vector3(3.5,1.2,-1.2)))
 await shot("clinic_stock",c.to_global(Vector3(-2.5,1.9,-1.0)),c.to_global(Vector3(-4.15,1.2,-2.65)))
 w.sky_rig.apply_shelter(0)
 w.opening_state.last_s=55*3600;w.collapse.update(0);await shot("clinic_abandoned",c.to_global(Vector3(5,1.7,12)),c.to_global(Vector3(0,1.7,2)))
 var q:=c.to_global(Vector3(0,0,7.3));var p:Vector3=w._ground(q.x,q.z);var z:Zombie=w._add_zombie(p,72);z.set_process(false);z.rotation.y=c.rotation.y;z.state=Zombie.State.CHASE;z.speed_now=1.3;z._animate(.1)
 await shot("infected_close",p-z.basis.z*2.6+Vector3.UP*1.6,p+Vector3.UP*1.15)
 z._apply_coat(73);z._attack_windup=.17;z._animate(.01);await shot("infected_attack",p-z.basis.z*2.6+Vector3.UP*1.6,p+Vector3.UP*1.15)
 w.clock.hour=21;w.sky_rig.apply_hour(21);w.collapse.update(0);await shot("clinic_night",c.to_global(Vector3(3,1.7,8)),c.to_global(Vector3(0,1.7,2)))
 w.clock.hour=11;w.sky_rig.apply_hour(11);w.weather.precip=.9;w.weather.wind=16;w.sky_rig.apply_shelter(1);c.set_night(0);await shot("clinic_storm_interior",c.to_global(Vector3(1.5,1.9,2.3)),c.to_global(Vector3(3.5,1.2,-1.2)))
 w.sky_rig.apply_shelter(1);var op:LookoutOpening=w.opening;await shot("city_letter",op.city_letter.global_position+Vector3(0,.40,.20),op.city_letter.global_position)
 op.read_city_letter();await shot("city_letter_modal",op.city_letter.global_position+Vector3(0,.40,.20),op.city_letter.global_position);w.reading.close()
 print("COLLAPSE_CAPTURE_DONE");quit()
