shader_type spatial;
render_mode cull_disabled;
// Building wood (cabins): vertex colours x procedural wood in object space. Replaces the old
// triplanar cloud-noise grain, which made the floor read as mottled felt.
//  - floor boards: grain along the boards, a tone per board, dark seams, knots, grime toward the
//    walls and in the corners, a lighter worn path where people walk;
//  - logs and other vertical faces: grain along the horizontal run, a tone per log course;
//  - other horizontal faces (table, shelf, roof underside): grain along x (z near the side walls).
// The generated cabin mesh has no UVs, so everything is derived from object-space position/normal.

uniform vec4 tint = vec4(1.0);   // linear multiply, like the old albedo_color
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;   // Cabin._grain_tex (greys 0.66..1)
uniform float floor_top = 0.3;       // object y of the floor surface (FLOOR_LOCAL_Y)
uniform float plank_pitch = 0.4;     // board + seam across the boards
uniform float plank_off = 0.3;       // a seam position across the boards
uniform bool floor_along_x = true;   // boards run along x (cabin) or z
uniform vec2 room_half = vec2(2.78, 2.28);   // inner wall faces (x, z) for floor grime
uniform float side_x = 2.6;          // |x| beyond this: horizontal faces belong to the side walls (grain along z)
uniform float log_step = 0.29;       // wall log course height
uniform float floor_k = 0.48;        // floor boards a touch darker than the bare vertex colour (TLD: dark worn planks)
uniform vec2 door_xz = vec2(0.0, 2.5);   // worn path: door -> room centre -> stove
uniform vec2 stove_xz = vec2(-2.35, -1.75);
uniform bool wall_vertical = false;  // board-and-batten siding (hut): grain runs up the wall
uniform float wall_board = 0.16;
uniform float desat = 0.0;          // mute the vertex colours (hut paint reads teal at interior exposure)
uniform float extra_k = 0.0;        // grain also on painted / weathered greys and greens (siding), not cloth or stone

varying vec3 op;
varying vec3 on;

void vertex() {
	op = VERTEX;
	on = NORMAL;
}

float h11(float x) { return fract(sin(x * 127.1 + 31.7) * 43758.5453); }
float nz(vec2 uv) { return clamp((texture(noise_tex, uv).r - 0.66) / 0.34, 0.0, 1.0); }

float seg_d(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// a = along the grain, b = across it (m), id = board / log index. Returns a brightness factor.
float wood(float a, float b, float id, float across_w) {
	float warp = nz(vec2(a * 0.35 + id * 0.13, b * 2.5 + id * 0.37));
	float rings = fract(b * 22.0 + warp * 4.0 + id * 0.61 + nz(vec2(a * 1.1, b * 6.0)) * 1.2);
	float g = mix(0.66, 1.0, smoothstep(0.0, 0.8, rings));          // early wood light -> late wood dark band
	g *= mix(1.0, 0.62, smoothstep(0.82, 0.93, rings) * (1.0 - smoothstep(0.96, 1.0, rings)));
	float streak = 0.8 + 0.3 * nz(vec2(a * 0.12 + id * 0.7, b * 5.0));   // long along the grain, narrow across
	float tone = 0.72 + 0.42 * h11(id * 7.3 + 1.0);
	float f = g * streak * tone;
	// knots: one chance per 0.9 m of board
	float cell = floor(a / 0.9);
	float hk = h11(cell * 3.1 + id * 17.7);
	if (hk > 0.72) {
		float ca = (cell + 0.5 + 0.5 * (h11(cell + id * 5.0) - 0.5)) * 0.9;
		float cb = across_w * (0.25 + 0.5 * h11(cell * 9.0 + id));
		float d = length(vec2((a - ca) / 0.045, (fract(b / across_w) * across_w - cb) / 0.022));
		f *= mix(0.45, 1.0, smoothstep(0.55, 1.0, d));
		f *= mix(0.82, 1.0, smoothstep(0.0, 0.25, abs(d - 1.35)));
	}
	return f;
}

void fragment() {
	vec3 n = normalize(on);
	vec3 an = abs(n);
	vec3 base = COLOR.rgb * tint.rgb;
	base = mix(base, vec3(dot(base, vec3(0.3, 0.55, 0.15))), desat);
	float f;
	float rough = 0.9;
	bool is_floor = an.y > 0.6 && abs(op.y - floor_top) < 0.04 && abs(op.x) < room_half.x + 0.05 && abs(op.z) < room_half.y + 0.05;
	if (is_floor) {
		float a = floor_along_x ? op.x : op.z;
		float c = floor_along_x ? op.z : op.x;
		float u = (c - plank_off) / plank_pitch;
		float id = floor(u);
		f = wood(a, c, id, plank_pitch) * floor_k;
		float e = abs(fract(u) - 0.5) * 2.0;           // 1 at the seams
		f *= mix(1.0, 0.62, smoothstep(0.86, 0.985, e));
		float fr = fract((a + h11(id * 2.3) * 1.9) / 1.9);   // butt joints, staggered per board
		f *= mix(0.6, 1.0, smoothstep(0.003, 0.009, min(fr, 1.0 - fr) * 1.9));
		vec2 xz = op.xz;
		float wd = min(room_half.x - abs(xz.x), room_half.y - abs(xz.y));
		float grime = 1.0 - smoothstep(0.0, 0.55, wd);
		f *= 1.0 - 0.38 * grime * (0.7 + 0.3 * nz(xz * 0.9));
		float path = min(seg_d(xz, door_xz, vec2(0.0, 0.2)), seg_d(xz, vec2(0.0, 0.2), stove_xz + vec2(0.6, 0.6)));
		float wear = (1.0 - smoothstep(0.25, 0.85, path)) * (0.55 + 0.45 * nz(xz * 1.7));
		f *= 1.0 + 0.16 * wear;
		rough = mix(0.92, 0.72, wear);
		f *= 0.92 + 0.12 * nz(xz * 0.35 + 5.0);       // broad stains
	} else if (an.y > 0.6) {
		bool along_z = abs(op.x) > side_x;
		float a = along_z ? op.z : op.x;
		float b = along_z ? op.x : op.z;
		f = wood(a, b, floor(op.y / log_step), 0.3);
	} else if (wall_vertical) {
		float h = an.x > an.z ? op.z : op.x;
		f = wood(op.y, h, floor(h / wall_board), wall_board);
	} else {
		float a = an.x > an.z ? op.z : op.x;
		float id = floor((op.y - floor_top) / log_step);
		f = wood(a, op.y + (an.x > an.z ? op.x : op.z) * 0.3, id, log_step);
		f *= 0.95 + 0.1 * nz(vec2(a * 0.2, op.y * 0.5));
	}
	// only wood-coloured vertices get grain (stone, iron, snow, cloth keep a plain weathering)
	// relative hue (COLOR is linear: wood g/r ~0.5, red cloth ~0.14, stone / snow / iron r <= b)
	float rr = max(base.r, 1e-3);
	float wood_k = smoothstep(0.3, 0.5, (base.r - base.b) / rr) * smoothstep(0.25, 0.4, base.g / rr);
	float mx = max(base.r, max(base.g, base.b));
	float sat = (mx - min(base.r, min(base.g, base.b))) / max(mx, 1e-3);
	wood_k = max(wood_k, extra_k * (1.0 - smoothstep(0.55, 0.75, sat)) * step(base.b, max(base.r, base.g) * 1.05));
	f = mix(0.9 + 0.16 * nz(op.xz * 1.3 + op.y * 0.7), f, wood_k);
	ALBEDO = base * f * 1.12;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
