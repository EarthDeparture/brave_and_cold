shader_type spatial;
render_mode specular_schlick_gg;

// Snow terrain material v1 (M2): banded painterly albedo + sun-driven sparkle.
// The sparkle reads as TLD's snow glint: view-dependent glints from a white-noise
// cell map, gated by the half-vector, so they shimmer as the camera moves.

uniform sampler2D snow_tex : source_color, repeat_enable;
uniform sampler2D sparkle_tex : repeat_enable;
uniform vec3 snow_tint : source_color = vec3(0.93, 0.95, 1.0);
uniform float sparkle_threshold : hint_range(0.99, 1.0) = 0.9985;
uniform float sparkle_strength : hint_range(0.0, 8.0) = 3.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = texture(snow_tex, world_pos.xz * 0.35).rgb;
	ALBEDO = base * snow_tint;
	ROUGHNESS = 0.88;
	SPECULAR = 0.45;
}

void light() {
	float cell = texture(sparkle_tex, world_pos.xz * 4.0).r;
	vec3 half_vec = normalize(VIEW + LIGHT);
	float glint = step(sparkle_threshold, cell)
	            * pow(max(dot(NORMAL, half_vec), 0.0), 24.0);
	DIFFUSE_LIGHT += glint * LIGHT_COLOR.rgb * LIGHT_COLOR.a * ATTENUATION * sparkle_strength;
}
