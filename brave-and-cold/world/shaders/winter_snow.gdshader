shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec3 flake_tint = vec3(0.8,0.86,0.93);
uniform int shelter_count = 0;
uniform vec4 shelter_frames[16]; // centre x,z, cosine and sine of yaw
uniform vec4 shelter_bounds[16]; // local half width/depth, floor and roof heights
varying vec3 flake_position;
void vertex() {
	flake_position = MODEL_MATRIX[3].xyz;
	mat4 facing = mat4(
		INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),
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
	ALBEDO = flake_tint;
	ALPHA = disc * near_fade * 0.70;
}
