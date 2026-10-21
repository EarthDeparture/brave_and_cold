shader_type spatial;
// Fake light shaft for a flashlight / weapon light: an open cone (apex at the lamp, opening along the
// mesh -Y) drawn additive. Only shows when there is something in the air to catch it (snowfall, fog,
// night haze): GameWorld drives `intensity` from the weather and the darkness.
// Seen from the holder the camera sits inside the cone, so there is no view-angle term (that made the
// shaft vanish in first person): brightness is the haze along the beam, fading with distance from the
// lamp, faded softly where the cone meets geometry (scene depth) and right at the camera.
render_mode blend_add, depth_draw_never, depth_test_disabled, cull_disabled, unshaded, shadows_disabled, fog_disabled;

uniform float intensity = 0.0;
uniform float length_m = 30.0;
uniform vec3 tint : source_color = vec3(1.0, 0.94, 0.82);
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying float along;

void vertex() {
	along = clamp(-VERTEX.y / length_m + 0.5, 0.0, 1.0);   // 0 at the lamp .. 1 at the far end (CylinderMesh is centred)
}

void fragment() {
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float scene = -vp.z / vp.w;
	float here = -VERTEX.z;
	float soft = clamp((scene - here) / 1.5, 0.0, 1.0);          // hidden behind / fading into what it lights
	float near = smoothstep(0.25, 0.8, here);                      // no smear across the lens
	float fall = pow(1.0 - along, 1.6) * smoothstep(0.0, 0.05, along);
	float a = intensity * fall * soft * near * 0.075;
	ALBEDO = tint * a;
	ALPHA = a;
}
