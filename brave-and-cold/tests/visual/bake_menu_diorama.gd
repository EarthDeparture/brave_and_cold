extends SceneTree
## Bakes the live main-menu scene from a real game build: the lookout's placement, the
## camera shot, and every standing tree within RADIUS of the lookout (exact game trees),
## plus hashes of the inputs so test_menu_diorama can tell when the bake is stale (e.g.
## after the tree canopy pass: just run this again).
##   godot --path brave-and-cold --script res://tests/visual/bake_menu_diorama.gd
const OUT := "res://data/menu/diorama.bin"
const RADIUS := 900.0
const HASHED := ["res://world/forest_scatter.gd", "res://data/maps/valley_b/canopy.png",
	"res://data/maps/valley_b/slope.png", "res://data/maps/valley_b/water_mask.png",
	"res://data/lookout_site.json", "res://world/fire_lookout.gd"]

func _initialize() -> void: call_deferred("run")

static func input_hashes() -> Dictionary:
	var h := {}
	for p: String in HASHED: h[p] = FileAccess.get_md5(p)
	return h

func run() -> void:
	SaveGame.pending = {}; seed(20261004)
	var w: Node3D = load("res://world/game_world.gd").new(); root.add_child(w)
	for i in 900:
		await process_frame
		if w.get("hud") != null and w.get("opening") != null and bool(w.get("built")): break
	var t: FireLookout = w.fire_lookout
	var forest: ForestScatter = w.forest
	if t == null or forest == null:
		print("BAKE failed: no lookout/forest"); quit(1); return
	var tp := t.global_position
	# the menu shot (same framing as capture_menu_bg lookout_*): 46 m out, subject right third
	var a := 3 * TAU / 4.0 + 0.4
	var eye := Vector3(tp.x + cos(a) * 46.0, 0, tp.z + sin(a) * 46.0)
	eye.y = w._ground(eye.x, eye.z).y + 1.6
	var tgt := tp + Vector3(0, 12.0, 0)
	var f := (tgt - eye).normalized(); var right := f.cross(Vector3.UP).normalized()
	tgt -= right * 19.0
	var trees := forest.export_region(Vector2(tp.x, tp.z), RADIUS)
	var n := 0
	for k in trees: n += (trees[k] as PackedFloat32Array).size() / 12
	var site: Variant = JSON.parse_string(FileAccess.get_file_as_string(FireLookout.SITE_PATH))
	var data := {
		"version": 1, "lookout_xform": t.global_transform, "site": site,
		"eye": eye, "target": tgt, "fov": 58.0, "hour": 18.3,
		"trees": trees, "tree_count": n, "radius": RADIUS,
		"detail": forest.detail_enabled, "crowns": forest.crown_quality_enabled, "diversity": forest.diversity_enabled,
		"inputs": input_hashes(),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/menu"))
	var fa := FileAccess.open(OUT, FileAccess.WRITE)
	fa.store_var(data, false); fa.close()
	print("BAKE ok trees=%d bytes=%d eye=%s" % [n, FileAccess.get_file_as_bytes(OUT).size(), str(eye)])
	quit(0)
