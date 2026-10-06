extends SceneTree
const OUTPUT:="res://shots/medical-firewood/"
var w:Node3D
func _initialize()->void:call_deferred("run")
func freeze(n:Node)->void:
	n.set_process(false);n.set_physics_process(false)
	for c:Node in n.get_children():freeze(c)
func shot(id:String)->void:
	w.gear._c.queue_redraw();w.hud._ui.queue_redraw()
	for frame in 12:await process_frame
	root.get_texture().get_image().save_png(OUTPUT+id+".png");print("MEDICAL_FIREWOOD_CAPTURE ",id)
func run()->void:
	DirAccess.make_dir_recursive_absolute(OUTPUT);create_timer(150).timeout.connect(func()->void:print("FAIL capture timeout");quit(2))
	root.size=Vector2i(1600,900);SaveGame.pending={};seed(20261004)
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.reading!=null:break
	freeze(w);w.out_path="test-no-autosave";w.hud.visible=false;w.viewmodel.visible=false;w.player.cam.fov=65
	w.clock.hour=10;w.sky_rig.apply_hour(10);w.sky_rig.apply_shelter(1)
	w.player.position=w.fire_lookout.to_global(Vector3(1.50,FireLookout.DECK_Y+1.26,.63))
	w.player.cam.position=Vector3.ZERO;w.player.cam.look_at(w.fire_lookout.to_global(Vector3(1.88,FireLookout.DECK_Y+.47,1.65)));w.player.cam.make_current()
	var initial:=w.opening._stock.get_node("Stock_wood") as MultiMeshInstance3D;var positions:Array[Transform3D]=[]
	for i in initial.multimesh.instance_count:positions.append(initial.multimesh.get_instance_transform(i))
	await shot("rack_starter_six")
	w.opening.pantry.remove("wood",w.opening.wood_left);await shot("rack_empty")
	w.inv.add("wood",6);w.chest_put(w.opening.pantry,"wood",6)
	var refilled:=w.opening._stock.get_node("Stock_wood") as MultiMeshInstance3D
	var layout_ok:=refilled.multimesh.instance_count==6
	for i in 6:layout_ok=layout_ok and refilled.multimesh.get_instance_transform(i).is_equal_approx(positions[i])
	if not layout_ok:print("FAIL GPU replenished stack layout");quit(1);return
	print("PASS GPU replenished six logs have identical original stacked transforms")
	await shot("rack_replenished_six")
	w.inv.add("wood",6);w.opening.stack_wood()
	var full:=w.opening._stock.get_node("Stock_wood") as MultiMeshInstance3D
	if full.multimesh.instance_count!=12 or full.multimesh.get_instance_transform(8).origin.y<.30:print("FAIL GPU full rack layer");quit(1);return
	print("PASS GPU twelve logs form three elevated rack layers")
	await shot("rack_full_twelve")
	w.inv.add("wood",15);w.chest_put(w.opening.pantry,"wood",15);await shot("rack_overflow_stored")
	w.player.health=65;w.player.injury.wound(.8,0);w.needs.calories=1800;w.needs.water=80;w.body.core=37
	w.gear.open();w.gear._sel={"id":"bandage","from":"pack","n":1};await shot("bandage_use_button")
	w.gear_use("bandage");w.gear._process(0);await shot("bandaged_recovery_status")
	w.needs.water=40;w.gear._process(0);root.size=Vector2i(1280,720);await shot("recovery_water_pause_720p")
	w.gear.close();w.queue_free();await process_frame;await process_frame;print("MEDICAL_FIREWOOD_CAPTURE_DONE");quit()
