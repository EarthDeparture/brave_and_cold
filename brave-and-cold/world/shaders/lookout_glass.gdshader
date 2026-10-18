shader_type spatial;
// Fire-lookout cab glass: same look as the imported glass (vertex-colour albedo/alpha, low
// roughness, depth pre-pass), plus a night glow seen from outside that is NOT one flat sheet:
//  - per-pane brightness (hash of the pane index), a few panes half-curtained,
//  - pooled light: brighter near the desk lamp and low in the frame, cooler toward the roof,
//  - the stove side flickers warm orange while the stove burns,
//  - fades out within ~9 m so on the deck you see the real lit room through clear glass.
render_mode blend_mix, depth_prepass_alpha, cull_disabled, specular_schlick_ggx;

uniform float glow = 0.0;          // 0..1 from FireLookout.set_night (0 inside the cab)
uniform float fire = 0.0;          // 0..1 stove burning
uniform vec3 glow_color : source_color = vec3(1.0, 0.64, 0.36);
uniform vec3 fire_color : source_color = vec3(1.0, 0.45, 0.18);
uniform vec2 lamp_xz = vec2(0.68, -1.50);
uniform vec2 stove_xz = vec2(-1.65, 1.20);
uniform float sill_y = 22.5;       // model-space window band
uniform float head_y = 23.8;
uniform float pane_w = 0.9;
uniform float near_fade_start = 4.0;
uniform float near_fade_end = 9.0;

varying vec3 local_pos;
varying vec3 local_nrm;

float hash1(float n) { return fract(sin(n * 127.1 + 311.7) * 43758.5453); }

void vertex() {
	local_pos = VERTEX;
	local_nrm = NORMAL;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
	ROUGHNESS = 0.24;
	METALLIC = 0.0;
	if (glow > 0.001) {
		// which wall: the axis the normal points along; u runs along that wall
		bool x_wall = abs(local_nrm.x) > abs(local_nrm.z);
		float u = x_wall ? local_pos.z : local_pos.x;
		float wall = x_wall ? (local_nrm.x > 0.0 ? 1.0 : 2.0) : (local_nrm.z > 0.0 ? 3.0 : 4.0);
		float pane = floor(u / pane_w);
		float h = hash1(pane * 7.0 + wall * 31.0);
		float pane_k = mix(0.62, 1.12, h);
		float v = clamp((local_pos.y - sill_y) / (head_y - sill_y), 0.0, 1.0);
		// a few panes have a pulled blind: the upper part goes dim
		if (hash1(pane * 3.0 + wall * 17.0 + 5.0) < 0.18) pane_k *= mix(1.0, 0.25, smoothstep(0.35, 0.45, v));
		float lamp = 1.0 / (1.0 + 0.22 * dot(local_pos.xz - lamp_xz, local_pos.xz - lamp_xz));
		float stove = 1.0 / (1.0 + 0.35 * dot(local_pos.xz - stove_xz, local_pos.xz - stove_xz));
		float pool = mix(1.0, 0.55, smoothstep(0.15, 1.0, v)) * (0.55 + 0.75 * lamp);
		float flick = 0.86 + 0.14 * sin(TIME * 7.3 + h * 6.0) * sin(TIME * 2.9 + 1.7);
		vec3 col = glow_color * pool * pane_k + fire_color * fire * stove * flick * 0.9;
		// soft dark frame line at pane edges so each pane reads as its own lit square
		float fu = fract(u / pane_w);
		float edge = smoothstep(0.0, 0.035, fu) * smoothstep(0.0, 0.035, 1.0 - fu);
		vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float d = length(world - CAMERA_POSITION_WORLD);
		float far = mix(0.12, 1.0, smoothstep(near_fade_start, near_fade_end, d));
		EMISSION = col * glow * edge * far * 2.1;
	}
}
