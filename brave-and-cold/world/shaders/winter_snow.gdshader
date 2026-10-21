shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec3 flake_tint = vec3(0.8,0.86,0.93);
// The player's torch / weapon light (GameWorld._update_beams): flakes inside the cone catch it. This is how a beam
// reads in falling snow - a sparkling cone of lit flakes - far more than any haze shaft.
global uniform vec4 player_lamp_pos;   // xyz, w = strength (0 off)
global uniform vec4 player_lamp_dir;   // xyz unit, w = cos(half angle)
global uniform float player_lamp_range;
uniform int shelter_count = 0;
uniform vec4 shelter_frames[16]; // centre x,z, cosine and sine of yaw
uniform vec4 shelter_bounds[16]; // local half width/depth, floor and roof heights
varying vec3 flake_position;
varying float lamp_lit;
void vertex() {
	flake_position = MODEL_MATRIX[3].xyz;
	lamp_lit = 0.0;
	if (player_lamp_pos.w > 0.0 && player_lamp_range > 0.0) {
		vec3 L = flake_position - player_lamp_pos.xyz;
		float d = max(length(L), 0.05);
		float c = dot(L / d, player_lamp_dir.xyz);
		float cone = smoothstep(player_lamp_dir.w - 0.02, mix(player_lamp_dir.w, 1.0, 0.55), c);
		float fall = pow(clamp(1.0 - d / player_lamp_range, 0.0, 1.0), 2.0) / (1.0 + 0.05 * d * d);
		lamp_lit = player_lamp_pos.w * cone * fall;
	}
	// a lit flake glints: it reads bigger than a dark one of the same size
	float grow = 1.0 + 1.4 * clamp(lamp_lit * 2.5, 0.0, 1.0);
	mat4 facing = mat4(
		INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz)*grow,
		INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz)*grow,
		INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	for (int i=0;i<16;i++) {
		if (i>=shelter_count) { break; }
		vec4 frame = shelter_frames[i];
		vec4 bounds = shelter_bounds[i];
		vec2 relative = flake_position.xz-frame.xy;
		vec2 local = vec2(frame.z*relative.x-frame.w*relative.y,frame.w*relative.x+frame.z*relative.y);
		if (abs(local.x)<bounds.x && abs(local.y)<bounds.y && flake_position.y>bounds.z && flake_position.y<bounds.w) {
			discard;
		}
	}
	float disc = 1.0-smoothstep(0.16,0.50,length(UV-vec2(0.5)));
	float near_fade = smoothstep(0.4,2.0,length(flake_position-CAMERA_POSITION_WORLD));
	float lit = lamp_lit;
	// flakes a metre or two away in the beam are the brightest thing in it: let them come close when lit
	float cam_d = length(flake_position-CAMERA_POSITION_WORLD);
	float fade_k = mix(near_fade, smoothstep(0.22, 0.7, cam_d), clamp(lit * 3.0, 0.0, 1.0));
	ALBEDO = flake_tint + vec3(1.0, 0.95, 0.85) * lit * 7.0;
	ALPHA = clamp(disc * fade_k * (0.70 + 0.30 * min(lit * 2.0, 1.0)), 0.0, 1.0);
}
