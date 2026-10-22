class_name Greenhouse
extends Node3D
## Phase F winter greenhouse (model: tools/blender/gen_greenhouse.py). Same collider API
## as Hut/Cabin. A box stove heats the room (RoomClimate with sun through the glazing);
## two raised beds hold 8 plots grown by Farming. Local frame: door on +Z.
const MODEL := "res://assets/greenhouse/greenhouse.glb"
const FT := 0.15
const HX := 1.6
const HZ := 2.2
const DOOR_HALF := 0.45
const WALL_T := 0.08
const PLOTS := [Vector2(-1.0, -1.49), Vector2(-1.0, -0.56), Vector2(-1.0, 0.36), Vector2(-1.0, 1.29),
	Vector2(1.0, -1.49), Vector2(1.0, -0.56), Vector2(1.0, 0.36), Vector2(1.0, 1.29)]
const SOIL_Y := 0.52
## Farming v2 props (local, door on +Z): snowmelt barrel in the door corner, compost bin in the far corner, a storm
## lantern on the ridge beam, the gardener's seed tin on the stove-side shelf.
const CROPS_GLB := "res://assets/greenhouse/crops.glb"   # tools/blender/gen_crops.py
const LEAF_SHADER := preload("res://world/shaders/crop_leaf.gdshader")
const BARREL_P := Vector3(-1.05, 0.0, 1.96)
const BIN_P := Vector3(1.22, 0.0, 1.98)
const LANTERN_P := Vector3(0.0, 2.05, 0.1)
const TIN_P := Vector3(0.62, 0.86, -1.95)
const SNOW_MELT_KG_H := 1.6      # per degree above 0 C, roughly (a 40 L drum by a box stove)
const COMPOST_H := 48.0          # warm hours to rot three loads down
const LANTERN_OIL_H := 10.0      # per half-litre
static var _crop_meshes: Dictionary = {}
## Generated plants are modelled small; a winter greenhouse plant in a good bed is bigger (potato haulm ~0.5 m).
const CROP_SCALE := {"potato": 1.7, "kale": 1.55, "carrot": 1.3, "beet": 1.45, "shallot": 1.25, "radish": 1.25}
var barrel := {"water_l": 0.0, "snow_kg": 0.0}
var compost_bin := {"loads": 0, "warm_s": 0.0, "ready": 0}
var lantern := {"oil_h": 0.0, "lit": false}
var tin_taken := false
var _lantern_light: OmniLight3D
var _lantern_glass: MeshInstance3D
var _tin: Node3D
var _barrel_water: MeshInstance3D
## Leaf blades per crop: count at sprout + extra at maturity, width, length, lift from the soil (rad).
const LEAF := {
	"potato": {"n0": 4, "n1": 6, "w": 0.09, "l": 0.34, "tilt": 0.95},
	"carrot": {"n0": 5, "n1": 9, "w": 0.025, "l": 0.30, "tilt": 1.15},
	"kale": {"n0": 4, "n1": 5, "w": 0.15, "l": 0.32, "tilt": 0.75},
}
var floor_y := 0.0
var door_open := false
var door_boards := 0
var door_hp := 40.0
var door_broken := false
var openings: Array[Opening] = []
var interior: InteriorLighting
var stove: Stove
var plots: Array = []
var _walls: Array[Rect2] = []
var _door: Node3D
var _plants: Array = []   # Node3D per plot
var _soil: MeshInstance3D
var _door_rect := Rect2(-DOOR_HALF, HZ - 0.04, 2 * DOOR_HALF, 0.08)   # HitZones.building_block reads it
var room: RoomClimate

