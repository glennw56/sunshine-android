extends SceneTree
## Phone-viewport proof that Order category chips wrap, stay tappable,
## and keep a stable selected style. Filter behavior stays strict.
##   DISPLAY=:1 godot --path . --display-driver x11 --rendering-driver opengl3 \
##     --resolution 720x1280 --audio-driver Dummy -s res://tools/capture_order_chips.gd

const ARTIFACT_DIR := "/opt/cursor/artifacts"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	DirAccess.make_dir_recursive_absolute(ARTIFACT_DIR)
	if change_scene_to_file("res://scenes/order/order.tscn") != OK:
		push_error("CHIPS FAIL load order")
		quit(1)
		return
	var scene_wait := 0.0
	while scene_wait < 8.0:
		await process_frame
		if current_scene and str(current_scene.scene_file_path).ends_with("order.tscn"):
			break
		scene_wait += 0.05
	var oc := root.get_node("OrderClient")
	var waited := 0.0
	while waited < 20.0:
		var pastry_n := 0
		for drink in oc.call("drinks"):
			if drink is Dictionary and str(oc.call("item_ui_category", drink)) == "pastry":
				pastry_n += 1
		if (oc.call("shop_drinks") as Array).size() >= 20 and pastry_n >= 5:
			break
		await process_frame
		waited += 0.05
	if current_scene == null or oc.call("shop_drinks").is_empty():
		push_error("CHIPS FAIL catalog/scene")
		quit(1)
		return
	current_scene.call("_select_category", "all")
	for _i in 10:
		await process_frame
		await RenderingServer.frame_post_draw
	if not _assert_row_layout():
		quit(1)
		return
	if _shot("%s/order_chips_row.png" % disk_dir, "order_chips_row.png") == null:
		quit(1)
		return
	var chips := ["all", "drink", "pastry", "savory", "bread", "more"]
	for cat in chips:
		current_scene.call("_select_category", cat)
		for _j in 8:
			await process_frame
			await RenderingServer.frame_post_draw
		if not _assert_selected(cat):
			quit(1)
			return
		if not _assert_row_layout():
			quit(1)
			return
		if _shot("%s/order_chips_%s.png" % [disk_dir, cat], "order_chips_%s.png" % cat) == null:
			quit(1)
			return
		if cat == "drink" and not await _assert_scroll_keeps_row():
			quit(1)
			return
	print("CHIPS OK")
	quit(0)


func _assert_selected(cat: String) -> bool:
	if str(current_scene.call("selected_category")) != cat:
		push_error("CHIPS FAIL selected=%s want=%s" % [current_scene.call("selected_category"), cat])
		return false
	var titles := {
		"all": "All",
		"drink": "Drinks",
		"pastry": "Pastries",
		"savory": "Savory",
		"bread": "Bread",
		"more": "Merch",
	}
	var want := str(titles.get(cat, cat))
	var selected_n := 0
	for chip in current_scene.call("category_chips"):
		var btn := chip as Button
		if btn == null:
			continue
		if btn.text.find("✓") >= 0:
			push_error("CHIPS FAIL checkmark prefix on %s" % btn.text)
			return false
		var on := str(btn.name) == ("Chip_%s" % cat)
		if on:
			selected_n += 1
			if btn.text != want:
				push_error("CHIPS FAIL selected text %s want %s" % [btn.text, want])
				return false
			if not bool(btn.get_meta("chip_selected", false)):
				push_error("CHIPS FAIL %s missing selected style" % btn.name)
				return false
		elif bool(btn.get_meta("chip_selected", false)):
			push_error("CHIPS FAIL %s looks selected while %s is active" % [btn.name, cat])
			return false
	if selected_n != 1:
		push_error("CHIPS FAIL expected one selected pill, got %d" % selected_n)
		return false
	var rows: Array = current_scene.call("visible_item_rows")
	for row in rows:
		if cat != "all" and str((row as Node).get_meta("item_category", "")) != cat:
			push_error("CHIPS FAIL filter leaked %s" % (row as Node).get_meta("item_name", ""))
			return false
	print("CHIPS selected ", cat, " label=", want, " rows=", rows.size())
	return true


func _assert_row_layout() -> bool:
	var wrap := current_scene.get_node_or_null("Safe/VBox/Jumps") as Control
	var row := current_scene.get_node_or_null("Safe/VBox/Jumps/Row")
	if wrap == null or row == null:
		push_error("CHIPS FAIL jumps row missing")
		return false
	if not row is HFlowContainer:
		push_error("CHIPS FAIL row must be HFlowContainer, got %s" % row.get_class())
		return false
	var view := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var chips: Array = current_scene.call("category_chips")
	if chips.size() < 6:
		push_error("CHIPS FAIL expected All+5 categories, got %d" % chips.size())
		return false
	var names := PackedStringArray()
	var prev: Rect2
	var i := 0
	for chip in chips:
		var btn := chip as Button
		var r := btn.get_global_rect()
		names.append(btn.text)
		if r.position.x < -1.0 or r.end.x > view.size.x + 1.0:
			push_error("CHIPS FAIL %s clipped %s view=%.0f" % [btn.text, r, view.size.x])
			return false
		if r.size.x < 80.0 or r.size.y < 48.0:
			push_error("CHIPS FAIL %s hit target %s" % [btn.text, r.size])
			return false
		if i > 0 and prev.grow(-2.0).intersects(r.grow(-2.0)):
			push_error("CHIPS FAIL overlap %s vs %s" % [names[i - 1], btn.text])
			return false
		prev = r
		i += 1
	if not names.has("Merch"):
		push_error("CHIPS FAIL Merch chip missing from row")
		return false
	print("CHIPS layout ", names, " wrap_h=", wrap.size.y)
	return true


func _assert_scroll_keeps_row() -> bool:
	var body := current_scene.get_node_or_null("Safe/VBox/Body") as ScrollContainer
	var wrap := current_scene.get_node_or_null("Safe/VBox/Jumps") as Control
	if body == null or wrap == null or not wrap.visible:
		push_error("CHIPS FAIL chip row must stay visible while the list scrolls")
		return false
	var bar := body.get_v_scroll_bar()
	body.scroll_vertical = maxi(400, int(bar.max_value) if bar else 400)
	for _i in 6:
		await process_frame
		await RenderingServer.frame_post_draw
	if str(current_scene.call("selected_category")) != "drink" or not wrap.visible:
		push_error("CHIPS FAIL scroll hid or switched the chip row")
		return false
	if _shot(
		ProjectSettings.globalize_path("res://export/review").path_join("order_chips_drink_scrolled.png"),
		"order_chips_drink_scrolled.png"
	) == null:
		return false
	print("CHIPS scroll kept drink row visible")
	return true


func _shot(disk: String, artifact_name: String) -> Image:
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("CHIPS FAIL screenshot " + artifact_name)
		return null
	if img.save_png(disk) != OK:
		push_error("CHIPS FAIL save " + disk)
		return null
	img.save_png("%s/%s" % [ARTIFACT_DIR, artifact_name])
	print("CAPTURE ", artifact_name, " ", img.get_width(), "x", img.get_height())
	return img
