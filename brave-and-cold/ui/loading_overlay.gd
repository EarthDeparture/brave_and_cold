class_name LoadingOverlay
extends CanvasLayer
## M5: keeps the menu's loading screen alive across change_scene and drives a real progress
## bar from the world build. The menu hands over its backdrop, grade, snow and loading page
## (reparented here, so the look is identical); game_world reports stages through
## LoadingOverlay.report() and awaits a frame between them, so this layer renders and the
## snow keeps falling while the valley builds. (No preload of game_world here: that would
## pull the world's preloaded assets into menu start-up.)

const TIMEOUT_S := 240.0
## Share of the bar for loading the world scene itself (threaded, before game_world._ready);
## the world's own 0..1 build stages map onto the rest. Measured: scene ~3.9 s of ~17 s headless.
const WORLD_BASE := 0.2

var bar: ColorRect            # fill, width driven by progress
var bar_w := 420.0
var stage_label: Label
var frac := 0.0
var shown := 0.0
var label := ""
var finished := false
var _born_ms := 0
var _drift_node: Control
static var current: LoadingOverlay
static var log_stages: Array = []     # [label, frac, ms since start] for tests / timing


func _init() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "LoadingOverlay"


## Moves `nodes` (in order) from the menu into a new overlay on the tree root.
static func adopt(tree: SceneTree, nodes: Array, fill: ColorRect, fill_w: float, stage: Label, drift: Control) -> LoadingOverlay:
	var o := LoadingOverlay.new()
	var holder := Control.new(); holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(holder)
	tree.root.add_child(o)
	for n: Node in nodes:
		if n == null or not is_instance_valid(n): continue
		n.reparent(holder, false)
	o.bar = fill; o.bar_w = fill_w; o.stage_label = stage; o._drift_node = drift
	o._born_ms = Time.get_ticks_msec()
	log_stages.clear()
	current = o
	if drift != null:   # the menu's push-in tween died with the menu; keep the camera breathing
		o.create_tween().tween_property(drift, "scale", drift.scale * 1.03, 40.0).set_trans(Tween.TRANS_SINE)
	return o


## Called by the world build. Safe with no overlay (tests, autostart without the menu).
static func report(f: float, text: String) -> void:
	if current != null and is_instance_valid(current): current.set_progress(WORLD_BASE + f * (1.0 - WORLD_BASE), text)


func set_progress(f: float, text: String) -> void:
	frac = clampf(maxf(f, frac), 0.0, 1.0)
	label = text
	log_stages.append([text, frac, Time.get_ticks_msec() - _born_ms])
	if stage_label != null: stage_label.text = text.to_upper()
	if frac >= 1.0: finished = true


var _shot_dir := ""
var _shot_n := 0
var _shot_label := "-"
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("loadshot="): _shot_dir = a.substr(9)


func _process(delta: float) -> void:
	if _shot_dir != "" and label != _shot_label:   # debug: one frame per stage, as drawn
		_shot_label = label; _shot_n += 1
		get_viewport().get_texture().get_image().save_png("%s/load_%02d.png" % [_shot_dir, _shot_n])
	# Ease toward the reported value; never lag far behind it (stages are seconds apart).
	shown = move_toward(shown, frac, delta * 1.2)
	shown = maxf(shown, frac - 0.15)
	if bar != null: bar.size.x = bar_w * shown
	var age := (Time.get_ticks_msec() - _born_ms) / 1000.0
	if (finished and shown >= 0.999) or age > TIMEOUT_S:
		_close()


func _close() -> void:
	if is_queued_for_deletion() or process_mode == Node.PROCESS_MODE_DISABLED: return
	process_mode = Node.PROCESS_MODE_DISABLED
	if current == self: current = null
	var holder := get_child(0) as Control
	var tw := holder.create_tween()
	tw.tween_property(holder, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(queue_free)
	# the tween must run while this layer is disabled
	holder.process_mode = Node.PROCESS_MODE_ALWAYS
