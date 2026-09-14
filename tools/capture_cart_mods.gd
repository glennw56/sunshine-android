extends SceneTree
## Cart / checkout with selected drink modifiers visible.
##   DISPLAY=:1 godot --path . --rendering-method gl_compatibility --resolution 720x1280 \
##     -s res://tools/capture_cart_mods.gd

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
	oc.call("clear_cart")
	oc.call("add_cart_item", str(pick.get("id", "")), mods, 1)
	if current_scene and current_scene.has_method("_set_tab"):
		current_scene.call("_set_tab", 1)
	for _i in 28:
		await process_frame
		await RenderingServer.frame_post_draw
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("CAPTURE FAIL image")
		quit(1)
		return
	var err := img.save_png(disk_dir.path_join("checkout_cart_mods.png"))
	var summary: String = oc.call("line_mod_summary", oc.get("cart")["items"][0])
	print(
		"CAPTURE checkout_cart_mods.png ",
		img.get_width(),
		"x",
		img.get_height(),
		" item=",
		pick.get("name"),
		" mods=",
		summary,
		" bar=",
		_bar(),
		" err=",
		err
	)
	quit(0 if err == OK else 1)


func _bar() -> String:
	if current_scene == null:
		return ""
	var lbl := current_scene.get_node_or_null("Safe/VBox/CartBar/Row/CartSummary") as Label
	return lbl.text if lbl else ""
