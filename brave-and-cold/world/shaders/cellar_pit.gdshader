shader_type spatial;
render_mode cull_back;
// A7 root cellar: the open hatch shows a 1.6 m earth pit without cutting the cabin floor.
// Interior mapping: the view ray through this floor-level quad is traced into a box
// (x,z in [-half_w, half_w], y in [-depth, 0]) in object space and the surface it hits is
// painted: plank-cribbed wall, shelf wall with jars, ladder wall, root wall, dirt floor.

uniform float depth = 1.6;
uniform float half_w = 0.4;
uniform vec3 earth : source_color = vec3(0.17, 0.13, 0.10);
uniform vec3 wood : source_color = vec3(0.33, 0.24, 0.15);
uniform float char_k = 0.0;   // burned cabin: the top boards are charred

varying vec3 o_pos;
varying vec3 o_cam;

void vertex() {
	o_pos = VERTEX;
	o_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

// literal colours below are written in sRGB like the uniforms; ALBEDO wants linear
vec3 lin(vec3 c) { return pow(c, vec3(2.2)); }

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return vn(p) * 0.5 + vn(p * 2.13) * 0.3 + vn(p * 4.37) * 0.2;
}

vec3 dirt(vec2 q) {
	float n = fbm(q * 7.0);
	float clods = vn(q * 19.0 + 3.7);
	return earth * (0.6 + 0.55 * n) * (0.9 + 0.2 * clods);
}

vec3 planks(vec2 q, float gap_k) {
	// horizontal boards 0.2 m high (q.x along the wall, q.y height)
	float b = fract(q.y * 5.0);
	float row = floor(q.y * 5.0);
	float grain = fbm(vec2(q.x * 2.5 + row * 7.1, q.y * 60.0));
	vec3 c = wood * (0.7 + 0.45 * grain) * (0.85 + 0.3 * h21(vec2(row, 3.0)));
	float gap = 1.0 - smoothstep(0.0, 0.07, b) * (1.0 - smoothstep(0.93, 1.0, b));
	return mix(c, earth * 0.35, gap * gap_k);
}

void fragment() {
	vec3 p = o_pos;
	vec3 d = normalize(o_pos - o_cam);
	d.y = min(d.y, -1e-4);
	float tx = abs(d.x) < 1e-5 ? 1e5 : ((d.x > 0.0 ? half_w : -half_w) - p.x) / d.x;
	float tz = abs(d.z) < 1e-5 ? 1e5 : ((d.z > 0.0 ? half_w : -half_w) - p.z) / d.z;
	float ty = (-depth - p.y) / d.y;
	float t = min(min(tx, tz), ty);
	vec3 h = p + d * t;
	vec3 c;
	float edge;
	if (t == ty) {
		// floor: dirt with old straw and a sack in one corner
		c = dirt(h.xz);
		float straw = smoothstep(0.62, 0.7, vn(vec2(h.x * 40.0, h.z * 3.0) + vn(h.xz * 4.0) * 3.0));
		c = mix(c, lin(vec3(0.42, 0.34, 0.2)), straw * 0.35);
		float sack = 1.0 - smoothstep(0.17, 0.2, length((h.xz - vec2(-0.2, 0.22)) * vec2(1.0, 1.3)));
		c = mix(c, lin(vec3(0.36, 0.3, 0.22)) * (0.8 + 0.3 * fbm(h.xz * 30.0)), sack);
		edge = min(half_w - abs(h.x), half_w - abs(h.z));
	} else if (t == tx) {
		vec2 q = vec2(h.z, h.y);
		if (h.x > 0.0) {
			// shelf wall: earth behind two board shelves with jars of preserves
			c = dirt(q + 3.0);
			for (int s = 0; s < 2; s++) {
				float sy = -0.55 - float(s) * 0.55;
				if (h.y > sy - 0.035 && h.y < sy) c = wood * (0.75 + 0.3 * fbm(vec2(h.z * 3.0, h.y * 50.0)));
				if (h.y >= sy && h.y < sy + 0.17) {
					float cell = floor((h.z + half_w) / 0.11);
					float lx = fract((h.z + half_w) / 0.11) - 0.5;
					float r = h21(vec2(cell, float(s) * 9.0));
					float jh = 0.11 + 0.05 * r;
					if (r > 0.3 && abs(lx) < 0.36 && h.y < sy + jh) {
						vec3 jar = lin(mix(vec3(0.30, 0.08, 0.06), vec3(0.27, 0.26, 0.11), step(0.65, r))) * (0.8 + 0.4 * h21(vec2(cell, 3.0 + float(s))));
						float lid_band = step(sy + jh - 0.02, h.y);
						jar = mix(jar * (0.75 + 0.5 * smoothstep(0.1, -0.2, lx)), lin(vec3(0.34, 0.33, 0.30)), lid_band);
						jar += vec3(0.025) * smoothstep(0.06, 0.0, abs(lx + 0.18)) * (1.0 - lid_band);
						c = jar;
					}
				}
			}
			if (abs(abs(h.z) - (half_w - 0.04)) < 0.025) c = wood * 0.7;
		} else {
			// plank cribbing holding the earth back
			c = planks(q, 1.0);
		}
		edge = min(half_w - abs(h.z), 1.0);
	} else {
		vec2 q = vec2(h.x, h.y);
		if (h.z < 0.0) {
			// ladder wall
			c = planks(q + vec2(5.0, 0.0), 0.6) * 0.8;
			float rail = 1.0 - step(0.022, abs(abs(h.x) - 0.17));
			float rung = step(abs(h.x), 0.17) * (1.0 - step(0.035, abs(fract(h.y / 0.3 + 0.5) - 0.5) * 0.3));
			if (rail + rung > 0.0) c = lin(vec3(0.36, 0.26, 0.16)) * (0.8 + 0.3 * fbm(vec2(h.x * 20.0, h.y * 9.0)));
		} else {
			// bare earth with roots
			c = dirt(q + 7.0);
			float root = smoothstep(0.03, 0.0, abs(vn(vec2(h.x * 6.0, h.y * 2.0)) - 0.5));
			c = mix(c, lin(vec3(0.28, 0.21, 0.14)), root * 0.6);
		}
		edge = min(half_w - abs(h.x), 1.0);
	}
	// depth: light from the room falls off quickly down the shaft; corners occlude
	float shade = mix(0.03, 1.0, exp(h.y * 2.2));
	shade *= mix(0.5, 1.0, smoothstep(0.0, 0.09, edge));
	shade *= mix(0.55, 1.0, smoothstep(-depth, -depth + 0.25, h.y) * 0.5 + 0.5 * step(-depth + 0.001, h.y));
	c *= shade;
	// the top lip of the shaft: charred when the cabin burned
	c = mix(c, c * 0.25, char_k * smoothstep(-0.25, 0.0, h.y));
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
