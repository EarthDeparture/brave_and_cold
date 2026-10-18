class_name MenuDiorama
extends Node3D
## M6: the live 3D scene behind the main menu, without loading the world first.
## The menu shows its painted stills at once; this builds a small slice of the real game in
## the background (terrain, the fire lookout lit for the night with chimney smoke, sky and
## clouds, and the exact game trees around it from data/menu/diorama.bin, baked by
## tests/visual/bake_menu_diorama.gd) and then the menu crossfades from the still into it.
## Same classes and materials as the game, so it follows art changes; re-bake after the
## tree pass (test_menu_diorama fails while the bake is stale).

signal built
const BAKE := "res://data/menu/diorama.bin"
const MAP := "res://data/terrain/valley_b"

var data: Dictionary = {}
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sky_rig: Node            # AtmosphereRig
var weather := Weather.new()
var terrain: Terrain3D
var forest: ForestScatter
var lookout: FireLookout
var cam: Camera3D
var smoke: GPUParticles3D
var stove := FireSource.new("wood_stove")
var ready_ok := false
var build_ms := 0
var step_ms: Array[int] = []   # main-thread time of each build step = menu hitch per frame
var _step_t := 0
var _t := 0.0
var _eye := Vector3.ZERO
var _target := Vector3.ZERO


static func available() -> bool:
	return ResourceLoader.exists(BAKE) or FileAccess.file_exists(BAKE)


## Builds over several frames (each step yields), so the menu keeps animating.
func build() -> void:
	var t0 := Time.get_ticks_msec()
	_step_t = t0
	var fa := FileAccess.open(BAKE, FileAccess.READ)
	if fa == null: return
	data = fa.get_var(false); fa.close()
	_eye = data.eye; _target = data.target
	var e := WorldEnvironmentBuilder.build(self)
	sun = e.sun; sky_mat = e.sky_mat; env = e.env
	_step()
	await get_tree().process_frame
	_step_t = Time.get_ticks_msec()
	terrain = WorldEnvironmentBuilder.terrain(self, MAP, "res://data/terrain/terrain_environment_assets.tres")
	terrain.set_physics_process(false)
	_step()
	await get_tree().process_frame
	_step_t = Time.get_ticks_msec()
	cam = Camera3D.new(); cam.fov = float(data.get("fov", 58.0)); cam.far = 4000.0
	add_child(cam)
	cam.global_position = _eye; cam.look_at(_target)
	terrain.set_camera(cam); terrain.set_physics_process(true)
	lookout = FireLookout.new()
	lookout.detail_enabled = true; lookout.route_dressing_enabled = true
	add_child(lookout)
	lookout.build(data.site)
	lookout.global_transform = data.lookout_xform
	lookout.build_foundations(terrain)
	_step()
	await get_tree().process_frame
	_step_t = Time.get_ticks_msec()
	forest = ForestScatter.new()
	forest.detail_enabled = bool(data.get("detail", true))
	forest.crown_quality_enabled = bool(data.get("crowns", true))
	forest.diversity_enabled = bool(data.get("diversity", true))
	forest.weather = weather
	forest.baked = data.trees
	forest.progress = func(_f: float) -> void:   # split instancing over frames (was one 300 ms hitch)
		_step()
		await get_tree().process_frame
		_step_t = Time.get_ticks_msec()
	add_child(forest)
	await forest.build(terrain)
	forest.progress = Callable()
	_step()
	await get_tree().process_frame
	_step_t = Time.get_ticks_msec()
	sky_rig = preload("res://world/atmosphere_rig.gd").new()
	add_child(sky_rig)
	sky_rig.setup(sun, env, sky_mat)
	sky_rig.material.set_shader_parameter("cloud_quality", true)
	sky_rig.weather = weather
	weather.lock_state(Weather.S.CLEAR); weather._t = 0.0; weather.advance(120.0, 0.0)
	if sky_rig.has_method("set_cloud_offset"): sky_rig.set_cloud_offset(Vector2(0.17, 0.08))
	_apply_hour(float(data.get("hour", 18.3)))
	stove.set_fuel(4 * 3600)
	smoke = FireVisual.smoke(lookout, Vector3(-1.65, FireLookout.DECK_Y + 4.02, 1.20))
	FireVisual.set_smoke(smoke, stove, weather.wind_dir)
	cam.make_current()
	_step()
	build_ms = Time.get_ticks_msec() - t0
	ready_ok = true
	print("MENU_DIORAMA built %d ms trees=%d steps(ms)=%s" % [build_ms, forest.tree_count, str(step_ms)])
	built.emit()


func _step() -> void:
	step_ms.append(Time.get_ticks_msec() - _step_t)


func _apply_hour(h: float) -> void:
	forest.update_detail_appearance()
	sky_rig.apply_hour(h)
	if sky_rig.has_method("apply_shelter"): sky_rig.apply_shelter(0.0)
	var night: float = sky_rig.gameplay_night_factor
	lookout.set_night(night, true, Vector3(0, -1000, 0))
	for il: Node in get_tree().get_nodes_in_group("interior_lighting"):
		if is_ancestor_of(il): (il as InteriorLighting).update(1.0 - night, weather.overcast, weather.precip)


## Held camera: a slow, small arc and push-in toward the tower, looping smoothly.
func _process(delta: float) -> void:
	if not ready_ok: return
	_t += delta
	weather.advance(delta, 0.0)
	var k := sin(_t * TAU / 90.0)           # 90 s loop
	var to := _target - _eye
	var side := to.cross(Vector3.UP).normalized()
	var p := _eye + side * (k * 3.0) + to.normalized() * (2.0 + 2.0 * sin(_t * TAU / 90.0 - 1.2))
	p.y = _eye.y + 0.25 * sin(_t * TAU / 37.0)
	cam.global_position = p
	cam.look_at(_target + side * (k * 1.2))
