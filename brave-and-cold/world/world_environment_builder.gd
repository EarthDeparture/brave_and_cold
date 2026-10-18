class_name WorldEnvironmentBuilder
extends RefCounted
## The game's sun, sky material and Environment, shared by GameWorld and the menu diorama
## so the live menu scene can never drift from the game's lighting setup.

## Adds a DirectionalLight3D and a WorldEnvironment under `parent`.
## Returns {"sun": DirectionalLight3D, "sky_mat": ProceduralSkyMaterial, "env": Environment}.
static func build(parent: Node) -> Dictionary:
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.shadow_bias = 0.15
	sun.shadow_normal_bias = 3.0
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 300.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	parent.add_child(sun)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.12
	sky_mat.ground_curve = 0.05
	sky_mat.sun_angle_max = 8.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_sky_affect = 0.6
	env.fog_aerial_perspective = 0.5
	env.ssao_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	return {"sun": sun, "sky_mat": sky_mat, "env": env}


## Terrain3D exactly as the game sets it up (detail winter assets, macro variation).
static func terrain(parent: Node, map_dir: String, assets_path: String) -> Terrain3D:
	var t := Terrain3D.new()
	t.name = "Terrain3D"
	t.assets = load(assets_path)
	t.data_directory = map_dir
	parent.add_child(t)
	t.material.auto_shader = false
	t.material.set_shader_param("blend_sharpness", 0.1)
	t.material.set_shader_param("enable_macro_variation", true)
	t.material.set_shader_param("macro_variation1", Color(0.88, 0.93, 1.0))
	t.material.set_shader_param("macro_variation2", Color(1.0, 0.97, 0.98))
	return t
