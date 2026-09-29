@tool
extends RefCounted
## rename_file scans res:// for class/autoload member references.
## Explicit owners and typed receivers are supported; dynamic receivers are not.
## rename_source retains the original file-local lexical behavior.

const KEYWORDS := [
	"if", "elif", "else", "for", "while", "break", "continue", "pass",
	"return", "match", "when", "as", "assert", "await", "breakpoint",
	"class", "class_name", "const", "enum", "extends", "func", "in", "is",
	"namespace", "preload", "self", "signal", "static", "super", "trait",
	"var", "void", "yield", "and", "or", "not", "true", "false", "null",
	"PI", "TAU", "INF", "NAN",
]


## Returns {error, message, replacements, source, files} on a changed rename.
## Validation and project reads finish before writing; write errors may leave
## earlier files updated. Callers should review the changed files.
static func rename_file(script_path: String, old_name: String, new_name: String) -> Dictionary:
	if script_path.get_extension() != "gd":
		return _failure(ERR_INVALID_PARAMETER, "Expected a .gd script path.")
	var file := FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		return _failure(FileAccess.get_open_error(), "Cannot read script.")
	var source := file.get_as_text()
	file.close()
	var result := rename_source(source, old_name, new_name)
	if result.error != OK or result.replacements == 0:
		return result
	var edits := {script_path: result.source}
	var code := _code_only(source)
	if script_path.begins_with("res://") and not _matches(code, "(?m)^(?:@[^\\n]*?[ \t]+)*(?:static\\s+)?(?:var|const|func|signal)\\s+" + old_name + "\\b").is_empty():
		var owners: Array[String] = []
		for declaration in _matches(code, "(?m)^class_name\\s+(\\w+)"):
			owners.append(declaration.get_string(1))
		for property in ProjectSettings.get_property_list():
			var key: String = property.name
			if key.begins_with("autoload/") and str(ProjectSettings.get_setting(key)).trim_prefix("*") == script_path:
				owners.append(key.trim_prefix("autoload/"))
		var paths: Array[String] = []
		var scan_error := _scripts("res://", paths)
		if scan_error != OK:
			return _failure(scan_error, "Cannot scan project scripts.")
		for path in paths:
			if path == script_path:
				continue
			var input := FileAccess.open(path, FileAccess.READ)
			if input == null:
				return _failure(FileAccess.get_open_error(), "Cannot read " + path)
			var original := input.get_as_text()
			input.close()
			var update := _references(original, owners, old_name, new_name)
			if update.replacements > 0:
				edits[path] = update.source
				result.replacements += update.replacements
	result["files"] = edits.keys()
	for path in edits:
		file = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return _failure(FileAccess.get_open_error(), "Cannot write " + path)
		file.store_string(edits[path])
		file.flush()
		var write_error := file.get_error()
		file.close()
		if write_error != OK:
			return _failure(write_error, "Cannot finish writing " + path)
	return result


static func _scripts(directory: String, paths: Array[String]) -> Error:
	var dir := DirAccess.open(directory)
	if dir == null:
		return DirAccess.get_open_error()
	for filename in dir.get_files():
		if filename.get_extension() == "gd":
			paths.append(directory.path_join(filename))
	for child in dir.get_directories():
		if child.begins_with("."):
			continue
		var error := _scripts(directory.path_join(child), paths)
		if error != OK:
			return error
	return OK


static func _matches(source: String, pattern: String) -> Array[RegExMatch]:
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex.search_all(source)


# Mask comments and strings, preserving offsets and line boundaries.
static func _code_only(source: String) -> String:
	var output := ""
	var cursor := 0
	while cursor < source.length():
		var start := cursor
		var character := source[cursor]
		if character == "#":
			while cursor < source.length() and source[cursor] != "\n":
				cursor += 1
		elif character == "\"" or character == "'":
			var delimiter := character
			if source.substr(cursor, 3) == character.repeat(3):
				delimiter = character.repeat(3)
			cursor += delimiter.length()
			while cursor < source.length():
				if source[cursor] == "\\":
					cursor = mini(cursor + 2, source.length())
				elif source.substr(cursor, delimiter.length()) == delimiter:
					cursor += delimiter.length()
					break
				else:
					cursor += 1
		else:
			output += character
			cursor += 1
			continue
		for index in range(start, cursor):
			output += "\n" if source[index] == "\n" else " "
	return output


