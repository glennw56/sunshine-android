extends SceneTree
## Guest menu with PREVIOUS ORDERS button, then live signed-in Square orders sheet.
##   DISPLAY=:1 godot --path . --rendering-method gl_compatibility --resolution 720x1280 \
##     -s res://tools/capture_previous_orders.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gs := root.get_node("GameSave")
	var ac := root.get_node("AccountClient")
	gs.call("clear_square_session")
	if change_scene_to_file("res://scenes/main_menu.tscn") != OK:
		push_error("CAPTURE FAIL menu")
		quit(1)
		return
	await _settle(24)
	if not _snap("menu_previous_orders_button.png"):
		quit(1)
		return
	var btn := current_scene.get_node_or_null("Safe/VBox/PreviousOrdersButton") as Button
	if btn == null:
		push_error("CAPTURE FAIL PreviousOrdersButton")
		quit(1)
		return
	btn.pressed.emit()
	await _settle(16)
	if not _snap("menu_previous_orders_guest.png"):
		quit(1)
		return
	var result: Dictionary = await ac.call("login_or_signup", "2564525192", true)
	if not result.get("ok", false):
		push_error("CAPTURE FAIL live login " + str(result.get("error", "")))
		quit(1)
		return
	if change_scene_to_file("res://scenes/main_menu.tscn") != OK:
		push_error("CAPTURE FAIL menu signed in")
		quit(1)
		return
	await _settle(24)
	btn = current_scene.get_node_or_null("Safe/VBox/PreviousOrdersButton") as Button
	if btn:
		btn.pressed.emit()
	await _settle(20)
	if not _snap("menu_previous_orders_list.png"):
		quit(1)
		return
	print("CAPTURE previous orders ok hello=", ac.call("hello_line"), " n=", ac.call("previous_orders").size())
	quit(0)


func _settle(frames: int) -> void:
	for _i in frames:
		await process_frame
		await RenderingServer.frame_post_draw


func _snap(name: String) -> bool:
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("CAPTURE FAIL image " + name)
		return false
	var err := img.save_png(disk_dir.path_join(name))
	print("CAPTURE ", name, " ", img.get_width(), "x", img.get_height(), " err=", err)
	return err == OK
