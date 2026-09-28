extends SceneTree
## ORDER-tap loading overlay + menu ready stills.
##   DISPLAY=:1 godot --path . --display-driver x11 --rendering-driver opengl3 \
##     --resolution 720x1280 -s res://tools/capture_ux_40.gd

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var disk := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk)
	var oc := root.get_node("OrderClient")
	oc.call("restore_cached_menu")
	oc.call("clear_cart")
	if change_scene_to_file("res://scenes/main_menu.tscn") != OK:
		push_error("CAPTURE FAIL main menu")
		quit(1)
		return
	await _settle(10)
	var lawn := current_scene
	BakeryTheme.show_loading_cover(lawn)
	await _settle(6)
	if not await _snap(disk, "order_tap_loading.png"):
		quit(1)
		return
	if change_scene_to_file("res://scenes/order/order.tscn") != OK:
		push_error("CAPTURE FAIL order")
		quit(1)
		return
	await _settle(4)
	if BakeryTheme.has_loading_cover(current_scene):
		if not await _snap(disk, "order_tap_loading_order.png"):
			quit(1)
			return
	var waited := 0
	while waited < 50:
		var content := current_scene.get_node_or_null("Safe/VBox/Body/Content")
		var photos := _count_tex(content)
		if photos >= 3 and not BakeryTheme.has_loading_cover(current_scene):
			break
		await process_frame
		waited += 1
	await _settle(8)
	if not await _snap(disk, "order_menu_ready.png"):
		quit(1)
		return
	var order := current_scene
	if order.has_method("_show_menu_loading"):
		order.call("_show_menu_loading")
		await _settle(8)
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
		await _settle(10)
	if not await _snap(disk, "order_menu_cards_scroll.png"):
		quit(1)
		return
	print("CAPTURE 0.1.40 layout done")
	quit(0)


func _count_tex(root: Node) -> int:
	if root == null:
		return 0
	var n := 0
	if root is TextureRect:
		n += 1
	for child in root.get_children():
		n += _count_tex(child)
	return n


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
