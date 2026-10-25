class_name FireVisual
extends RefCounted
## Shared fire presentation pieces so every FireSource looks the same family:
## the lookout's coal-bed ember window and its soft billboard smoke column.
const EMBER_SHADER := preload("res://world/shaders/stove_embers.gdshader")
static var _puff_tex: ImageTexture

## Coal bed seen through a stove door. Set "intensity" (0..1) from FireSource.glow().
static func ember_window(size: Vector2) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = size; mi.mesh = q
	var m := ShaderMaterial.new(); m.shader = EMBER_SHADER; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Chimney / campfire smoke column. Drive with set_smoke().
static func smoke(parent: Node3D, local_pos: Vector3, amount := 20, puff := 1.6) -> GPUParticles3D:
	var p := GPUParticles3D.new(); parent.add_child(p); p.position = local_pos
	p.amount = amount; p.lifetime = 4.0; p.preprocess = 1.0; p.emitting = false
	p.visibility_aabb = AABB(Vector3(-10, -2, -10), Vector3(20, 15, 20))
	var motion := ParticleProcessMaterial.new(); motion.direction = Vector3.UP; motion.spread = 12.0
	motion.initial_velocity_min = .35; motion.initial_velocity_max = .65; motion.scale_min = .18; motion.scale_max = .42
	motion.gravity = Vector3(0, .45, 0)
	var ramp := Gradient.new(); ramp.offsets = PackedFloat32Array([0, .12, .65, 1])
	ramp.colors = PackedColorArray([Color(.42, .45, .47, 0), Color(.70, .72, .74, .18), Color(.76, .78, .80, .10), Color(.52, .54, .56, 0)])
	var fade := GradientTexture1D.new(); fade.gradient = ramp; motion.color_ramp = fade; p.process_material = motion
	if _puff_tex == null:
		var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var r := Vector2((x - 31.5) / 31.5, (y - 31.5) / 31.5).length()
				image.set_pixel(x, y, Color(1, 1, 1, pow(maxf(0, 1 - r * r), 2)))
		_puff_tex = ImageTexture.create_from_image(image)
	var material := StandardMaterial3D.new(); material.albedo_texture = _puff_tex; material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true; material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new(); quad.size = Vector2(puff, puff); quad.material = material
	p.draw_pass_1 = quad; p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

## Smoke follows the wind; embers give a thin wisp, a cold fire none.
static func set_smoke(p: GPUParticles3D, src: FireSource, wind_dir: Vector2) -> void:
	if p == null: return
	p.emitting = src.is_lit() or src.has_embers()
	p.amount_ratio = 1.0 if src.is_lit() else 0.35
	(p.process_material as ParticleProcessMaterial).gravity = Vector3(wind_dir.x * .18, .45, wind_dir.y * .18)
