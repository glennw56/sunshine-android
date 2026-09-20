extends SceneTree
## Phone-viewport proof that Order category tabs are pinned and do not move.
## Fixed 2×3 grid, no chip-row scroll, filter stays strict.
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
	var baseline := _chip_geometry()
	if not _assert_row_layout(baseline):
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
		var now := _chip_geometry()
		if not _assert_row_layout(now):
			quit(1)
			return
		if not _assert_same_geometry(baseline, now, "select %s" % cat):
			quit(1)
			return
		if _shot("%s/order_chips_%s.png" % [disk_dir, cat], "order_chips_%s.png" % cat) == null:
			quit(1)
			return
		if cat == "drink" and not await _assert_scroll_keeps_row(now):
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


func _chip_geometry() -> Dictionary:
	var wrap := current_scene.get_node_or_null("Safe/VBox/Jumps") as Control
	var out := {
		"wrap_pos": wrap.get_global_rect() if wrap else Rect2(),
		"chips": {},
	}
	for chip in current_scene.call("category_chips"):
		var btn := chip as Button
		if btn:
			out["chips"][btn.name] = btn.get_global_rect()
	return out


func _assert_same_geometry(before: Dictionary, after: Dictionary, why: String) -> bool:
	var a: Rect2 = before.get("wrap_pos", Rect2())
	var b: Rect2 = after.get("wrap_pos", Rect2())
	if a.position.distance_to(b.position) > 0.5 or absf(a.size.x - b.size.x) > 0.5 or absf(a.size.y - b.size.y) > 0.5:
		push_error("CHIPS FAIL tab bar moved on %s: %s -> %s" % [why, a, b])
		return false
	var before_chips: Dictionary = before.get("chips", {})
	var after_chips: Dictionary = after.get("chips", {})
	if before_chips.size() != after_chips.size():
		push_error("CHIPS FAIL chip count changed on %s" % why)
		return false
	for name in before_chips.keys():
		var r0: Rect2 = before_chips[name]
		var r1: Rect2 = after_chips.get(name, Rect2())
		if r0.position.distance_to(r1.position) > 0.5 or absf(r0.size.x - r1.size.x) > 0.5 or absf(r0.size.y - r1.size.y) > 0.5:
			push_error("CHIPS FAIL %s moved on %s: %s -> %s" % [name, why, r0, r1])
			return false
	print("CHIPS geometry stable on ", why, " wrap_y=", b.position.y)
	return true


func _assert_row_layout(geo: Dictionary) -> bool:
	var wrap := current_scene.get_node_or_null("Safe/VBox/Jumps") as Control
	var row := current_scene.get_node_or_null("Safe/VBox/Jumps/Row")
	if wrap == null or row == null:
		push_error("CHIPS FAIL jumps row missing")
		return false
	if wrap is ScrollContainer:
		push_error("CHIPS FAIL Jumps must not be a ScrollContainer")
		return false
	if not row is GridContainer:
		push_error("CHIPS FAIL row must be GridContainer, got %s" % row.get_class())
		return false
	if (row as GridContainer).columns != 3:
		push_error("CHIPS FAIL grid must be 3 columns, got %d" % (row as GridContainer).columns)
		return false
	var view := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var chips: Array = current_scene.call("category_chips")
	if chips.size() != 6:
		push_error("CHIPS FAIL expected fixed All+5 categories, got %d" % chips.size())
		return false
	var names := PackedStringArray()
	var ys: Array = []
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
		if i > 0:
			var prev: Rect2 = (chips[i - 1] as Control).get_global_rect()
			if prev.grow(-2.0).intersects(r.grow(-2.0)):
				push_error("CHIPS FAIL overlap %s vs %s" % [names[i - 1], btn.text])
				return false
		if not ys.has(snappedf(r.position.y, 1.0)):
			ys.append(snappedf(r.position.y, 1.0))
		i += 1
	if ys.size() != 2:
		push_error("CHIPS FAIL expected a fixed 2-row wrap, got rows=%s" % [ys])
		return false
	if not names.has("Merch"):
		push_error("CHIPS FAIL Merch chip missing from row")
		return false
	print("CHIPS layout ", names, " rows=", ys, " wrap=", geo.get("wrap_pos", Rect2()))
	return true


func _assert_scroll_keeps_row(before: Dictionary) -> bool:
	var body := current_scene.get_node_or_null("Safe/VBox/Body") as ScrollContainer
	var wrap := current_scene.get_node_or_null("Safe/VBox/Jumps") as Control
	if body == null or wrap == null or not wrap.visible:
		push_error("CHIPS FAIL chip row must stay visible while the list scrolls")
		return false
	if wrap is ScrollContainer:
		push_error("CHIPS FAIL Jumps must stay a non-scroll pin, not ScrollContainer")
		return false
	if _shot(
		ProjectSettings.globalize_path("res://export/review").path_join("order_chips_drink_before_scroll.png"),
		"order_chips_drink_before_scroll.png"
	) == null:
		return false
	var bar := body.get_v_scroll_bar()
	var max_y := 800
	if bar:
		max_y = maxi(800, int(bar.max_value))
	body.scroll_vertical = max_y
	for _i in 10:
		await process_frame
		await RenderingServer.frame_post_draw
	if str(current_scene.call("selected_category")) != "drink" or not wrap.visible:
		push_error("CHIPS FAIL scroll hid or switched the chip row")
		return false
	var after := _chip_geometry()
	if not _assert_same_geometry(before, after, "hard list scroll"):
		return false
	if _shot(
		ProjectSettings.globalize_path("res://export/review").path_join("order_chips_drink_scrolled.png"),
		"order_chips_drink_scrolled.png"
	) == null:
		return false
	print(
		"CHIPS pin proof drink wrap_y=",
		(after.get("wrap_pos", Rect2()) as Rect2).position.y,
		" list_y=",
		body.scroll_vertical
	)
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