func setup(terrain: Terrain3D, x: float, z: float, yaw_deg: float) -> bool:
	var hmax := -1e9; var hmin := 1e9
	for cx in [-HX, 0.0, HX]:
		for cz in [-HZ, 0.0, HZ]:
			var p := Vector3(x, 0, z) + Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3(cx, 0, cz)
			var h: float = terrain.data.get_height(p)
			if is_nan(h): return false
			hmax = maxf(hmax, h); hmin = minf(hmin, h)
	if hmax - hmin > 0.9: return false
	position = Vector3(x, hmax - 0.05, z); rotation_degrees = Vector3(0, yaw_deg, 0)
	floor_y = position.y + FT
	var model := (load(MODEL) as PackedScene).instantiate() as Node3D; add_child(model)
	var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.roughness = 0.92; mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = Cabin._grain_tex(); mat.uv1_triplanar = true; mat.uv1_scale = Vector3(2.6, 0.3, 2.6); mat.albedo_color = Color(1.12, 1.12, 1.12)
	var poly := StandardMaterial3D.new(); poly.vertex_color_use_as_albedo = true; poly.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	poly.albedo_color = Color(0.95, 0.97, 1.0, 0.62); poly.roughness = 0.55  # milky, frosted winter poly; poly.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		match String(mi.name):
			"greenhouse_panels":
				mi.material_override = poly; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			"greenhouse_soil":
				mi.material_override = mat.duplicate(); _soil = mi
			_:
				mi.material_override = mat
		mi.visibility_range_end = 260.0
	_door = model.find_child("greenhouse_door", true, false) as Node3D
	var t := WALL_T
	_walls = [Rect2(-HX - t, -HZ - t, 2 * HX + 2 * t, 2 * t), Rect2(-HX - t, HZ - t, HX + t - DOOR_HALF, 2 * t),
		Rect2(DOOR_HALF, HZ - t, HX + t - DOOR_HALF, 2 * t), Rect2(-HX - t, -HZ - t, 2 * t, 2 * HZ + 2 * t), Rect2(HX - t, -HZ - t, 2 * t, 2 * HZ + 2 * t)]
	for bx in [-1.0, 1.0]:  # raised beds are solid
		_walls.append(Rect2(bx - 0.5, -1.98, 1.0, 3.76))
	stove = Stove.new(); stove.build(self, "box_stove", Vector3(0.15, FT, -1.85), Vector3(0.15, 3.25, -1.95), 0.0, FT + 2.38)
	_walls.append(stove.footprint)
	for i in PLOTS.size():
		plots.append(Farming.new_plot())
		var n := Node3D.new(); add_child(n); n.position = Vector3(PLOTS[i].x, SOIL_Y, PLOTS[i].y); _plants.append(n)
	_build_props()
	interior = InteriorLighting.new(); add_child(interior)
	interior.build(openings, Vector3(0, FT + 1.5, 0), maxf(HX, HZ), stove.fire, stove.position)
	_set_door(false)
	return true

## Sun through the glazing, 0..1 (Farming.light_factor), set by GameWorld each update.
var light := 0.0
func lantern_lit() -> bool: return bool(lantern.lit) and float(lantern.oil_h) > 0.0
func advance(game_s: float, air_c: float) -> void:   # the stove advances with the other stove buildings
	var l := maxf(light, Farming.rule("lantern_light") if lantern_lit() else 0.0)
	for i in plots.size():
		var was := Farming.stage(plots[i]) + Farming.status(plots[i])
		Farming.advance(plots[i], game_s, air_c, l)
		if Farming.stage(plots[i]) + Farming.status(plots[i]) != was: _refresh_plant(i)
	# snowmelt barrel: snow by the stove turns to watering water (not drinking water)
	if float(barrel.snow_kg) > 0.0 and air_c > 0.5:
		var m := minf(float(barrel.snow_kg), SNOW_MELT_KG_H * air_c * game_s / 3600.0)
		barrel.snow_kg = float(barrel.snow_kg) - m; barrel.water_l = minf(40.0, float(barrel.water_l) + m)
	# compost rots only while it is warm
	if int(compost_bin.loads) >= 3 and air_c > 5.0:
		compost_bin.warm_s = float(compost_bin.warm_s) + game_s
		if float(compost_bin.warm_s) >= COMPOST_H * 3600.0:
			compost_bin.loads = int(compost_bin.loads) - 3; compost_bin.ready = int(compost_bin.ready) + 2; compost_bin.warm_s = 0.0
	if lantern_lit():
		lantern.oil_h = maxf(0.0, float(lantern.oil_h) - game_s / 3600.0)
		if float(lantern.oil_h) <= 0.0: lantern.lit = false
	_update_props()

