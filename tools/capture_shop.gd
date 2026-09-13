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
	if player_cam:
		player_cam.current = true
	print("CAPTURE shop proof shots ok")
	quit(0)
