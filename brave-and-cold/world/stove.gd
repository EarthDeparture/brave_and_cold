class_name Stove
extends Node3D
## A placed stove that follows the fire standard: generated model (gen_stoves.py),
## FireSource rules, coal-bed ember window, firelight, crackle and chimney smoke.
## Owners (hut, store) give it a spot and a chimney top, add `footprint` to their
## collision, and route interactions through GameWorld.fire_actions().
const MODELS := {
	"box_stove": {"glb": "res://assets/stoves/box_stove.glb", "ember": Vector3(0, .31, .205), "ember_size": Vector2(.22, .16), "top": .58, "half": Vector2(.26, .23)},
	"pot_belly": {"glb": "res://assets/stoves/pot_belly.glb", "ember": Vector3(0, .40, .29), "ember_size": Vector2(.16, .12), "top": .77, "half": Vector2(.30, .30)},
}
var fire: FireSource
var smoke: GPUParticles3D
var footprint := Rect2()  # owner-local xz rectangle
var _ember: MeshInstance3D
var _light: OmniLight3D
var _snd: AudioStreamPlayer3D
var _t := 0.0
var _phase := randf() * 6.0
var kind := ""

## stack_from >= 0: also raise an iron stack (owner-local y stack_from -> chimney top) for shells
## whose model has no chimney of its own (the detail store shell).
func build(p_owner: Node3D, p_kind: String, local_pos: Vector3, chimney_top_local: Vector3, yaw := 0.0, stack_from := -1.0) -> void:
	kind = p_kind
	var spec: Dictionary = MODELS[kind]
	p_owner.add_child(self); position = local_pos; rotation.y = yaw
	fire = FireSource.new(kind)
	var model := (load(spec.glb) as PackedScene).instantiate() as Node3D; add_child(model)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var m := StandardMaterial3D.new(); m.vertex_color_use_as_albedo = true; m.roughness = 0.7; m.metallic = 0.35
		mi.material_override = m; mi.visibility_range_end = 70.0
	_ember = FireVisual.ember_window(spec.ember_size); add_child(_ember); _ember.position = spec.ember
	(_ember.material_override as ShaderMaterial).set_shader_parameter("intensity", 0.0)
	_light = OmniLight3D.new(); add_child(_light); _light.position = spec.ember + Vector3(0, .1, .35)
	_light.light_color = Color(1.0, .62, .36); _light.omni_range = 4.5; _light.shadow_enabled = false; _light.light_energy = 0.0
	_light.distance_fade_enabled = true; _light.distance_fade_begin = 40.0; _light.distance_fade_length = 10.0
	_snd = AudioStreamPlayer3D.new(); add_child(_snd); _snd.stream = Sfx.get_stream("fire")
	_snd.unit_size = 2.5; _snd.max_distance = 18.0; _snd.volume_db = -8.0; _snd.position = Vector3(0, .35, 0)
	smoke = FireVisual.smoke(p_owner, chimney_top_local, 16, 1.4)
	if stack_from >= 0.0:
		_build_stack(p_owner, chimney_top_local, stack_from)
	var half: Vector2 = spec.half
	if absf(sin(yaw)) > 0.7: half = Vector2(half.y, half.x)
	footprint = Rect2(local_pos.x - half.x, local_pos.z - half.y, half.x * 2, half.y * 2)

func _build_stack(p_owner: Node3D, top: Vector3, from_y: float) -> void:
	var iron := StandardMaterial3D.new(); iron.albedo_color = Color(.09, .085, .08); iron.roughness = .8; iron.metallic = .3
	var pipe := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = .075; cm.bottom_radius = .075; cm.height = top.y - from_y; cm.radial_segments = 10
	pipe.mesh = cm; pipe.material_override = iron; p_owner.add_child(pipe); pipe.position = Vector3(top.x, (top.y + from_y) * .5, top.z)
	var cap := MeshInstance3D.new(); var cc := CylinderMesh.new(); cc.top_radius = .03; cc.bottom_radius = .16; cc.height = .1; cc.radial_segments = 10
	cap.mesh = cc; cap.material_override = iron; p_owner.add_child(cap); cap.position = top + Vector3(0, .12, 0)
	pipe.visibility_range_end = 220.0; cap.visibility_range_end = 220.0

func top_world() -> Vector3:
	return to_global(Vector3(0, float(MODELS[kind].top), 0.1))

func advance(game_s: float) -> void:
	fire.advance(game_s)

func _process(delta: float) -> void:
	_t += delta
	var glow := fire.glow()
	var fl := 0.82 + 0.12 * sin(_t * 9.0 + _phase) + 0.06 * sin(_t * 23.0)
	(_ember.material_override as ShaderMaterial).set_shader_parameter("intensity", clampf(glow * fl, 0.0, 1.2))
	_light.light_energy = 1.3 * glow * fl
	_light.visible = glow > 0.0
	if fire.is_lit() and not _snd.playing: _snd.play()
	elif not fire.is_lit() and _snd.playing: _snd.stop()
