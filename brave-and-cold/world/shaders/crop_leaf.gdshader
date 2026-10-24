shader_type spatial;
// Greenhouse crops (tools/blender/gen_crops.py): colour from the vertex colours, thin leaves lit through from
// behind (sun through the poly glazing), two-sided with the normal flipped on the back face, a little
// per-plant colour jitter and a frost tint uniform for a cold night.
render_mode cull_disabled;

uniform float jitter = 0.0;           // -1..1 per plot: slightly paler / deeper green
uniform float frost = 0.0;            // 0..1: rimed, greyed leaves after a frost scare
uniform float withered = 0.0;         // 1 = frost-killed: matte, papery, no light through it
uniform vec3 translucency : source_color = vec3(0.30, 0.42, 0.10);

uniform float veins = 1.0;             // A7: pinnate venation on the leaf blades (UV: u across, v along)

// Midrib down the middle (tapering to the tip) and lateral veins running out and forward to the margin.
// Leaves carry UV v > 0; stems / roots / bulbs have UV (0, 0) and get none.
float vein_mask(vec2 uv) {
	if (uv.y < 0.005) return 0.0;
	float au = abs(uv.x - 0.5);
	float mid = 1.0 - smoothstep(0.0, 0.028 * (1.0 - 0.7 * uv.y) + 0.004, au);
	float f = fract(uv.y * 8.0 - au * 2.4);
	float lat = (1.0 - smoothstep(0.0, 0.07, min(f, 1.0 - f))) * (1.0 - smoothstep(0.28, 0.48, au)) * smoothstep(0.03, 0.08, au);
	return max(mid, lat * 0.55) * smoothstep(0.0, 0.06, uv.y);
}

void fragment() {
	vec3 c = COLOR.rgb;
	float vn = vein_mask(UV) * veins * (1.0 - withered);
	c = mix(c, c * 1.22 + vec3(0.025, 0.03, 0.01), vn * 0.55);   // veins paler, a touch yellower than the blade
	c *= 1.0 + 0.12 * jitter;
	c = mix(vec3(dot(c, vec3(0.3, 0.59, 0.11))), c, 0.78);   // TLD palette: greens a little muted
	c = mix(c, vec3(0.55, 0.60, 0.62), frost * 0.55);
	ALBEDO = c;
	if (!FRONT_FACING) NORMAL = -NORMAL;
	ROUGHNESS = mix(mix(0.62, 0.85, frost), 0.97, withered);
	SPECULAR = mix(0.35, 0.08, withered);
	BACKLIGHT = translucency * c * 2.2 * (1.0 - 0.8 * withered) * (1.0 - 0.45 * vn);   // veins block the light
}
