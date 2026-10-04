extends SceneTree
## Full imported world contract. Uses no player save; checks presentation against original physics/scatter.
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func stop(node: Node) -> void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():stop(child)
func run() -> void:
	SaveGame.pending={}
	var world: Node3D = load("res://world/game_world.gd").new()
	root.add_child(world)
	for i in 600:
		await process_frame
		if world.hud!=null:break
	await process_frame
	stop(world)
	check(world.environment_detail_enabled,"candidate presentation enabled")
	check(world.audio!=null and world.inv!=null,"world completes startup with materials, audio, and survival")
	check(world.snowfall._far!=null and world.snowfall.amount+world.snowfall._far.amount<=12000,"depth layers remain within original particle count")
	var baseline:=ForestScatter.new()
	root.add_child(baseline)
	baseline.set_process(false)
	baseline.exclude=world.forest.exclude
	baseline.build(world.terrain)
	# Road/trail exclusion closures grow while the lookout is added. Rebuild both
	# banks against the same completed exclusion snapshot.
	var candidate := ForestScatter.new()
	candidate.detail_enabled = true
	root.add_child(candidate)
	candidate.set_process(false)
	candidate.exclude = baseline.exclude
	candidate.build(world.terrain)
	check(baseline.tree_count==candidate.tree_count and baseline.excluded==candidate.excluded,"tree population and exclusions preserved")
	check(baseline._trunks==candidate._trunks,"every trunk location and collision radius preserved")
	var same_transforms:=true
	for key in baseline._mms:
		var a:MultiMesh=baseline._mms[key][0]
		var b:MultiMesh=candidate._mms[key][0]
		if a.instance_count!=b.instance_count:same_transforms=false;break
		for i in a.instance_count:
			if a.get_instance_transform(i)!=b.get_instance_transform(i):same_transforms=false;break
	check(same_transforms,"all tree instance transforms and variant assignments preserved")
	var tree:Dictionary=world.forest.nearest_tree(Vector3(-120,0,133),Vector3.FORWARD,50,false)
	var old_fell:Dictionary=baseline.fell(tree.x,tree.z)
	var new_fell:Dictionary=candidate.fell(tree.x,tree.z)
	check(old_fell==new_fell,"felling returns identical interaction and transform metadata")
	world.weather.lock_state(Weather.S.BLIZZARD)
	world.player.global_position=world.fire_lookout.to_global(Vector3(0,FireLookout.DECK_Y+1.7,0))
	world.weather_presentation.reset_visuals()
	for i in 300:world.weather_presentation._process(1.0/60.0)
	var hidden:=true
	for mote in world.weather_presentation._motes:hidden=hidden and not mote.visible
	check(hidden,"ground powder cannot spawn upstairs or inside lookout")
	world.snowfall._mask_position=Vector3(INF,INF,INF)
	world.snowfall._process(0.0)
	check(world.snowfall._shelter_frames.size()>0,"both snowfall layers share actual building roof masks")
	world.player.global_position=Vector3(-1,world.ice.ice_at(-1,803)+1.7,803)
	world.weather_presentation.reset_visuals()
	for i in 240:world.weather_presentation._process(1.0/60.0)
	var grounded:=true
	var visible_count:=0
	for mote in world.weather_presentation._motes:
		if mote.visible:
			visible_count+=1
			var h:float=world.player._terrain_h(mote.position.x,mote.position.z)
			grounded=grounded and absf(mote.position.y-h-.16)<.05
	check(visible_count>0 and grounded,"wind powder follows the actual ice/ground rather than a flat emitter plane")
	world.player.dead=true
	world.weather_presentation._process(.1)
	check(not world.weather_presentation._breath.visible,"breath stops after death")
	world.player.dead=false
	var vm:Viewmodel=world.viewmodel
	for mode in ["fists","axe","rifle"]:
		vm.mode=mode;vm._cur=mode;vm._equip=1.0;vm.freeze_t=0
		vm._process(0)
		check(vm._right.position.distance_to(vm._sl_r.position)<.0001 and (not vm._left.visible or vm._left.position.distance_to(vm._sl_l.position)<.0001),"new cloth cuffs stay attached in "+mode)
	var presentation_assets := ResourceLoader.load("res://data/terrain/terrain_environment_assets.tres","",ResourceLoader.CACHE_MODE_IGNORE) as Terrain3DAssets
	var material_count: int = presentation_assets.get_texture_count()
	var original_assets := load("res://data/terrain/terrain_winter_assets.tres") as Terrain3DAssets
	print("TERRAIN_TEXTURE_COUNT candidate=",material_count," original=",original_assets.get_texture_count())
	var ids_match := material_count>=4 and original_assets.get_texture_count()>=4
	for i in 4:
		print("TERRAIN_SLOT ",i," candidate=",presentation_assets.get_texture(i).id," original=",original_assets.get_texture(i).id)
		ids_match = ids_match and presentation_assets.get_texture(i).id==original_assets.get_texture(i).id and presentation_assets.get_texture(i).name==original_assets.get_texture(i).name
	check(ids_match,"terrain texture IDs remain compatible with original control maps")
	for path in ["res://assets/environment_detail/audio/step_wood.wav","res://assets/environment_detail/audio/step_ice.wav","res://assets/environment_detail/audio/timber_creak.wav","res://assets/environment_detail/audio/window_rattle.wav"]:
		var sound:=load(path) as AudioStreamWAV
		check(sound!=null and sound.get_length()>.15 and sound.get_length()<2.0,"original material audio imports: "+path.get_file())
	print("ENVIRONMENT_DETAIL_TESTS failures=",failures)
	candidate.free()
	baseline.free()
	world.free()
	quit(1 if failures>0 else 0)
