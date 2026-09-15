extends SceneTree
## Type a phone and tap Continue against live bakery-drinks.
##   DISPLAY=:1 godot --path . --rendering-method gl_compatibility --resolution 720x1280 \
##     -s res://tools/capture_login_live.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gs := root.get_node("GameSave")
	gs.call("clear_square_session")
	if change_scene_to_file("res://scenes/account/login.tscn") != OK:
		push_error("CAPTURE FAIL login")
		quit(1)
		return
	for _i in 16:
		await process_frame
		await RenderingServer.frame_post_draw
	var scene := current_scene
	var phone := scene.get_node_or_null("Safe/Card/Pad/Col/Phone") as LineEdit
	var go := scene.get_node_or_null("Safe/Card/Pad/Col/Continue") as Button
	if phone == null or go == null:
		push_error("CAPTURE FAIL widgets")
		quit(1)
		return
	phone.text = "(205) 555-0123"
	go.pressed.emit()
	var waited := 0.0
	while waited < 12.0:
		await process_frame
		await RenderingServer.frame_post_draw
		waited += 0.05
		var status := scene.get_node_or_null("Safe/Card/Pad/Col/Status") as Label
		if status and status.text.strip_edges() != "" and status.text.find("Looking up") < 0:
			break
		if current_scene and current_scene.name == "MainMenu":
			break
	_snap("login_live_continue.png")
	print("CAPTURE login live scene=", current_scene.name if current_scene else "?")
	quit(0)


func _snap(name: String) -> void:
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var img: Image = root.get_texture().get_image()
	if img:
		img.save_png(disk_dir.path_join(name))
		print("CAPTURE ", name, " ", img.get_width(), "x", img.get_height())
