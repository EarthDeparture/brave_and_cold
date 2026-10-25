extends SceneTree
## Imports a pipeline heightmap (tools/terrain extract_window.py output) into Terrain3D region files.
## Run: Godot --headless --path brave-and-cold --script res://tools/build_terrain.gd -- valley_b
## Heights are shifted so the lowest point of the map is y = 0.

const REGION_SIZE := 256


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var map_name: String = args[0] if args.size() > 0 else "valley_b"
	var src_dir := "res://data/maps/%s" % map_name
	var out_dir := "res://data/terrain/%s" % map_name

	var meta = JSON.parse_string(FileAccess.get_file_as_string(src_dir + "/meta.json"))
	if meta == null:
		push_error("meta.json missing for " + map_name)
		quit(1)
		return
	var size_m: int = int(meta["size_m"])
	var zmin: float = meta["z_min_m"]
	var zmax: float = meta["z_max_m"]

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var t := Terrain3D.new()
	t.name = "Terrain3D"
	root.add_child(t)
	t.region_size = REGION_SIZE
	t.data_directory = out_dir
	await process_frame
	await process_frame
	if t.data == null:
		push_error("Terrain3D.data is null")
		quit(1)
		return

	var img: Image = Terrain3DUtil.load_image(
		ProjectSettings.globalize_path(src_dir + "/height.r16"),
		ResourceLoader.CACHE_MODE_IGNORE, Vector2(zmin, zmax), Vector2i(size_m, size_m))
	if img == null:
		push_error("failed to load height.r16")
		quit(1)
		return
	img = _smooth(img, 3, 2)
	var mm := Terrain3DUtil.get_min_max(img)
	print("HEIGHT_IMAGE ", img.get_size(), " min/max ", mm)

	var images: Array[Image] = []
	images.resize(Terrain3DRegion.TYPE_MAX)
	images[Terrain3DRegion.TYPE_HEIGHT] = img
	var half := size_m * 0.5
	t.data.import_images(images, Vector3(-half, 0.0, -half), -zmin, 1.0)
	t.data.calc_height_range(true)
	t.data.save_directory(out_dir)
	print("REGIONS ", t.data.get_region_count(), " height_range ", t.data.get_height_range())
	print("BUILD_OK ", out_dir)
	quit(0)


## Box-blur a float heightmap (radius r px, n passes) to remove 16-bit quantisation terraces
## (they show up as contour-line banding under grazing sun).
func _smooth(img: Image, r: int, passes: int) -> Image:
	if img.get_format() != Image.FORMAT_RF:
		img.convert(Image.FORMAT_RF)
	var w := img.get_width()
	var h := img.get_height()
	var a: PackedFloat32Array = img.get_data().to_float32_array()
	var b := PackedFloat32Array()
	b.resize(a.size())
	for _p in range(passes):
		# horizontal
		for y in range(h):
			var row := y * w
			for x in range(w):
				var s := 0.0
				for k in range(-r, r + 1):
					s += a[row + clampi(x + k, 0, w - 1)]
				b[row + x] = s / float(2 * r + 1)
		# vertical
		for y in range(h):
			for x in range(w):
				var s2 := 0.0
				for k in range(-r, r + 1):
					s2 += b[clampi(y + k, 0, h - 1) * w + x]
				a[y * w + x] = s2 / float(2 * r + 1)
	return Image.create_from_data(w, h, false, Image.FORMAT_RF, a.to_byte_array())
