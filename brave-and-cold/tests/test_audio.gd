extends SceneTree
## Check PCM source samples and imported duration/loop metadata. QOA bytes are
## compressed frames, never signed PCM samples (AudioStreamWAV documentation).
var fails := 0
func check(ok: bool, msg: String) -> void:
	print(("PASS " if ok else "FAIL ")+msg)
	if not ok: fails+=1
func inspect(sound: AudioStreamWAV, id: String) -> void:
	check(sound!=null and sound.format==AudioStreamWAV.FORMAT_16_BITS,id+" has measurable PCM source")
	if sound==null or sound.format!=AudioStreamWAV.FORMAT_16_BITS:return
	var bytes := sound.data
	var n := bytes.size()/2
	var peak := 0.0
	var rms := 0.0
	for i in n:
		var v := float(bytes.decode_s16(i*2))/32768.0
		peak=maxf(peak,absf(v));rms+=v*v
	rms=sqrt(rms/n)
	check(peak>.3 and peak<1.0,"%s peak %.3f"%[id,peak])
	check(rms>.01,"%s rms %.3f"%[id,rms])
	var first := float(bytes.decode_s16(0))/32768.0
	var last := float(bytes.decode_s16((n-1)*2))/32768.0
	if sound.loop_mode==AudioStreamWAV.LOOP_FORWARD:
		check(absf(first-last)<.15,"%s source loop seam %.4f"%[id,absf(first-last)])
	else:
		check(absf(last)<.05,id+" ends quietly")
func _init() -> void:
	for id in ["wind","fire","gunshot","thud","groan","howl","growl","step00","step11","step22"]:
		var runtime := Sfx.get_stream(id)
		var pcm := runtime
		if runtime.format!=AudioStreamWAV.FORMAT_16_BITS:
			pcm=AudioStreamWAV.load_from_file(Sfx.REC_DIR+id+".wav",{"compress/mode":0})
			if pcm==null:check(false,id+" source loading");continue
			pcm.loop_mode=runtime.loop_mode
			check(absf(pcm.get_length()-runtime.get_length())<.002,id+" imported duration matches source")
			if runtime.loop_mode==AudioStreamWAV.LOOP_FORWARD:
				check(runtime.loop_end==roundi(runtime.get_length()*runtime.mix_rate),id+" compressed loop uses sample frame count")
		inspect(pcm,id)
	for id in ["step_wood","step_ice","timber_creak","window_rattle"]:
		var path: String = "res://assets/environment_detail/audio/"+id+".wav"
		var runtime := load(path) as AudioStreamWAV
		var pcm := AudioStreamWAV.load_from_file(path,{"compress/mode":0})
		check(runtime!=null and pcm!=null and absf(runtime.get_length()-pcm.get_length())<.002,id+" imported duration matches source")
		inspect(pcm,id)
	print("AUDIO_TESTS failures=",fails)
	quit(1 if fails>0 else 0)
