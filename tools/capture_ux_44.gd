extends SceneTree
## ORDER tap: cover shows, then menu is visible with cover gone.
##   DISPLAY=:1 godot --path . --display-driver x11 --rendering-driver opengl3 \
##     --resolution 720x1280 -s res://tools/capture_ux_44.gd

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
	await _settle(8)
	var lawn := current_scene
	BakeryTheme.show_loading_cover(lawn)
	await _settle(6)
	if not BakeryTheme.has_loading_cover(lawn):
		push_error("CAPTURE FAIL cover missing after ORDER tap")
		quit(1)
		return
	if not await _snap(disk, "order_tap_loading.png"):
		quit(1)
		return
	if change_scene_to_file("res://scenes/order/order.tscn") != OK:
		push_error("CAPTURE FAIL order")
		quit(1)
		return
	var waited := 0
	while waited < 90:
		var order := current_scene
		var content := order.get_node_or_null("Safe/VBox/Body/Content") if order else null
		var photos := _count_tex(content)
		var cover := BakeryTheme.has_loading_cover(order)
		if photos >= 3 and not cover:
			break
		await process_frame
		waited += 1
	await _settle(6)
	if BakeryTheme.has_loading_cover(current_scene):
		push_error("CAPTURE FAIL cover still up after menu paint")
		quit(1)
		return
	if _count_tex(current_scene.get_node_or_null("Safe/VBox/Body/Content")) < 3:
		push_error("CAPTURE FAIL menu cards missing")
		quit(1)
		return
	if not await _snap(disk, "order_menu_ready.png"):
		quit(1)
		return
	print("CAPTURE 0.1.44 ORDER cover dismissed")
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