## A lit lantern behind poly panels is a beacon at night (light cue like the stove's).
func lantern_cue(bus: NoiseBus, night: float) -> void:
	if bus != null and lantern_lit() and night > 0.15: bus.emit_light(global_position, 55.0 * night, self)

func plot_world(i: int) -> Vector3: return to_global(Vector3(PLOTS[i].x, SOIL_Y + 0.15, PLOTS[i].y))

## Interaction entries for GameWorld (pos, r, tol, text, hold, act). `say` shows a message.
func actions(inv: Inventory, say: Callable) -> Array:
	var out: Array = []
	out.append({"pos": to_global(Vector3(0, FT + 1.0, HZ)), "r": 2.2, "tol": 1.0, "text": "Close door" if door_open else "Open door", "hold": 0.0, "act": func() -> void: toggle_door()})
	out.append_array(_prop_actions(inv, say))
	for i in plots.size():
		var p: Dictionary = plots[i]; var pos := plot_world(i); var st := Farming.status(p)
		if inv.count("compost") > 0 and not bool(p.get("compost", false)) and not bool(p.dead) and not Farming.ripe(p):
			out.append({"pos": pos, "r": 1.9, "tol": 0.45, "text": "Work compost into the %s" % ("plot" if String(p.crop) == "" else st), "hold": 2.0,
				"act": func() -> void: say.call(Farming.add_compost(p, inv)); _refresh_plant(i)})
		if String(p.crop) == "":
			for cid: String in Farming.crop_ids():
				var seed_id := String(Farming.crop(cid).seed)
				if inv.count(seed_id) > 0:
					out.append({"pos": pos, "r": 1.9, "tol": 0.45, "text": "Plant %s • %s x%d" % [Farming.crop(cid).name, inv.name_of(seed_id).to_lower(), inv.count(seed_id)], "hold": 3.0,
						"act": func() -> void: say.call(Farming.plant(p, cid, inv)); _refresh_plant(i)})
			if out.size() == 1 or out[-1].pos != pos:
				out.append({"pos": pos, "r": 1.9, "tol": 0.45, "text": "Empty plot • needs seeds or a seed potato", "hold": 0.0, "act": func() -> void: say.call("Seed packets and seed potatoes turn up in homes and the store")})
			continue
		if Farming.ripe(p) or bool(p.dead):
			out.append({"pos": pos, "r": 1.9, "tol": 0.45, "text": ("Clear %s" if bool(p.dead) else "Harvest %s") % st, "hold": 2.0, "act": func() -> void: say.call(Farming.harvest(p, inv)); _refresh_plant(i)})
		elif float(p.water) < 0.95:
			var src := "snowmelt %.1f L" % float(barrel.water_l) if float(barrel.water_l) >= 0.5 else ("0.5 L bottle" if inv.count("clean_water") > 0 else "needs water")
			var can := float(barrel.water_l) >= 0.5 or inv.count("clean_water") > 0
			out.append({"pos": pos, "r": 1.9, "tol": 0.45, "text": "Water %s • %s" % [st, src], "hold": 1.5 if can else 0.0,
				"act": func() -> void: say.call(Farming.water(p, inv, barrel)); _refresh_plant(i); _update_props()})
		else:
			out.append({"pos": pos, "r": 1.9, "tol": 0.45, "text": st, "hold": 0.0, "act": func() -> void: say.call(st)})
	return out

