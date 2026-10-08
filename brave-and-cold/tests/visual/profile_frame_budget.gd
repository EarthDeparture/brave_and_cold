extends SceneTree
## Frame-budget attribution: same seeded world/route as benchmark_opening_quality,
## one moving case per variant, toggling one subsystem at a time.
## Reports frame interval, CPU/GPU viewport render time, process/physics time,
## draw calls and primitives. Usage:
##   --path brave-and-cold --script res://tests/visual/profile_frame_budget.gd -- case=logging-forest
var w:Node3D
var options:Dictionary={}
func _initialize()->void:call_deferred("run")

func _med(a:Array[float])->float:
	if a.is_empty():return 0.0
	a.sort();return a[a.size()/2]

func run()->void:
	create_timer(900).timeout.connect(func()->void:quit(2))
	for arg:String in OS.get_cmdline_user_args():
		var p:=arg.split("=",true,1);options[p[0]]=p[1] if p.size()>1 else "1"
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);AudioServer.set_bus_mute(0,true)
	SaveGame.pending={};seed(20261004);w=load("res://world/game_world.gd").new();root.add_child(w)
	for i in 700:
		await process_frame
		if w.collapse!=null and w.reading!=null:break
	w._frames=100;w.out_path="benchmark-no-autosave";w._autosave_t=-10000
	w.player.sim_on=true;w.player.frozen=false;w.player.god=true;w.player.noclip=false;w.player.cam.fov=70
	w.opening_zombie_count=250;w.opening_state.last_s=96*3600;w.collapse.update(0)
	w.clock.day=5;w.clock.total_game_s=96*3600;w.opening_state.align_calendar(5,12,w.clock.total_game_s,true)
	root.content_scale_size=Vector2i(1920,1080);DisplayServer.window_set_size(Vector2i(1920,1080));root.size=Vector2i(1920,1080)
	await process_frame;await RenderingServer.frame_post_draw
	var vp:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(vp,true)
	var path:Array=w.fire_lookout.site.path.points_world_xyz
	var a:Array=path[70];var b:Array=path[110];var road:Vector2=w.road.points[180];var end:Vector2=w.road.points[208]
	var clinic:Clinic=w.collapse.clinic
	var ce:=clinic.to_global(Vector3(8,0,10));var cx:=clinic.to_global(Vector3(8,0,35))
	var cases:={"logging-forest":[Vector2(a[0],a[2]),Vector2(b[0],b[2]),Weather.S.CLOUDY],"town-road":[road,end,Weather.S.CLEAR],"clinic-encounter":[Vector2(ce.x,ce.z),Vector2(cx.x,cx.z),Weather.S.CLOUDY]}
	var variants:PackedStringArray=options.get("variants","base,no_forest,no_terrain,no_pop,no_shadows,no_fog,no_snow,no_post,no_grass,base").split(",")
	for cname:String in String(options.get("case","logging-forest")).split(","):
		var sc:Array=cases[cname]
		for v:String in variants:
			var undo:Array[Callable]=_apply(v)
			w.player.sim_dir=Vector3.ZERO;w.player.place(sc[0].x,sc[0].y);w.needs.calories=2000;w.needs.water=85;w.needs.fatigue=0;w.body.core=37
			w.clock.hour=12.0;w.weather.lock_state(sc[2]);w.weather.advance(120,0)
			var fr:Array[float]=[];var cpu:Array[float]=[];var gpu:Array[float]=[];var pr:Array[float]=[];var ph:Array[float]=[];var dc:Array[float]=[];var prim:Array[float]=[];var zp:Array[float]=[];var za:Array[float]=[];var act:=0;Zombie.prof_on=true;w.prof_on=true;w.prof.clear();var nfr:=0
			var t0:=Time.get_ticks_msec();var last:=Time.get_ticks_usec()
			while Time.get_ticks_msec()-t0<9000:
				var to:Vector2=(sc[1]-Vector2(w.player.position.x,w.player.position.z)).normalized()
				w.player.sim_dir=Vector3(to.x,0,to.y);w.player.yaw=atan2(-to.x,-to.y);w.player.pitch=-.055;w.player.rotation.y=w.player.yaw;w.player.cam.rotation.x=w.player.pitch
				await process_frame;await RenderingServer.frame_post_draw
				var now:=Time.get_ticks_usec()
				if Time.get_ticks_msec()-t0<2500:w.prof.clear()
				else:nfr+=1
				if Time.get_ticks_msec()-t0>=2500:
					fr.append((now-last)/1000.0);cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp)+RenderingServer.get_frame_setup_time_cpu())
					gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp));pr.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000);ph.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
					zp.append(Zombie.prof_us/1000.0);za.append(Zombie.prof_anim_us/1000.0);act=maxi(act,w.pop.active.size());dc.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));prim.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
				last=now;Zombie.prof_us=0;Zombie.prof_anim_us=0
			w.player.sim_dir=Vector3.ZERO;w.prof_on=false
			var parts:PackedStringArray=[]
			for k:String in w.prof:parts.append("%s=%.2f"%[k,float(w.prof[k])/maxf(1,nfr)])
			print("BUDGET_WORLD ",cname," ",v," ",", ".join(parts))
			for u:Callable in undo:u.call()
			fr.sort();print("BUDGET %-16s %-11s p95=%6.2f frame=%6.2f render_cpu=%6.2f gpu=%6.2f process=%6.2f physics=%6.2f zombies=%5.2f anim=%5.2f active=%d draws=%5d prims=%8d n=%d" % [cname,v,fr[int(fr.size()*.95)] if fr.size()>0 else 0.0,_med(fr),_med(cpu),_med(gpu),_med(pr),_med(ph),_med(zp),_med(za),act,int(_med(dc)),int(_med(prim)),fr.size()])
	print("BUDGET_COMPLETE");w.queue_free();await process_frame;quit()

