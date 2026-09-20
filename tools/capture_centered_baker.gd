extends SceneTree
## Prove the local baker is horizontally centered in the default TPP camera.
##   DISPLAY=:1 godot --path . --rendering-method gl_compatibility --resolution 720x1280 \
##     -s res://tools/capture_centered_baker.gd

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
	if player == null:
		push_error("CAPTURE FAIL player")
		quit(1)
		return
	var cam := player.find_child("Camera3D", true, false) as Camera3D
	var arm := player.get_node_or_null("SpringArm") as SpringArm3D
	if cam == null or arm == null:
		push_error("CAPTURE FAIL camera rig")
		quit(1)
		return
	var chest := player.global_position + Vector3(0, 0.72, 0)
	var screen := cam.unproject_position(chest)
	var vp := cam.get_viewport().get_visible_rect().size
	var nx := screen.x / vp.x
	print("CENTER baker nx=", nx, " screen=", screen, " vp=", vp, " arm=", arm.position, " h_offset=", cam.h_offset)
	if not _save("explore_baker_centered.png", disk_dir):
		quit(1)
		return
	if absf(arm.position.x) > 0.08 or absf(nx - 0.5) > 0.12:
		push_error("CAPTURE FAIL baker not centered nx=%.3f arm.x=%.3f" % [nx, arm.position.x])
		quit(1)
		return
	print("CAPTURE centered baker ok")
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
