extends SceneTree
## Proof: empty-cache ORDER shows named Square drinks with prices.
##   DISPLAY=:1 godot --path . --display-driver x11 --rendering-driver opengl3 \
##     --resolution 720x1280 -s res://tools/capture_ux_46.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var disk := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk)
	var oc := root.get_node("OrderClient")
	var gs := root.get_node("GameSave")
	gs.set("cached_square_menu", {})
	oc.set("menu", {})
	oc.set("_last_menu_fingerprint", "")
	oc.set("_menu_fetching", false)
	oc.set("_last_fetch_result", {})
	oc.call("clear_cart")
	var t0 := Time.get_ticks_msec()
	var result: Dictionary = await oc.call("fetch_menu")
	var msec := Time.get_ticks_msec() - t0
	var drinks: Array = oc.call("drinks")
	print("CAPTURE fetch_menu msec=", msec, " ok=", result.get("ok"), " count=", drinks.size())
	var names := PackedStringArray()
	var biscoff := false
	var viet := false
	for item in drinks:
		if not item is Dictionary:
			continue
		var n := str(item.get("name", "")).strip_edges()
		names.append("%s $%0.2f" % [n, float(item.get("price_cents", 0)) / 100.0])
		if n == "Biscoff Coffee" and int(item.get("price_cents", 0)) > 0:
			biscoff = true
		if n == "Vietnamese Coffee" and int(item.get("price_cents", 0)) > 0:
			viet = true
	print("CAPTURE items ", ", ".join(names))
	if msec > 5000:
		push_error("CAPTURE FAIL drinks-primary fetch_menu too slow (%d ms)" % msec)
		quit(1)
		return
	if not bool(result.get("ok", false)) or drinks.is_empty() or not biscoff or not viet:
		push_error("CAPTURE FAIL named Square drinks with prices did not load")
		quit(1)
		return
	if change_scene_to_file("res://scenes/order/order.tscn") != OK:
		push_error("CAPTURE FAIL order")
		quit(1)
		return
	for _i in 18:
		await process_frame
		await RenderingServer.frame_post_draw
	var scene := current_scene
	if scene == null:
		push_error("CAPTURE FAIL no order scene")
		quit(1)
		return
	if _label_has(scene, "Couldn’t load the menu") or _label_has(scene, "taking too long"):
		push_error("CAPTURE FAIL Order showed catalog error")
		quit(1)
		return
	if not _label_has(scene, "Biscoff Coffee") or not _label_has(scene, "Vietnamese Coffee"):
		push_error("CAPTURE FAIL Order UI missing named drinks")
		quit(1)
		return
	var png := "%s/order_menu_items_loaded.png" % disk
	var img := scene.get_viewport().get_texture().get_image()
	if img == null or img.save_png(png) != OK:
		push_error("CAPTURE FAIL screenshot")
		quit(1)
		return
	print("CAPTURE wrote ", png)
	print("CAPTURE 0.1.46 ORDER named Square items loaded")
	quit(0)


func _label_has(n: Node, needle: String) -> bool:
	if n is Label and str((n as Label).text).find(needle) >= 0:
		return true
	if n is Button and str((n as Button).text).find(needle) >= 0:
		return true
	for child in n.get_children():
		if _label_has(child, needle):
			return true
	return false
