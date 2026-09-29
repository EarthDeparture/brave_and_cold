extends SceneTree

const Renamer = preload("res://addons/dev_tools/rename_variable.gd")
var failures := 0


func _init() -> void:
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
	_check(Renamer.rename_source("var health", "health", "health").replacements == 0, "same name")
	_check(Renamer.rename_source("var other", "health", "energy").replacements == 0, "absent name")
	for invalid in ["", "two words", "2name", "var", "if", "self"]:
		_check(Renamer.rename_source(source, "health", invalid).error == ERR_INVALID_PARAMETER, "invalid new name: " + invalid)
	_check(Renamer.rename_source(source, "", "energy").error == ERR_INVALID_PARAMETER, "invalid old name")
	_check(Renamer.rename_source("var health = 'health", "health", "energy").source == "var energy = 'health", "unterminated string")
	var path := "user://test_rename_variable.gd"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	_check(Renamer.rename_file(path, "health", "if").error == ERR_INVALID_PARAMETER, "invalid file rename")
	_check(FileAccess.get_file_as_string(path) == source, "invalid rename leaves file untouched")
	_check(Renamer.rename_file(path, "health", "energy").error == OK, "file rename succeeds")
	_check(FileAccess.get_file_as_string(path) == expected, "file contents")
	DirAccess.remove_absolute(path)
	_check(Renamer.rename_file(path, "health", "energy").error != OK, "missing file")
	_check(Renamer.rename_file("user://test.txt", "health", "energy").error == ERR_INVALID_PARAMETER, "wrong extension")
	if failures == 0:
		print("Renamer tests passed.")
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
