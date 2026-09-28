extends SceneTree
## Nameless Square session → first / last / email form.
## Does not POST a dummy phone to live Square.
##   DISPLAY=:1 godot --path . --rendering-method gl_compatibility --resolution 720x1280 \
##     -s res://tools/capture_profile.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ac := root.get_node("AccountClient")
	ac.call("logout")
	var ok: bool = ac.call("apply_square_payload", {
		"ok": true,
		"session_token": "sess_capture_nameless",
		"customer": {
			"id": "CUST_CAPTURE_NAMELESS",
			"phone": "+12564525192",
			"given_name": "",
			"family_name": "",
			"nickname": "",
			"display_name": "",
		},
	})
	if not ok or not bool(ac.call("needs_profile")):
		push_error("CAPTURE FAIL nameless session")
		quit(1)
		return
	if change_scene_to_file("res://scenes/account/login.tscn") != OK:
		push_error("CAPTURE FAIL login")
		quit(1)
		return
	for _i in 16:
		await process_frame
		await RenderingServer.frame_post_draw
	var login := current_scene
	if login and login.has_method("show_profile_form"):
		login.call("show_profile_form")
	for _j in 12:
		await process_frame
		await RenderingServer.frame_post_draw
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("CAPTURE FAIL image")
		quit(1)
		return
	var disk := disk_dir.path_join("login_profile_nameless.png")
	var err := img.save_png(disk)
	print("CAPTURE login_profile_nameless.png ", img.get_width(), "x", img.get_height(), " -> ", disk, " err=", err)
	quit(0 if err == OK else 1)