func _refresh_plant(i: int) -> void:
	var n: Node3D = _plants[i]
	for c in n.get_children(): c.queue_free()
	var p: Dictionary = plots[i]
	if String(p.crop) == "": return
	var mesh := _crop_mesh("crop_%s_%s" % [String(p.crop), Farming.stage(p)])
	if mesh == null: return
	var rng := RandomNumberGenerator.new(); rng.seed = i * 31 + 7
	var mi := MeshInstance3D.new(); mi.mesh = mesh; n.add_child(mi)
	mi.rotation.y = rng.randf_range(0.0, TAU); var s := rng.randf_range(0.92, 1.08) * float(CROP_SCALE.get(String(p.crop), 1.3)); mi.scale = Vector3(s, s, s)
	var m := ShaderMaterial.new(); m.shader = LEAF_SHADER
	m.set_shader_parameter("jitter", rng.randf_range(-1.0, 1.0))
	m.set_shader_parameter("frost", clampf(float(p.frost_s) / (Farming.rule("frost_kill_h") * 3600.0), 0.0, 1.0) if not bool(p.dead) else 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 60.0
	if bool(p.get("compost", false)):   # a dark ring of compost round the crown
		var ring := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.17; cm.bottom_radius = 0.19; cm.height = 0.012; cm.radial_segments = 14
		ring.mesh = cm; ring.position.y = 0.004; n.add_child(ring)
		var rm := StandardMaterial3D.new(); rm.albedo_color = Color(0.09, 0.07, 0.05); rm.roughness = 0.95; ring.material_override = rm


static func _crop_mesh(nm: String) -> Mesh:
	if _crop_meshes.is_empty() and ResourceLoader.exists(CROPS_GLB):
		var root := (load(CROPS_GLB) as PackedScene).instantiate()
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false): _crop_meshes[String(mi.name)] = mi.mesh
		root.free()
	return _crop_meshes.get(nm)


# ---------------------------------------------------------------- farming v2 props
func _wood_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_texture = Cabin._grain_tex(); m.uv1_triplanar = true; m.uv1_scale = Vector3(2.0, 0.4, 2.0)
	m.albedo_color = c; m.roughness = 0.9; return m


