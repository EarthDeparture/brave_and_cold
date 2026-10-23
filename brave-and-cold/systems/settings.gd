class_name Settings
extends RefCounted
## Persistent user settings (user://settings.cfg).

const PATH := "user://settings.cfg"
static var master := 0.8        # 0..1
static var sensitivity := 0.002  # radians per pixel
static var dev_menu := false      # developer menu available (toggle key: backtick)
## Graphics preset. Measured 2026-10-07, GTX 1080 Ti 1080p logging-forest walk (GPU ms):
## quality 21.9 (4096 sun shadow atlas, MSAA 4x), balanced 14.9 (2048 atlas, MSAA 2x),
## performance ~10 (2048 atlas, FXAA, no SSAO, near trees cast cheap far-crown shadows).
## The alpha-tested crowns are fill-rate bound in the shadow map; atlas size is the big lever.
const GRAPHICS := ["performance", "balanced", "quality"]
static var graphics := "balanced"
static var track_hints := true    # TLD-style read of tracks / blood when looking down at them
static var _loaded := false


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var c := ConfigFile.new()
	if c.load(PATH) == OK:
		master = float(c.get_value("audio", "master", master))
		sensitivity = float(c.get_value("controls", "sensitivity", sensitivity))
		dev_menu = bool(c.get_value("debug", "dev_menu", dev_menu))
		graphics = String(c.get_value("video", "graphics", graphics))
		track_hints = bool(c.get_value("gameplay", "track_hints", track_hints))
	if not GRAPHICS.has(graphics):
		graphics = "balanced"
	for arg: String in OS.get_cmdline_user_args():   # benchmarks / captures: graphics=quality
		if arg.begins_with("graphics=") and GRAPHICS.has(arg.substr(9)):
			graphics = arg.substr(9)
	apply()


static func save_all() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "master", master)
	c.set_value("controls", "sensitivity", sensitivity)
	c.set_value("debug", "dev_menu", dev_menu)
	c.set_value("video", "graphics", graphics)
	c.set_value("gameplay", "track_hints", track_hints)
	c.save(PATH)


static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.0001)))


## Renderer-wide parts of the preset. Scene parts (SSAO, forest shadow proxies) are read by
## AtmosphereRig / ForestScatter through the helpers below.
static func apply_graphics(vp: Viewport) -> void:
	var q := graphics == "quality"
	RenderingServer.directional_shadow_atlas_set_size(4096 if q else 2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH if graphics != "performance" else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	if vp != null:
		match graphics:
			"quality":
				vp.msaa_3d = Viewport.MSAA_4X
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			"balanced":
				vp.msaa_3d = Viewport.MSAA_2X
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			_:
				vp.msaa_3d = Viewport.MSAA_DISABLED
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA


static func ssao_enabled() -> bool:
	return graphics != "performance"


static func forest_shadow_proxies() -> bool:
	return graphics == "performance"
