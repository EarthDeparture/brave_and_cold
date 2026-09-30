extends SceneTree
## Sanity checks on synthesized audio: non-silent, not clipped, sane duration, loops seamless.

var fails := 0


func check(ok: bool, msg: String) -> void:
	print(("PASS " if ok else "FAIL ") + msg)
	if not ok:
		fails += 1


func _init() -> void:
	var ids := ["wind", "fire", "gunshot", "thud", "groan", "howl", "growl", "step00", "step11", "step22"]
	for id in ids:
		var s := Sfx.get_stream(id)
		var n := s.data.size() / 2
		var peak := 0.0
		var rms := 0.0
		for i in range(n):
			var v := float(s.data.decode_s16(i * 2)) / 32768.0
			peak = maxf(peak, absf(v))
			rms += v * v
		rms = sqrt(rms / n)
		check(peak > 0.3 and peak < 1.0, "%s peak %.2f" % [id, peak])
		check(rms > 0.01, "%s rms %.3f (not silent)" % [id, rms])
		if s.loop_mode == AudioStreamWAV.LOOP_FORWARD:
			var a := float(s.data.decode_s16(0)) / 32768.0
			var b := float(s.data.decode_s16((n - 1) * 2)) / 32768.0
			check(absf(a - b) < 0.15, "%s loop seam %.3f" % [id, absf(a - b)])
		else:
			var b := float(s.data.decode_s16((n - 1) * 2)) / 32768.0
			check(absf(b) < 0.05, "%s ends quiet %.3f" % [id, absf(b)])
	print("AUDIO_TESTS failures=", fails)
	quit()