func _build_props() -> void:
	var iron := StandardMaterial3D.new(); iron.albedo_color = Color(0.16, 0.15, 0.14); iron.metallic = 0.6; iron.roughness = 0.6
	# snowmelt barrel: a sawn-off steel drum on two bricks, water surface rises with what has melted
	var b := Node3D.new(); add_child(b); b.position = BARREL_P + Vector3(0, FT, 0)
	var drum := MeshInstance3D.new(); var dm := CylinderMesh.new(); dm.top_radius = 0.20; dm.bottom_radius = 0.20; dm.height = 0.62; dm.radial_segments = 20; dm.cap_top = false
	drum.mesh = dm; drum.position.y = 0.37; drum.material_override = iron; b.add_child(drum)
	for hy in [0.14, 0.58]:
		var hoop := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.195; tm.outer_radius = 0.215; tm.rings = 20; tm.ring_segments = 6
		hoop.mesh = tm; hoop.position.y = hy + 0.06; hoop.material_override = iron; b.add_child(hoop)
	_barrel_water = MeshInstance3D.new(); var wm := CylinderMesh.new(); wm.top_radius = 0.19; wm.bottom_radius = 0.19; wm.height = 0.01; wm.radial_segments = 20
	_barrel_water.mesh = wm; var wmat := StandardMaterial3D.new(); wmat.albedo_color = Color(0.20, 0.24, 0.26); wmat.roughness = 0.08; wmat.metallic_specular = 0.8
	_barrel_water.material_override = wmat; b.add_child(_barrel_water)
	# compost bin: open slatted pallet box with dark rotting matter
	var cb := Node3D.new(); add_child(cb); cb.position = BIN_P + Vector3(0, FT, 0)
	var wood := _wood_mat(Color(0.62, 0.54, 0.44))
	for side in [[Vector3(0, 0, -0.2), Vector3(0.42, 0.05, 0.03)], [Vector3(0, 0, 0.2), Vector3(0.42, 0.05, 0.03)], [Vector3(-0.2, 0, 0), Vector3(0.03, 0.05, 0.42)], [Vector3(0.2, 0, 0), Vector3(0.03, 0.05, 0.42)]]:
		for k in 5:
			var sl := MeshInstance3D.new(); var bx := BoxMesh.new(); bx.size = side[1]; sl.mesh = bx; sl.material_override = wood
			sl.position = (side[0] as Vector3) + Vector3(0, 0.04 + k * 0.085, 0); sl.rotation.y = randf_range(-0.03, 0.03); cb.add_child(sl)
	var heap := MeshInstance3D.new(); var hm := SphereMesh.new(); hm.radius = 0.19; hm.height = 0.22; hm.radial_segments = 10; hm.rings = 5
	heap.mesh = hm; heap.position.y = 0.16; heap.scale = Vector3(1, 0.7, 1); heap.name = "Heap"
	var hmat := StandardMaterial3D.new(); hmat.albedo_color = Color(0.10, 0.08, 0.05); hmat.roughness = 1.0; heap.material_override = hmat; cb.add_child(heap)
	# storm lantern on the ridge beam
	var ln := Node3D.new(); add_child(ln); ln.position = LANTERN_P + Vector3(0, FT, 0)
	var cap := MeshInstance3D.new(); var cpm := CylinderMesh.new(); cpm.top_radius = 0.025; cpm.bottom_radius = 0.06; cpm.height = 0.05; cap.mesh = cpm; cap.position.y = 0.09; cap.material_override = iron; ln.add_child(cap)
	var base := MeshInstance3D.new(); var bpm := CylinderMesh.new(); bpm.top_radius = 0.06; bpm.bottom_radius = 0.065; bpm.height = 0.04; base.mesh = bpm; base.position.y = -0.09; base.material_override = iron; ln.add_child(base)
	_lantern_glass = MeshInstance3D.new(); var gm := CylinderMesh.new(); gm.top_radius = 0.045; gm.bottom_radius = 0.05; gm.height = 0.13; gm.radial_segments = 14
	_lantern_glass.mesh = gm; ln.add_child(_lantern_glass)
	var glass := StandardMaterial3D.new(); glass.albedo_color = Color(0.85, 0.80, 0.70, 0.55); glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.emission_enabled = true; glass.emission = Color(1.0, 0.72, 0.38); glass.emission_energy_multiplier = 0.0; _lantern_glass.material_override = glass
	var bail := MeshInstance3D.new(); var bm2 := TorusMesh.new(); bm2.inner_radius = 0.045; bm2.outer_radius = 0.052; bail.mesh = bm2; bail.rotation.x = PI * 0.5; bail.position.y = 0.16; bail.material_override = iron; ln.add_child(bail)
	_lantern_light = OmniLight3D.new(); _lantern_light.light_color = Color(1.0, 0.70, 0.38); _lantern_light.omni_range = 5.5; _lantern_light.light_energy = 0.0
	_lantern_light.shadow_enabled = false; ln.add_child(_lantern_light)
	# the gardener's seed tin
	_tin = Node3D.new(); add_child(_tin); _tin.position = TIN_P + Vector3(0, FT, 0)
	var tin := MeshInstance3D.new(); var tb := BoxMesh.new(); tb.size = Vector3(0.20, 0.09, 0.13); tin.mesh = tb
	var tmat := StandardMaterial3D.new(); tmat.albedo_color = Color(0.36, 0.42, 0.30); tmat.metallic = 0.5; tmat.roughness = 0.55; tin.material_override = tmat; _tin.add_child(tin)
	var shelf := MeshInstance3D.new(); var sb := BoxMesh.new(); sb.size = Vector3(0.6, 0.03, 0.2); shelf.mesh = sb; shelf.position.y = -0.06; shelf.material_override = wood; add_child(shelf); shelf.position = TIN_P + Vector3(0, FT - 0.06, 0)
	_update_props()


