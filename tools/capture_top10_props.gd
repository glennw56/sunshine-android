extends SceneTree
## Capture the 10 top-seller patio props at display scale.
##   DISPLAY=:1 godot --path . --display-driver x11 --rendering-driver opengl3 \
##     -s res://tools/capture_top10_props.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/explore/explore_3d.tscn")
	if packed == null:
		push_error("CAPTURE FAIL load explore_3d")
		quit(1)
		return
	var explore: Node = packed.instantiate()
	root.add_child(explore)
	await process_frame
	await process_frame
	await process_frame
	var hud := explore.get_node_or_null("HUD")
	if hud:
		hud.visible = false
	var player_cam := explore.get_node_or_null("Player/Camera3D") as Camera3D
	if player_cam:
		player_cam.current = false
	var world := explore.get_node_or_null("World") as Node3D
	var props := 0
	if world:
		for child in world.get_children():
			if child.is_in_group("menu_prop"):
				props += 1
				print("CAPTURE prop ", child.name, " pos=", child.position, " scale=", child.scale)
	print("CAPTURE menu_prop count=", props)
	if props != 10:
		push_error("CAPTURE FAIL expected 10 menu props, got %d" % props)
		quit(1)
		return
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var shots: Array[Dictionary] = [
		{"name": "top10_spawn", "pos": Vector3(0.0, 1.62, 11.0), "look": Vector3(0.0, 1.15, -1.2), "fov": 52.0},
		{"name": "top10_picnic_west", "pos": Vector3(-7.05, 1.62, 5.35), "look": Vector3(-4.80, 1.02, 3.90), "fov": 46.0},
		{"name": "top10_picnic_east", "pos": Vector3(7.05, 1.62, 5.35), "look": Vector3(4.80, 1.02, 3.90), "fov": 46.0},
		{"name": "top10_picnic_north", "pos": Vector3(2.35, 1.68, -3.15), "look": Vector3(0.0, 1.02, -4.70), "fov": 48.0},
		{"name": "top10_center_coffee", "pos": Vector3(1.55, 1.38, 1.15), "look": Vector3(0.0, 0.98, -0.45), "fov": 46.0},
		{"name": "top10_fruit_tea", "pos": Vector3(-4.80, 1.42, 2.55), "look": Vector3(-4.80, 1.02, 0.80), "fov": 46.0},
		{"name": "top10_overhead", "pos": Vector3(0.0, 16.0, 10.0), "look": Vector3(0.0, 0.6, -0.6), "fov": 50.0},
	]
	var cam := Camera3D.new()
	cam.name = "Top10CaptureCam"
	root.add_child(cam)
	var saved := 0
	for shot in shots:
		cam.current = true
		cam.fov = float(shot["fov"])
		cam.position = shot["pos"]
		cam.look_at(shot["look"], Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var tex: ViewportTexture = root.get_texture()
		if tex == null:
			push_error("CAPTURE FAIL viewport")
			quit(1)
			return
		var img: Image = tex.get_image()
		if img == null:
			push_error("CAPTURE FAIL image " + str(shot["name"]))
			quit(1)
			return
		var disk := disk_dir.path_join("%s.png" % str(shot["name"]))
		var err := img.save_png(disk)
		print("CAPTURE ", shot["name"], " ", img.get_width(), "x", img.get_height(), " -> ", disk, " err=", err)
		saved += 1
	print("CAPTURE done ", saved, " pngs")
	quit(0)
