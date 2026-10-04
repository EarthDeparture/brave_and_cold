shader_type sky;
render_mode use_half_res_pass, disable_fog;

uniform vec3 zenith_color : source_color = vec3(0.12, 0.29, 0.56);
uniform vec3 haze_color = vec3(0.3,0.45,0.6);
uniform vec3 horizon_color : source_color = vec3(0.65, 0.78, 0.88);
uniform vec3 sunset_color : source_color = vec3(1.0, 0.57, 0.27);
uniform vec3 cloud_light : source_color = vec3(0.92, 0.94, 0.94);
uniform vec3 cloud_shadow : source_color = vec3(0.36, 0.47, 0.61);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.72);
uniform vec3 sun_direction = vec3(0.0, 0.6, -0.8);
uniform vec3 moon_direction = vec3(0.0, 0.6, 0.8);
uniform vec2 cloud_offset = vec2(0.0);
uniform sampler2D cloud_fields : filter_linear_mipmap, repeat_enable;
uniform float coverage = 0.35;
uniform float overcast = 0.0;
uniform float daylight = 1.0;
uniform float twilight = 0.0;
uniform float moon_strength = 0.0;

float hash21(vec2 p) {
	// Combine axes independently: x^y alone repeats along lattice diagonals.
	ivec2 cell = ivec2(p);
	uint h = uint(cell.x)*374761393u + uint(cell.y)*668265263u;
	h = (h ^ (h >> 13u))*1274126177u;
	return float((h ^ (h >> 16u)) & 16777215u)/16777215.0;
}
float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1,0)), f.x),
		mix(hash21(i + vec2(0,1)), hash21(i + vec2(1)), f.x), f.y);
}
float fbm(vec2 p) {
	return textureLod(cloud_fields,p*0.065,0.0).r;
}
vec3 atmosphere(vec3 d) {
	float altitude = max(d.y, 0.0);
	vec3 color = mix(haze_color, zenith_color, 1.0-exp(-altitude*5.0));
	vec3 horizontal_sun = normalize(vec3(sun_direction.x,0.0001,sun_direction.z));
	float toward_sun = pow(max(dot(normalize(vec3(d.x,0.0001,d.z)), horizontal_sun),0.0), 3.0);
	float warm_band = smoothstep(0.0,0.08,altitude) * exp(-altitude * 7.0) * twilight * (0.16 + 0.84 * toward_sun);
	color = mix(color, sunset_color, warm_band * (1.0-overcast*0.7));
	float glow = pow(max(dot(d, sun_direction),0.0), 24.0);
	color += sun_color * glow * daylight * (0.12 + twilight*0.22) * (1.0-overcast*0.8);
	// Same horizon below eye level: no hard ground/sky seam from an elevated lookout.
	if (d.y < 0.0) {
		color = haze_color;
	}
	return color;
}
vec4 clouds(vec3 d) {
	if (d.y < -0.025) { return vec4(0.0); }
	// Bounded curved projection avoids a horizon singularity and distant plane edges.
	vec2 p = d.xz / (max(d.y,0.0)*0.65 + 0.32) * 3.3 + cloud_offset;
	vec2 warp = vec2(textureLod(cloud_fields,p*0.033,0.0).b,textureLod(cloud_fields,p*0.033+vec2(0.31,0.17),0.0).b) - 0.5;
	p += warp * 1.6;
	float shape = fbm(p);
	float wisps = textureLod(cloud_fields,p*0.065 + cloud_offset*0.018,0.0).g;
	float n = shape * 0.86 + wisps * 0.14;
	float threshold = 0.67 - coverage * 0.28;
	float density = smoothstep(threshold-0.015,threshold+0.032,n);
	density = mix(density, max(density,0.90), smoothstep(0.72,1.0,overcast));
	vec2 light_vector = normalize(sun_direction.xz+vec2(0.0001));
	float toward_light = fbm(p + light_vector * 0.28);
	float depth = smoothstep(threshold,threshold+0.20,n);
	float body = clamp(0.72-depth*0.38+(n-toward_light)*4.5,0.0,1.0);
	float edge = (1.0-smoothstep(threshold,threshold+0.09,n))*density;
	float forward = pow(max(dot(d,sun_direction),0.0),8.0);
	vec3 col = mix(cloud_shadow,cloud_light,body * (1.0-overcast*0.45));
	col += cloud_light * edge * (0.3+forward*0.6) * daylight;
	// Thin high layer uses a different scale and direction, without sharp noise.
	float high = smoothstep(0.55,0.76,fbm(p*0.44+vec2(32.0,-19.0)+cloud_offset*0.24));
	col = mix(col,cloud_light,high*0.18);
	density = max(density,high*0.24*(1.0-overcast));
	float horizon_fade = smoothstep(-0.025,0.10,d.y);
	col = mix(atmosphere(d),col,horizon_fade);
	return vec4(col,density*horizon_fade);
}
float stars(vec3 d) {
	// Three-dimensional cells prevent panorama seams; derivatives soften subpixel stars.
	vec3 p = d * 380.0;
	vec3 cell = floor(p);
	vec3 f = fract(p)-0.5;
	float random = hash21(cell.xy + cell.z*vec2(17.0,43.0));
	float radius = mix(0.018,0.065,hash21(cell.yz+3.7));
	float aa = max(length(fwidth(p)),0.025);
	float spot = 1.0-smoothstep(radius,radius+aa,length(f));
	return spot * step(0.986,random) * smoothstep(0.04,0.28,d.y);
}
void sky() {
	vec3 d = normalize(EYEDIR);
	if (AT_HALF_RES_PASS) {
		vec4 deck = clouds(d);
		COLOR = deck.rgb;
		ALPHA = deck.a;
	} else if (AT_CUBEMAP_PASS) {
		// Lighting gets the same palette and cloud cover at a bounded cost.
		vec3 base = atmosphere(d);
		float veil = coverage * smoothstep(0.0,0.45,d.y);
		COLOR = mix(base, mix(cloud_shadow,cloud_light,0.42),veil*0.70);
	} else {
		vec3 base = atmosphere(d);
		float sun_dot = dot(d,sun_direction);
		float disk = smoothstep(cos(0.008),cos(0.0065),sun_dot);
		base += sun_color * disk * 5.0 * daylight * (1.0-overcast);
		float moon_dot = dot(d,moon_direction);
		float moon_disk = smoothstep(cos(0.014),cos(0.012),moon_dot);
		float moon_texture = 0.80 + 0.20*noise2(d.xz*630.0);
		base += vec3(0.65,0.76,0.92) * moon_disk * moon_texture * moon_strength;
		base += vec3(0.72,0.80,1.0) * pow(max(moon_dot,0.0),180.0) * moon_strength * 0.07;
		base += vec3(0.62,0.74,0.98) * stars(d) * (1.0-daylight) * (1.0-overcast) * 0.65;
		COLOR = mix(base,HALF_RES_COLOR.rgb,HALF_RES_COLOR.a);
	}
}
