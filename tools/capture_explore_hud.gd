extends SceneTree
## Portrait Explore HUD: silent look pad, no LOOK coaching, Menu button.
##   DISPLAY=:1 godot --path . --rendering-method gl_compatibility --resolution 720x1280 \
##     -s res://tools/capture_explore_hud.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://scenes/explore/explore_3d.tscn") != OK:
		push_error("CAPTURE FAIL explore")
		quit(1)
		return
	for _i in 36:
		await process_frame
		await RenderingServer.frame_post_draw
	var hud := current_scene.get_node_or_null("HUD") if current_scene else null
	if hud and hud.has_method("push_chat"):
		hud.call("push_chat", "Ada", "hello patio")
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("CAPTURE FAIL image")
		quit(1)
		return
	var disk := disk_dir.path_join("explore_hud_silent_look.png")
	var err := img.save_png(disk)
	print("CAPTURE explore_hud_silent_look.png ", img.get_width(), "x", img.get_height(), " -> ", disk, " err=", err)
	quit(0 if err == OK else 1)
