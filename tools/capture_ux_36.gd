extends SceneTree
## Big type + square photo rows + quieter Explore (no Fresh Batch enter toast).
##   DISPLAY=:1 godot --path . --display-driver x11 --rendering-driver opengl3 \
##     --resolution 720x1280 -s res://tools/capture_ux_36.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var disk := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk)
	var oc := root.get_node("OrderClient")
	var ac := root.get_node("AccountClient")
	oc.call("restore_cached_menu")
	oc.call("clear_cart")
	if change_scene_to_file("res://scenes/main_menu.tscn") != OK:
		push_error("CAPTURE FAIL menu")
		quit(1)
		return
	await _settle(16)
	if not await _snap(disk, "menu_big_type.png"):
		quit(1)
		return
	if change_scene_to_file("res://scenes/order/order.tscn") != OK:
		push_error("CAPTURE FAIL order")
		quit(1)
		return
	await _settle(12)
	if not await _snap(disk, "order_photo_rows.png"):
		quit(1)
		return
	var drinks: Array = oc.call("drinks")
	var pick: Dictionary = {}
	for row in drinks:
		if row is Dictionary and int(row.get("price_cents", 0)) > 0:
			pick = row
			break
	if not pick.is_empty():
		oc.call("add_cart_item", str(pick.get("id", "")), {}, 1)
	var order := current_scene
	if order.has_method("_set_tab"):
		order.call("_set_tab", 1)
	await _settle(10)
	if not await _snap(disk, "cart_photo_rows.png"):
		quit(1)
		return
	if order.has_method("_refresh_cart_bar"):
		order.call("_refresh_cart_bar")
	await _settle(6)
	if not await _snap(disk, "order_clear_cart.png"):
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
		await _settle(20)
		if not await _snap(disk, "previous_orders.png"):
			quit(1)
			return
	else:
		print("CAPTURE previous orders skipped login=", login.get("error", ""))
	var gs := root.get_node("GameSave")
	gs.set("debug_unix", int(Time.get_unix_time_from_datetime_dict({
		"year": 2026, "month": 4, "day": 15, "hour": 15, "minute": 30, "second": 0
	})))
	if change_scene_to_file("res://scenes/explore/explore_3d.tscn") != OK:
		push_error("CAPTURE FAIL explore")
		quit(1)
		return
	await _settle(28)
	if not await _snap(disk, "explore_hud_quiet.png"):
		quit(1)
		return
	var player := current_scene.get_node_or_null("Player")
	if player and player.has_method("toss_cookie"):
		player.call("toss_cookie")
	await _settle(6)
	if not await _snap(disk, "explore_toss_cookie.png"):
		quit(1)
		return
	print("CAPTURE cookie projectiles=", root.get_tree().get_nodes_in_group("cookie_projectile").size())
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
