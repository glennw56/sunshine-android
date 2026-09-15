extends SceneTree
## Portrait proof: Order list with Square $ prices + sticky cart total after add.
##   DISPLAY=:1 godot --path . --rendering-method gl_compatibility --resolution 720x1280 \
##     -s res://tools/capture_order_prices.gd
## Writes export/review/order_prices_cart.png

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://scenes/order/order.tscn") != OK:
		push_error("CAPTURE FAIL load order")
		quit(1)
		return
	var oc := root.get_node("OrderClient")
	var waited := 0.0
	while waited < 12.0 and oc.call("drinks").is_empty():
		await process_frame
		waited += 0.05
	var pick: Dictionary = {}
	for drink in oc.call("drinks"):
		if drink is Dictionary and bool(oc.call("has_square_price", drink)) and int(drink.get("price_cents", 0)) > 0:
			if str(drink.get("category", "")) == "pastry":
				pick = drink
				break
			elif pick.is_empty():
				pick = drink
	if pick.is_empty():
		push_error("CAPTURE FAIL no Square-priced item")
		quit(1)
		return
	oc.call("clear_cart")
	oc.call("add_cart_item", str(pick.get("id", "")), {}, 1)
	if current_scene and current_scene.has_method("_render"):
		current_scene.call("_render")
	for _i in 24:
		await process_frame
		await RenderingServer.frame_post_draw
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("CAPTURE FAIL image")
		quit(1)
		return
	var disk := disk_dir.path_join("order_prices_cart.png")
	var err := img.save_png(disk)
	var summary := ""
	if current_scene:
		var lbl := current_scene.get_node_or_null("Safe/VBox/CartBar/Row/CartSummary") as Label
		if lbl:
			summary = lbl.text
	print(
		"CAPTURE order_prices_cart.png ",
		img.get_width(),
		"x",
		img.get_height(),
		" item=",
		pick.get("name"),
		" cents=",
		oc.call("cart_subtotal_cents"),
		" bar=",
		summary,
		" -> ",
		disk,
		" err=",
		err
	)
	quit(0 if err == OK else 1)
