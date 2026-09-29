@tool
extends RefCounted
## File-local lexical renamer. Call rename_file(path, old_name, new_name).
## All matching identifier tokens are renamed, including shadowed names and
## member accesses. This utility does not resolve scopes or other scripts.

const KEYWORDS := [
	"if", "elif", "else", "for", "while", "break", "continue", "pass",
	"return", "match", "when", "as", "assert", "await", "breakpoint",
	"class", "class_name", "const", "enum", "extends", "func", "in", "is",
	"namespace", "preload", "self", "signal", "static", "super", "trait",
	"var", "void", "yield", "and", "or", "not", "true", "false", "null",
	"PI", "TAU", "INF", "NAN",
]


## Returns {error, message, replacements}; failed validation never writes a file.
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
	file = FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		return _failure(FileAccess.get_open_error(), "Cannot write script.")
	file.store_string(result.source)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return _failure(write_error, "Cannot finish writing script.")
	return result


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
