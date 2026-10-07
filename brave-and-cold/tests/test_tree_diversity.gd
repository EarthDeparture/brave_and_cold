extends SceneTree
## Whole-map identities, collision, felling, save replay and imported LODs.
var failures := 0
var quality_compare:=false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1

func forest(t: Terrain3D, diverse: bool) -> ForestScatter:
	var f := ForestScatter.new(); f.detail_enabled = true; f.diversity_enabled = diverse or quality_compare
	f.crown_quality_enabled=diverse
	root.add_child(f); f.set_process(false); f.hide(); f.build(t)
	return f

func transforms(f: ForestScatter) -> Dictionary:
	var records := {}
	for key: Vector3i in f._mms:
		var near_mesh: MultiMesh = f._mms[key][0]
		var far_mesh: MultiMesh = f._mms[key][1]
		for index in near_mesh.instance_count:
			var xf := near_mesh.get_instance_transform(index)
			check_lod = check_lod and xf == far_mesh.get_instance_transform(index)
			records[ForestScatter.tree_key(xf.origin.x, xf.origin.z)] = {"xf": xf, "variant": key.z, "index": index, "pair": f._mms[key]}
	return records

var check_lod := true
func run() -> void:
	quality_compare=OS.get_cmdline_user_args().has("quality_compare=1")
	create_timer(120).timeout.connect(func() -> void: print("FAIL tree diagnostic timeout"); quit(2))
	var camera := Camera3D.new(); root.add_child(camera); camera.make_current()
	camera.position = Vector3(0, 80, 0)
	var t := Terrain3D.new(); t.assets = load("res://data/terrain/terrain_winter_assets.tres")
	t.data_directory = "res://data/terrain/valley_b"; root.add_child(t)
	t.set_camera(camera)
	await process_frame; await process_frame
	var original := forest(t, false)
	var diverse := forest(t, true)
	check(original.tree_count > 100000 and original.tree_count == diverse.tree_count, "entire map retains tree population")
	check(original._trunks == diverse._trunks, "every tree root, collision radius and occlusion trunk is unchanged")
	var a := transforms(original); var b := transforms(diverse)
	if b.size() != diverse.tree_count:
		push_error("This contract requires real renderer MultiMesh storage; run with Vulkan, not --headless.")
		original.free(); diverse.free(); t.free(); quit(1); return
	var exact := a.size() == b.size()
	for key: String in a:
		if not b.has(key) or a[key].xf != b[key].xf: exact = false; break
	check(exact, "all saved-coordinate identities, height, girth and yaw transforms survive diversification")
	if quality_compare:
		var variants_same:=true
		for key:String in a:variants_same=variants_same and a[key].variant==b[key].variant
		check(variants_same,"quality resources preserve every existing species identity")
	check(check_lod, "near and far instances have identical placement transforms")
	var counts := {}; var specimens := {}
	for key: String in b:
		var vi: int = b[key].variant
		counts[ForestScatter.VARIANTS[vi]] = int(counts.get(ForestScatter.VARIANTS[vi], 0)) + 1
		if vi >= 3 and not specimens.has(vi): specimens[vi] = key
	check(counts.size() == 8 and specimens.size() == 5, "all five new families appear alongside all original spruces")
	print("TREE_VARIANT_COUNTS ", JSON.stringify(counts))
	var cuts: Array[String] = []
	for vi: int in specimens:
		var key: String = specimens[vi]; var record: Dictionary = b[key]
		var pos: Vector3 = record.xf.origin
		var collided_a := original.resolve_trunks(pos.x + .1, pos.z, .3)
		var collided_b := diverse.resolve_trunks(pos.x + .1, pos.z, .3)
		check(collided_a == collided_b, ForestScatter.VARIANTS[vi] + " uses the unchanged smooth walking trunk response")
		var info := diverse.fell(pos.x, pos.z)
		check(not info.is_empty() and info.vi == vi and info.basis == record.xf.basis, "felling retains correct mesh and transform: " + ForestScatter.VARIANTS[vi])
		if info.is_empty(): continue
		var both_hidden := true
		for mm: MultiMesh in record.pair: both_hidden = both_hidden and mm.get_instance_transform(record.index).basis.get_scale().length() < .001
		check(both_hidden and diverse.felled.has(key), "cut removes both LODs and records the existing save key")
		check(diverse.fell(pos.x, pos.z).is_empty(), "repeated cut cannot duplicate a new-family tree")
		var result := original.apply_felled([key])
		check(result.size() == 1 and is_equal_approx(float(result[0].h), float(info.h)) and is_equal_approx(float(result[0].r), float(info.r)), "diverse cut replays into original presentation with identical wood metadata")
		cuts.append(key)
		var falling := FallingTree.new(); root.add_child(falling); falling.set_process(false)
		var landed := {"count": 0}
		falling.setup(diverse.tree_mesh(vi), diverse.tree_mat(), info.origin, info.basis, Vector3.FORWARD, info.h, func() -> void: landed.count += 1)
		check(falling._mi.mesh == diverse.tree_mesh(vi) and falling._mi.material_override == diverse.tree_mat(), "falling visual keeps new tree mesh and alpha/snow shader")
		falling._process(10)
		check(landed.count == 1, "new-family fall completes the existing log callback once")
		# Inspect actual imported near/far resource triangle bounds.
		var pair: Array = record.pair
		for lod in 2:
			var imported: Mesh = (pair[lod] as MultiMesh).mesh
			check(imported.get_surface_count() == 1 and imported.get_faces().size() / 3 <= (1100 if lod else 4200), "imported LOD fits single-surface geometry budget")
			var arrays := imported.surface_get_arrays(0)
			check((arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size() == (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() * 4, "imported bark normal map has valid tangent storage")
	# New-map generation must also replay existing old presentation cuts.
	var replay := forest(t, true)
	check(transforms(replay).size() == b.size(), "fresh generation has the same full population")
	var loaded := replay.apply_felled(cuts)
	check(loaded.size() == 5 and replay.felled.size() == 5, "fresh diverse forest restores all five species' saved cuts")
	for info: Dictionary in loaded:
		var key := ForestScatter.tree_key(info.x, info.z)
		check(info.vi == b[key].variant and info.basis == b[key].xf.basis, "seeded species and transforms remain stable after save reload")
	print("TREE_DIVERSITY_TEST failures=", failures)
	replay.free(); original.free(); diverse.free(); t.free()
	await process_frame; await process_frame
	quit(1 if failures else 0)
