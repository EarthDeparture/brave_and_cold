class_name IceField
extends RefCounted
## Walkable ice: the water mask + authored surface level (same data WaterSurfaces draws). ice_at() = surface y, or NAN off the water.

var mask: Image
var buf: PackedByteArray
var n := 2048
var half := 1024
var span := 1.0


func load_map(dir: String = "res://data/maps/valley_b") -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(dir + "/water.json"))
	span = float(data["z_max_m"]) - float(data["z_min_m"])
	n = int(data["size_m"])
	half = n / 2
	mask = MapIO.load_png(dir + "/water_mask.png")
	mask.convert(Image.FORMAT_L8)
	var f := FileAccess.open(dir + "/water_level.r16", FileAccess.READ)
	buf = f.get_buffer(n * n * 2)
	f.close()


func ice_at(x: float, z: float) -> float:
	var px := int(floorf(x)) + half
	var py := int(floorf(z)) + half
	if px < 0 or py < 0 or px >= n or py >= n:
		return NAN
	if mask.get_pixel(px, py).r < 0.5:
		return NAN
	return float(buf.decode_u16((py * n + px) * 2)) / 65535.0 * span


## Metres from (x,z) to the nearest shore along 16 rays (capped): how far out on the ice a spot is.
func clearance(x: float, z: float, cap: float = 40.0) -> float:
	var best := cap
	for a in 16:
		var d := Vector2.from_angle(float(a) * TAU / 16.0)
		var r := 2.0
		while r < best:
			if is_nan(ice_at(x + d.x * r, z + d.y * r)):
				best = r
				break
			r += 2.0
	return best