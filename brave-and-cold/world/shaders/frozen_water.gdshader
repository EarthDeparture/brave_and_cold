shader_type spatial;
render_mode cull_disabled;

uniform bool winter_surface = false;
uniform bool detail_surface = false;
uniform sampler2D ice_fields : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_noise : filter_linear_mipmap, repeat_enable;
varying vec3 world_position;
varying float face_up;

vec2 hash2(vec2 p) {
	if (winter_surface) {
		ivec2 cell = ivec2(p);
		uint h = uint(cell.x)*374761393u + uint(cell.y)*668265263u;
		h = (h ^ (h >> 13u))*1274126177u;
		h ^= h >> 16u;
		uint k = (h ^ 2246822519u)*3266489917u;
		k = (k ^ (k >> 13u))*1274126177u;
		return vec2(float(h & 16777215u),float((k ^ (k >> 16u)) & 16777215u))/16777215.0;
	}
	// Integer hashing avoids amplified sin()/rounding differences at triangle
	// boundaries on D3D12. Each lattice point must produce exactly one value.
	uvec2 q = uvec2(ivec2(p));
	q = (q ^ q.yx ^ uvec2(374761393u, 668265263u)) * uvec2(2246822519u, 3266489917u);
	q = (q ^ (q >> uvec2(13u))) * uvec2(1274126177u, 1597334677u);
	q = q ^ (q >> uvec2(16u));
	return vec2(q & uvec2(16777215u)) / 16777215.0;
}

float noise2(vec2 p) {
	if (winter_surface) { return textureLod(surface_noise,p*0.0137,0.0).r; }
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i).x, hash2(i + vec2(1.0, 0.0)).x, f.x),
		mix(hash2(i + vec2(0.0, 1.0)).x, hash2(i + vec2(1.0, 1.0)).x, f.x), f.y);
}

float fracture(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float nearest = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 d = neighbor + hash2(cell + neighbor) - f;
			float dist = dot(d, d);
			if (dist < nearest) {
				second = nearest;
				nearest = dist;
			} else {
				second = min(second, dist);
			}
		}
	}
	return sqrt(second) - sqrt(nearest);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	face_up = NORMAL.y;
}

void fragment() {
	if (detail_surface) {
        vec2 uv = world_position.xz / 60.0;
        vec4 field = texture(ice_fields, uv);
        float top = smoothstep(0.0, 0.6, face_up);
        float frost = smoothstep(.25,.80,field.r) * (1.0 - field.b * .5);
        vec3 clear_ice = mix(vec3(.045,.105,.135),vec3(.17,.28,.32),field.g);
        clear_ice += field.a * vec3(.10,.14,.15);
        clear_ice = mix(clear_ice,vec3(.28,.39,.43),frost*.48);
        clear_ice = mix(clear_ice,vec3(.78,.84,.89),field.b);
        ALBEDO = mix(vec3(.028,.078,.102),clear_ice,top);
        ROUGHNESS = mix(.56,.43+field.g*.12+field.b*.32+frost*.09,top);
        SPECULAR = .32;
        METALLIC = 0.0;
        vec2 texel = vec2(1.0)/vec2(textureSize(ice_fields,0));
        float dx = texture(ice_fields,uv+vec2(texel.x,0)).g-texture(ice_fields,uv-vec2(texel.x,0)).g;
        float dz = texture(ice_fields,uv+vec2(0,texel.y)).g-texture(ice_fields,uv-vec2(0,texel.y)).g;
        vec3 world_normal = normalize(vec3(-dx*1.8,1.0,-dz*1.8));
        if (top>.5) NORMAL = normalize((VIEW_MATRIX*vec4(world_normal,0.0)).xyz);
        else if (!FRONT_FACING) NORMAL = -NORMAL;
    } else {
	vec2 p = world_position.xz;
	vec2 wind = vec2(p.x + p.y * 0.35, p.y - p.x * 0.35);
	float broad = noise2(p * 0.025) * 0.65 + noise2(p * 0.095 + 23.0) * 0.35;
	float streak = noise2(wind * vec2(0.035, 1.3));
	float scratches = noise2(wind * vec2(0.10, 5.0));
	vec2 warp = vec2(noise2(p * 0.13), noise2(p * 0.09 + 11.0)) - 0.5;
	float edge = fracture(p * 0.075 + warp * 0.38);
	float aa = max(fwidth(edge), 0.001);
	float width = mix(0.0008, 0.0025, noise2(p * 0.17));
	float crack = (1.0 - smoothstep(max(0.0, width - aa), width + aa, edge)) * min(1.0, width / aa);
	crack *= mix(0.20, 0.80, noise2(p * 0.4 + 47.0));
	float frost = 1.0 - smoothstep(0.004, 0.012 + aa, edge);
	float snow = smoothstep(0.70, 0.86, broad + (streak - 0.5) * 0.44);
	float top = smoothstep(0.0, 0.6, face_up);
	vec3 ice = mix(vec3(0.035, 0.090, 0.115), vec3(0.13, 0.23, 0.27), broad);
	ice += streak * vec3(0.018, 0.027, 0.030);
	ice = mix(ice, vec3(0.31, 0.43, 0.47), frost * 0.4);
	ice = mix(ice, vec3(0.38, 0.51, 0.56), crack * 0.65);
	ice = mix(ice, vec3(0.66, 0.73, 0.78), snow * 0.86);
	vec3 underside = vec3(0.023, 0.075, 0.095) + broad * vec3(0.024, 0.040, 0.045);
	ALBEDO = mix(underside, ice, top);
	ROUGHNESS = mix(0.38, 0.28 + snow * 0.47 + frost * 0.08 + scratches * 0.04, top);
	if (winter_surface) { ROUGHNESS = clamp(ROUGHNESS+0.18,0.0,1.0); }
	SPECULAR = winter_surface ? 0.34 : 0.55;
	METALLIC = 0.0;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
    }
}
