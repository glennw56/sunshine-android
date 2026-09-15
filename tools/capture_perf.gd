extends SceneTree
## Time cache-first Order + Previous Orders paint. Photos must not block the list.
##   DISPLAY=:1 godot --path . --display-driver x11 --rendering-driver opengl3 \
##     --resolution 720x1280 -s res://tools/capture_perf.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var oc := root.get_node("OrderClient")
	var gs := root.get_node("GameSave")
	var ac := root.get_node("AccountClient")
	var t_restore := Time.get_ticks_usec()
	var restored: bool = oc.call("restore_cached_menu")
	var restore_ms := (Time.get_ticks_usec() - t_restore) / 1000.0
	print("PERF restore_cached_menu restored=", restored, " drinks=", oc.call("drinks").size(), " ms=", restore_ms)
	if change_scene_to_file("res://scenes/order/order.tscn") != OK:
		push_error("CAPTURE FAIL order")
		quit(1)
		return
	var t_order := Time.get_ticks_msec()
	for _i in 4:
		await process_frame
	var order_ms := Time.get_ticks_msec() - t_order
	var busy := current_scene.get_node_or_null("Safe/VBox/Busy") as Label
	var rows := _count_named(current_scene.get_node_or_null("Safe/VBox/Body/Content"), "PanelContainer")
	print("PERF order first paint ms=", order_ms, " drinks=", oc.call("drinks").size(), " rows=", rows, " busy=", busy.visible if busy else false)
	if not await _snap(disk_dir, "order_fast_cache.png"):
		quit(1)
		return
	var login: Dictionary = await ac.call("login_or_signup", "2564525192", true)
	print("PERF login ok=", login.get("ok", false))
	if change_scene_to_file("res://scenes/main_menu.tscn") != OK:
		push_error("CAPTURE FAIL menu")
		quit(1)
		return
	for _j in 8:
		await process_frame
	var prev := current_scene.get_node_or_null("Safe/VBox/PreviousOrdersButton") as Button
	if prev == null:
		push_error("CAPTURE FAIL PreviousOrdersButton")
		quit(1)
		return
	var t_prev := Time.get_ticks_msec()
	prev.pressed.emit()
	for _k in 4:
		await process_frame
	var prev_ms := Time.get_ticks_msec() - t_prev
	var sheet := current_scene.get_node_or_null("OrdersSheet")
	var listed := 0
	if sheet:
		listed = _count_named(sheet.get_node_or_null("Safe/Card/Pad/Col/Scroll/List"), "HBoxContainer")
	print("PERF previous orders first paint ms=", prev_ms, " cached=", gs.get("previous_orders").size() if gs.get("previous_orders") is Array else 0, " line_rows=", listed, " visible=", sheet.visible if sheet else false)
	if not await _snap(disk_dir, "previous_orders_fast.png"):
		quit(1)
		return
	if change_scene_to_file("res://scenes/explore/explore_3d.tscn") != OK:
		push_error("CAPTURE FAIL explore")
		quit(1)
		return
	var t_ex := Time.get_ticks_msec()
	for _n in 6:
		await process_frame
	var explore_first_ms := Time.get_ticks_msec() - t_ex
	var world := current_scene.get_node_or_null("World")
	print("PERF explore first frames ms=", explore_first_ms, " world_children=", world.get_child_count() if world else 0)
	for _m in 18:
		await process_frame
	if not await _snap(disk_dir, "explore_fast.png"):
		quit(1)
		return
	print("PERF done restore_ms=", restore_ms, " order_ms=", order_ms, " previous_ms=", prev_ms, " explore_ms=", explore_first_ms)
	quit(0)


func _count_named(root: Node, type_name: String) -> int:
	if root == null:
		return 0
	var n := 0
	for child in root.get_children():
		if child.get_class() == type_name:
			n += 1
		n += _count_named(child, type_name)
	return n


func _snap(disk_dir: String, file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	var tex: ViewportTexture = root.get_texture()
	if tex == null:
		push_error("CAPTURE FAIL viewport " + file_name)
		return false
	var img: Image = tex.get_image()
	if img == null:
		push_error("CAPTURE FAIL image " + file_name)
		return false
	var disk := disk_dir.path_join(file_name)
	var err := img.save_png(disk)
	print("CAPTURE ", file_name, " ", img.get_width(), "x", img.get_height(), " -> ", disk, " err=", err)
	return err == OK
