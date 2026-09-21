extends SceneTree
## Lawn Donate button + donation screen screenshots.
##   DISPLAY=:1 godot --path . --rendering-method gl_compatibility --resolution 720x1280 \
##     -s res://tools/capture_donate.gd

const OUT := "res://export/review"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://scenes/main_menu.tscn") != OK:
		push_error("CAPTURE FAIL menu")
		quit(1)
		return
	for _i in 24:
		await process_frame
		await RenderingServer.frame_post_draw
	if not _snap("lawn_donate_above_tip.png"):
		quit(1)
		return
	if change_scene_to_file("res://scenes/donate/donate.tscn") != OK:
		push_error("CAPTURE FAIL donate")
		quit(1)
		return
	var stats: Label = null
	for _j in 360:
		await process_frame
		await RenderingServer.frame_post_draw
		if stats == null:
			stats = root.get_node_or_null("Donate/Safe/Stack/Center/Card/Pad/Col/Stats") as Label
		if stats != null and stats.text.find("Raised") >= 0 and stats.text.find("supporter") < 0:
			for _k in 12:
				await process_frame
				await RenderingServer.frame_post_draw
			break
	if not _snap("donate_screen_square.png"):
		quit(1)
		return
	print("CAPTURE donate ok")
	quit(0)


func _snap(name: String) -> bool:
	var disk_dir := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		push_error("CAPTURE FAIL image " + name)
		return false
	var disk := disk_dir.path_join(name)
	var err := img.save_png(disk)
	print("CAPTURE ", name, " ", img.get_width(), "x", img.get_height(), " -> ", disk, " err=", err)
	return err == OK
