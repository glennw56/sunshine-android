extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.set_environment("MINIGOLF_BOT", "1")
	var packed := load("res://scenes/minigolf/course.tscn") as PackedScene
	var course := packed.instantiate()
	root.add_child(course)
	current_scene = course
	var results: Array = await course.round_finished
	for row in results:
		if int(row.get("strokes", 0)) > 0:
			print("ONE ", row)
	quit(0)
