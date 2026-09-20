extends SceneTree
## Capture the south-lawn spawn to prove feet sit on the grass.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	if change_scene_to_file("res://scenes/explore/explore_3d.tscn") != OK:
		push_error("CAPTURE FAIL explore")
		quit(1)
		return
	for _i in 40:
		await process_frame
		await RenderingServer.frame_post_draw
	var player := current_scene.get_node_or_null("Player") as Node3D
	if player:
		print("GROUNDED player_y=", player.global_position.y, " pos=", player.global_position)
	if not _save("explore_grounded.png", disk_dir):
		quit(1)
		return
	print("CAPTURE grounded ok")
	quit(0)


func _save(name: String, disk_dir: String) -> bool:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		push_error("CAPTURE FAIL empty " + name)
		return false
	var path := disk_dir.path_join(name)
	var err := img.save_png(path)
	print("CAPTURE ", name, " ", img.get_width(), "x", img.get_height(), " -> ", path, " err=", err)
	var art := "/opt/cursor/artifacts/" + name
	img.save_png(art)
	print("CAPTURE artifact ", art)
	return err == OK
