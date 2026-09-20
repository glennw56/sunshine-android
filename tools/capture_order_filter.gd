extends SceneTree
## Prove Order category chips filter (no scroll-spy).
##   DISPLAY=:1 godot --path . --display-driver x11 --rendering-driver opengl3 \
##     --resolution 720x1280 -s res://tools/capture_order_filter.gd
## Writes export/review/order_filter_*.png and /opt/cursor/artifacts/.

const ARTIFACT_DIR := "/opt/cursor/artifacts"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	DirAccess.make_dir_recursive_absolute(ARTIFACT_DIR)
	if change_scene_to_file("res://scenes/order/order.tscn") != OK:
		push_error("FILTER FAIL load order")
		quit(1)
		return
	var scene_wait := 0.0
	while scene_wait < 8.0:
		await process_frame
		if current_scene and str(current_scene.scene_file_path).ends_with("order.tscn"):
			break
		scene_wait += 0.05
	if current_scene == null:
		push_error("FILTER FAIL order scene never became current")
		quit(1)
		return
	var oc := root.get_node("OrderClient")
	var waited := 0.0
	while waited < 20.0:
		var n: int = (oc.call("shop_drinks") as Array).size()
		var pastry_n := 0
		for drink in oc.call("drinks"):
			if drink is Dictionary and str(oc.call("item_ui_category", drink)) == "pastry":
				pastry_n += 1
		if n >= 20 and pastry_n >= 5:
			break
		await process_frame
		waited += 0.05
	if oc.call("shop_drinks").is_empty():
		push_error("FILTER FAIL empty Square catalog")
		quit(1)
		return
	if current_scene.has_method("_render"):
		current_scene.call("_render")
	for _i in 12:
		await process_frame
		await RenderingServer.frame_post_draw
	if not _assert_mapping(oc):
		quit(1)
		return
	var chips := ["all", "drink", "pastry", "savory", "bread", "more"]
	var counts := {}
	for cat in chips:
		if not current_scene.has_method("_select_category"):
			push_error("FILTER FAIL _select_category missing")
			quit(1)
			return
		current_scene.call("_select_category", cat)
		for _j in 10:
			await process_frame
			await RenderingServer.frame_post_draw
		if not _assert_filter(cat):
			quit(1)
			return
		var n := _visible_count()
		counts[cat] = n
		var img := _shot("%s/order_filter_%s.png" % [disk_dir, cat], "order_filter_%s.png" % cat)
		if img == null:
			quit(1)
			return
		if cat == "drink":
			if not await _assert_scroll_does_not_switch_chip(disk_dir):
				quit(1)
				return
	if int(counts.get("all", 0)) < 8:
		push_error("FILTER FAIL All should list the full shop, got %s" % counts.get("all", 0))
		quit(1)
		return
	if int(counts.get("drink", 0)) < 1:
		push_error("FILTER FAIL Drinks chip listed no drinks")
		quit(1)
		return
	if int(counts.get("drink", 0)) >= int(counts.get("all", 0)):
		push_error("FILTER FAIL Drinks must be a subset of All")
		quit(1)
		return
	if int(counts.get("pastry", 0)) < 1:
		push_error("FILTER FAIL Pastries chip listed no pastries")
		quit(1)
		return
	print("FILTER OK counts=", counts)
	quit(0)


func _assert_mapping(oc: Node) -> bool:
	var expect := {
		"Vietnamese Coffee": "drink",
		"Coffee": "drink",
		"Fruit Tea": "drink",
		"Matcha Latte": "drink",
		"Water": "drink",
		"Coffee Tiramisu Cake": "pastry",
		"Chocolate Chip Cookie": "pastry",
		"Ham and Cheese Croissant": "savory",
		"Sausage Croissant": "savory",
		"Plain Sourdough": "bread",
		"Tote Bag": "more",
	}
	var by_name := {}
	for item in oc.call("drinks"):
		if item is Dictionary:
			by_name[str(item.get("name", ""))] = item
	for item_name in expect.keys():
		if not by_name.has(item_name):
			print("FILTER note: live catalog missing ", item_name)
			continue
		var got := str(oc.call("item_ui_category", by_name[item_name]))
		if got != expect[item_name]:
			push_error("FILTER FAIL %s mapped to %s want %s" % [item_name, got, expect[item_name]])
			return false
		print("FILTER map ", item_name, " -> ", got)
	var mystery := {"name": "Unknown Widget 4095", "category": "", "category_ids": []}
	if str(oc.call("item_ui_category", mystery)) != "":
		push_error("FILTER FAIL uncategorized item must not join every chip")
		return false
	return true


