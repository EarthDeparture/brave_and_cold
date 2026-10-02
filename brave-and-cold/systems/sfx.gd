class_name Sfx
extends RefCounted
## Procedural sound synthesis (no audio assets yet). Streams are built once and cached.
## Placeholder quality: good enough to carry gameplay feedback, NOT final audio.

const RATE := 22050
static var _cache: Dictionary = {}


static func get_stream(id: String) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	var s: AudioStreamWAV
	match id:
		"wind": s = _wav(_wind(), true)
		"fire": s = _wav(_fire(), true)
		"gunshot": s = _wav(_gunshot())
		"thud": s = _wav(_thud())
		"groan": s = _wav(_groan())
		"howl": s = _wav(_howl())
		"grunt": s = _wav(_grunt())
		"zdeath": s = _wav(_zdeath())
		"yelp": s = _wav(_yelp())
		"roar": s = _wav(_roar())
		"snort": s = _wav(_snort())
		"growl": s = _wav(_growl())
		"chop": s = _wav(_chop())
		"crash": s = _wav(_crash())
		"rustle": s = _wav(_rustle())
		"slice": s = _wav(_slice())
		"glass": s = _wav(_glass())
		"hammer": s = _wav(_hammer())
		_:
			if id.begins_with("step"):
				s = _wav(_step(int(id.substr(4, 1)), int(id.substr(5, 1))))
			else:
				push_warning("Sfx: unknown " + id)
				s = _wav(PackedFloat32Array([0.0]))
	_cache[id] = s
	return s


