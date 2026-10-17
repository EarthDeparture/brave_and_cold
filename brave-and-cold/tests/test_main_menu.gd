extends SceneTree
## Title screen: current-game backdrops load and crossfade, every page opens and closes,
## and New Game asks before replacing an existing save. Never writes or deletes the save,
## never starts the game.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func run() -> void:
	# Headless root is 1152x1152; force the project's 16:9 base so layout checks mean something.
	root.size = Vector2i(1152, 648)
	var m: Control = (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(m)
	for i in 5: await process_frame
	check(m._layers.size() == 3 and m._layers.filter(func(l: TextureRect) -> bool: return l.modulate.a > 0.99).size() == 1, "three backdrops, one showing")
	var before: int = m._cur
	m._show_backdrop((before + 1) % 3)
	check(m._cur == (before + 1) % 3 and m._layers[(before + 1) % 3].modulate.a == 1.0, "backdrops crossfade to the next scene")
	var labels: Array = m._items.map(func(b: Button) -> String: return b.text)
	check(labels.has("NEW GAME") and labels.has("OPTIONS") and labels.has("CONTROLS") and labels.has("QUIT"), "menu items: %s" % str(labels))
	check(labels.has("CONTINUE") == SaveGame.exists(), "Continue only when a save exists")
	if SaveGame.exists():
		var note_found := false
		for c in m._main.get_children():
			if c is MarginContainer: note_found = true
		check(note_found, "Continue shows the save's day / time")
	m._show_controls()
	check(m._controls.visible and not m._main.visible, "Controls page opens")
	check(m.BINDS.size() >= 12, "controls list the real bindings (%d)" % m.BINDS.size())
	await process_frame; await process_frame
	var vis := Rect2(Vector2.ZERO, Vector2(1152, 648))
	var back_b: Button = null
	for b in m._controls.find_children("*", "Button", true, false): back_b = b
	check(back_b != null and vis.encloses(back_b.get_global_rect()), "Controls Back fits on screen (%s in %s)" % [str(back_b.get_global_rect() if back_b else null), str(vis)])
	check(MenuStyle.bundled(), "bundled OFL fonts present")
	# UI sounds: hover once per focus move, throttled; press plays a click; Back plays back.
	MenuStyle.quiet_until_ms = 0; MenuStyle.played.clear()
	m._show_main()
	var items: Array = m._items
	MenuStyle.played.clear()
	await create_timer(0.25).timeout
	items[1].grab_focus()
	items[2].grab_focus()   # within 80 ms: throttled
	check(MenuStyle.played.count("hover") == 1, "hover ticks once for a fast sweep (%s)" % str(MenuStyle.played))
	await create_timer(0.12).timeout
	items[3].grab_focus()
	check(MenuStyle.played.count("hover") == 2, "hover ticks again after the gap")
	for k in MenuStyle.UI_SOUNDS: check(ResourceLoader.exists(MenuStyle.UI_SOUNDS[k][0]), "ui sound asset: " + k)
	var tf := MenuStyle.title_font() as FontVariation
	check(tf != null and tf.base_font is FontFile, "title uses the bundled font file, not a system font")
	check(FileAccess.file_exists("res://assets/fonts/Cormorant_Garamond/OFL.txt") and FileAccess.file_exists("res://assets/fonts/Barlow_Semi_Condensed/OFL.txt"), "font licences ship beside the fonts")
	m._show_main()
	check(m._main.visible and not m._controls.visible, "and returns")
	m._show_options()
	check(m._options.visible and not m._main.visible, "Options page opens")
	m._options._back()
	check(m._main.visible and not m._options.visible, "Options Back returns")
	if SaveGame.exists():
		m._new_game()
		check(m._confirm.visible and not m._starting, "New Game with a save asks first, starts nothing")
		m._show_main()
		check(not m._confirm.visible and m._main.visible, "Back from the confirm keeps the save")
	m.queue_free(); await process_frame
	print("MAIN_MENU_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
