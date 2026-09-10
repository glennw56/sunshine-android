extends SceneTree
## Press the three main-menu buttons and load each feature scene.
##   godot --headless --path . -s res://tools/launch_smoke.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://scenes/main_menu.tscn") != OK:
		push_error("LAUNCH FAIL main menu")
		quit(1)
		return
	if not await _wait_scene("main_menu.tscn"):
		return
	print("LAUNCH menu ok")
	if not await _press("Safe/VBox/OrderButton", "order.tscn"):
		return
	var drinks: Array = root.get_node("OrderClient").call("drinks")
	print("LAUNCH order ok drinks=", drinks.size())
	if drinks.is_empty():
		push_error("LAUNCH FAIL order catalog empty")
		quit(1)
		return
	if not await _press("Safe/VBox/Header/Back", "main_menu.tscn"):
		return
	if not await _press("Safe/VBox/TipButton", "tip_ad.tscn"):
		return
	print("LAUNCH tip ok")
	if not await _press("Safe/VBox/Header/Back", "main_menu.tscn"):
		return
	if not await _press("Safe/VBox/ExploreButton", "explore_3d.tscn"):
		return
	var explore := current_scene
	if explore.get_node_or_null("ReviewCameras") == null:
		push_error("LAUNCH FAIL ReviewCameras missing")
		quit(1)
		return
	var cams := 0
	for child in explore.get_node("ReviewCameras").get_children():
		if child is Camera3D:
			cams += 1
	print("LAUNCH explore ok cameras=", cams, " world=", explore.get_node("World").get_child_count())
	if cams < 8:
		push_error("LAUNCH FAIL expected 8 review cameras")
		quit(1)
		return
	if not await _press("HUD/Root/Top/Back", "main_menu.tscn"):
		return
	print("LAUNCH all Order / Tip Ad / Explore ok")
	quit(0)


func _press(path: String, expect_suffix: String) -> bool:
	var btn := current_scene.get_node_or_null(path) as BaseButton
	if btn == null:
		push_error("LAUNCH FAIL missing " + path + " on " + str(current_scene.scene_file_path))
		quit(1)
		return false
	btn.pressed.emit()
	return await _wait_scene(expect_suffix)


func _wait_scene(suffix: String) -> bool:
	var waited := 0.0
	while waited < 12.0:
		await process_frame
		waited += 0.05
		if current_scene == null:
			continue
		if str(current_scene.scene_file_path).ends_with(suffix):
			# Let _ready / HTTP finish a couple frames.
			await process_frame
			await process_frame
			if suffix.ends_with("order.tscn"):
				var catalog_wait := 0.0
				var oc := root.get_node("OrderClient")
				while catalog_wait < 8.0:
					var loaded: Array = oc.call("drinks")
					if not loaded.is_empty():
						break
					await process_frame
					catalog_wait += 0.05
			return true
	push_error("LAUNCH FAIL timeout waiting for " + suffix + " have " + str(current_scene.scene_file_path if current_scene else "null"))
	quit(1)
	return false
