extends RefCounted

const Renamer = preload("res://addons/dev_tools/rename_variable.gd")
var failures := 0


func run() -> Variant:
	failures = 0
	var local_source := "func hit():\n\tvar health = 10\n\thealth -= 1\n\treturn health\n"
	var local_expected := "func hit():\n\tvar energy = 10\n\tenergy -= 1\n\treturn energy\n"
	var local_result := Renamer.rename_source(local_source, "health", "energy")
	_check(local_result.error == OK and local_result.source == local_expected, "local variable declaration and usages")
	_check(local_result.replacements == 3, "local variable replacement count")
	var source := "@export var health: int = 10\r\nfunc hit(health: int):\r\n\tvar health_copy = health\r\n\tself.health -= health\r\n"
	var expected := "@export var energy: int = 10\r\nfunc hit(energy: int):\r\n\tvar health_copy = energy\r\n\tself.energy -= energy\r\n"
	var result := Renamer.rename_source(source, "health", "energy")
	_check(result.error == OK and result.source == expected, "declarations, parameters, usages, CRLF")
	_check(result.replacements == 5, "replacement count")
	var protected := "# health\nvar text = \"health \\\" health\"\nvar other = 'health \\' health'\n"
	protected += "var multi = \"\"\"health\n# health\n\"\"\"\nvar single = '''health\nhealth'''\n"
	protected += "var path = ^\"health\"\nvar key = &\"health\"\n"
	result = Renamer.rename_source(protected + "var health = health # health", "health", "energy")
	_check(result.source == protected + "var energy = energy # health", "strings, escapes, multiline strings, comments")
	result = Renamer.rename_source("health health2 _health health_copy myhealth healthé", "health", "energy")
	_check(result.source == "energy health2 _health health_copy myhealth healthé", "identifier boundaries")
	_check(result.error == OK and result.replacements == 1, "only whole identifiers are replaced")
	_check(Renamer.rename_source("var health", "health", "health").replacements == 0, "same name")
	var unchanged := "var other = 10\nfunc read():\n\treturn other\n"
	result = Renamer.rename_source(unchanged, "health", "energy")
	_check(result.error == OK and result.source == unchanged and result.replacements == 0, "non-matching identifiers leave source unchanged")
	for invalid in ["", "two words", "2name", "var", "if", "self"]:
		_check(Renamer.rename_source(source, "health", invalid).error == ERR_INVALID_PARAMETER, "invalid new name: " + invalid)
	_check(Renamer.rename_source(source, "", "energy").error == ERR_INVALID_PARAMETER, "invalid old name")
	_check(Renamer.rename_source("var health = 'health", "health", "energy").source == "var energy = 'health", "unterminated string")
	var path := "user://test_rename_variable.gd"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "create temporary script")
		return failures
	file.store_string(source)
	file.close()
	_check(Renamer.rename_file(path, "health", "if").error == ERR_INVALID_PARAMETER, "invalid file rename")
	_check(FileAccess.get_file_as_string(path) == source, "invalid rename leaves file untouched")
	_check(Renamer.rename_file(path, "health", "energy").error == OK, "file rename succeeds")
	_check(FileAccess.get_file_as_string(path) == expected, "file contents")
	_check(DirAccess.remove_absolute(path) == OK, "remove temporary script")
	_check(Renamer.rename_file(path, "health", "energy").error != OK, "missing file")
	_check(Renamer.rename_file("user://test.txt", "health", "energy").error == ERR_INVALID_PARAMETER, "wrong extension")
	return failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
