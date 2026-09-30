class_name Settings
extends RefCounted
## Persistent user settings (user://settings.cfg).

const PATH := "user://settings.cfg"
static var master := 0.8        # 0..1
static var sensitivity := 0.002  # radians per pixel
static var _loaded := false


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var c := ConfigFile.new()
	if c.load(PATH) == OK:
		master = float(c.get_value("audio", "master", master))
		sensitivity = float(c.get_value("controls", "sensitivity", sensitivity))
	apply()


static func save_all() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "master", master)
	c.set_value("controls", "sensitivity", sensitivity)
	c.save(PATH)


static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.0001)))
