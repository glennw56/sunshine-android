extends SceneTree
## Readable customize / outfit shots for Game Design.
## Before the slot-picker layout, this scrolls each choice row.
## After show_slot() exists, it opens one slot at a time.
##   DISPLAY=:1 godot --path . --rendering-method gl_compatibility \
##     --resolution 720x1280 --audio-driver Dummy \
##     -s res://tools/capture_customize_review.gd

const DEFAULT_RECIPE := {
	"v": 1,
	"skin": "peach",
	"hair": "bangs",
	"hair_color": "brown",
	"outfit": "blush",
	"bottoms": "skirt",
	"pants": "wine",
	"apron": "grey",
	"hat": "sun",
	"accessory": "glasses",
}
const EMPTY_RECIPE := {
	"v": 1,
	"skin": "fair",
	"hair": "none",
	"hair_color": "brown",
	"outfit": "cream",
	"bottoms": "skirt",
	"pants": "cream",
	"apron": "none",
	"hat": "none",
	"accessory": "none",
}
const DRESSED_RECIPE := {
	"v": 1,
	"skin": "rich",
	"hair": "wavy",
	"hair_color": "honey",
	"outfit": "apricot",
	"bottoms": "pants",
	"pants": "navy",
	"apron": "wine",
	"hat": "beanie",
	"accessory": "glasses",
}
const SLOT_FIELDS := [
	"skin", "hair", "hair_color", "outfit", "apron", "hat", "accessory", "bottoms", "pants",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var phase := OS.get_environment("SUNSHINE_SHOT_PHASE").strip_edges()
	if phase == "":
		phase = "review"
	if phase == "patio":
		if not await _test_patio():
			quit(1)
			return
		quit(0)
		return
	var disk_dir := "/opt/cursor/artifacts/screenshots/customize-%s" % phase
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var gs: Node = root.get_node("GameSave")
	gs.call("set_square_session", {
		"session_token": "sess_customize_review",
		"customer": {
			"id": "CUST_LOOK_REVIEW",
			"phone": "2565550199",
			"given_name": "Ada",
			"family_name": "Baker",
			"display_name": "Ada Baker",
		},
	})
	var ps: Node = root.get_node("ProfileStore")
	ps.set("avatar", DEFAULT_RECIPE.duplicate(true))
	gs.set("avatar_recipe", DEFAULT_RECIPE.duplicate(true))
	if not await _scene("res://scenes/main_menu.tscn", 20):
		quit(1)
		return
	if not _snap(disk_dir, "01_customize_hub_entry_menu.png"):
		quit(1)
		return
	if not await _scene("res://scenes/explore/customize.tscn", 240):
		quit(1)
		return
	var screen := current_scene
	if not await _wait_ready(screen, 400):
		push_error("CAPTURE FAIL customize never built")
		quit(1)
		return
	_apply(screen, DEFAULT_RECIPE)
	await _frames(12)
	if not _snap(disk_dir, "02_customize_default.png"):
		quit(1)
		return
	_apply(screen, EMPTY_RECIPE)
	await _frames(10)
	if not _snap(disk_dir, "03_customize_empty.png"):
		quit(1)
		return
	for field in SLOT_FIELDS:
		if not await _show_field(screen, field):
			push_error("CAPTURE FAIL slot " + field)
			quit(1)
			return
		await _frames(4)
		if not _snap(disk_dir, "04_slot_%s.png" % field):
			quit(1)
			return
	_apply(screen, DRESSED_RECIPE)
	await _show_field(screen, "outfit")
	await _frames(12)
	if not _snap(disk_dir, "05_preview_fully_dressed.png"):
		quit(1)
		return
	if screen.has_method("_toggle_profile"):
		screen.call("_toggle_profile")
		await _frames(4)
		if not _snap(disk_dir, "07_edit_profile.png"):
			quit(1)
			return
		screen.call("_toggle_profile")
		await _frames(2)
	if screen.has_method("_request_leave"):
		screen.call("_request_leave", "res://scenes/main_menu.tscn")
		await _frames(4)
		if not _snap(disk_dir, "08_unsaved_leave.png"):
			quit(1)
			return
		var leave := screen.get_node_or_null("LeaveDialog") as CanvasItem
		if leave:
			leave.visible = false
		await _frames(2)
	screen._user.text = "look_review"
	screen._nick.text = "Ada"
	await screen._on_save()
	await _frames(8)
	if not _snap(disk_dir, "06_save_confirm.png"):
		quit(1)
		return
	print("CAPTURE customize review ok -> ", disk_dir)
	if phase == "review":
		if not await _test_patio():
			quit(1)
			return
	quit(0)


func _test_patio() -> bool:
	var disk_dir := "/opt/cursor/artifacts/screenshots/test-world"
	DirAccess.make_dir_recursive_absolute(disk_dir)
	if change_scene_to_file("res://scenes/explore/explore_test.tscn") != OK:
		push_error("CAPTURE FAIL explore test")
		return false
	for _i in 24:
		await process_frame
		await RenderingServer.frame_post_draw
	var explore := current_scene.get_node_or_null("Explore")
	if explore == null:
		push_error("CAPTURE FAIL explore test child")
		return false
	var player_cam := explore.get_node_or_null("Player/Camera3D") as Camera3D
	if player_cam:
		player_cam.current = true
	for _i in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	if not _snap(disk_dir, "01_ping_hud.png"):
		return false
	var hud := explore.get_node_or_null("HUD")
	if hud:
		hud.visible = false
	if player_cam:
		player_cam.current = false
	var shots := [
		["02_bigger_patio.png", Vector3(0.0, 16.0, 18.0), Vector3(0.0, 0.0, 0.0)],
		["03_halloween_north_lawn.png", Vector3(-14.0, 3.4, -24.5), Vector3(-14.2, 0.35, -31.0)],
		["04_halloween_west_corner.png", Vector3(-4.5, 3.2, 8.5), Vector3(-10.0, 0.4, 4.2)],
		["05_halloween_disco_fringe.png", Vector3(0.2, 2.8, 1.2), Vector3(0.1, 0.4, -5.1)],
		["06_pumpkin_bin.png", Vector3(5.2, 2.4, 27.2), Vector3(8.0, 0.5, 31.0)],
	]
	for shot in shots:
		if not await _shot_at(explore, disk_dir, str(shot[0]), shot[1], shot[2]):
			return false
	print("CAPTURE test world ok -> ", disk_dir)
	return true


func _shot_at(explore: Node, disk_dir: String, file_name: String, pos: Vector3, look: Vector3) -> bool:
	var cam := explore.get_node_or_null("ReviewShotCam") as Camera3D
	if cam == null:
		cam = Camera3D.new()
		cam.name = "ReviewShotCam"
		cam.fov = 55.0
		explore.add_child(cam)
	cam.position = pos
	cam.look_at(look, Vector3.UP)
	cam.current = true
	for _i in 6:
		await process_frame
		await RenderingServer.frame_post_draw
	return _snap(disk_dir, file_name)


func _apply(screen: Node, recipe: Dictionary) -> void:
	screen.set("_recipe", recipe.duplicate(true))
	for field in recipe.keys():
		if str(field) == "v":
			continue
		if screen.has_method("_pick"):
			screen.call("_pick", str(field), str(recipe[field]))
	if screen.has_method("_refresh_preview"):
		screen.call("_refresh_preview")
	for field in SLOT_FIELDS:
		if screen.has_method("_paint_row"):
			screen.call("_paint_row", field)


func _show_field(screen: Node, field: String) -> bool:
	if screen.has_method("show_slot"):
		screen.call("show_slot", field)
		await _frames(3)
		var scroll := screen.get_node_or_null("Safe/Card/Pad/Col/Scroll") as ScrollContainer
		var panel := screen.get_node_or_null("Safe/Card/Pad/Col/Scroll/Choices/SlotOptions/Slot_%s" % field) as Control
		if scroll and panel and scroll.has_method("ensure_control_visible"):
			scroll.ensure_control_visible(panel)
		await _frames(3)
		return true
	var scroll := screen.get_node_or_null("Safe/Card/Pad/Col/Scroll") as ScrollContainer
	var choices := screen.get_node_or_null("Safe/Card/Pad/Col/Scroll/Choices") as Control
	if scroll == null or choices == null:
		return false
	var titles := {
		"skin": "Skin",
		"hair": "Hair",
		"hair_color": "Hair color",
		"outfit": "Outfit",
		"bottoms": "Bottoms",
		"pants": "Pants",
		"apron": "Apron",
		"hat": "Hat",
		"accessory": "Accessory",
	}
	var want := str(titles.get(field, field))
	for child in choices.get_children():
		if child is Label and str((child as Label).text) == want:
			scroll.scroll_vertical = int((child as Control).position.y)
			await _frames(2)
			return true
	return false


func _wait_ready(screen: Node, frames: int) -> bool:
	for _i in frames:
		await process_frame
		if screen.get("_user") != null and screen.get("_choice_buttons") is Dictionary:
			return true
	return false


func _scene(path: String, frames: int) -> bool:
	if change_scene_to_file(path) != OK:
		push_error("CAPTURE FAIL scene " + path)
		return false
	for _i in frames:
		await process_frame
		if current_scene != null:
			break
	return current_scene != null


func _frames(n: int) -> void:
	for _i in n:
		await process_frame
		await RenderingServer.frame_post_draw


func _snap(disk_dir: String, name: String) -> bool:
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("CAPTURE FAIL image " + name)
		return false
	var disk := disk_dir.path_join(name)
	var err := img.save_png(disk)
	print("CAPTURE ", name, " ", img.get_width(), "x", img.get_height(), " -> ", disk, " err=", err)
	return err == OK
