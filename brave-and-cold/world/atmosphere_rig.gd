class_name AtmosphereRig
extends SkyRig
## Art-directed winter sky. Legacy gameplay darkness is evaluated by SkyRig,
## independently of the two continuous celestial lights used for rendering.
const SKY_SHADER := preload("res://world/shaders/winter_sky.gdshader")
var material := ShaderMaterial.new()
var moon: DirectionalLight3D
var cloud_offset := Vector2.ZERO
var _base_fog := 0.0
var _base_ambient := 0.0
var _base_ambient_color := Color.WHITE
var _hour := 12.0

func setup(sun_light: DirectionalLight3D, environment: Environment, sky_material: ProceduralSkyMaterial) -> void:
	super.setup(sun_light,environment,sky_material)
	material.shader = SKY_SHADER
	material.set_shader_parameter("cloud_fields",preload("res://assets/textures/atmosphere/cloud_fields.png"))
	env.sky.sky_material = material
	env.sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky.process_mode = Sky.PROCESS_MODE_REALTIME
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.ambient_light_sky_contribution = 0.28
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.0
	env.ssao_power = 1.4
	env.ssao_detail = 0.35
	env.ssao_light_affect = 0.05
	env.ssao_ao_channel_affect = 0.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 0.65
	sun.shadow_blur = 1.6
	moon = DirectionalLight3D.new()
	moon.name = "WinterMoon"
	moon.light_color = Color(0.53,0.66,0.90)
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	moon.directional_shadow_max_distance = 180.0
	moon.shadow_bias = 0.04
	moon.shadow_normal_bias = 0.65
	moon.shadow_blur = 2.0
	add_child(moon)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	get_viewport().msaa_3d = Viewport.MSAA_4X

func _process(delta: float) -> void:
	if weather != null:
		cloud_offset += weather.wind_dir * weather.wind * delta * 0.00018
		material.set_shader_parameter("cloud_offset",cloud_offset)

func set_cloud_offset(offset: Vector2) -> void:
	cloud_offset = offset
	material.set_shader_parameter("cloud_offset",cloud_offset)

func apply_hour(h: float) -> void:
	# The baseline curve still determines enemy perception and building lamp timing.
	gameplay_night_factor = gameplay_darkness_at(h)
	_hour = fposmod(h,24.0)
	var elevation := sin(PI*(_hour-6.0)/12.0)*42.0
	var azimuth := 60.0+(_hour-6.0)*15.0
	sun.rotation_degrees = Vector3(-elevation,azimuth,0.0)
	moon.rotation_degrees = Vector3(elevation*0.90,azimuth+180.0,0.0)
	var day := smoothstep(-7.0,9.0,elevation)
	var warm := (1.0-smoothstep(2.0,24.0,elevation))*smoothstep(-9.0,1.0,elevation)
	var o := weather.overcast if weather != null else 0.0
	var c := weather.coverage if weather != null else 0.35
	var precipitation := weather.precip if weather != null else 0.0
	sun.light_color = Color(1.0,0.95,0.83).lerp(Color(1.0,0.61,0.34),warm)
	sun.light_energy = smoothstep(0.0,7.0,elevation)*(1.45-warm*0.55)*(1.0-o*0.93)
	sun.visible = sun.light_energy > 0.002
	moon.light_energy = (1.0-day)*0.18*(1.0-o*0.87)*smoothstep(0.0,8.0,-elevation)
	moon.visible = moon.light_energy > 0.002
	var zenith := Color(0.025,0.039,0.090).lerp(Color(0.12,0.31,0.58),day)
	zenith = zenith.lerp(Color(0.22,0.17,0.34),warm*0.66)
	var horizon := Color(0.074,0.104,0.175).lerp(Color(0.66,0.79,0.88),day)
	horizon = horizon.lerp(Color(0.66,0.45,0.46),warm*0.55)
	var grey := Color(0.070,0.085,0.125).lerp(Color(0.54,0.61,0.68),day)
	zenith = zenith.lerp(grey.darkened(0.22),o*0.87)
	horizon = horizon.lerp(grey.lightened(0.08),o*0.90)
	var lit := Color(0.10,0.135,0.22).lerp(Color(0.94,0.96,0.97),day)
	lit = lit.lerp(Color(1.0,0.69,0.44),warm*0.8)
	var shade := Color(0.037,0.052,0.10).lerp(Color(0.36,0.46,0.60),day)
	shade = shade.lerp(Color(0.32,0.25,0.39),warm*0.70)
	lit = lit.lerp(grey.lightened(0.12),o*0.60)
	shade = shade.lerp(grey.darkened(0.17),o*0.70)
	material.set_shader_parameter("zenith_color",zenith)
	material.set_shader_parameter("horizon_color",horizon)
	material.set_shader_parameter("sunset_color",Color(1.0,0.55,0.25))
	material.set_shader_parameter("cloud_light",lit)
	material.set_shader_parameter("cloud_shadow",shade)
	material.set_shader_parameter("sun_color",sun.light_color)
	material.set_shader_parameter("sun_direction",sun.global_basis.z.normalized())
	material.set_shader_parameter("moon_direction",moon.global_basis.z.normalized())
	material.set_shader_parameter("daylight",day)
	material.set_shader_parameter("twilight",warm)
	material.set_shader_parameter("moon_strength",(1.0-day)*(1.0-o))
	material.set_shader_parameter("coverage",c)
	material.set_shader_parameter("overcast",o)
	env.ambient_light_color = Color(0.23,0.31,0.49).lerp(Color(0.43,0.59,0.78),day)
	env.ambient_light_color = env.ambient_light_color.lerp(Color(0.48,0.45,0.59),warm*0.35)
	env.ambient_light_color = env.ambient_light_color.lerp(grey,o*0.60)
	env.ambient_light_energy = lerpf(0.23,0.57,day)+o*day*0.20
	env.fog_light_color = horizon.lerp(shade,0.12)
	env.fog_density = (0.00055 + warm*0.0002)*(1.0+o*1.4+precipitation*18.0)
	env.fog_light_energy = 0.8
	var haze := env.fog_light_color.srgb_to_linear()*env.fog_light_energy
	material.set_shader_parameter("haze_color",Vector3(haze.r,haze.g,haze.b))
	_base_fog = env.fog_density
	_base_ambient = env.ambient_light_energy
	_base_ambient_color = env.ambient_light_color

func apply_shelter(indoor: float) -> void:
	# Fog remains a world-distance effect through windows. Never clear a storm
	# outside merely because the camera crossed a doorway.
	var k := clampf(indoor,0.0,1.0)
	env.fog_density = _base_fog
	env.ambient_light_energy = _base_ambient * lerpf(1.0,0.92,k)
	env.ambient_light_color = _base_ambient_color.lerp(Color(0.55,0.49,0.41),0.12*k)

func to_dict() -> Dictionary:
	return {"cloud_offset":[cloud_offset.x,cloud_offset.y]}

func from_dict(data: Dictionary) -> void:
	var phase: Array = data.get("cloud_offset",[0.0,0.0])
	if phase.size() == 2:
		set_cloud_offset(Vector2(float(phase[0]),float(phase[1])))

func snow_tint() -> Color:
	var day := smoothstep(-7.0,9.0,sin(PI*(_hour-6.0)/12.0)*42.0)
	var o := weather.overcast if weather != null else 0.0
	return Color(0.18,0.26,0.40).lerp(Color(0.92,0.95,1.0).lerp(Color(0.68,0.75,0.83),o),day)
