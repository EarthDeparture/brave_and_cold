class_name CreatureClips
extends RefCounted
## Recorded creature sounds dropped into res://assets/audio/creatures/<kind>/<event>_<anything>.(ogg|wav|mp3).
##   kind  = zombie | wolf | bear | deer
##   event = idle alert attack hurt death (zombie) / howl growl hurt death (wolf) / roar growl hurt death (bear) / snort hurt death (deer)
## The event is the file name up to the first digit, underscore or dash: "idle_03.ogg", "idle3.wav", "idle-b.ogg" are all "idle".
## Several files with the same event are variants, one is picked at random each time. A missing event falls back along CHAIN,
## and when nothing is found PICK returns null and the caller plays the procedural stand-in (Sfx), so the game works with zero files.

const ROOT := "res://assets/audio/creatures/"
const EXT := ["ogg", "wav", "mp3"]
const CHAIN := {
	"idle": ["idle", "groan", "moan"],
	"alert": ["alert", "scream", "shout", "idle"],
	"attack": ["attack", "growl", "snarl", "grunt"],
	"hurt": ["hurt", "pain", "yelp", "grunt"],
	"death": ["death", "die", "hurt"],
	"howl": ["howl"],
	"growl": ["growl", "snarl", "attack"],
	"roar": ["roar", "growl"],
	"snort": ["snort", "alert"],
}

static var _paths: Dictionary = {}    # kind -> {event -> [path]}
static var _streams: Dictionary = {}  # path -> AudioStream
static var _scanned := false


static func rescan() -> void:
	_paths.clear()
	_streams.clear()
	_scanned = true
	for kind in DirAccess.get_directories_at(ROOT):
		var ev: Dictionary = {}
		for f in DirAccess.get_files_at(ROOT + kind):
			var fn: String = f
			if fn.ends_with(".import"):
				fn = fn.trim_suffix(".import")
			elif fn.ends_with(".remap"):
				fn = fn.trim_suffix(".remap")
			if not (fn.get_extension().to_lower() in EXT):
				continue
			var e := event_of(fn)
			if e == "":
				continue
			var path: String = ROOT + kind + "/" + fn
			if not ev.has(e):
				ev[e] = []
			if not (ev[e] as Array).has(path):
				(ev[e] as Array).append(path)
		_paths[kind] = ev


static func event_of(file_name: String) -> String:
	var b := file_name.get_basename().to_lower()
	var out := ""
	for ch in b:
		if ch == "_" or ch == "-" or ch == " " or (ch >= "0" and ch <= "9"):
			break
		out += ch
	return out


## How many files are loaded for a kind (tests, debug).
static func count(kind: String) -> int:
	if not _scanned:
		rescan()
	var n := 0
	for e in (_paths.get(kind, {}) as Dictionary).values():
		n += (e as Array).size()
	return n


## A random recorded clip for this kind + event (following CHAIN), or null.
static func pick(kind: String, event: String) -> AudioStream:
	if not _scanned:
		rescan()
	var ev: Dictionary = _paths.get(kind, {})
	if ev.is_empty():
		return null
	for e: String in CHAIN.get(event, [event]):
		if ev.has(e):
			var arr: Array = ev[e]
			return _load(String(arr[randi() % arr.size()]))
	return null


static func _load(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path) as AudioStream
	else:
		# dropped in but not imported yet (editor not focused / headless): read the raw file so it still plays
		match path.get_extension().to_lower():
			"ogg":
				s = AudioStreamOggVorbis.load_from_file(path)
			"mp3":
				s = AudioStreamMP3.load_from_file(path)
			"wav":
				s = AudioStreamWAV.load_from_file(path)
	_streams[path] = s
	return s
