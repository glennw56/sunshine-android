extends SceneTree
## Capture PNGs from Explore 3D review cameras.
##   godot --path . --headless -s res://tools/capture_review.gd
## Writes export/review/<Name>.png (editor/headless) and user://review/.
## Headless GPUs may save a blank/clear-color frame — use the editor if that happens.

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
	var rig := explore.get_node_or_null("ReviewCameras") as ReviewCameras
	if rig == null:
		push_error("CAPTURE FAIL missing ReviewCameras")
		quit(1)
		return
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://review"))
	var saved := 0
	for shot_name in ReviewCameras.SHOT_NAMES:
		var cam := rig.camera_named(shot_name)
		if cam == null:
			push_error("CAPTURE FAIL missing camera " + shot_name)
			quit(1)
			return
		cam.current = true
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var tex: ViewportTexture = root.get_texture()
		if tex == null:
			push_error("CAPTURE FAIL viewport texture")
			quit(1)
			return
		var img: Image = tex.get_image()
		if img == null:
			push_error("CAPTURE FAIL image " + shot_name)
			quit(1)
			return
		var file_name := "%s.png" % shot_name
		var disk := disk_dir.path_join(file_name)
		var user := ProjectSettings.globalize_path("user://review").path_join(file_name)
		var err := img.save_png(disk)
		img.save_png(user)
		print("CAPTURE ", shot_name, " ", img.get_width(), "x", img.get_height(), " -> ", disk, " err=", err)
		saved += 1
		cam.current = false
	if player_cam:
		player_cam.current = true
	print("CAPTURE done ", saved, " pngs in ", disk_dir)
	quit(0 if saved == ReviewCameras.SHOT_NAMES.size() else 1)
