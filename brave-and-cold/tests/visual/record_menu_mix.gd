extends SceneTree
## Records the real menu mix (wind bed + UI sounds, engine volumes) to res://shots/menu_mix.wav
## so the levels can be measured (tools/audio/analyze_ui_sounds.py --mix). Event times are
## printed so the analysis can be matched to hover / click / back / start.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var rec := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, rec, 0)
	rec.set_recording_active(true)
	var t0 := Time.get_ticks_msec()
	var m: Control = (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await create_timer(3.2).timeout          # wind fades in to its -16 dB bed by ~2.5 s
	MenuStyle.quiet_until_ms = 0
	var items: Array = m._items
	var marks := []
	for i in [1, 2, 3]:
		items[i].grab_focus(); marks.append(["hover", Time.get_ticks_msec() - t0])
		await create_timer(0.35).timeout
	MenuStyle.sound(m, "click"); marks.append(["click", Time.get_ticks_msec() - t0])
	await create_timer(0.6).timeout
	MenuStyle.sound(m, "back"); marks.append(["back", Time.get_ticks_msec() - t0])
	await create_timer(0.6).timeout
	MenuStyle.sound(m, "start"); marks.append(["start", Time.get_ticks_msec() - t0])
	await create_timer(0.9).timeout
	rec.set_recording_active(false)
	var wav := rec.get_recording()
	if wav == null:
		print("RECORD empty"); quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	wav.save_to_wav(ProjectSettings.globalize_path("res://shots/menu_mix.wav"))
	print("RECORD ok len=%.2f s marks=%s" % [wav.get_length(), str(marks)])
	quit(0)
