extends SceneTree
## Status: paid making + app order xxx + ahead stills.
##   DISPLAY=:1 godot --path . --display-driver x11 --rendering-driver opengl3 \
##     --resolution 720x1280 -s res://tools/capture_ux_41.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var disk := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk)
	var oc := root.get_node("OrderClient")
	var ac := root.get_node("AccountClient")
	oc.call("restore_cached_menu")
	oc.call("clear_cart")
	ac.call("apply_square_payload", {
		"ok": true,
		"session_token": "sess_capture_status",
		"customer": {
			"id": "CUST_CAPTURE",
			"phone": "+12055550123",
			"given_name": "Ada",
			"family_name": "Lovelace",
			"nickname": "",
			"display_name": "Ada Lovelace",
		},
	})
	if change_scene_to_file("res://scenes/order/order.tscn") != OK:
		push_error("CAPTURE FAIL order")
		quit(1)
		return
	await _settle(16)
	var order := current_scene
	order.set("_detail_drink", {})
	order.set("_tab", 2)
	order.set("_my_status", {
		"open_orders": [{
			"id": "OPEN_UNPAID",
			"name": "Unpaid checkout",
			"status": "making",
			"order_number": "99",
			"ahead": 0,
			"items": [{"name": "Should hide unpaid", "qty": 1}],
		}, {
			"id": "PAID_READY",
			"name": "Ready pastry",
			"status": "ready",
			"paid": true,
			"order_number": "7",
			"ahead": 0,
			"items": [{"name": "Should hide ready", "qty": 1}],
		}, {
			"id": "PAID_MAKING",
			"name": "Nutella Croissant",
			"status": "making",
			"paid": true,
			"tender_count": 1,
			"net_amount_due_cents": 0,
			"order_number": "42",
			"ahead": 2,
			"items": [{
				"name": "Nutella Croissant",
				"qty": 1,
				"modifiers": [{"name": "Reheat"}],
				"detail": "Reheat",
			}],
		}],
	})
	if order.has_method("_render"):
		order.call("_render")
	await _settle(12)
	if not await _snap(disk, "order_status_making.png"):
		quit(1)
		return
	order.set("_my_status", {"open_orders": []})
	order.set("_status_error", "Square status unavailable.")
	if order.has_method("_render"):
		order.call("_render")
	await _settle(8)
	if not await _snap(disk, "order_status_error.png"):
		quit(1)
		return
	print("CAPTURE 0.1.41 status done")
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
