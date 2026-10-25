shader_type spatial;
// Bare hands (weapons W8). The approved anatomical textures (albedo, normal, roughness) plus what read as
// "smooth plastic" up close: pores and fine crease grain as a micro-bump in object space (the hand is ~20 cm, so
// object space = real millimetres), roughness that varies (oily knuckles, dry backs), subsurface scattering and
// a little red light through thin fingers. `tint` carries the cold colour (SurvivorHandRig.set_cold).
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(0.80, 0.66, 0.57, 1.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform float normal_scale = 1.0;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap;
uniform vec4 rough_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform float roughness = 0.72;
uniform float pore_strength = 0.35;
uniform float sss = 0.22;
uniform vec3 backlight_col : source_color = vec3(0.16, 0.06, 0.04);   // W8: a torch 0.5 m away turned the hand neon red

varying vec3 opos;

float h3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float vnoise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h3(i), h3(i + vec3(1,0,0)), f.x), mix(h3(i + vec3(0,1,0)), h3(i + vec3(1,1,0)), f.x), f.y);
	float b = mix(mix(h3(i + vec3(0,0,1)), h3(i + vec3(1,0,1)), f.x), mix(h3(i + vec3(0,1,1)), h3(i + vec3(1,1,1)), f.x), f.y);
	return mix(a, b, f.z);
}
// pores: cellular-ish pits ~0.5 mm apart
float pores(vec3 p) {
	vec3 q = p * 1700.0;
	vec3 i = floor(q); vec3 f = fract(q);
	float d = 1.0;
	for (int z = -1; z <= 1; z++) for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec3 g = vec3(float(x), float(y), float(z));
		vec3 o = vec3(h3(i + g), h3(i + g + 17.0), h3(i + g + 31.0));
		d = min(d, length(g + o - f));
	}
	return smoothstep(0.0, 0.45, d);   // 0 in a pore, 1 on the skin between
}

void vertex() { opos = VERTEX; }

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb * tint.rgb;
	float grain = vnoise(opos * 260.0);                     // fine crease grain / skin lines
	float hgt = pores(opos) * 0.6 + grain * 0.4;
	// fade the micro bump out before it aliases (far / small on screen)
	float px = length(fwidth(opos)) * 1700.0;
	float k = pore_strength * clamp(1.4 - px, 0.0, 1.0);
	vec3 dpdx = dFdx(VERTEX); vec3 dpdy = dFdy(VERTEX);
	float dhx = dFdx(hgt); float dhy = dFdy(hgt);
	vec3 r1 = cross(dpdy, NORMAL); vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * k * 0.0009);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	float rt = dot(texture(rough_tex, UV), rough_channel);
	float rv = mix(0.86, 1.12, vnoise(opos * 70.0));        // oily/dry patches
	ROUGHNESS = clamp(roughness * rt * rv + (1.0 - pores(opos)) * 0.08, 0.3, 1.0);
	SPECULAR = 0.3;
	ALBEDO = base * mix(0.92, 1.0, grain);
	SSS_STRENGTH = sss;
	BACKLIGHT = backlight_col;
}
