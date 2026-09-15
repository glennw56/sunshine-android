extends SceneTree
## Capture every customer surface that must list Square modifiers.
##   DISPLAY=:1 godot --path . --rendering-method gl_compatibility --resolution 720x1280 \
##     -s res://tools/capture_mods_everywhere.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://scenes/order/order.tscn") != OK:
		push_error("CAPTURE FAIL order")
		quit(1)
		return
	var oc := root.get_node("OrderClient")
	var waited := 0.0
	while waited < 12.0 and oc.call("drinks").is_empty():
		await process_frame
		waited += 0.05
	var pick: Dictionary = {}
	for drink in oc.call("drinks"):
		if drink is Dictionary and drink.get("groups") is Array and (drink.get("groups") as Array).size() > 0:
			if bool(oc.call("has_square_price", drink)):
				pick = drink
				break
	if pick.is_empty():
		push_error("CAPTURE FAIL no Square drink with mods")
		quit(1)
		return
	var mods: Dictionary = oc.call("example_checkout_mods", pick)
	if current_scene and current_scene.has_method("_open_detail"):
		current_scene.call("_open_detail", pick, mods, 1)
	if not await _snap("order_item_mods.png"):
		quit(1)
		return
	oc.call("clear_cart")
	oc.call("add_cart_item", str(pick.get("id", "")), mods, 1)
	if current_scene:
		current_scene.set("_detail_drink", {})
		current_scene.set("_cart_edit_idx", -1)
		if current_scene.has_method("_set_tab"):
			current_scene.call("_set_tab", 1)
	if not await _snap("checkout_cart_mods.png"):
		quit(1)
		return
	var summary: String = oc.call("line_mod_summary", oc.get("cart")["items"][0])
	var labels: PackedStringArray = oc.call("line_mod_labels", oc.get("cart")["items"][0])
	var label_list: Array = []
	for lab in labels:
		label_list.append(str(lab))
	var ac := root.get_node("AccountClient")
	ac.call("apply_square_payload", {
		"ok": true,
		"session_token": "sess_capture_mods",
		"customer": {
			"id": "CUST_CAPTURE",
			"phone": "+12564525192",
			"given_name": "Ada",
			"family_name": "Lovelace",
			"display_name": "Ada Lovelace",
		},
		"orders": [{
			"id": "ORD_CAPTURE",
			"name": str(pick.get("name", "Order")),
			"date": "2026-09-14",
			"total_cents": 425,
			"items": [{
				"name": str(pick.get("name", "Coffee")),
				"qty": 1,
				"price_cents": 425,
				"modifiers": label_list,
				"detail": summary,
			}],
		}],
		"open_orders": [{
			"name": "Ada",
			"status": "making",
			"order_number": "42",
			"ahead": 1,
			"items": [{
				"name": str(pick.get("name", "Coffee")),
				"qty": 1,
				"id": str(pick.get("id", "")),
				"modifiers": mods,
			}],
		}],
	})
	if current_scene:
		current_scene.set("_detail_drink", {})
		current_scene.set("_tab", 2)
		current_scene.set("_my_status", {
			"open_orders": [{
				"name": "Ada",
				"status": "making",
				"order_number": "42",
				"ahead": 1,
				"items": [{
					"name": str(pick.get("name", "Coffee")),
					"qty": 1,
					"id": str(pick.get("id", "")),
					"modifiers": mods,
				}],
			}],
		})
		if current_scene.has_method("_render"):
			current_scene.call("_render")
	if not await _snap("order_status_mods.png"):
		quit(1)
		return
	if change_scene_to_file("res://scenes/main_menu.tscn") != OK:
		push_error("CAPTURE FAIL menu")
		quit(1)
		return
	await _settle(20)
	var btn := current_scene.get_node_or_null("Safe/VBox/PreviousOrdersButton") as Button
	if btn:
		btn.pressed.emit()
	if not await _snap("previous_orders_mods.png"):
		quit(1)
		return
	print(
		"CAPTURE mods everywhere item=",
		pick.get("name"),
		" mods=",
		summary,
		" bar=",
		_bar()
	)
	quit(0)


func _bar() -> String:
	if current_scene == null:
		return ""
	var lbl := current_scene.get_node_or_null("Safe/VBox/CartBar/Row/CartSummary") as Label
	return lbl.text if lbl else ""


func _settle(frames: int) -> void:
	for _i in frames:
		await process_frame
		await RenderingServer.frame_post_draw


func _snap(name: String) -> bool:
	await _settle(24)
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("CAPTURE FAIL image " + name)
		return false
	var err := img.save_png(disk_dir.path_join(name))
	print("CAPTURE ", name, " ", img.get_width(), "x", img.get_height(), " err=", err)
	return err == OK
