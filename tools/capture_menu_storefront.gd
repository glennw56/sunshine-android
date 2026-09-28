extends SceneTree
## Guest main menu on the exact storefront photo.
##   DISPLAY=:1 godot --path . --rendering-method gl_compatibility --resolution 720x1280 \
##     -s res://tools/capture_menu_storefront.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gs := root.get_node("GameSave")
	gs.call("clear_square_session")
	if change_scene_to_file("res://scenes/main_menu.tscn") != OK:
		push_error("CAPTURE FAIL menu")
		quit(1)
		return
	for _i in 24:
		await process_frame
		await RenderingServer.frame_post_draw
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("CAPTURE FAIL image")
		quit(1)
		return
	var disk := disk_dir.path_join("menu_storefront.png")
	var err := img.save_png(disk)
	print("CAPTURE menu_storefront.png ", img.get_width(), "x", img.get_height(), " -> ", disk, " err=", err)
	quit(0 if err == OK else 1)
