extends SceneTree
## Portrait proof: phone login, logged-in home (name + previous orders).
##   DISPLAY=:1 godot --path . --rendering-method gl_compatibility --resolution 720x1280 \
##     -s res://tools/capture_account.gd

const OUT := "res://export/review"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gs := root.get_node("GameSave")
	var ac := root.get_node("AccountClient")
	gs.call("clear_square_session")
	if change_scene_to_file("res://scenes/account/login.tscn") != OK:
		push_error("CAPTURE FAIL login")
		quit(1)
		return
	for _i in 20:
		await process_frame
		await RenderingServer.frame_post_draw
	if not _snap("login_phone.png"):
		quit(1)
		return
	ac.call(
		"apply_square_payload",
		{
			"ok": true,
			"created": false,
			"customer": {
				"id": "CUST_CAPTURE",
				"phone": "+12055550123",
				"given_name": "Ada",
				"family_name": "Lovelace",
				"nickname": "",
				"display_name": "Ada Lovelace",
			},
			"orders": [
				{
					"id": "ORD_CAPTURE",
					"name": "Nutella Croissant",
					"date": "2026-09-14",
					"total_cents": 600,
					"items": [{"name": "Nutella Croissant", "qty": 1}],
				}
			],
		}
	)
	if change_scene_to_file("res://scenes/main_menu.tscn") != OK:
		push_error("CAPTURE FAIL menu")
		quit(1)
		return
	for _j in 24:
		await process_frame
		await RenderingServer.frame_post_draw
	if not _snap("home_logged_in.png"):
		quit(1)
		return
	if not _snap("previous_orders.png"):
		quit(1)
		return
	if change_scene_to_file("res://scenes/order/order.tscn") != OK:
		push_error("CAPTURE FAIL order")
		quit(1)
		return
	var waited := 0.0
	var oc := root.get_node("OrderClient")
	while waited < 12.0 and oc.call("drinks").is_empty():
		await process_frame
		waited += 0.05
	if current_scene:
		current_scene.set("_my_status", {
			"open_orders": [{
				"id": "ORD_OPEN",
				"name": "Nutella Croissant",
				"status": "making",
				"order_number": "42",
				"ahead": 2,
				"items": [{"name": "Nutella Croissant", "qty": 1}],
			}]
		})
		if current_scene.has_method("_set_tab"):
			current_scene.call("_set_tab", 2)
	for _k in 20:
		await process_frame
		await RenderingServer.frame_post_draw
	if not _snap("order_status.png"):
		quit(1)
		return
	print("CAPTURE account screens ok")
	quit(0)


func _snap(name: String) -> bool:
	var disk_dir := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("CAPTURE FAIL image " + name)
		return false
	var disk := disk_dir.path_join(name)
	var err := img.save_png(disk)
	print("CAPTURE ", name, " ", img.get_width(), "x", img.get_height(), " -> ", disk, " err=", err)
	return err == OK
