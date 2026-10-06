extends SceneTree
const OUTPUT := "res://shots/survival-props/"
var w:Node3D
func _initialize() -> void:call_deferred("run")
func freeze(node:Node) -> void:
	node.set_process(false);node.set_physics_process(false)
	for child:Node in node.get_children():freeze(child)
func camera(local:Vector3,target:Vector3) -> void:
	w.player.position=w.fire_lookout.to_global(local+Vector3.UP*FireLookout.DECK_Y)
	w.player.cam.position=Vector3.ZERO;w.player.cam.look_at(w.fire_lookout.to_global(target+Vector3.UP*FireLookout.DECK_Y));w.player.cam.make_current()
func shot(id:String) -> void:
	for frame in 12:await process_frame
	root.get_texture().get_image().save_png(OUTPUT+id+".png");print("SURVIVAL_CAPTURE ",id)
func run() -> void:
	root.size=Vector2i(1600,900);SaveGame.pending={};seed(20261004)
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.gear!=null:break
	freeze(w);w.hud.visible=false;w.viewmodel.visible=false;w.player.cam.fov=70
	w.clock.hour=10;w.sky_rig.apply_hour(10);w.sky_rig.apply_shelter(1)
	camera(Vector3(1.48,1.22,.48),Vector3(1.88,.72,1.65))
	await shot("pantry_full")
	w.opening.pantry.remove("beans",2);w.opening.pantry.remove("jerky",1);w.opening.pantry.remove("wood",3);w.opening.update_presentation();await shot("pantry_half")
	w.opening.pantry.remove("beans",2);w.opening.pantry.remove("jerky",1);w.opening.pantry.remove("wood",w.opening.wood_left);w.opening.update_presentation();await shot("pantry_empty")
	for data:Array in [["wood",8,Vector3(-.60,0,.3)],["plank",3,Vector3(.30,0,.25)],["stick",7,Vector3(.15,0,-.4)]]:
		ItemPickup.spawn(w,data[0],data[1],w.fire_lookout.to_global(data[2]+Vector3.UP*FireLookout.DECK_Y))
	camera(Vector3(.25,1.2,1.4),Vector3(0,.1,0));await shot("recovered_resources")
	camera(Vector3(-.4,1.6,.6),Vector3(.25,1.0,1.55))
	var vm:Viewmodel=w.viewmodel;vm.visible=true;vm.mode="axe";vm._cur="axe";vm._equip=1;vm.freeze_t=0
	for kind:String in ["hammer","split","reach"]:
		vm.begin_work(kind,2.5)
		for gloved:bool in [false,true]:
			vm.glove_item="hide_mitts" if gloved else ""
			vm.update_work(vm.work_period*.35/Viewmodel.SWING_LEN if kind!="reach" else 1.25);vm._process(0)
			await shot(kind+("_gloves" if gloved else "_bare"))
	vm.end_work(false);w.queue_free();await process_frame;quit()
