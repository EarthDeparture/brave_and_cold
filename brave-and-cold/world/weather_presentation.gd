extends Node3D
## Presentation only: local wind-carried powder and cold breath. No survival state.
var world: Node3D
var _rng := RandomNumberGenerator.new()
var _motes: Array[MeshInstance3D] = []
var _life := PackedFloat32Array()
var _velocity: Array[Vector3] = []
var _breath: MeshInstance3D
var _breath_material: ShaderMaterial
var _phase := 0.0
var _ground_refresh := 0.0

func _ready() -> void:
	_rng.seed = 71031
	for i in 28:
		var mote := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(2.2,0.24)
		var material := ShaderMaterial.new()
		material.shader = preload("res://world/shaders/winter_vapour.gdshader")
		mesh.material = material
		mote.mesh = mesh
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mote.visible = false
		add_child(mote)
		_motes.append(mote)
		_life.append(-1.0)
		_velocity.append(Vector3.ZERO)
	_breath = MeshInstance3D.new()
	var breath_mesh := QuadMesh.new()
	breath_mesh.size = Vector2(.32,.15)
	_breath_material = ShaderMaterial.new()
	_breath_material.shader = preload("res://world/shaders/winter_vapour.gdshader")
	breath_mesh.material = _breath_material
	_breath.mesh = breath_mesh
	_breath.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.player.cam.add_child(_breath)
	_breath.position = Vector3(0,-.18,-.45)
	_breath.visible = false

func reset_visuals() -> void:
	_rng.seed = 71031
	_phase = 0.0
	for i in _life.size(): _life[i] = -1.0

func _process(delta: float) -> void:
	if world == null or world.player == null: return
	var player: Player = world.player
	var weather: Weather = world.weather
	_phase += delta
	_ground_refresh -= delta
	var strength := clampf((weather.wind-4.5)/14.0,0.0,1.0)
	var airborne := strength*(.3+.7*weather.precip)
	var temperature: float = world.air_c()
	var sheltered := false
	for building in world._building_list():
		if building.has_method("is_sheltered_at") and building.is_sheltered_at(player.global_position):
			sheltered = true; break
		if building is Cabin and building.contains_xz(player.position.x,player.position.z):
			sheltered = true; break
	var tint := Color(.75,.82,.91)
	if world.sky_rig.has_method("snow_tint"): tint = world.sky_rig.snow_tint()
	var ground_update := _ground_refresh<=0.0
	if ground_update: _ground_refresh=.10
	for i in _motes.size():
		var mote := _motes[i]
		_life[i] -= delta
		if _life[i]<0.0:
			if airborne<.03 or sheltered:
				mote.visible=false; continue
			var heading := _rng.randf_range(0,TAU)
			var distance := _rng.randf_range(3.0,20.0)
			var p := player.global_position+Vector3(cos(heading)*distance,0,sin(heading)*distance)
			var height: float = player._terrain_h(p.x,p.z)
			if is_nan(height) or absf(height-(player.position.y-player.eye_h))>5.0 or _inside_building(Vector3(p.x,height+.4,p.z)):
				mote.visible=false; continue
			p.y=height+.16
			mote.global_position=p
			_life[i]=_rng.randf_range(2.5,4.5)
			_velocity[i]=Vector3(weather.wind_dir.x,0,weather.wind_dir.y)*weather.wind*_rng.randf_range(.12,.25)
			mote.visible=true
		mote.global_position+=_velocity[i]*delta
		if ground_update and mote.visible:
			var height: float = player._terrain_h(mote.position.x,mote.position.z)
			if is_nan(height) or _inside_building(Vector3(mote.position.x,height+.4,mote.position.z)): mote.visible=false
			else: mote.position.y=height+.16
		var material := mote.mesh.material as ShaderMaterial
		material.set_shader_parameter("tint",tint)
		material.set_shader_parameter("opacity",sin(clampf(_life[i]/4.5,0,1)*PI)*airborne*.11 if not sheltered else 0.0)
		material.set_shader_parameter("phase",_phase*.6+float(i))
	var breath_time := fposmod(_phase,4.2)
	var breath_age := breath_time/1.35
	_breath.visible=temperature<3.0 and breath_age<1.0 and not player.dead
	if _breath.visible:
		var fade := sin(breath_age*PI)
		_breath_material.set_shader_parameter("opacity",fade*.12*clampf((3.0-temperature)/15.0,0,1))
		_breath_material.set_shader_parameter("tint",tint)
		_breath_material.set_shader_parameter("phase",_phase)
		_breath.position=Vector3(.018*sin(_phase),-.18+breath_age*.035,-.45-breath_age*.30)
		_breath.scale=Vector3.ONE*(.5+breath_age*.9)

func _inside_building(point: Vector3) -> bool:
	for building in world._building_list():
		if building.has_method("is_sheltered_at") and building.is_sheltered_at(point): return true
		if building is Cabin and building.contains_xz(point.x,point.z): return true
	return false
