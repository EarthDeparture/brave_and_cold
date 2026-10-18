shader_type spatial;
// Sight glass for weapon kit v3. Clear coated glass with a fresnel sheen. For reflex sights and
// red-dot tubes the dot is collimated: it is lit wherever the eye ray through this pane runs
// within dot_mrad of the sight axis (the bore line), so it stays on the target while the frame
// drifts, and is only seen through the glass, like the real thing. Scope lenses: dark, no dot.
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

uniform vec3 axis_world = vec3(0.0, 0.0, -1.0);   // set every frame by WeaponPresentation
uniform float dot_on = 0.0;
uniform float dot_mrad = 4.0;
uniform float glow_mrad = 11.0;
uniform float brightness = 1.0;                   // dimmer at night (auto)
uniform vec4 tint : source_color = vec4(0.55, 0.80, 0.85, 0.07);
uniform vec3 dot_color : source_color = vec3(1.0, 0.10, 0.05);
uniform float dark = 0.0;                         // scope objective / eyepiece: dark glass

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 ray = normalize(world - CAMERA_POSITION_WORLD);
	float ang = acos(clamp(dot(ray, normalize(axis_world)), -1.0, 1.0)) * 1000.0;   // mrad
	float core = 1.0 - smoothstep(dot_mrad * 0.7, dot_mrad, ang);
	float halo = exp(-(ang * ang) / (glow_mrad * glow_mrad)) * 0.28;
	float d = (core + halo) * dot_on;
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 4.0);
	ALBEDO = mix(tint.rgb, vec3(0.015, 0.018, 0.03), dark);
	EMISSION = vec3(0.0);
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = mix(0.7, 0.22, dark);                 // coated scope glass reads dark, not mirror-white
	EMISSION = dot_color * d * 7.0 * brightness;
	ALPHA = clamp(mix(tint.a, 0.88, dark) + fres * 0.30 + core * dot_on, 0.0, 1.0);
}
