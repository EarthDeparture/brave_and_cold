class_name Footprints
extends Node3D
## Pooled projected-decal footprints. Ring buffer of POOL decals; each fades over LIFE_S seconds (matches SnowField trample life).

const POOL := 300
const LIFE_S := 240.0

var _decals: Array[Decal] = []
var _age: PackedFloat32Array = PackedFloat32Array()
var _next := 0
var _left := false
var _acc := 0.0


func _ready() -> void:
	var tex := _make_boot_texture()
	for i in range(POOL):
		var d := Decal.new()
		d.texture_albedo = tex
		d.size = Vector3(0.20, 1.5, 0.45)
		d.upper_fade = 0.3
		d.lower_fade = 0.3
		d.cull_mask = 1
		d.visible = false
		d.distance_fade_enabled = true
		d.distance_fade_begin = 50.0
		d.distance_fade_length = 15.0
		add_child(d)
		_decals.append(d)
		_age.append(LIFE_S)


func step(x: float, y: float, z: float, yaw: float, tier: int) -> void:
	if tier <= 0:
		return
	var side := 0.13 if _left else -0.13
	_left = not _left
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var d := _decals[_next]
	d.global_position = Vector3(x, y, z) + right * side
	d.rotation = Vector3(0.0, yaw, 0.0)
	var s := 1.0 + 0.12 * tier
	d.size = Vector3(0.20 * s, 1.5, 0.45 * s)
	d.modulate = Color(1, 1, 1, 0.45 + 0.06 * tier)
	d.visible = true
	_age[_next] = 0.0
	_next = (_next + 1) % POOL


func _process(delta: float) -> void:
	_acc += delta
	if _acc < 0.5:
		return
	var dt := _acc
	_acc = 0.0
	for i in range(POOL):
		if _age[i] >= LIFE_S:
			continue
		_age[i] += dt
		var d := _decals[i]
		if _age[i] >= LIFE_S:
			d.visible = false
		else:
			var f := 1.0 - _age[i] / LIFE_S
			var base := d.modulate
			d.modulate = Color(base.r, base.g, base.b, minf(base.a, f * 0.9))


## 32x64 boot print: forefoot bulge, narrow arch, heel; subtle tread; cool tint.
static func _make_boot_texture() -> ImageTexture:
	var w := 32
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var u := absf((x + 0.5) / w * 2.0 - 1.0)
			var v := (y + 0.5) / h * 2.0 - 1.0
			var w1 := 0.85 * sqrt(maxf(1.0 - pow((v + 0.45) / 0.5, 2.0), 0.0))
			var w2 := 0.62 * sqrt(maxf(1.0 - pow((v - 0.6) / 0.36, 2.0), 0.0))
			var arch := 0.42 if (v > -0.1 and v < 0.3) else 0.0
			var ww := maxf(maxf(w1, w2), arch)
			var a := 0.0
			if ww > 0.0:
				a = 1.0 - smoothstep(ww * 0.8, ww, u)
			var tread := 0.93 + 0.07 * sin(y * 1.6)
			img.set_pixel(x, y, Color(0.50 * tread, 0.56 * tread, 0.74 * tread, a))
	return ImageTexture.create_from_image(img)
