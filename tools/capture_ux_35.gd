extends SceneTree
## Order Clear cart + larger type, then Explore cookie toss.
##   DISPLAY=:1 godot --path . --display-driver x11 --rendering-driver opengl3 \
##     --resolution 720x1280 -s res://tools/capture_ux_35.gd

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
	for _i in 10:
		await process_frame
	var drinks: Array = oc.call("drinks")
	var pick: Dictionary = {}
	for row in drinks:
		if row is Dictionary and int(row.get("price_cents", 0)) > 0:
			pick = row
			break
	if not pick.is_empty():
		oc.call("add_cart_item", str(pick.get("id", "")), {}, 1)
	var order := current_scene
	if order.has_method("_refresh_cart_bar"):
		order.call("_refresh_cart_bar")
	for _j in 8:
		await process_frame
	if not await _snap(disk, "order_clear_cart.png"):
		quit(1)
		return
	print("CAPTURE clear cart visible=", order.get_node_or_null("Safe/VBox/CartBar/Row/ClearCart").visible if order.get_node_or_null("Safe/VBox/CartBar/Row/ClearCart") else false)
	if change_scene_to_file("res://scenes/explore/explore_3d.tscn") != OK:
		push_error("CAPTURE FAIL explore")
		quit(1)
		return
	for _k in 28:
		await process_frame
	var player := current_scene.get_node_or_null("Player")
	if player and player.has_method("toss_cookie"):
		player.call("toss_cookie")
	for _n in 4:
		await process_frame
	if not await _snap(disk, "explore_toss_cookie.png"):
		quit(1)
		return
	print("CAPTURE cookie projectiles=", root.get_tree().get_nodes_in_group("cookie_projectile").size())
	quit(0)


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
