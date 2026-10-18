extends SceneTree
## In-game UI font A/B: HUD with a message and the action prompt, then the gear screen.
## Args: -- tag=<name>  -> res://shots/hud_fonts/<tag>_{hud,gear}.png
var w: Node3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var tag := "now"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="): tag = a.substr(4)
	root.size = Vector2i(1920, 1080); SaveGame.pending = {}; seed(20261004)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/hud_fonts"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for i in 700:
		await process_frame
		if w.hud != null and w.opening != null: break
	for i in 30: await process_frame
	w.hud.say("Font check: the quick brown fox. Temperature -14 C. 62% to catch.")
	for i in 20: await process_frame
	root.get_texture().get_image().save_png("res://shots/hud_fonts/%s_hud.png" % tag); print("HUDFONT hud")
	if tag.contains("worst"):   # longest status strings: tired, soaked, frost-nipped
		w.needs.fatigue = 88.0; w.body.wetness = 0.62
		var fb = w.get("frostbite")
		if fb != null:
			for k in fb.risk.keys(): fb.risk[k] = 60.0
	w.gear.open()
	for i in 20: await process_frame
	root.get_texture().get_image().save_png("res://shots/hud_fonts/%s_gear.png" % tag); print("HUDFONT gear")
	quit(0)
