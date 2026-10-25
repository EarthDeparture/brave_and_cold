extends SceneTree
## Run from the project directory:
## godot --headless --script tests/run_tests.gd

const RenameTests = preload("res://tests/test_rename_variable.gd")


func _init() -> void:
	# A missing return (for example after a runtime error) must fail the run.
	var failures: Variant = RenameTests.new().run()
	if typeof(failures) != TYPE_INT:
		push_error("Rename tests did not complete.")
		quit(1)
	elif failures > 0:
		print("Rename tests failed: %d checks." % failures)
		quit(1)
	else:
		print("Renamer tests passed.")
		quit(0)
