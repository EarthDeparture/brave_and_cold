shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Slope/height-based snow-rock blend for cold open-world terrain.
uniform vec4 snow_color : source_color = vec4(0.92, 0.94, 0.98, 1.0);
uniform vec4 rock_color : source_color = vec4(0.28, 0.26, 0.24, 1.0);
uniform float snow_roughness : hint_range(0.0, 1.0) = 0.25;
uniform float rock_roughness : hint_range(0.0, 1.0) = 0.85;

// Slopes steeper than this (in world-normal.y terms) are bare rock.
uniform float slope_threshold : hint_range(0.0, 1.0) = 0.7;
uniform float slope_blend_width : hint_range(0.001, 0.5) = 0.15;

// Below this world-space height, even flat ground shows rock.
uniform float snow_line_height = 0.0;
uniform float height_blend_width : hint_range(0.01, 5.0) = 1.5;

varying vec3 world_normal;
varying vec3 world_pos;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float slope_factor = smoothstep(slope_threshold - slope_blend_width, slope_threshold + slope_blend_width, world_normal.y);
	float height_factor = smoothstep(snow_line_height - height_blend_width, snow_line_height + height_blend_width, world_pos.y);
	float snow_amount = clamp(slope_factor * 0.5 + height_factor * 0.5 + slope_factor * height_factor * 0.5, 0.0, 1.0);

	ALBEDO = mix(rock_color.rgb, snow_color.rgb, snow_amount);
	ROUGHNESS = mix(rock_roughness, snow_roughness, snow_amount);
}
