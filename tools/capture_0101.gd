extends SceneTree
## Batch-3 shots: patio walkers, disco floor and host, bullseye, a menu prop, remote cookie.


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
	_hide_hud()
	for guest in world.get_tree().get_nodes_in_group("village_npc"):
		(guest as Node).set_process(false)
	await _walkers(world, dir)
	await _disco(world, dir)
	await _bullseye(world, dir)
	await _menu(world, dir)
	await _remote(world, dir)
	print("CAPTURE 0101 ok")
	quit(0)


func _walkers(world: Node3D, dir: String) -> void:
	var cam := _cam(42.0)
	var focus := Vector3(-6.4, 1.15, 4.6)
	cam.global_position = Vector3(-2.4, 1.55, 1.6)
	cam.look_at(focus, Vector3.UP)
	await _draw()
	_save(dir, "batch3_patio_walkers.png")


func _disco(world: Node3D, dir: String) -> void:
	var party := world.get_node("DiscoParty")
	party.call("apply_until", Time.get_unix_time_from_system() + 60.0)
	var player := current_scene.get_node("Explore/Player") as Node3D
	player.global_position = Vector3(18, 0.2, 18)
	for _i in 10:
		await process_frame
	var wash := party.find_child("DiscoWash", true, false) as CanvasItem
	if wash:
		wash.visible = false
	var host := party.find_child("HostDancer", true, false) as Node3D
	var focus := host.global_position + Vector3(0, 0.9, 0) if host else Vector3(0.15, 1.2, -2.55)
	var cam := _cam(48.0)
	cam.global_position = focus + Vector3(2.6, 1.35, 2.8)
	cam.look_at(focus, Vector3.UP)
	await _draw()
	_save(dir, "batch3_disco_host.png")


func _bullseye(world: Node3D, dir: String) -> void:
	var eye := world.get_node("DiscoBullseye") as Node3D
	var face := eye.find_child("Face", true, false) as Node3D
	var focus := face.global_position if face else eye.global_position + Vector3(0, 3.05, 0)
	var cam := _cam(32.0)
	cam.global_position = focus + Vector3(0.15, 0.15, 2.4)
	cam.look_at(focus, Vector3.UP)
	await _draw()
	_save(dir, "batch3_bullseye.png")


func _menu(world: Node3D, dir: String) -> void:
	var plate: Node3D = null
	for node in world.get_tree().get_nodes_in_group("menu_prop"):
		if node.has_meta("batch3_prop") and node is Node3D:
			plate = node
			break
	if plate == null:
		push_error("CAPTURE FAIL no batch3 menu prop")
		return
	var focus := plate.global_position + Vector3(0, 0.12, 0)
	var cam := _cam(28.0)
	cam.global_position = focus + Vector3(0.55, 0.42, 0.7)
	cam.look_at(focus, Vector3.UP)
	await _draw()
	_save(dir, "batch3_menu_prop.png")
	print("CAPTURE menu ", plate.name, " at ", plate.global_position)


func _remote(world: Node3D, dir: String) -> void:
	var Remote := load("res://scripts/explore/remote_baker.gd")
	var remote: Node3D = Remote.new()
	world.add_child(remote)
	remote.call("setup", {"net_id": "batch3", "display_name": "Mara", "x": 1.2, "y": 0.02, "z": 2.0})
	for _i in 4:
		await process_frame
	var hand := remote.find_child("HandSocket", true, false) as Node3D
	var focus := hand.global_position if hand else remote.global_position + Vector3(0.2, 0.75, 0)
	var cam := _cam(30.0)
	cam.global_position = focus + Vector3(0.55, 0.28, -0.85)
	cam.look_at(focus + Vector3(0, 0.15, 0), Vector3.UP)
	await _draw()
	_save(dir, "batch3_remote_cookie.png")


func _hide_hud() -> void:
	var explore := current_scene.get_node_or_null("Explore")
	if explore == null:
		return
	for child in explore.get_children():
		if child is CanvasLayer or child is Control:
			(child as Node).visible = false


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
