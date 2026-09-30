extends SceneTree
## Builds the terrain texture asset list and paints forest-floor under real canopy.
## Run: Godot --headless --path brave-and-cold --script res://tools/paint_terrain.gd -- valley_b
## Texture ids: 0 snow, 1 rock, 2 forest floor, 3 ice. Auto shader: flat = snow, steep = rock.

const TEX_DIR := "res://assets/terrain/"
const ASSETS_PATH := "res://data/terrain/terrain_assets.tres"
const CANOPY_MIN := 26  # 8-bit, metres/40 -> ~4 m
const FOREST_MAX_SLOPE := 40  # 8-bit deg/90 -> ~14 deg... see below


func _make_tex(id: int, tex_name: String, color: Color, uv_scale: float) -> Terrain3DTextureAsset:
	var a := Terrain3DTextureAsset.new()
	a.id = id
	a.name = tex_name
	a.albedo_texture = load(TEX_DIR + tex_name + "_alb.png")
	a.normal_texture = load(TEX_DIR + tex_name + "_nrm.png")
	a.albedo_color = color
	a.uv_scale = uv_scale
	return a


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var map_name: String = args[0] if args.size() > 0 else "valley_b"
	var src_dir := "res://data/maps/%s" % map_name
	var out_dir := "res://data/terrain/%s" % map_name
	var meta = JSON.parse_string(FileAccess.get_file_as_string(src_dir + "/meta.json"))
	var size_m: int = int(meta["size_m"])
	var half := size_m / 2

	var assets := Terrain3DAssets.new()
	assets.set_texture(0, _make_tex(0, "snow", Color.WHITE, 0.10))
	assets.set_texture(1, _make_tex(1, "rock", Color.WHITE, 0.08))
	assets.set_texture(2, _make_tex(2, "forest", Color.WHITE, 0.10))
	assets.set_texture(3, _make_tex(3, "ice", Color.WHITE, 0.06))
	var err := ResourceSaver.save(assets, ASSETS_PATH)
	print("ASSETS_SAVED ", err)

	var t := Terrain3D.new()
	t.name = "Terrain3D"
	t.data_directory = out_dir
	root.add_child(t)
	await process_frame
	await process_frame
	if t.data == null:
		push_error("Terrain3D.data null")
		quit(1)
		return

	var canopy := Image.load_from_file(ProjectSettings.globalize_path(src_dir + "/canopy.png"))
	var slope := Image.load_from_file(ProjectSettings.globalize_path(src_dir + "/slope.png"))
	canopy.convert(Image.FORMAT_L8)
	slope.convert(Image.FORMAT_L8)
	var painted := 0
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	for py in range(0, size_m):
		for px in range(0, size_m):
			var s: float = slope.get_pixel(px, py).r * 90.0
			var c: int = int(canopy.get_pixel(px, py).r * 255.0)
			var p := Vector3(px - half + 0.5, 0.0, py - half + 0.5)
			if s >= 30.0:
				# steep: snow sheds, rock shows through (more on steeper ground)
				t.data.set_control_base_id(p, 0)
				t.data.set_control_overlay_id(p, 1)
				t.data.set_control_blend(p, clampf((s - 30.0) / 18.0, 0.0, 1.0) * 0.9)
				t.data.set_control_auto(p, false)
				painted += 1
			elif c >= 64:  # > ~10 m canopy: forest floor shows through the snow
				var density := clampf((c - 64.0) / 96.0, 0.0, 1.0)
				var n := noise.get_noise_2d(px, py) * 0.5 + 0.5
				t.data.set_control_base_id(p, 0)
				t.data.set_control_overlay_id(p, 2)
				t.data.set_control_blend(p, density * (0.25 + 0.75 * n) * 0.5)
				t.data.set_control_auto(p, false)
				painted += 1
	print("FOREST_PIXELS ", painted, " of ", size_m * size_m)
	t.data.save_directory(out_dir)
	print("PAINT_OK")
	quit(0)