func _hide(n:Node)->Callable:
	if n==null or not (n is Node3D):return func()->void:pass
	var was:bool=(n as Node3D).visible;(n as Node3D).visible=false
	return func()->void:(n as Node3D).visible=was

func _stop(n:Node)->Callable:
	if n==null:return func()->void:pass
	var was:=n.process_mode;n.process_mode=Node.PROCESS_MODE_DISABLED
	return func()->void:n.process_mode=was

func _apply(v:String)->Array[Callable]:
	var u:Array[Callable]=[]
	if v.begins_with("stop:"):   # stop:audio / stop:hud ... disables one world member's processing
		var n:Node=w.get(v.substr(5)) as Node
		u.append(_stop(n));return u
	if v.begins_with("gone:"):   # gone:footprints ... hides and stops it
		var n2:Node=w.get(v.substr(5)) as Node
		u.append(_stop(n2));u.append(_hide(n2));return u
	match v:
		"no_forest":u.append(_hide(w.forest));u.append(_stop(w.forest))
		"no_terrain":u.append(_hide(w.terrain))
		"no_pop":
			u.append(_stop(w.pop))
			for z:Node in w.zombies:u.append(_hide(z));u.append(_stop(z))
			for c:Node in w.pop.get_children():u.append(_hide(c))
		"no_shadows":
			var s:bool=w.sun.shadow_enabled;w.sun.shadow_enabled=false;u.append(func()->void:w.sun.shadow_enabled=s)
		"no_fog":
			var vf:bool=w.env.volumetric_fog_enabled;var f:bool=w.env.fog_enabled
			w.env.volumetric_fog_enabled=false;w.env.fog_enabled=false
			u.append(func()->void:w.env.volumetric_fog_enabled=vf;w.env.fog_enabled=f)
		"no_snow":u.append(_hide(w.snowfall));u.append(_hide(w.weather_presentation))
		"no_post":
			var e:Environment=w.env;var st:=[e.ssao_enabled,e.ssil_enabled,e.sdfgi_enabled,e.glow_enabled,e.ssr_enabled]
			e.ssao_enabled=false;e.ssil_enabled=false;e.sdfgi_enabled=false;e.glow_enabled=false;e.ssr_enabled=false
			u.append(func()->void:e.ssao_enabled=st[0];e.ssil_enabled=st[1];e.sdfgi_enabled=st[2];e.glow_enabled=st[3];e.ssr_enabled=st[4])
		"no_grass":u.append(_hide(w.plants));u.append(_hide(w.footprints))
		"no_ssao","no_ssil","no_sdfgi","no_glow","no_ssr":
			var prop:String=v.substr(3)+"_enabled";var was:bool=w.env.get(prop);w.env.set(prop,false)
			u.append(func()->void:w.env.set(prop,was))
		"sh4_150","sh2_150","sh2_120","sh4_200":
			var m:DirectionalLight3D.ShadowMode=w.sun.directional_shadow_mode;var d:float=w.sun.directional_shadow_max_distance
			w.sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if v.begins_with("sh4") else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			w.sun.directional_shadow_max_distance=float(v.split("_")[1])
			u.append(func()->void:w.sun.directional_shadow_mode=m;w.sun.directional_shadow_max_distance=d)
		"forest_noshadow":
			for c:Node in w.forest.get_children():
				if c is GeometryInstance3D:
					var g:GeometryInstance3D=c;var cs:=g.cast_shadow;g.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					u.append(func()->void:g.cast_shadow=cs)
		"atlas2048","atlas3072":
			var sz:=int(v.substr(5));RenderingServer.directional_shadow_atlas_set_size(sz,true)
			u.append(func()->void:RenderingServer.directional_shadow_atlas_set_size(4096,true))
		"msaa_off","msaa_2x","fxaa_only":
			var ms:=root.msaa_3d;var sa:=root.screen_space_aa
			root.msaa_3d=Viewport.MSAA_2X if v=="msaa_2x" else Viewport.MSAA_DISABLED
			if v=="fxaa_only":root.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
			u.append(func()->void:root.msaa_3d=ms;root.screen_space_aa=sa)
		"shadow_proxy":
			for c:Node in w.forest.get_children():
				if c is MultiMeshInstance3D and (c as MultiMeshInstance3D).cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
					var g:MultiMeshInstance3D=c;g.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					u.append(func()->void:g.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
			for key:Vector3i in w.forest._mms:
				var pair:Array=w.forest._mms[key]
				var p:=MultiMeshInstance3D.new();p.multimesh=pair[1];p.material_override=w.forest._mat
				p.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY;p.visibility_range_end=w.forest.near_end+20.0
				w.forest.add_child(p);u.append(func()->void:p.queue_free())
		"soft_low","soft_med":
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW if v=="soft_low" else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			u.append(func()->void:RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH))
		"sky_incr":
			var pm:Sky.ProcessMode=w.env.sky.process_mode;w.env.sky.process_mode=Sky.PROCESS_MODE_INCREMENTAL
			u.append(func()->void:w.env.sky.process_mode=pm)
		"ssao_low":
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW,true,0.5,2,50,300)
			u.append(func()->void:RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM,true,0.5,2,50,300))
		"ssao_nodetail":
			var sd:float=w.env.ssao_detail;w.env.ssao_detail=0.0;u.append(func()->void:w.env.ssao_detail=sd)
		"balanced2":
			for x:String in ["balanced","ssao_nodetail"]:u.append_array(_apply(x))
		"balanced":
			for x:String in ["atlas2048","soft_med","msaa_2x","ssao_low","sky_incr"]:u.append_array(_apply(x))
		"balanced_proxy":
			for x:String in ["balanced","shadow_proxy"]:u.append_array(_apply(x))
		"near70","near80":
			var ne:=float(v.substr(4))
			for c:Node in w.forest.get_children():
				if c is GeometryInstance3D:
					var g:GeometryInstance3D=c;var b0:=g.visibility_range_begin;var e0:=g.visibility_range_end
					if b0<=0.0 and e0>0.0 and e0<300.0:g.visibility_range_end=ne
					elif b0>0.0:g.visibility_range_begin=ne-10.0
					u.append(func()->void:g.visibility_range_begin=b0;g.visibility_range_end=e0)
	return u
