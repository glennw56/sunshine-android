extends SceneTree
## ORDER tap: no full-screen cover; menu cards + photo placeholders.
##   DISPLAY=:1 godot --path . --display-driver x11 --rendering-driver opengl3 \
##     --resolution 720x1280 -s res://tools/capture_ux_45.gd

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
	await _settle(6)
	if BakeryTheme.has_loading_cover(current_scene):
		push_error("CAPTURE FAIL lawn must not show Loading menu cover")
		quit(1)
		return
	if change_scene_to_file("res://scenes/order/order.tscn") != OK:
		push_error("CAPTURE FAIL order")
		quit(1)
		return
	await _settle(4)
	if BakeryTheme.has_loading_cover(current_scene):
		push_error("CAPTURE FAIL Order must not show full-screen cover")
		quit(1)
		return
	var waited := 0
	while waited < 90:
		var content := current_scene.get_node_or_null("Safe/VBox/Body/Content") if current_scene else null
		if _count_tex(content) >= 3:
			break
		await process_frame
		waited += 1
	await _settle(4)
	if _count_tex(current_scene.get_node_or_null("Safe/VBox/Body/Content")) < 3:
		push_error("CAPTURE FAIL menu cards missing")
		quit(1)
		return
	if not await _snap(disk, "order_menu_photo_placeholders.png"):
		quit(1)
		return
	var order := current_scene
	if order and order.has_method("_show_menu_loading"):
		order.call("_show_menu_loading")
		await _settle(8)
		if not await _snap(disk, "order_inline_skeleton.png"):
			quit(1)
			return
		if order.has_method("_render"):
			order.call("_render")
	print("CAPTURE 0.1.45 ORDER no cover, cards visible")
	quit(0)


func _count_tex(n: Node) -> int:
	if n == null:
		return 0
	var c := 1 if n is TextureRect else 0
	for child in n.get_children():
		c += _count_tex(child)
	return c


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