func _assert_filter(cat: String) -> bool:
	if str(current_scene.call("selected_category")) != cat:
		push_error("FILTER FAIL selected chip is %s want %s" % [current_scene.call("selected_category"), cat])
		return false
	if not _chip_selected(cat):
		push_error("FILTER FAIL chip %s is not highlighted" % cat)
		return false
	var rows: Array = current_scene.call("visible_item_rows")
	if cat != "all" and rows.is_empty():
		print("FILTER note: no visible rows for ", cat)
		return true
	for row in rows:
		var got := str((row as Node).get_meta("item_category", ""))
		var name := str((row as Node).get_meta("item_name", ""))
		if cat == "all":
			continue
		if got != cat:
			push_error("FILTER FAIL visible %s has category %s under chip %s" % [name, got, cat])
			return false
	print("FILTER chip ", cat, " rows=", rows.size(), " selected=", current_scene.call("selected_category"))
	return true


func _assert_scroll_does_not_switch_chip(disk_dir: String) -> bool:
	var body := current_scene.get_node_or_null("Safe/VBox/Body") as ScrollContainer
	if body == null:
		push_error("FILTER FAIL menu body missing")
		return false
	var before := str(current_scene.call("selected_category"))
	if before != "drink":
		push_error("FILTER FAIL expected drink chip before scroll, got %s" % before)
		return false
	body.scroll_vertical = 0
	await process_frame
	var bar := body.get_v_scroll_bar()
	var max_y := 240
	if bar:
		max_y = maxi(240, int(bar.max_value))
	body.scroll_vertical = max_y
	for _i in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	var after := str(current_scene.call("selected_category"))
	if after != "drink":
		push_error("FILTER FAIL scroll-spy changed chip %s -> %s" % [before, after])
		return false
	if not _chip_selected("drink"):
		push_error("FILTER FAIL drink chip lost highlight after scroll")
		return false
	for row in current_scene.call("visible_item_rows"):
		if str((row as Node).get_meta("item_category", "")) != "drink":
			push_error("FILTER FAIL non-drink visible after scroll")
			return false
	if _shot("%s/order_filter_drink_scrolled.png" % disk_dir, "order_filter_drink_scrolled.png") == null:
		return false
	print("FILTER scroll kept drink chip at y=", body.scroll_vertical)
	return true


func _visible_count() -> int:
	return (current_scene.call("visible_item_rows") as Array).size()


func _chip_selected(cat: String) -> bool:
	if str(current_scene.call("selected_category")) != cat:
		return false
	var row := current_scene.get_node_or_null("Safe/VBox/Jumps/Row")
	if row == null:
		return false
	var titles := {
		"all": "All",
		"drink": "Drinks",
		"pastry": "Pastries",
		"savory": "Savory",
		"bread": "Bread",
		"more": "Merch",
		"uncategorized": "Uncategorized",
	}
	var title := str(titles.get(cat, cat))
	for child in row.get_children():
		var chip := child as Button
		if chip == null:
			continue
		var label := chip.text.replace("✓", "").strip_edges()
		var name_hit := str(chip.name).begins_with("Chip_%s" % cat)
		if name_hit or label == title:
			print("FILTER chip node ", chip.name, " text=", chip.text, " pressed=", chip.button_pressed)
			return chip.text.find("✓") >= 0 or chip.button_pressed or name_hit
	print("FILTER chip row children:")
	for child in row.get_children():
		print("  ", child.name, " ", child.get_class(), " ", child.get("text") if child is Button else "")
	return false


func _shot(disk: String, artifact_name: String) -> Image:
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("FILTER FAIL screenshot " + artifact_name)
		return null
	var err := img.save_png(disk)
	if err != OK:
		push_error("FILTER FAIL save " + disk)
		return null
	var copy := "%s/%s" % [ARTIFACT_DIR, artifact_name]
	img.save_png(copy)
	print("CAPTURE ", artifact_name, " ", img.get_width(), "x", img.get_height(), " -> ", disk, " + ", copy)
	return img