func _update_props() -> void:
	if _barrel_water == null: return
	_barrel_water.position.y = 0.08 + 0.6 * clampf((float(barrel.water_l) + float(barrel.snow_kg)) / 40.0, 0.0, 1.0)
	var on := lantern_lit()
	_lantern_light.light_energy = 1.4 if on else 0.0
	(_lantern_glass.material_override as StandardMaterial3D).emission_energy_multiplier = 2.5 if on else 0.0
	_tin.visible = not tin_taken
	var heap := find_child("Heap", true, false) as Node3D
	if heap != null: heap.scale = Vector3(1, 0.25 + 0.25 * mini(int(compost_bin.loads) + int(compost_bin.ready), 4), 1)


func _prop_actions(inv: Inventory, say: Callable) -> Array:
	var out: Array = []
	var bp := to_global(BARREL_P + Vector3(0, FT + 0.7, 0))
	var snow := inv.count("snow_portion")
	if snow > 0:
		out.append({"pos": bp, "r": 1.6, "tol": 0.5, "text": "Tip snow into the melt barrel x%d • %.1f L water" % [snow, float(barrel.water_l)], "hold": 1.5,
			"act": func() -> void:
				var n := inv.count("snow_portion"); inv.remove("snow_portion", n); barrel.snow_kg = float(barrel.snow_kg) + 0.5 * n
				say.call("The snow will melt by the stove: water for the beds, not for drinking"); _update_props()})
	else:
		out.append({"pos": bp, "r": 1.6, "tol": 0.5, "text": "Melt barrel • %.1f L water, %.1f kg snow" % [float(barrel.water_l), float(barrel.snow_kg)], "hold": 0.0,
			"act": func() -> void: say.call("Collect snow outside and tip it in; the stove melts it for the beds")})
	var cp := to_global(BIN_P + Vector3(0, FT + 0.5, 0))
	var feed := _compostable(inv)
	if int(compost_bin.ready) > 0:
		out.append({"pos": cp, "r": 1.6, "tol": 0.5, "text": "Take compost x%d" % int(compost_bin.ready), "hold": 1.5,
			"act": func() -> void: inv.add("compost", int(compost_bin.ready)); say.call("Took %d loads of compost" % int(compost_bin.ready)); compost_bin.ready = 0; _update_props()})
	if feed != "":
		out.append({"pos": cp, "r": 1.6, "tol": 0.5, "text": "Add %s to the compost • %d/3" % [inv.name_of(feed).to_lower(), int(compost_bin.loads)], "hold": 1.0,
			"act": func() -> void: inv.remove(feed); compost_bin.loads = int(compost_bin.loads) + 1; say.call("Into the compost. Three loads rot down in two warm days"); _update_props()})
	elif int(compost_bin.ready) == 0:
		var h := COMPOST_H - float(compost_bin.warm_s) / 3600.0
		out.append({"pos": cp, "r": 1.6, "tol": 0.5, "text": ("Compost bin • rotting, ~%d h warm left" % int(h)) if int(compost_bin.loads) >= 3 else "Compost bin • %d/3 • rotten or spoiled food" % int(compost_bin.loads), "hold": 0.0,
			"act": func() -> void: say.call("Spoiled food and rotten meat go in; keep the greenhouse warm")})
	var lp := to_global(LANTERN_P + Vector3(0, FT - 0.6, 0))
	if float(lantern.oil_h) < 1.0 and inv.count("lamp_oil") > 0:
		out.append({"pos": lp, "r": 2.0, "tol": 0.7, "text": "Fill the lantern • lamp oil", "hold": 2.0,
			"act": func() -> void: inv.remove("lamp_oil"); lantern.oil_h = float(lantern.oil_h) + LANTERN_OIL_H; lantern.lit = true; say.call("The lantern burns through the night: the beds grow at half pace in the dark. It shows for miles."); _update_props()})
	elif float(lantern.oil_h) > 0.0:
		out.append({"pos": lp, "r": 2.0, "tol": 0.7, "text": ("Put out the lantern • %d h oil" if bool(lantern.lit) else "Light the lantern • %d h oil") % int(float(lantern.oil_h)), "hold": 0.5,
			"act": func() -> void: lantern.lit = not bool(lantern.lit); _update_props()})
	if not tin_taken:
		out.append({"pos": to_global(TIN_P + Vector3(0, FT, 0)), "r": 1.6, "tol": 0.5, "text": "Open the gardener's seed tin", "hold": 1.0,
			"act": func() -> void:
				tin_taken = true
				inv.add("radish_seeds", 2); inv.add("beet_seeds", 2); inv.add("shallot", 3); inv.add("lamp_oil", 1)
				say.call("Radish and beet seed, three shallots, a bottle of lamp oil. Someone meant to winter here."); _update_props()})
	return out


