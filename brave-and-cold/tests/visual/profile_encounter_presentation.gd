extends SceneTree
## Isolated script timings; no renderer, terrain, AI or frame-rate claim.
func _initialize()->void:call_deferred("run")
func run()->void:
	var label:="baseline"
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("profile_label="):label=arg.trim_prefix("profile_label=")
	var z:=Zombie.new();root.add_child(z);z.set_process(false)
	z._model=(load(Zombie.MODEL) as PackedScene).instantiate();z.add_child(z._model)
	for node:Node in z._model.find_children("*","Skeleton3D",true,false):z._skin=node as Skeleton3D;break
	for side:String in ["l","r"]:
		for prefix:String in ["zombie_arm_","zombie_leg_","zombie_knee_","zombie_elbow_"]:
			var joint:=z._model.find_child(prefix+side,true,false) as Node3D
			z._skin_drivers[z._skin.find_bone("skin_"+String(joint.name))]=joint;joint.rotation.x=.35
	z._deform_skin()
	var c:=Clinic.new();root.add_child(c)
	c._dressing=(load(Clinic.MODEL) as PackedScene).instantiate();c.add_child(c._dressing)
	c.rear=Node3D.new();c.add_child(c.rear)
	if c.has_method("_bind_stock_visuals"):c.call("_bind_stock_visuals")
	var w:=Node3D.new();root.add_child(w);c.build_stock(w)
	var samples:Array=[]
	for repeat in 3:
		var start:=Time.get_ticks_usec()
		for i in 10000:z._deform_skin()
		var skin_us:=float(Time.get_ticks_usec()-start)/10000
		start=Time.get_ticks_usec()
		for i in 10000:c.update_loot_visuals()
		samples.append({"repeat":repeat+1,"skin_call_us":skin_us,"clinic_refresh_call_us":float(Time.get_ticks_usec()-start)/10000})
	var out:="res://shots/encounter-polish"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var receipt:={"label":label,"iterations_per_repeat":10000,"samples":samples,"scope":"Isolated script calls on actual imported models. Refresh call cost is separate from its event frequency. No GPU, frame-time or complete-game claim."}
	var f:=FileAccess.open(out+"/presentation-"+label+".json",FileAccess.WRITE);f.store_string(JSON.stringify(receipt,"  "));f.close()
	print("PRESENTATION_PROFILE ",JSON.stringify(receipt));quit()
