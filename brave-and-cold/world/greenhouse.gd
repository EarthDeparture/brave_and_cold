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
	interior = InteriorLighting.new(); add_child(interior)
	interior.build(openings, Vector3(0, FT + 1.5, 0), maxf(HX, HZ), stove.fire, stove.position)
	_set_door(false)
	return true

## Sun through the glazing, 0..1 (Farming.light_factor), set by GameWorld each update.
var light := 0.0
func advance(game_s: float, air_c: float) -> void:   # the stove advances with the other stove buildings
	for i in plots.size():
		var was := Farming.status(plots[i])
		Farming.advance(plots[i], game_s, air_c, light)
		if Farming.status(plots[i]) != was: _refresh_plant(i)

func plot_world(i: int) -> Vector3: return to_global(Vector3(PLOTS[i].x, SOIL_Y + 0.15, PLOTS[i].y))

## Interaction entries for GameWorld (pos, r, tol, text, hold, act). `say` shows a message.
func actions(inv: Inventory, say: Callable) -> Array:
	var out: Array = []
	out.append({"pos": to_global(Vector3(0, FT + 1.0, HZ)), "r": 2.2, "tol": 1.0, "text": "Close door" if door_open else "Open door", "hold": 0.0, "act": func() -> void: toggle_door()})
	for i in plots.size():
		var p: Dictionary = plots[i]; var pos := plot_world(i); var st := Farming.status(p)
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
			out.append({"pos": pos, "r": 1.9, "tol": 0.45, "text": "Water %s • %s" % [st, "0.5 L bottle" if inv.count("clean_water") > 0 else "needs drinking water"], "hold": 1.5 if inv.count("clean_water") > 0 else 0.0,
				"act": func() -> void: say.call(Farming.water(p, inv)); _refresh_plant(i)})
		else:
			out.append({"pos": pos, "r": 1.9, "tol": 0.45, "text": st, "hold": 0.0, "act": func() -> void: say.call(st)})
	return out

func _refresh_plant(i: int) -> void:
	var n: Node3D = _plants[i]
	for c in n.get_children(): c.queue_free()
	var p: Dictionary = plots[i]
	if String(p.crop) == "": return
	var g := clampf(float(p.growth), 0.08, 1.0)
	var col: Array = Farming.crop(String(p.crop)).get("color", [0.2, 0.35, 0.18])
	var c := Color(col[0], col[1], col[2]) if not bool(p.dead) else Color(0.30, 0.24, 0.15)
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 0.8
	var shape: Dictionary = LEAF.get(String(p.crop), LEAF.potato)
	var dead := bool(p.dead)
	var leaves := int(shape.n0) + int(g * float(shape.n1)); var rng := RandomNumberGenerator.new(); rng.seed = i * 31 + 7
	for k in leaves:   # upright blades from the crown: they lengthen with growth and flop when dead
		var pivot := Node3D.new(); n.add_child(pivot)
		var a := TAU * k / leaves + rng.randf_range(-0.25, 0.25)
		pivot.rotation.y = a
		var tilt := (float(shape.tilt) + rng.randf_range(-0.15, 0.15)) if not dead else 0.12
		var blade := Node3D.new(); pivot.add_child(blade); blade.rotation.x = -tilt
		var length := float(shape.l) * (0.35 + 0.65 * g) * rng.randf_range(0.8, 1.15)
		var leaf := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(float(shape.w) * (0.6 + 0.4 * g), 0.01, length)
		leaf.mesh = bm; leaf.material_override = m; leaf.position = Vector3(0, 0, length * 0.5); blade.add_child(leaf)
		leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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
	return {"open": door_open, "broken": door_broken, "hp": door_hp, "fire": stove.fire.to_dict(), "plots": plots.duplicate(true)}

func restore_state(d: Dictionary) -> void:
	door_broken = bool(d.get("broken", false)); door_hp = float(d.get("hp", 40.0))
	_set_door(bool(d.get("open", false)) or door_broken)
	if d.has("fire"): stove.fire.restore(d.fire)
	var ps: Array = d.get("plots", [])
	for i in mini(ps.size(), plots.size()):
		plots[i] = Farming.new_plot(); (plots[i] as Dictionary).merge(ps[i], true)
	refresh_all()
