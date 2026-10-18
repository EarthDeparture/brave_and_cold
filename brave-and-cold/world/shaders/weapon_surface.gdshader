shader_type spatial;
// Weapon kit v3 surfaces: the generated albedo tile + a hand-wear pass driven by the GLB's
// vertex colour mask (R = convex edge, G = 1 - cavity). Worn edges: bluing rubs to bare steel,
// oiled wood goes pale and dry, black synthetic scuffs grey; cavities collect grime.
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform int family = 0;                 // 0 wood, 1 metal, 2 synthetic, 3 fabric
uniform float roughness_base = 0.5;
uniform float metallic_base = 0.0;
uniform float wear = 0.7;               // 0 factory new .. 1 hard-used
uniform vec3 bare_metal : source_color = vec3(0.62, 0.63, 0.64);
uniform float has_mask = 1.0;

varying vec3 vpos;

float h3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float vnoise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h3(i), h3(i + vec3(1,0,0)), f.x), mix(h3(i + vec3(0,1,0)), h3(i + vec3(1,1,0)), f.x), f.y);
	float b = mix(mix(h3(i + vec3(0,0,1)), h3(i + vec3(1,0,1)), f.x), mix(h3(i + vec3(0,1,1)), h3(i + vec3(1,1,1)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() { vpos = VERTEX; }

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	float edge = mix(0.0, COLOR.r, has_mask);
	float open = mix(1.0, COLOR.g, has_mask);
	float n = vnoise(vpos * 220.0) * 0.6 + vnoise(vpos * 60.0) * 0.4;
	// wear only on the sharpest convex edges (coarse lofts carry broad R gradients: a low threshold made blotches)
	float w = smoothstep(0.48, 0.82, edge * 1.15 + (n - 0.5) * 0.40) * wear;
	// faint all-over handling marks (hands rub the middle of parts too), mostly on wood
	float rub = smoothstep(0.70, 0.97, vnoise(vpos * 35.0)) * (family == 0 ? 0.22 : 0.08) * wear;
	vec3 worn = base;
	float rough = roughness_base;
	float metal = metallic_base;
	if (family == 0) { worn = base * 1.35 + vec3(0.05, 0.035, 0.015); rough = mix(roughness_base, 0.85, w); }
	else if (family == 1) { worn = bare_metal; rough = mix(roughness_base, 0.28, w); metal = mix(metallic_base, 0.95, w); }
	else if (family == 2) { worn = base + vec3(0.10); rough = mix(roughness_base, 0.55, w); }
	else { worn = base * 1.15; }
	vec3 c = mix(base, worn, clamp(w + rub * (family == 1 ? 0.6 : 0.3), 0.0, 1.0));
	c *= mix(0.55, 1.0, open);                 // grime in recesses
	ALBEDO = c;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = family == 1 ? 0.6 : 0.4;
}
