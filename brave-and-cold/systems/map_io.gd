class_name MapIO
extends RefCounted
## Loads raw map rasters that ship as plain files (data/maps is .gdignore'd so Godot does not import them) - works in editor and exported builds.


static func load_png(path: String) -> Image:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_error("MapIO: cannot read " + path)
		return null
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		push_error("MapIO: bad png " + path)
		return null
	return img
