extends SceneTree
## Centered TPP patio + planted feet after a short walk and look.
## Do not type PlayerExplorer here — -s mode compiles before autoloads.
##   xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 720x1280 \
##     -s res://tools/capture_tpp_controls.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	if change_scene_to_file("res://scenes/explore/explore_3d.tscn") != OK:
		push_error("CAPTURE FAIL explore")
		quit(1)
		return
	for _i in 36:
		await process_frame
		await RenderingServer.frame_post_draw
	var player := current_scene.get_node_or_null("Player") as Node3D
	if player == null:
		push_error("CAPTURE FAIL player")
		quit(1)
		return
	print("TPP spawn y=", player.global_position.y, " pos=", player.global_position, " yaw=", player.rotation.y)
	player.set("joy_vector", Vector2(0, 1))
	for _j in 36:
		await physics_frame
	player.set("joy_vector", Vector2.ZERO)
	if player.has_method("apply_touch_look"):
		player.call("apply_touch_look", Vector2(48, 10))
	for _k in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	print("TPP after walk+look y=", player.global_position.y, " pos=", player.global_position, " yaw=", player.rotation.y)
	if not _save("explore_tpp_look.png", disk_dir):
		quit(1)
		return
	print("CAPTURE tpp ok")
	quit(0)


func _save(name: String, disk_dir: String) -> bool:
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("CAPTURE FAIL image " + name)
		return false
	var disk := disk_dir.path_join(name)
	var err := img.save_png(disk)
	print("CAPTURE ", name, " ", img.get_width(), "x", img.get_height(), " -> ", disk, " err=", err)
	img.save_png("/opt/cursor/artifacts/" + name)
	return err == OK