## Something that can go in the compost: rotten meat, or food that is nearly spoiled.
func _compostable(inv: Inventory) -> String:
	if inv.count("rotten_meat") > 0: return "rotten_meat"
	for id: String in inv.ids():
		if Inventory.kind_of(id) == "food" and Inventory.shelf_s(id) > 0.0 and inv.count(id) > 0 and inv.freshness(id) < 0.3: return id
	return ""


func refresh_all() -> void:
	for i in plots.size(): _refresh_plant(i)

func toggle_door() -> void:
	if door_broken: return
	_set_door(not door_open)

func _set_door(v: bool) -> void:
	door_open = v
	if _door != null: _door.rotation.y = deg_to_rad(100.0) if v else 0.0

func noise_leak() -> float: return 1.0 if door_open else 0.7
func sight_line_open(_a: Vector3, _b: Vector3) -> bool: return true   # clear-ish poly walls
func door_world_pos() -> Vector3: return to_global(Vector3(0.0, 0.0, HZ + 0.6))
func bash_door(dmg: float) -> void:
	if door_broken or door_open: return
	door_hp -= dmg
	if door_hp <= 0.0:
		door_broken = true; _set_door(true)

func to_local_xz(x: float, z: float) -> Vector2:
	var l := to_local(Vector3(x, position.y, z)); return Vector2(l.x, l.z)

func contains_xz(x: float, z: float) -> bool:
	var l := to_local_xz(x, z); return absf(l.x) < HX - 0.1 and absf(l.y) < HZ - 0.1

func floor_at(x: float, z: float, _terrain_h: float) -> float:
	var l := to_local_xz(x, z)
	if absf(l.x) < HX - 0.1 and l.y > -HZ + 0.1 and l.y < HZ + 0.35: return floor_y
	return NAN

func resolve(x: float, z: float, r: float) -> Vector2:
	var l := to_local_xz(x, z)
	var rects := _walls.duplicate()
	if not door_open: rects.append(Rect2(-DOOR_HALF, HZ - 0.04, 2 * DOOR_HALF, 0.08))
	for w: Rect2 in rects:
		var cx := clampf(l.x, w.position.x, w.end.x); var cz := clampf(l.y, w.position.y, w.end.y)
		var d := l - Vector2(cx, cz); var dl := d.length()
		if dl < r:
			l = Vector2(cx, cz) + (d / dl if dl > 0.0001 else Vector2(1, 0)) * r
	var g := to_global(Vector3(l.x, 0, l.y)); return Vector2(g.x, g.z)

func state_dict() -> Dictionary:
	return {"open": door_open, "broken": door_broken, "hp": door_hp, "fire": stove.fire.to_dict(), "plots": plots.duplicate(true),
		"barrel": barrel.duplicate(), "compost": compost_bin.duplicate(), "lantern": lantern.duplicate(), "tin": tin_taken}

func restore_state(d: Dictionary) -> void:
	door_broken = bool(d.get("broken", false)); door_hp = float(d.get("hp", 40.0))
	_set_door(bool(d.get("open", false)) or door_broken)
	if d.has("fire"): stove.fire.restore(d.fire)
	var ps: Array = d.get("plots", [])
	for i in mini(ps.size(), plots.size()):
		plots[i] = Farming.new_plot(); (plots[i] as Dictionary).merge(ps[i], true)
	barrel.merge(d.get("barrel", {}), true); compost_bin.merge(d.get("compost", {}), true); lantern.merge(d.get("lantern", {}), true)
	tin_taken = bool(d.get("tin", false))
	refresh_all(); _update_props()
