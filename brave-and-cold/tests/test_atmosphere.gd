extends SceneTree
## Behaviour, continuity and save round-trip checks. Never touches user:// saves.
var failures := 0
func check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ")+label)
	if not condition: failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var old := SkyRig.new()
	var upgraded := AtmosphereRig.new()
	root.add_child(old)
	root.add_child(upgraded)
	old.setup(DirectionalLight3D.new(),Environment.new(),ProceduralSkyMaterial.new())
	root.add_child(old.sun)
	old.env.sky = Sky.new()
	var light := DirectionalLight3D.new()
	root.add_child(light)
	var environment := Environment.new()
	environment.sky = Sky.new()
	upgraded.setup(light,environment,ProceduralSkyMaterial.new())
	old.weather = Weather.new()
	upgraded.weather = Weather.new()
	var max_difference := 0.0
	var max_turn := 0.0
	var previous := Vector3.ZERO
	for state in 5:
		old.weather.lock_state(state)
		upgraded.weather.lock_state(state)
		for step in 2881:
			var hour := float(step)/120.0
			old.apply_hour(hour)
			upgraded.apply_hour(hour)
			max_difference = maxf(max_difference,absf(upgraded.gameplay_night_factor-clampf(1.0-old.sun.light_energy/0.7,0.0,1.0)))
			var direction := upgraded.sun.basis.z
			if step>0: max_turn=maxf(max_turn,previous.angle_to(direction))
			previous=direction
	check("legacy enemy/lamp darkness preserved across 14,405 clock/weather combinations",max_difference<0.000001)
	check("solar direction continuous across dawn, dusk and midnight",max_turn<0.004)
	upgraded.weather.lock_state(Weather.S.BLIZZARD)
	upgraded.apply_hour(12.0)
	var fog := upgraded.env.fog_density
	upgraded.apply_shelter(1.0)
	check("shelter keeps outdoor storm depth through windows",is_equal_approx(fog,upgraded.env.fog_density))
	upgraded.set_cloud_offset(Vector2(2.7,-8.2))
	var snapshot := JSON.parse_string(JSON.stringify(upgraded.to_dict())) as Dictionary
	upgraded.set_cloud_offset(Vector2.ZERO)
	upgraded.from_dict(snapshot)
	check("cloud phase survives JSON",upgraded.cloud_offset.is_equal_approx(Vector2(2.7,-8.2)))
	var a := Weather.new(391)
	a.set_state(Weather.S.BLIZZARD)
	for i in 400: a.advance(0.1,4.8)
	var b := Weather.new(1)
	b.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	var identical := true
	for i in 18000:
		a.advance(0.1,4.8)
		b.advance(0.1,4.8)
		identical = identical and a.state==b.state and absf(a._left_h-b._left_h)<0.000001 and absf(a.wind-b.wind)<0.000001 and absf(a.overcast-b.overcast)<0.000001 and a.wind_dir.is_equal_approx(b.wind_dir)
	check("weather blend, gusts and future sequence resume for 24 game hours",identical)
	var legacy := Weather.new()
	legacy.from_dict({"state":Weather.S.SNOW,"left":2.35})
	check("legacy weather dictionary remains readable",legacy.state==Weather.S.SNOW and is_equal_approx(legacy._left_h,2.35) and is_equal_approx(legacy.precip,0.65))
	print("ATMOSPHERE_TESTS failures=",failures," max_gameplay_difference=",max_difference," max_solar_step_radians=",max_turn)
	old.free()
	upgraded.free()
	light.free()
	quit(1 if failures>0 else 0)
