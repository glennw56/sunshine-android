extends SceneTree
## Portrait shots of the Loyalty screen (guest, 140 points, top reward) and the menu button.
##   xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 720x1280 \
##     --audio-driver Dummy -s res://tools/capture_loyalty.gd

const RECIPE := {
	"skin": "peach",
	"hair": "bun",
	"hair_color": "honey",
	"outfit": "blush",
	"bottoms": "skirt",
	"pants": "wine",
	"apron": "blush",
	"hat": "sun",
	"accessory": "glasses",
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var disk_dir := "/opt/cursor/artifacts/screenshots"
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var gs: Node = root.get_node("GameSave")
	gs.call("clear_square_session")
	gs.set("avatar_recipe", RECIPE.duplicate(true))
	gs.call("set_account_guest")
	if change_scene_to_file("res://scenes/loyalty/loyalty.tscn") != OK:
		push_error("CAPTURE FAIL loyalty guest")
		quit(1)
		return
	if not await _settle():
		quit(1)
		return
	if not _snap(disk_dir, "loyalty_guest.png"):
		quit(1)
		return
	gs.call("clear_square_session")
	gs.set("avatar_recipe", RECIPE.duplicate(true))
	gs.call("set_square_session", _payload(140))
	if change_scene_to_file("res://scenes/loyalty/loyalty.tscn") != OK:
		push_error("CAPTURE FAIL loyalty 140")
		quit(1)
		return
	if not await _settle():
		quit(1)
		return
	if not _snap(disk_dir, "loyalty_140.png"):
		quit(1)
		return
	gs.call("set_square_session", _payload(200))
	if change_scene_to_file("res://scenes/loyalty/loyalty.tscn") != OK:
		push_error("CAPTURE FAIL loyalty 200")
		quit(1)
		return
	if not await _settle():
		quit(1)
		return
	if not _snap(disk_dir, "loyalty_200.png"):
		quit(1)
		return
	if change_scene_to_file("res://scenes/main_menu.tscn") != OK:
		push_error("CAPTURE FAIL menu")
		quit(1)
		return
	for _i in 12:
		await process_frame
		await RenderingServer.frame_post_draw
	if not _snap(disk_dir, "loyalty_menu.png"):
		quit(1)
		return
	print("CAPTURE loyalty screens ok")
	quit(0)


func _payload(points: int) -> Dictionary:
	return {
		"customer": {
			"id": "CUST_LOYALTY_PREVIEW",
			"phone": "+12055550123",
			"given_name": "Ada",
			"family_name": "Baker",
			"display_name": "Ada Baker",
		},
		"loyalty": {
			"enrolled": true,
			"account_id": "LOY_PREVIEW",
			"points": points,
			"program_id": "PROG_PREVIEW",
		},
	}


func _settle() -> bool:
	for _i in 36:
		await process_frame
		await RenderingServer.frame_post_draw
	return true


func _snap(disk_dir: String, name: String) -> bool:
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("CAPTURE FAIL image " + name)
		return false
	var disk := disk_dir.path_join(name)
	var err := img.save_png(disk)
	print("CAPTURE ", name, " ", img.get_width(), "x", img.get_height(), " -> ", disk, " err=", err)
	return err == OK
