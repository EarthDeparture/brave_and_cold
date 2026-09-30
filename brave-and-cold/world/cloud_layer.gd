class_name CloudLayer
extends MeshInstance3D
## Cheap high cloud deck: one big plane following the camera, fbm-shaded, tinted by SkyRig each frame.

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 lit_color : source_color = vec3(1.0);
uniform vec3 shade_color : source_color = vec3(0.6, 0.65, 0.8);
uniform float coverage = 0.5;
uniform float drift = 0.0;
varying vec3 wpos;

float hash(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5; float s = 0.0;
	for (int i = 0; i < 5; i++) { s += a * vnoise(p); p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.03 + 11.7; a *= 0.5; }
	return s;
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = wpos.xz * 0.00035 + vec2(drift, drift * 0.35);
	float n = fbm(uv);
	float d = smoothstep(1.0 - coverage - 0.12, 1.0 - coverage + 0.12, n);
	// lit edge: sample toward the sun-ish direction for a cheap thickness cue
	float n2 = fbm(uv + vec2(0.012, 0.008));
	float thick = clamp((n - n2) * 14.0 + 0.5, 0.0, 1.0);
	vec3 col = mix(shade_color, lit_color, thick);
	float dist = length(wpos.xz - CAMERA_POSITION_WORLD.xz);
	float horizon = 1.0 - smoothstep(2500.0, 5500.0, dist);
	ALBEDO = col;
	ALPHA = d * horizon * 0.9;
}
"""

var mat := ShaderMaterial.new()
var follow: Node3D
var _t := 0.0


func _init() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(20000.0, 20000.0)
	pm.subdivide_width = 1
	pm.subdivide_depth = 1
	mesh = pm
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0


func set_tint(lit: Color, shade: Color, coverage: float) -> void:
	mat.set_shader_parameter("lit_color", lit)
	mat.set_shader_parameter("shade_color", shade)
	mat.set_shader_parameter("coverage", coverage)


func _process(delta: float) -> void:
	_t += delta
	mat.set_shader_parameter("drift", _t * 0.0004)
	if follow != null:
		# follow camera xz in coarse steps is not needed: shader uses world coords, so plane can follow exactly
		global_position = Vector3(follow.global_position.x, 1100.0, follow.global_position.z)