# Explicit global owners and typed receivers are statically identifiable.
# Bare names in other scripts and dynamically obtained receivers are untouched.
static func _references(source: String, owners: Array[String], old_name: String, new_name: String) -> Dictionary:
	var code := _code_only(source)
	var members := {}
	# Collect members first: declarations may follow a method using them.
	for declaration in _matches(code, "(?m)^(?:@[^\\n]*?[ \t]+)*(?:var|const)[ \t]+(\\w+)(?:[ \t]*:[ \t]*(\\w+))?"):
		members[declaration.get_string(1)] = declaration.get_string(2) in owners
	var scopes: Array[Dictionary] = []
	var offsets: Array[int] = []
	var offset := 0
	for line in code.split("\n"):
		if line.strip_edges().is_empty():
			offset += line.length() + 1
			continue
		var indent := line.length() - line.strip_edges(true, false).length()
		while not scopes.is_empty() and indent <= int(scopes.back().indent):
			scopes.pop_back()
		var bindings := {}
		for declaration in _matches(line, "\\b(?:var|const|for)\\s+(\\w+)(?:\\s*:\\s*(\\w+))?"):
			bindings[declaration.get_string(1)] = declaration.get_string(2) in owners
		if "func " in line:
			for parameter in _matches(line, "[(,]\\s*(\\w+)\\s*(?::\\s*(\\w+))?"):
				bindings[parameter.get_string(1)] = parameter.get_string(2) in owners
		if indent > 0 or "func " in line:
			scopes.append({"indent": indent if "func " in line or line.strip_edges().begins_with("for ") else indent - 1, "bindings": bindings})
		for reference in _matches(line, "\\b(\\w+)\\s*\\.\\s*(" + old_name + ")\\b"):
			var receiver := reference.get_string(1)
			var resolved := receiver in owners
			if members.has(receiver):
				resolved = members[receiver]
			for scope in scopes:
				if scope.bindings.has(receiver):
					resolved = scope.bindings[receiver]
			var prefix := line.substr(0, reference.get_start()).strip_edges()
			if resolved and not prefix.ends_with("."):
				offsets.append(offset + reference.get_start(2))
		offset += line.length() + 1
	var output := source
	offsets.reverse()
	for position in offsets:
		output = output.substr(0, position) + new_name + output.substr(position + old_name.length())
	return {"source": output, "replacements": offsets.size()}


## Returns the edited source without touching disk, for preview and review.
## Preserves whitespace, line endings, comments, and single/triple quoted strings.
static func rename_source(source: String, old_name: String, new_name: String) -> Dictionary:
	if not _valid_name(old_name) or not _valid_name(new_name):
		return _failure(ERR_INVALID_PARAMETER, "Names must be non-keyword identifiers.")
	var pieces := PackedStringArray()
	var replacements := 0
	var cursor := 0
	while cursor < source.length():
		var start := cursor
		var character := source[cursor]
		if character == "#":
			while cursor < source.length() and source[cursor] != "\n":
				cursor += 1
		elif character == "\"" or character == "'":
			var delimiter := character
			if source.substr(cursor, 3) == character.repeat(3):
				delimiter = character.repeat(3)
			cursor += delimiter.length()
			while cursor < source.length():
				if source[cursor] == "\\":
					cursor = mini(cursor + 2, source.length())
				elif source.substr(cursor, delimiter.length()) == delimiter:
					cursor += delimiter.length()
					break
				else:
					cursor += 1
		elif _identifier_character(character):
			cursor += 1
			while cursor < source.length() and _identifier_character(source[cursor]):
				cursor += 1
			if source.substr(start, cursor - start) == old_name and old_name != new_name:
				pieces.append(new_name)
				replacements += 1
				continue
		else:
			cursor += 1
		pieces.append(source.substr(start, cursor - start))
	return {"error": OK, "message": "", "source": "".join(pieces), "replacements": replacements}


static func _identifier_character(character: String) -> bool:
	# Keep non-ASCII text attached so a match never replaces part of a word.
	# Prefixing permits digits in the remainder of an identifier.
	return character.unicode_at(0) >= 128 or ("_" + character).is_valid_identifier()


static func _valid_name(value: String) -> bool:
	return value.is_valid_identifier() and value not in KEYWORDS


static func _failure(error: int, message: String) -> Dictionary:
	return {"error": error, "message": message, "replacements": 0}
