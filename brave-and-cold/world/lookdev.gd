extends Node3D
## Look-dev harness: loads the imported Terrain3D map, sets a lighting preset, flies a camera.
## Interactive: open world/lookdev.tscn (F5). WASD + mouse, Shift fast, 1-6 switch presets.
## Screenshot: Godot --path brave-and-cold res://world/lookdev.tscn -- preset=dusk pos=0,0 yaw=30 pitch=-5 out=C:/tmp/shot.png

const MAP := "res://data/terrain/valley_b"

# sun_pitch_deg, sun_yaw_deg, sun_color, sun_energy, sky_top, sky_horizon, ground_horizon, fog_color, fog_density, ambient_color, ambient_energy
const PRESETS := {
	"noon": [-58.0, 30.0, Color(1.0, 0.96, 0.88), 1.6, Color(0.20, 0.40, 0.74), Color(0.68, 0.80, 0.92), Color(0.62, 0.74, 0.86), Color(0.70, 0.80, 0.90), 0.0009, Color(0.42, 0.56, 0.80), 0.9],
	"morning": [-22.0, 60.0, Color(1.0, 0.86, 0.66), 1.5, Color(0.30, 0.48, 0.78), Color(0.90, 0.80, 0.72), Color(0.70, 0.72, 0.80), Color(0.82, 0.80, 0.84), 0.0014, Color(0.38, 0.50, 0.76), 0.8],
	"dusk": [-5.0, 250.0, Color(1.0, 0.45, 0.22), 1.3, Color(0.20, 0.16, 0.42), Color(0.98, 0.50, 0.32), Color(0.55, 0.32, 0.42), Color(0.72, 0.42, 0.50), 0.0022, Color(0.36, 0.28, 0.58), 0.7],
	"twilight": [8.0, 250.0, Color(0.5, 0.5, 0.9), 0.15, Color(0.06, 0.08, 0.24), Color(0.30, 0.34, 0.60), Color(0.20, 0.22, 0.40), Color(0.22, 0.26, 0.48), 0.0026, Color(0.18, 0.22, 0.46), 0.7],
	"night": [45.0, 200.0, Color(0.42, 0.55, 0.95), 0.25, Color(0.01, 0.02, 0.07), Color(0.05, 0.08, 0.18), Color(0.03, 0.05, 0.12), Color(0.05, 0.08, 0.16), 0.0028, Color(0.10, 0.16, 0.34), 0.6],
	"overcast": [-40.0, 30.0, Color(0.80, 0.86, 0.94), 0.5, Color(0.60, 0.66, 0.74), Color(0.78, 0.82, 0.86), Color(0.70, 0.74, 0.80), Color(0.76, 0.80, 0.85), 0.0040, Color(0.62, 0.68, 0.78), 1.1],
}
const PRESET_KEYS := ["noon", "morning", "dusk", "twilight", "night", "overcast"]

var terrain: Terrain3D
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var cam: Camera3D
var yaw := 0.0
var pitch := 0.0
var speed := 12.0
var out_path := ""
var frames := 0


func _ready() -> void:
	var opts := _parse_args()
	_build_world()
	apply_preset(opts.get("preset", "noon"))
	var xz := PackedStringArray(String(opts.get("pos", "0,0")).split(","))
	var p := Vector3(float(xz[0]), 0.0, float(xz[1]))
	yaw = deg_to_rad(float(opts.get("yaw", 0.0)))
	pitch = deg_to_rad(float(opts.get("pitch", -5.0)))
	out_path = String(opts.get("out", ""))
	cam.position = p
	cam.position.y = 400.0
	_pending_ground_pos = p
	_pending_eye = float(opts.get("eye", 1.7))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if out_path == "" else Input.MOUSE_MODE_VISIBLE


var _pending_ground_pos := Vector3.ZERO
var _pending_eye := 1.7
var _placed := false


func _parse_args() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			d[kv[0]] = kv[1]
	return d


func _build_world() -> void:
	terrain = Terrain3D.new()
	terrain.name = "Terrain3D"
	terrain.data_directory = MAP
	add_child(terrain)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)

	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.12
	sky_mat.ground_curve = 0.05
	sky_mat.sun_angle_max = 8.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_sky_affect = 0.6
	env.fog_aerial_perspective = 0.5
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	cam = Camera3D.new()
	cam.far = 6000.0
	cam.fov = 70.0
	add_child(cam)
	cam.make_current()
	terrain.set_camera(cam)


func apply_preset(name: String) -> void:
	var p: Array = PRESETS.get(name, PRESETS["noon"])
	sun.rotation_degrees = Vector3(p[0], p[1], 0.0)
	sun.light_color = p[2]
	sun.light_energy = p[3]
	sky_mat.sky_top_color = p[4]
	sky_mat.sky_horizon_color = p[5]
	sky_mat.ground_horizon_color = p[6]
	sky_mat.ground_bottom_color = (p[6] as Color).darkened(0.5)
	env.fog_light_color = p[7]
	env.fog_density = p[8]
	env.ambient_light_color = p[9]
	env.ambient_light_energy = p[10]


func _place_on_ground() -> void:
	var h: float = terrain.data.get_height(_pending_ground_pos)
	if is_nan(h):
		return
	cam.position = _pending_ground_pos + Vector3(0, h + _pending_eye, 0)
	_placed = true


func _process(delta: float) -> void:
	frames += 1
	if not _placed and frames > 5:
		_place_on_ground()
	cam.rotation = Vector3(pitch, yaw, 0.0)
	if out_path != "":
		if frames == 40:
			var img := get_viewport().get_texture().get_image()
			img.save_png(out_path)
			print("SHOT_SAVED ", out_path, " cam ", cam.position)
			get_tree().quit()
		return
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir -= cam.global_transform.basis.z
	if Input.is_key_pressed(KEY_S): dir += cam.global_transform.basis.z
	if Input.is_key_pressed(KEY_A): dir -= cam.global_transform.basis.x
	if Input.is_key_pressed(KEY_D): dir += cam.global_transform.basis.x
	if Input.is_key_pressed(KEY_E): dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q): dir -= Vector3.UP
	var s := speed * (5.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	cam.position += dir.normalized() * s * delta


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * 0.002
		pitch = clampf(pitch - e.relative.y * 0.002, -1.5, 1.5)
	elif e is InputEventKey and e.pressed:
		if e.keycode >= KEY_1 and e.keycode <= KEY_6:
			apply_preset(PRESET_KEYS[e.keycode - KEY_1])
		elif e.keycode == KEY_ESCAPE:
			get_tree().quit()
