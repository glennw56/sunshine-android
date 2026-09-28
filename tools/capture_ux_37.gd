extends SceneTree
## Wide (~95% card) Square item photos on Order, detail, cart, Previous Orders.
##   DISPLAY=:1 godot --path . --display-driver x11 --rendering-driver opengl3 \
##     --resolution 720x1280 -s res://tools/capture_ux_37.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var disk := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk)
	var oc := root.get_node("OrderClient")
	var ac := root.get_node("AccountClient")
	oc.call("restore_cached_menu")
	oc.call("clear_cart")
	if change_scene_to_file("res://scenes/order/order.tscn") != OK:
		push_error("CAPTURE FAIL order")
		quit(1)
		return
	await _settle(14)
	if not await _snap(disk, "order_wide_photos.png"):
		quit(1)
		return
	var drinks: Array = oc.call("drinks")
	var pick: Dictionary = {}
	for row in drinks:
		if row is Dictionary and int(row.get("price_cents", 0)) > 0:
			pick = row
			break
	var order := current_scene
	if not pick.is_empty() and order.has_method("_open_detail"):
		order.call("_open_detail", pick)
		await _settle(10)
		if not await _snap(disk, "order_item_wide_photo.png"):
			quit(1)
			return
		oc.call("add_cart_item", str(pick.get("id", "")), {}, 1)
	if order.has_method("_set_tab"):
		order.call("_set_tab", 1)
	await _settle(10)
	if not await _snap(disk, "cart_wide_photos.png"):
		quit(1)
		return
	var login: Dictionary = await ac.call("login_or_signup", "2564525192", true)
	if login.get("ok", false):
		if change_scene_to_file("res://scenes/main_menu.tscn") != OK:
			push_error("CAPTURE FAIL signed-in menu")
			quit(1)
			return
		await _settle(16)
		var prev := current_scene.get_node_or_null("Safe/VBox/PreviousOrdersButton") as Button
		if prev:
			prev.pressed.emit()
		await _settle(22)
		if not await _snap(disk, "previous_orders_wide_photos.png"):
			quit(1)
			return
	else:
		print("CAPTURE previous orders skipped login=", login.get("error", ""))
	print("CAPTURE wide photos done")
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
