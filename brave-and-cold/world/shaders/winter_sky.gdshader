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
uniform bool cloud_quality = true;
uniform float aurora = 0.0;          // 0..1, AmbientLife: about one clear night in four
uniform float aurora_time = 0.0;

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
	if (cloud_quality) {
		// Broad density transition and directional thickness give connected
		// cloud masses shaded undersides without additive white edge clipping.
		float thickness = smoothstep(threshold-0.035,threshold+0.16,n);
		float shaded = fbm(p+light_vector*0.65);
		float light_access = clamp(0.54-thickness*0.27+(n-toward_light)*1.6+(n-shaded)*0.65,0.08,0.84);
		light_access *= 1.0-overcast*0.28;
		col = mix(cloud_shadow,cloud_light,light_access);
		float silver = (1.0-thickness)*forward*daylight*(1.0-overcast)*0.20;
		col = mix(col,cloud_light,silver);
		col = mix(col,cloud_light,high*0.10);
		density = smoothstep(threshold-0.045,threshold+0.065,n);
		float storm_deck = smoothstep(0.72,1.0,overcast);
		density = mix(density,max(density,0.82+shape*0.12),storm_deck);
		density = max(density,high*0.20*(1.0-overcast));
	}
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
// Aurora: curtains = ribbons on a plane, extruded upward by marching stacked planes along the view ray. The
// same ground track at every height gives the vertical ray structure; the bottom edge is bright and sharp,
// green fading to violet at the top. Ribbons wander on a slow domain warp; fine rays shimmer along them.
float aurora_ribbon(vec2 q, float t) {
	float w = noise2(q * 0.2 + vec2(t * 0.020, -t * 0.013)) * 2.6 + noise2(q * 0.6 - vec2(t * 0.045, 0.0)) * 0.6;
	float y = q.y + w * 1.5 + sin(q.x * 0.16 + t * 0.03) * 1.2;
	float r = abs(fract(y * 0.09) - 0.5) * 2.0;                 // 0 on a ribbon's centre line
	float band = exp(-r * r * 70.0) + 0.12 * exp(-r * r * 12.0);
	float region = smoothstep(0.22, 0.52, noise2(q * 0.05 + vec2(3.1, t * 0.004)));   // only an arc or two
	float rays = 0.40 + 0.60 * noise2(vec2(q.x * 1.6 + y * 0.5 + t * 0.25, y * 0.3));
	return band * region * rays;
}
vec3 aurora_light(vec3 d, float jitter) {
	if (d.y < 0.03) { return vec3(0.0); }
	vec3 acc = vec3(0.0);
	float t = aurora_time;
	for (int i = 0; i < 20; i++) {
		float hf = (float(i) + jitter) / 20.0;
		float h = 1.0 + hf * 1.1;
		vec2 q = d.xz / (d.y + 0.08) * h * 5.0 + vec2(4.0, 9.0);
		float c = aurora_ribbon(q, t);
		vec3 col = mix(vec3(0.10, 1.00, 0.42), vec3(0.20, 0.75, 0.62), smoothstep(0.15, 0.5, hf));
		col = mix(col, vec3(0.55, 0.22, 0.85), smoothstep(0.55, 1.0, hf));
		acc += col * c * exp(-hf * 2.8) * smoothstep(0.0, 0.05, hf);
	}
	acc /= 20.0;
	float horizon = smoothstep(0.03, 0.22, d.y);
	vec2 north = normalize(d.xz + vec2(0.0001));
	float bias = 0.45 + 0.55 * smoothstep(-0.4, 0.6, -north.y);   // brighter toward the north (-z)
	float pulse = 0.75 + 0.25 * sin(t * 0.07 + d.x * 2.0);
	return acc * horizon * bias * pulse * 3.2;
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
		// The aurora lights the snow a little green (cheap: no curtains in the radiance pass).
		COLOR += vec3(0.01, 0.05, 0.03) * aurora * (1.0-daylight) * (1.0-overcast) * smoothstep(0.0, 0.6, d.y);
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
		if (aurora > 0.001) {
			float jit = hash21(FRAGCOORD.xy);
			base += aurora_light(d, jit) * aurora * (1.0-daylight) * (1.0-overcast);
		}
		COLOR = mix(base,HALF_RES_COLOR.rgb,HALF_RES_COLOR.a);
	}
}
