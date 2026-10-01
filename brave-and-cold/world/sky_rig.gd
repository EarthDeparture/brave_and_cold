class_name SkyRig
extends Node
## Time-of-day lighting: interpolates look-dev preset keyframes by game hour and drives sun, sky, fog and ambient.

# hour -> preset key. Keys are the arrays in LookdevPresets (same layout as lookdev.gd).
const P_NIGHT := [45.0, 200.0, Color(0.42, 0.55, 0.95), 0.25, Color(0.01, 0.02, 0.07), Color(0.05, 0.08, 0.18), Color(0.03, 0.05, 0.12), Color(0.05, 0.08, 0.16), 0.0028, Color(0.10, 0.16, 0.34), 0.6]
const P_TWILIGHT := [8.0, 250.0, Color(0.5, 0.5, 0.9), 0.15, Color(0.06, 0.08, 0.24), Color(0.30, 0.34, 0.60), Color(0.20, 0.22, 0.40), Color(0.22, 0.26, 0.48), 0.0026, Color(0.18, 0.22, 0.46), 0.7]
const P_MORNING := [-22.0, 60.0, Color(1.0, 0.86, 0.66), 1.5, Color(0.30, 0.48, 0.78), Color(0.90, 0.80, 0.72), Color(0.70, 0.72, 0.80), Color(0.82, 0.80, 0.84), 0.0014, Color(0.52, 0.60, 0.78), 0.85]
const P_NOON := [-58.0, 30.0, Color(1.0, 0.96, 0.88), 1.6, Color(0.20, 0.40, 0.74), Color(0.68, 0.80, 0.92), Color(0.62, 0.74, 0.86), Color(0.70, 0.80, 0.90), 0.0009, Color(0.54, 0.63, 0.82), 0.95]
const P_DUSK := [-5.0, 250.0, Color(1.0, 0.50, 0.26), 1.3, Color(0.16, 0.22, 0.42), Color(0.98, 0.56, 0.36), Color(0.45, 0.38, 0.52), Color(0.66, 0.48, 0.56), 0.0022, Color(0.42, 0.47, 0.58), 0.85]

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var clouds: CloudLayer
var coverage := 0.45
var weather: Weather
var _keys: Array = []  # [hour, preset]


func _init() -> void:
	_keys = [[0.0, P_NIGHT], [5.0, P_NIGHT], [6.0, P_TWILIGHT], [7.5, P_MORNING], [12.0, P_NOON],
		[15.5, P_MORNING], [17.0, P_DUSK], [18.3, P_TWILIGHT], [19.5, P_NIGHT], [24.0, P_NIGHT]]


func setup(sun_light: DirectionalLight3D, environment: Environment, sky_material: ProceduralSkyMaterial) -> void:
	sun = sun_light
	env = environment
	sky_mat = sky_material


func apply_hour(h: float) -> void:
	h = fposmod(h, 24.0)
	var a: Array = _keys[0]
	var b: Array = _keys[_keys.size() - 1]
	for i in range(_keys.size() - 1):
		if h >= float(_keys[i][0]) and h <= float(_keys[i + 1][0]):
			a = _keys[i]
			b = _keys[i + 1]
			break
	var span := maxf(float(b[0]) - float(a[0]), 0.001)
	var t := smoothstep(0.0, 1.0, (h - float(a[0])) / span)
	var pa: Array = a[1]
	var pb: Array = b[1]
	# sun / moon direction
	var pitch: float
	var yaw: float
	if h > 5.5 and h < 18.5:
		var elev := maxf(sin(PI * (h - 6.0) / 12.0) * 52.0, 2.0)
		pitch = -elev
		yaw = 60.0 + (h - 6.0) / 12.0 * 190.0
	else:
		pitch = -35.0
		yaw = 200.0
	sun.rotation_degrees = Vector3(pitch, yaw, 0.0)
	sun.light_color = (pa[2] as Color).lerp(pb[2], t)
	sun.light_energy = lerpf(pa[3], pb[3], t)
	sky_mat.sky_top_color = (pa[4] as Color).lerp(pb[4], t)
	sky_mat.sky_horizon_color = (pa[5] as Color).lerp(pb[5], t)
	var gh: Color = (pa[6] as Color).lerp(pb[6], t)
	sky_mat.ground_horizon_color = gh
	sky_mat.ground_bottom_color = gh.darkened(0.5)
	env.fog_light_color = (pa[7] as Color).lerp(pb[7], t)
	env.fog_density = lerpf(pa[8], pb[8], t)
	env.ambient_light_color = (pa[9] as Color).lerp(pb[9], t)
	env.ambient_light_energy = lerpf(pa[10], pb[10], t)

	if weather != null:
		var o := weather.overcast
		var day := clampf(sun.light_energy / 1.5, 0.0, 1.0)
		var gray := Color(0.60, 0.64, 0.70) * (0.22 + 0.78 * day)
		gray.a = 1.0
		sun.light_energy *= 1.0 - 0.75 * o
		sky_mat.sky_top_color = (sky_mat.sky_top_color as Color).lerp(gray.darkened(0.15), o * 0.8)
		sky_mat.sky_horizon_color = (sky_mat.sky_horizon_color as Color).lerp(gray, o * 0.85)
		sky_mat.ground_horizon_color = (sky_mat.ground_horizon_color as Color).lerp(gray, o * 0.5)
		env.fog_light_color = env.fog_light_color.lerp(gray.lightened(0.1), o * 0.8)
		env.fog_density *= weather.fog_mult
		env.ambient_light_color = env.ambient_light_color.lerp(gray, o * 0.5)
		coverage = weather.coverage

	if clouds != null:
		var lum := 0.3 + 0.7 * clampf(sun.light_energy / 1.5, 0.0, 1.0)
		var hor: Color = sky_mat.sky_horizon_color
		var lit: Color = hor.lerp(sun.light_color, 0.45).lightened(0.2) * lum
		var shade: Color = (sky_mat.sky_top_color as Color).lerp(hor, 0.55) * (0.55 + 0.45 * lum)
		lit.a = 1.0
		shade.a = 1.0
		clouds.set_tint(lit, shade, coverage)
