extends SceneTree
## Menu loading card + drag-scroll proof stills.
##   DISPLAY=:1 godot --path . --display-driver x11 --rendering-driver opengl3 \
##     --resolution 720x1280 -s res://tools/capture_ux_39.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var disk := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk)
	var oc := root.get_node("OrderClient")
	oc.call("restore_cached_menu")
	oc.call("clear_cart")
	if change_scene_to_file("res://scenes/order/order.tscn") != OK:
		push_error("CAPTURE FAIL order")
		quit(1)
		return
	await _settle(12)
	var order := current_scene
	if order.has_method("_show_menu_loading"):
		order.call("_show_menu_loading")
		await _settle(10)
		if not await _snap(disk, "order_loading_menu.png"):
			quit(1)
			return
		if order.has_method("_show_menu_error"):
			order.call("_show_menu_error", "Square catalog unavailable.")
			await _settle(8)
			if not await _snap(disk, "order_menu_error_retry.png"):
				quit(1)
				return
		if order.has_method("_render"):
			order.call("_render")
		await _settle(12)
	if not await _snap(disk, "order_menu_cards_scroll.png"):
		quit(1)
		return
	print("CAPTURE 0.1.39 layout done")
	quit(0)


func _settle(frames: int) -> void:
	for _i in frames:
		await process_frame
		await RenderingServer.frame_post_draw


func _snap(disk_dir: String, name: String) -> bool:
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("CAPTURE FAIL image " + name)
		return false
	var err := img.save_png(disk_dir.path_join(name))
	print("CAPTURE ", name, " ", img.get_width(), "x", img.get_height(), " err=", err)
	return err == OK
