extends SceneTree
## Side views of a mid-dance wardrobe baker (female and male) and the host,
## plus the Loyalty screen showing a mock customer name.


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
	var explore := current_scene.get_node("Explore")
	for child in explore.get_children():
		if child is CanvasLayer or child is Control:
			(child as Node).visible = false
	var player := explore.get_node("Player") as Node3D
	player.global_position = Vector3(0, 0.02, 8)
	player.rotation.y = 0.0
	var avatar := player.get_node("Avatar")
	var cam := _cam(32.0)
	await _dance_shot(avatar, player, cam, dir, "dance_female_side.png", {"v": 1, "body": "female"})
	await _dance_shot(avatar, player, cam, dir, "dance_male_side.png", {"v": 1, "body": "male", "accessory": "none"})
	var host := explore.get_node("World/DiscoParty").find_child("HostDancer", true, false) as Node3D
	var party := explore.get_node("World/DiscoParty")
	party.call("apply_until", Time.get_unix_time_from_system() + 30.0)
	await process_frame
	host.rotation.y = 0.0
	var larm := host.find_child("ArmL", true, false) as Node3D
	var rarm := host.find_child("ArmR", true, false) as Node3D
	if larm:
		larm.rotation.x = 1.15 + 0.35
	if rarm:
		rarm.rotation.x = 1.15 - 0.35
	_frame(cam, host.global_position + Vector3(3.1, 1.15, 0.15), host.global_position + Vector3(0, 0.85, -0.15))
	await RenderingServer.frame_post_draw
	_save(dir, "dance_host_side.png")
	DisplayServer.window_set_size(Vector2i(720, 1280))
	var gs := root.get_node("GameSave")
	gs.call("set_square_session", {
		"customer": {
			"id": "CUST_LOYALTY_PREVIEW",
			"phone": "2564525192",
			"given_name": "Ada",
			"family_name": "Baker",
			"display_name": "Ada Baker",
		},
		"loyalty": {
			"enrolled": true,
			"account_id": "LOY_PREVIEW",
			"points": 140,
			"program_id": "PROG_PREVIEW",
		},
	})
	if change_scene_to_file("res://scenes/loyalty/loyalty.tscn") != OK:
		push_error("CAPTURE FAIL loyalty")
		quit(1)
		return
	for _i in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	_save(dir, "loyalty_name.png")
	print("CAPTURE 0104 ok")
	quit(0)


func _dance_shot(avatar: Node, player: Node3D, cam: Camera3D, dir: String, file_name: String, recipe: Dictionary) -> void:
	avatar.call("rebuild", recipe)
	await process_frame
	player.global_position = Vector3(0, 0.02, 8)
	player.rotation.y = 0.0
	avatar.call("set_dancing", true)
	avatar.set("_throw_left", 0.0)
	avatar.set("_hit_left", 0.0)
	avatar.set("_dance_t", 0.12)
	await process_frame
	player.rotation.y = 0.0
	var larm := avatar.get("_larm") as Node3D
	var rarm := avatar.get("_rarm") as Node3D
	if larm:
		larm.rotation.x = 1.15 + 0.36
	if rarm:
		rarm.rotation.x = 1.15 - 0.28
	_frame(cam, player.global_position + Vector3(3.2, 1.2, 0.15), player.global_position + Vector3(0, 1.0, -0.2))
	await RenderingServer.frame_post_draw
	_save(dir, file_name)
	print("CAPTURE arm ", file_name, " L ", larm.rotation.x if larm else "none", " R ", rarm.rotation.x if rarm else "none")


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


func _save(dir: String, file_name: String) -> void:
	var img: Image = root.get_texture().get_image()
	var path := dir.path_join(file_name)
	var err := img.save_png(path)
	print("CAPTURE ", path, " ", err, " ", img.get_size())
