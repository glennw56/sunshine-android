extends SceneTree
## Capture spawn / porch / deck proof shots of the Irondale voxel shop.
##   godot --path . --rendering-method gl_compatibility -s res://tools/capture_shop.gd
## Writes export/review/shop_*.png

const ReviewCamerasLib := preload("res://scripts/explore/review_cameras.gd")

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
	for _i in 6:
		await process_frame
		await RenderingServer.frame_post_draw
	var hud := explore.get_node_or_null("HUD")
	if hud:
		hud.visible = false
	var player_cam := explore.get_node_or_null("Player/Camera3D") as Camera3D
	if player_cam:
		player_cam.current = false
	var rig := explore.get_node_or_null("ReviewCameras")
	if rig == null:
		push_error("CAPTURE FAIL missing ReviewCameras")
		quit(1)
		return
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var shots := [
		{"name": "Entrance", "file": "shop_spawn.png"},
		{"name": "Dining", "file": "shop_porch.png"},
		{"name": "Dining", "file": "shop_ramp.png"},
		{"name": "RightCorner", "file": "shop_2229.png"},
		{"name": "Exterior", "file": "shop_deck.png"},
		{"name": "SunshineCloseup", "file": "shop_sign.png"},
	]
	for shot in shots:
		var cam := rig.get_node_or_null(str(shot["name"])) as Camera3D
		if cam == null:
			push_error("CAPTURE FAIL missing " + str(shot["name"]))
			quit(1)
			return
		cam.current = true
		for _j in 4:
			await process_frame
			await RenderingServer.frame_post_draw
		var tex: ViewportTexture = root.get_texture()
		if tex == null:
			push_error("CAPTURE FAIL viewport")
			quit(1)
			return
		var img: Image = tex.get_image()
		if img == null:
			push_error("CAPTURE FAIL image " + str(shot["file"]))
			quit(1)
			return
		var disk := disk_dir.path_join(str(shot["file"]))
		var err := img.save_png(disk)
		print("CAPTURE ", shot["file"], " ", img.get_width(), "x", img.get_height(), " -> ", disk, " err=", err)
		cam.current = false
	for shot_name in ReviewCamerasLib.SHOT_NAMES:
		var cam := rig.get_node_or_null(shot_name) as Camera3D
		if cam == null:
			continue
		cam.current = true
		for _k in 3:
			await process_frame
			await RenderingServer.frame_post_draw
		var extra: Image = root.get_texture().get_image()
		if extra:
			extra.save_png(disk_dir.path_join("%s.png" % shot_name))
		cam.current = false
	# Extra still-matched angles (4× video pack).
	var stills := [
		{"file": "still_spawn.png", "pos": Vector3(-2.3, 1.7, -11.5), "look": Vector3(1.6, 1.55, 0.25), "fov": 66.0},
		{"file": "still_2231.png", "pos": Vector3(0.35, 1.65, -4.8), "look": Vector3(3.4, 1.25, 0.9), "fov": 60.0},
		{"file": "still_ramp.png", "pos": Vector3(2.15, 1.55, -3.4), "look": Vector3(3.9, 0.85, 1.6), "fov": 56.0},
		{"file": "still_2229.png", "pos": Vector3(3.4, 1.6, -6.6), "look": Vector3(8.5, 1.35, 0.2), "fov": 58.0},
		{"file": "still_deck.png", "pos": Vector3(9.8, 2.45, 10.2), "look": Vector3(5.8, 1.95, 5.4), "fov": 62.0},
	]
	for shot in stills:
		var cam := Camera3D.new()
		cam.fov = float(shot["fov"])
		cam.position = shot["pos"]
		rig.add_child(cam)
		cam.look_at(shot["look"], Vector3.UP)
		cam.current = true
		for _n in 4:
			await process_frame
			await RenderingServer.frame_post_draw
		var still_img: Image = root.get_texture().get_image()
		if still_img:
			still_img.save_png(disk_dir.path_join(str(shot["file"])))
			print("CAPTURE ", shot["file"], " ", still_img.get_width(), "x", still_img.get_height())
		cam.current = false
		cam.queue_free()
	if player_cam:
		player_cam.current = true
	print("CAPTURE shop proof shots ok")
	quit(0)
