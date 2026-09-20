extends SceneTree
## Lawn DONATE above Tip, then the Square donation sheet.
##   godot --headless --path . --resolution 720x1280 -s res://tools/capture_donate.gd

const OUT := "res://export/review"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gs := root.get_node("GameSave")
	var ac := root.get_node("AccountClient")
	gs.call("clear_square_session")
	gs.call("set_last_donate_name", "")
	ac.call(
		"apply_square_payload",
		{
			"ok": true,
			"created": false,
			"customer": {
				"id": "CUST_DONATE",
				"phone": "+12055550123",
				"given_name": "Ada",
				"family_name": "Lovelace",
				"display_name": "Ada Lovelace",
			},
			"orders": [],
		}
	)
	if change_scene_to_file("res://scenes/main_menu.tscn") != OK:
		push_error("CAPTURE FAIL menu")
		quit(1)
		return
	await _settle(24)
	var donate := current_scene.get_node_or_null("Safe/VBox/DonateButton") as Button
	var tip := current_scene.get_node_or_null("Safe/VBox/TipButton") as Button
	if donate == null or tip == null or donate.get_index() >= tip.get_index():
		push_error("CAPTURE FAIL Donate must sit above Tip")
		quit(1)
		return
	if not _snap("lawn_donate_above_tip.png"):
		quit(1)
		return
	donate.pressed.emit()
	var waited := 0.0
	while waited < 8.0:
		await process_frame
		waited += 0.05
		if current_scene and str(current_scene.scene_file_path).ends_with("donate.tscn"):
			break
	if current_scene == null or not str(current_scene.scene_file_path).ends_with("donate.tscn"):
		push_error("CAPTURE FAIL donate scene")
		quit(1)
		return
	await _settle(12)
	var note := current_scene.get_node_or_null("Safe/Stack/Scroll/Center/Card/Pad/Col/ProgressNote") as Label
	var fetch_wait := 0.0
	while fetch_wait < 8.0:
		if note and note.text.find("From the Square") >= 0:
			break
		await process_frame
		fetch_wait += 0.05
	await _settle(8)
	if not _snap("donate_sheet.png"):
		quit(1)
		return
	var bar := current_scene.get_node_or_null("Safe/Stack/Scroll/Center/Card/Pad/Col/Progress") as ProgressBar
	var name_field := current_scene.get_node_or_null("Safe/Stack/Scroll/Center/Card/Pad/Col/Name") as LineEdit
	if bar == null or name_field == null:
		push_error("CAPTURE FAIL donate controls")
		quit(1)
		return
	print(
		"CAPTURE donate ok goal_bar=",
		bar.value,
		" name_placeholder=",
		name_field.placeholder_text,
		" note=",
		note.text if note else "?"
	)
	quit(0)


func _settle(frames: int) -> void:
	for _i in frames:
		await process_frame
		await RenderingServer.frame_post_draw


func _snap(name: String) -> bool:
	var img := get_root().get_viewport().get_texture().get_image()
	if img == null:
		push_error("CAPTURE FAIL empty " + name)
		return false
	var dir := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(dir)
	var err := img.save_png(dir.path_join(name))
	if err != OK:
		push_error("CAPTURE FAIL write " + name + " " + str(err))
		return false
	print("CAPTURE ", name)
	return true
