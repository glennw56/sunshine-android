extends SceneTree
## Capture customize preview + third-person Explore for the 0.1.51 COS milestone.
##   DISPLAY=:1 godot --path . --rendering-method gl_compatibility --resolution 720x1280 \
##     -s res://tools/capture_cos_milestone.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var account: Node = root.get_node("AccountClient")
	account.call("apply_square_payload", {
		"ok": true,
		"session_token": "sess_capture_look",
		"customer": {
			"id": "CUST_LOOK_CAP",
			"given_name": "Ada",
			"family_name": "Baker",
		},
	})
	if change_scene_to_file("res://scenes/explore/customize.tscn") != OK:
		push_error("CAPTURE FAIL customize")
		quit(1)
		return
	var customize := current_scene
	if customize and customize.has_method("_on_save"):
		customize.call("_on_save")
	for _i in 28:
		await process_frame
		await RenderingServer.frame_post_draw
	if not _save("customize_look.png", disk_dir):
		quit(1)
		return
	if change_scene_to_file("res://scenes/explore/explore_3d.tscn") != OK:
		push_error("CAPTURE FAIL explore")
		quit(1)
		return
	for _i in 36:
		await process_frame
		await RenderingServer.frame_post_draw
	if not _save("explore_third_person.png", disk_dir):
		quit(1)
		return
	print("CAPTURE cos milestone ok")
	quit(0)


func _save(name: String, disk_dir: String) -> bool:
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("CAPTURE FAIL image " + name)
		return false
	var disk := disk_dir.path_join(name)
	var err := img.save_png(disk)
	print("CAPTURE ", name, " ", img.get_width(), "x", img.get_height(), " -> ", disk, " err=", err)
	return err == OK
