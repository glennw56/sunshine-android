extends SceneTree
## Night shots of grand_gate.glb from the patio side, plus a wider wall view.


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
	var north := world.get_node("PerimeterWall/GateNorth") as Node3D
	var cam := _cam(38.0)
	var focus := north.global_position + Vector3(0, 6.2, 0)
	cam.global_position = north.global_position + Vector3(0.4, 2.4, 16.0)
	cam.look_at(focus, Vector3.UP)
	await _draw()
	_save(dir, "gate_new_closeup.png")
	cam.fov = 50.0
	cam.global_position = north.global_position + Vector3(36.0, 9.0, 72.0)
	cam.look_at(north.global_position + Vector3(0, 8.0, 0), Vector3.UP)
	await _draw()
	_save(dir, "gate_new_wide.png")
	print("CAPTURE gate ok")
	quit(0)


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


func _save(dir: String, name: String) -> void:
	var img: Image = root.get_texture().get_image()
	var path := dir.path_join(name)
	var err := img.save_png(path)
	print("CAPTURE ", path, " ", err, " ", img.get_size())