static func _wav(d: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	var b := PackedByteArray()
	b.resize(d.size() * 2)
	for i in range(d.size()):
		b.encode_s16(i * 2, int(clampf(d[i], -1.0, 1.0) * 32000.0))
	w.data = b
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = d.size()
	return w


static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


static func _norm(s: PackedFloat32Array, peak: float) -> void:
	var m := 0.0001
	for v in s:
		m = maxf(m, absf(v))
	var k := peak / m
	for i in range(s.size()):
		s[i] *= k


## Crossfade the tail into the head so the buffer loops without a click.
static func _make_loop(s: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n := s.size() - fade
	var o := PackedFloat32Array()
	o.resize(n)
	for i in range(n):
		o[i] = s[i]
	for i in range(fade):
		var t := float(i) / float(fade)
		o[i] = s[i] * t + s[n + i] * (1.0 - t)
	return o


static func _wind() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var fade := int(0.8 * RATE)
	var s := _buf(8.0 + 0.8)
	var n := s.size() - fade
	var y1 := 0.0
	var y2 := 0.0
	var h1 := 0.0
	var h2 := 0.0
	var bp_lo := 0.0
	for i in range(s.size()):
		var t := float(i) / float(n)
		var x := rng.randf_range(-1.0, 1.0)
		y1 += 0.035 * (x - y1)
		y2 += 0.035 * (y1 - y2)
		h1 += 0.22 * (x - h1)
		bp_lo += 0.06 * (h1 - bp_lo)
		h2 = h1 - bp_lo  # band-ish hiss
		var gust := 0.55 + 0.3 * sin(TAU * t * 2.0) + 0.15 * sin(TAU * t * 5.0 + 1.3)
		s[i] = (y2 * 9.0 + h2 * 1.4 * (0.4 + 0.6 * gust)) * gust
	var o := _make_loop(s, fade)
	_norm(o, 0.7)
	return o


static func _fire() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var fade := int(0.6 * RATE)
	var rum := _buf(5.0 + 0.6)
	var y := 0.0
	for i in range(rum.size()):
		y += 0.04 * (rng.randf_range(-1.0, 1.0) - y)
		rum[i] = y
	var o := _make_loop(rum, fade)
	_norm(o, 0.22)
	var n := o.size()
	for e in range(75):
		var pos := rng.randi() % n
		var amp := rng.randf_range(0.15, 0.9)
		var decay := rng.randf_range(18.0, 70.0)
		var lp := 0.0
		var a := rng.randf_range(0.3, 0.9)
		for j in range(400):
			lp += a * (rng.randf_range(-1.0, 1.0) - lp)
			o[(pos + j) % n] += lp * amp * exp(-float(j) / decay) * 0.6
	_norm(o, 0.8)
	return o


static func _step(set_id: int, variant: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + set_id * 10 + variant
	var dur := 0.26 + 0.05 * set_id
	var s := _buf(dur)
	var a: float = [0.55, 0.3, 0.14][clampi(set_id, 0, 2)]
	var y := 0.0
	var crackle: float = [0.012, 0.007, 0.003][clampi(set_id, 0, 2)]
	var imp := 0.0
	for i in range(s.size()):
		var t := float(i) / float(s.size())
		var env := pow(1.0 - t, 2.2) * minf(1.0, float(i) / 60.0)
		y += a * (rng.randf_range(-1.0, 1.0) - y)
		if rng.randf() < crackle:
			imp = rng.randf_range(0.5, 1.0)
		imp *= 0.96
		var thump := sin(TAU * (55.0 - 25.0 * t) * float(i) / RATE) * exp(-t * 9.0) * (0.3 + 0.25 * set_id)
		s[i] = (y * 1.4 + imp * 0.9 * rng.randf_range(-1.0, 1.0) + thump) * env
	_norm(s, 0.75)
	return s


static func _gunshot() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var s := _buf(2.2)
	var lp1 := 0.0
	var lp2 := 0.0
	var ph := 0.0
	for i in range(s.size()):
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		lp1 += 0.12 * (x - lp1)
		lp2 += 0.03 * (x - lp2)
		ph += TAU * (40.0 + 90.0 * exp(-t / 0.04)) / RATE
		var crack := x * exp(-t / 0.006) * 1.0
		var boom := lp1 * exp(-t / 0.09) * 2.6
		var thump := sin(ph) * exp(-t / 0.14) * 1.1
		var tail := lp2 * exp(-t / 0.7) * 5.0 * minf(1.0, t * 12.0)
		s[i] = crack + boom + thump + tail
	_norm(s, 0.95)
	return s


## Window smashing: sharp hiss burst then falling glass tinkles.
static func _glass() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	var s := _buf(0.95)
	var lp := 0.0
	var rf := 3000.0
	var ra := 0.0
	var rph := 0.0
	for i in range(s.size()):
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		lp += 0.12 * (x - lp)
		var hp := x - lp
		if rng.randf() < 0.004 * exp(-t / 0.35):
			rf = rng.randf_range(2400.0, 6800.0)
			ra = rng.randf_range(0.3, 0.75)
			rph = 0.0
		rph += TAU * rf / RATE
		ra *= 0.9986
		s[i] = hp * exp(-t / 0.07) * 1.1 + sin(rph) * ra * 0.55 + lp * exp(-t / 0.03) * 0.6
	_norm(s, 0.85)
	return s


## Hammering nails: three sharp taps with a metallic ring.
static func _hammer() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 53
	var s := _buf(0.6)
	var lp := 0.0
	for i in range(s.size()):
		var t := float(i) / RATE
		var k := mini(int(t / 0.19), 2)
		var lt := t - float(k) * 0.19
		var x := rng.randf_range(-1.0, 1.0)
		lp += 0.3 * (x - lp)
		s[i] = (x - lp) * exp(-lt / 0.004) * 0.9 + sin(TAU * 1250.0 * lt) * exp(-lt / 0.025) * 0.7 + sin(TAU * 150.0 * lt) * exp(-lt / 0.05) * 0.8
	_norm(s, 0.85)
	return s


static func _thud() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var s := _buf(0.32)
	var lp := 0.0
	var ph := 0.0
	for i in range(s.size()):
		var t := float(i) / RATE
		lp += 0.2 * (rng.randf_range(-1.0, 1.0) - lp)
		ph += TAU * (60.0 + 70.0 * exp(-t / 0.05)) / RATE
		s[i] = sin(ph) * exp(-t / 0.07) + lp * exp(-t / 0.025) * 1.2
	_norm(s, 0.85)
	return s


static func _chop() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var s := _buf(0.28)
	var lp := 0.0
	var ph := 0.0
	for i in range(s.size()):
		var t := float(i) / RATE
		lp += 0.45 * (rng.randf_range(-1.0, 1.0) - lp)
		ph += TAU * (190.0 + 120.0 * exp(-t / 0.02)) / RATE
		s[i] = lp * exp(-t / 0.012) * 1.1 + sin(ph) * exp(-t / 0.06) * 0.8
	_norm(s, 0.85)
	return s


## Tree going over: wood crack impulses, then a swelling low rumble of branches.
static func _crash() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 43
	var s := _buf(1.5)
	var lp := 0.0
	var lp2 := 0.0
	var imp := 0.0
	for i in range(s.size()):
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		lp += 0.5 * (x - lp)
		lp2 += 0.05 * (x - lp2)
		if rng.randf() < 0.004 * exp(-t / 0.6):
			imp = rng.randf_range(0.5, 1.0)
		imp *= 0.93
		var swell := sin(PI * clampf(t / 1.4, 0.0, 1.0))
		s[i] = imp * rng.randf_range(-1.0, 1.0) * 0.9 + lp2 * swell * 5.0 + lp * swell * exp(-t / 0.5) * 0.2
	_norm(s, 0.8)
	return s


## Dry plants / cloth / leather: band-passed noise with a ragged envelope.
static func _rustle() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	var s := _buf(0.6)
	var y1 := 0.0
	var y2 := 0.0
	for i in range(s.size()):
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		y1 += 0.25 * (x - y1)
		y2 += 0.05 * (x - y2)
		var env := (0.55 + 0.45 * sin(TAU * 14.0 * t + sin(TAU * 3.0 * t) * 2.0)) * sin(PI * clampf(t / 0.6, 0.0, 1.0))
		s[i] = (y1 - y2) * env * 3.0
	_norm(s, 0.5)
	return s


## Knife through hide and meat: short swish plus a wet low click.
static func _slice() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 53
	var s := _buf(0.4)
	var lp := 0.0
	var wet := 0.0
	for i in range(s.size()):
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		lp += 0.3 * (x - lp)
		wet += 0.08 * (x - wet)
		var swish := (x - lp) * exp(-t / 0.1) * 0.5
		var click := wet * exp(-pow((t - 0.13) / 0.02, 2.0)) * 3.0
		s[i] = swish + click
	_norm(s, 0.6)
	return s


static func _groan() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var dur := 1.9
	var s := _buf(dur)
	var ph := 0.0
	var breath := 0.0
	for i in range(s.size()):
		var t := float(i) / RATE
		var f0 := 78.0 - 22.0 * (t / dur) + 5.0 * sin(TAU * 6.0 * t)
		ph += TAU * f0 / RATE
		var v := 0.0
		for k in range(1, 15):
			var fk := f0 * k
			var w := exp(-pow((fk - 520.0) / 260.0, 2.0)) + 0.55 * exp(-pow((fk - 1250.0) / 380.0, 2.0)) + 0.06
			v += sin(ph * k) * w / pow(float(k), 0.5)
		breath += 0.25 * (rng.randf_range(-1.0, 1.0) - breath)
		var rasp := 0.6 + 0.4 * sin(TAU * 27.0 * t)
		var env := pow(sin(PI * t / dur), 0.7) * (0.85 + 0.15 * sin(TAU * 2.3 * t))
		s[i] = (v * 0.35 + breath * 0.9 * rasp) * env
	_norm(s, 0.85)
	return s


static func _growl() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var dur := 1.3
	var s := _buf(dur)
	var ph := 0.0
	var br := 0.0
	for i in range(s.size()):
		var t := float(i) / RATE
		ph += TAU * (95.0 + 10.0 * sin(TAU * 4.0 * t)) / RATE
		br += 0.35 * (rng.randf_range(-1.0, 1.0) - br)
		var rasp := 0.5 + 0.5 * sin(TAU * 38.0 * t)
		var v := sin(ph) + 0.6 * sin(ph * 2.0) + 0.4 * sin(ph * 3.0)
		var env := pow(sin(PI * t / dur), 0.6)
		s[i] = (v * 0.4 * rasp + br * 0.7) * env
	_norm(s, 0.8)
	return s


static func _howl() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var dur := 3.6
	var s := _buf(dur)
	var ph := 0.0
	var br := 0.0
	for i in range(s.size()):
		var t := float(i) / RATE
		var u := t / dur
		var f := 330.0 + 230.0 * pow(sin(PI * minf(u * 1.25, 1.0) * 0.5 + 0.0), 1.5) - 90.0 * maxf(0.0, u - 0.7) / 0.3
		f += (3.0 + 9.0 * u) * sin(TAU * 5.4 * t)
		ph += TAU * f / RATE
		br += 0.3 * (rng.randf_range(-1.0, 1.0) - br)
		var v := sin(ph) + 0.35 * sin(ph * 2.0) + 0.14 * sin(ph * 3.0)
		var env := pow(sin(PI * u), 0.55)
		s[i] = (v * 0.5 + br * 0.08) * env
	_norm(s, 0.8)
	return s


## Shared vocal synth: harmonic series shaped by one formant, f0 glides a -> b, plus breath noise, asymmetric envelope.
static func _vocal(seed_v: int, dur: float, fa: float, fb: float, formant: float, breath: float, rasp_hz: float, attack: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var s := _buf(dur)
	var ph := 0.0
	var br := 0.0
	for i in range(s.size()):
		var t := float(i) / RATE
		var u := t / dur
		var f0 := lerpf(fa, fb, u) + 3.0 * sin(TAU * 6.0 * t)
		ph += TAU * f0 / RATE
		var v := 0.0
		for k in range(1, 13):
			var fk := f0 * float(k)
			var w := exp(-pow((fk - formant) / (formant * 0.5), 2.0)) + 0.05
			v += sin(ph * float(k)) * w / pow(float(k), 0.45)
		br += 0.3 * (rng.randf_range(-1.0, 1.0) - br)
		var rasp := 1.0 - 0.5 * (0.5 + 0.5 * sin(TAU * rasp_hz * t))
		var env := minf(1.0, u / attack) * pow(maxf(0.0, 1.0 - u), 0.8)
		s[i] = (v * 0.3 + br * breath * rasp) * env
	_norm(s, 0.85)
	return s


static func _grunt() -> PackedFloat32Array:
	return _vocal(61, 0.5, 95.0, 60.0, 480.0, 0.7, 31.0, 0.08)


static func _zdeath() -> PackedFloat32Array:
	return _vocal(62, 1.5, 105.0, 32.0, 420.0, 0.8, 22.0, 0.05)


static func _yelp() -> PackedFloat32Array:
	return _vocal(63, 0.45, 760.0, 430.0, 1500.0, 0.12, 14.0, 0.04)


static func _roar() -> PackedFloat32Array:
	return _vocal(64, 1.7, 78.0, 58.0, 380.0, 0.95, 36.0, 0.12)


## Deer alarm: a short breathy blow through the nose.
static func _snort() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 65
	var s := _buf(0.4)
	var y1 := 0.0
	var y2 := 0.0
	for i in range(s.size()):
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		y1 += 0.35 * (x - y1)
		y2 += 0.06 * (x - y2)
		s[i] = (y1 - y2) * exp(-t / 0.09) * minf(1.0, t / 0.02) * 2.0
	_norm(s, 0.7)
	return s
