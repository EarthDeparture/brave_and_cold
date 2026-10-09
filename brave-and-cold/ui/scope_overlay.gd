class_name ScopeOverlay
extends ColorRect
## GPU optic picture over the 3D view (one full-screen quad, no CPU polygon redraw):
## - scope: hard black tube edge + soft eye-box shadow that drifts with the hold
##   (the reticle itself stays on the true aim point), tighter at high power;
## - tube_dot: wide tube, red dot; reflex: no tube, red dot only;
## - reticles: duplex, BDC (first-focal-plane holdover marks for 200/300/400 m
##   from the real projectile model), dot.
## A short blackout as the eye meets the eyepiece hides the model/scope swap.
const MUZZLE_V := 760.0 # must equal GameWorld.MUZZLE_V / ZERO_M / GRAV (tested)
const ZERO_M := 100.0
const GRAV := 9.8
const FADE_S := 0.14
const CODE := """
shader_type canvas_item;
uniform vec2 size = vec2(1920.0, 1080.0);
uniform int mode = 0;            // 0 tube (black outside), 1 open (reflex)
uniform float radius = 475.0;
uniform float edge = 50.0;
uniform vec2 offset = vec2(0.0);
uniform int reticle = 1;         // 0 none, 1 duplex, 2 bdc, 3 dot
uniform vec3 bdc_px = vec3(0.0);
uniform float px = 1.0;          // size.y / 1080
uniform float fade = 0.0;
uniform vec4 ink : source_color = vec4(0.03, 0.03, 0.03, 1.0);
uniform vec4 dot_col : source_color = vec4(0.95, 0.13, 0.08, 1.0);
float band(float d, float w) { return 1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, abs(d)); }
void fragment() {
	vec2 p = UV * size - size * 0.5;
	float a = 0.0;
	float inside = 1.0;
	if (mode == 0) {
		float r = length(p - offset);
		float outside = smoothstep(radius - 1.5, radius + 1.5, r);
		float shadow = smoothstep(radius - edge, radius, r) * 0.9;
		a = max(max(outside, shadow), smoothstep(radius * 0.55, radius, length(p)) * 0.12);
		inside = 1.0 - smoothstep(radius - 3.0, radius, r);
	}
	float ret = 0.0;
	if (reticle == 1 || reticle == 2) {
		float post = radius * 0.45;
		float wx = abs(p.x) < post ? 1.1 * px : 4.0 * px;
		float wy = abs(p.y) < post ? 1.1 * px : 4.0 * px;
		ret = max(band(p.y, wx) * step(abs(p.x), radius), band(p.x, wy) * step(abs(p.y), radius));
		if (reticle == 2) {
			ret = max(ret, band(p.y - bdc_px.x, 1.2 * px) * step(abs(p.x), 8.0 * px));
			ret = max(ret, band(p.y - bdc_px.y, 1.2 * px) * step(abs(p.x), 6.5 * px));
			ret = max(ret, band(p.y - bdc_px.z, 1.2 * px) * step(abs(p.x), 5.0 * px));
		}
	}
	float dotv = 0.0;
	if (reticle == 3 || reticle == 2) {
		float d = length(p);
		float rr = (reticle == 3 ? 2.6 : 1.4) * px;
		dotv = max(1.0 - smoothstep(rr, rr + 1.0, d), (reticle == 3 ? 0.35 : 0.0) * exp(-d * d / (36.0 * px * px)));
	}
	vec4 o = vec4(0.0, 0.0, 0.0, a);
	o = mix(o, vec4(ink.rgb, 1.0), ret * inside);
	o = mix(o, vec4(dot_col.rgb, 1.0), dotv * inside);
	o = mix(o, vec4(0.0, 0.0, 0.0, 1.0), fade);
	COLOR = o;
}
"""
var mat: ShaderMaterial
var fade := 0.0
var radius_px := 0.0
var bdc := Vector3.ZERO
var _was_on := false

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new(); mat.shader = Shader.new(); mat.shader.code = CODE
	material = mat; visible = false; name = "ScopeOverlay"

## Holdover below the reticle centre (rad) for a target at d metres, rifle zeroed at ZERO_M.
static func drop_angle(d: float) -> float:
	return 0.5 * GRAV * (d - ZERO_M) / (MUZZLE_V * MUZZLE_V)

## on: optic picture wanted; kind/reticle from RifleDB.optic; mag = live true
## magnification; fov = live vertical FOV (deg); sway = Player.sway (rad).
func update_view(on: bool, kind: String, reticle: String, mag: float, fov: float, sway: Vector2, delta: float) -> void:
	if not on:
		visible = false; _was_on = false; return
	if not _was_on: fade = 1.0
	_was_on = true
	fade = move_toward(fade, 0.0, delta / FADE_S) if kind != "reflex" else 0.0
	visible = true
	var s := get_viewport_rect().size
	var px_per_rad := s.y / (2.0 * tan(deg_to_rad(fov) * 0.5))
	var power := clampf((mag - 2.0) / 10.0, 0.0, 1.0)
	var tube := kind != "reflex"
	radius_px = s.y * (0.47 if kind == "tube_dot" else 0.44 * lerpf(1.0, 0.86, power))
	bdc = Vector3(tan(drop_angle(200)), tan(drop_angle(300)), tan(drop_angle(400))) * px_per_rad
	mat.set_shader_parameter("size", s)
	mat.set_shader_parameter("mode", 0 if tube else 1)
	mat.set_shader_parameter("radius", radius_px)
	mat.set_shader_parameter("edge", radius_px * (0.06 if kind == "tube_dot" else lerpf(0.10, 0.18, power)))
	# Eye-box drift: the tube shadow lags the hold; the reticle stays on the aim point.
	mat.set_shader_parameter("offset", Vector2(-sway.x, sway.y) * px_per_rad * 0.35)
	mat.set_shader_parameter("reticle", {"none": 0, "duplex": 1, "bdc": 2, "dot": 3}.get(reticle, 1))
	mat.set_shader_parameter("bdc_px", bdc)
	mat.set_shader_parameter("px", s.y / 1080.0)
	mat.set_shader_parameter("fade", fade)
