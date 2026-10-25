shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;
// X3: fur look for the lofted animals (wolf / deer / bear). No shells or cards: vertex colours broken up by
// clumped strands running along the body (object space: the models face -Z), soft wrapped diffuse, a pale fuzz
// rim where the coat turns away from the light, a little light through the thin edges. Roughness 1, weak spec.

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;   // Cabin._grain_tex (greys 0.66..1)
uniform float strand = 1.0;      // strand / clump contrast
uniform float rim = 0.16;        // fuzz rim strength (0.45 washed the coats out in snow light)
uniform float scale = 1.0;       // model scale (bear fur is coarser)
uniform vec4 tint = vec4(1.0);   // carcass stages darken / redden the coat (Carcass.update_stage)
uniform float wet = 0.0;         // 1 = soaked raw meat: glossy

varying vec3 op;
varying vec3 on;

void vertex() {
	op = VERTEX / scale;
	on = NORMAL;
}

float nz(vec2 uv) { return clamp((texture(noise_tex, uv).r - 0.66) / 0.34, 0.0, 1.0); }

void fragment() {
	vec3 c = COLOR.rgb;
	// strands run back along the body (z) and down the legs (y): stretch the noise across them
	vec3 an = abs(normalize(on));
	vec2 uv_side = vec2(op.z * 1.2, op.y * 9.0);       // flanks: streaks along the body
	vec2 uv_top = vec2(op.z * 1.2, op.x * 9.0);        // back
	vec2 uv_leg = vec2(op.x * 9.0 + op.z * 9.0, op.y * 1.5);
	float s_side = nz(uv_side) * 0.6 + nz(uv_side * 2.7 + 3.1) * 0.4;
	float s_top = nz(uv_top) * 0.6 + nz(uv_top * 2.7 + 1.7) * 0.4;
	float s_leg = nz(uv_leg);
	float legs = 1.0 - smoothstep(0.35, 0.5, op.y);   // below the belly line
	float s = mix(mix(s_side, s_top, an.y), s_leg, legs);
	float clump = nz(op.zy * 0.8 + op.x) ;
	c *= mix(1.0, 0.72 + 0.5 * s, strand) * (0.9 + 0.2 * clump);
	c *= tint.rgb;
	ALBEDO = c;
	ROUGHNESS = mix(1.0, 0.45, wet);
	SPECULAR = mix(0.12, 0.4, wet);
	// fuzz: fibres catch light at grazing angles
	RIM = rim;
	RIM_TINT = 0.85;
	BACKLIGHT = c * 0.08;
}
