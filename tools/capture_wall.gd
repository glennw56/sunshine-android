extends SceneTree
## Ground-level shots of each perimeter wall from inside the patio,
## plus a corner and a wide view of the north gate.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var dir := "/opt/cursor/artifacts"
	DirAccess.make_dir_recursive_absolute(dir)
	if change_scene_to_file("res://scenes/explore/explore_test.tscn") != OK:
		push_error("CAPTURE FAIL explore_test")
		quit(1)
		return
	for _i in 12:
		await process_frame
	var world := current_scene.get_node("Explore/World") as Node3D
	for child in current_scene.get_node("Explore").get_children():
		if child is CanvasLayer or child is Control:
			(child as Node).visible = false
	var wall := world.get_node("PerimeterWall") as Node3D
	var cam := _cam(42.0)
	# Inside face of each run is 102 m from the origin. Stand on the grass
	# at eye height and look along the stone, not into the gate opening.
	var eye := 1.65
	var back := 16.0
	var along := 42.0
	_frame(cam, Vector3(along, eye, -102.0 + back), Vector3(along, 7.0, -102.0))
	await _draw()
	_save(dir, "wall_north.png")
	_frame(cam, Vector3(102.0 - back, eye, along), Vector3(102.0, 7.0, along))
	await _draw()
	_save(dir, "wall_east.png")
	_frame(cam, Vector3(-along, eye, 102.0 - back), Vector3(-along, 7.0, 102.0))
	await _draw()
	_save(dir, "wall_south.png")
	_frame(cam, Vector3(-102.0 + back, eye, -along), Vector3(-102.0, 7.0, -along))
	await _draw()
	_save(dir, "wall_west.png")
	cam.fov = 48.0
	_frame(cam, Vector3(-86.0, eye, -86.0), Vector3(-102.0, 6.0, -102.0))
	await _draw()
	_save(dir, "wall_corner.png")
	var north := wall.get_node("GateNorth") as Node3D
	cam.fov = 50.0
	_frame(cam, north.global_position + Vector3(28.0, 4.5, 48.0), north.global_position + Vector3(0, 9.0, 0))
	await _draw()
	_save(dir, "wall_gate_wide.png")
	print("CAPTURE wall ok")
	quit(0)


func _frame(cam: Camera3D, at: Vector3, focus: Vector3) -> void:
	cam.global_position = at
	cam.look_at(focus, Vector3.UP)


func _cam(fov: float) -> Camera3D:
	var cam := current_scene.find_child("ShotCam", true, false) as Camera3D
	if cam == null:
		cam = Camera3D.new()
		cam.name = "ShotCam"
		current_scene.add_child(cam)
	cam.current = true
	cam.fov = fov
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	return cam


func _draw() -> void:
	for _i in 3:
		await process_frame
		await RenderingServer.frame_post_draw


func _save(dir: String, file_name: String) -> void:
	var img: Image = root.get_texture().get_image()
	var path := dir.path_join(file_name)
	var err := img.save_png(path)
	print("CAPTURE ", path, " ", err, " ", img.get_size())
