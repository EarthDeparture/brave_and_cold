shader_type spatial;
// Greenhouse crops (tools/blender/gen_crops.py): colour from the vertex colours, thin leaves lit through from
// behind (sun through the poly glazing), two-sided with the normal flipped on the back face, a little
// per-plant colour jitter and a frost tint uniform for a cold night.
render_mode cull_disabled;

uniform float jitter = 0.0;           // -1..1 per plot: slightly paler / deeper green
uniform float frost = 0.0;            // 0..1: rimed, greyed leaves after a frost scare
uniform float withered = 0.0;         // 1 = frost-killed: matte, papery, no light through it
uniform vec3 translucency : source_color = vec3(0.30, 0.42, 0.10);

void fragment() {
	vec3 c = COLOR.rgb;
	c *= 1.0 + 0.12 * jitter;
	c = mix(vec3(dot(c, vec3(0.3, 0.59, 0.11))), c, 0.78);   // TLD palette: greens a little muted
	c = mix(c, vec3(0.55, 0.60, 0.62), frost * 0.55);
	ALBEDO = c;
	if (!FRONT_FACING) NORMAL = -NORMAL;
	ROUGHNESS = mix(mix(0.62, 0.85, frost), 0.97, withered);
	SPECULAR = mix(0.35, 0.08, withered);
	BACKLIGHT = translucency * c * 2.2 * (1.0 - 0.8 * withered);
}
