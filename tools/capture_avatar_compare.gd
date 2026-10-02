extends SceneTree
## Side-by-side sources: player maker, Loyalty, and the Explore player's AvatarBody.
## Same non-default recipe (navy pants, wine apron, apricot top). Not a second mesh.
##   xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 720x1280 \
##     --audio-driver Dummy -s res://tools/capture_avatar_compare.gd

const RECIPE := {
	"v": 1,
	"skin": "rich",
	"hair": "wavy",
	"hair_color": "honey",
	"outfit": "apricot",
	"bottoms": "pants",
	"pants": "navy",
	"apron": "wine",
	"hat": "none",
	"accessory": "glasses",
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var disk_dir := "/opt/cursor/artifacts/screenshots"
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var gs: Node = root.get_node("GameSave")
	var ps: Node = root.get_node("ProfileStore")
	gs.call("set_square_session", {
		"customer": {
			"id": "CUST_LOOK_COMPARE",
			"phone": "2564525192",
			"given_name": "Ada",
			"family_name": "Baker",
			"display_name": "Ada Baker",
		},
		"loyalty": {
			"enrolled": true,
			"account_id": "LOY_COMPARE",
			"points": 140,
			"program_id": "PROG_COMPARE",
		},
	})
	_apply_look(gs, ps)
	if change_scene_to_file("res://scenes/explore/customize.tscn") != OK:
		push_error("CAPTURE FAIL customize")
		quit(1)
		return
	if not await _wait_for(func() -> bool: return _avatar() != null, 240):
		push_error("CAPTURE FAIL customize avatar")
		quit(1)
		return
	var maker := current_scene
	maker.set("_recipe", RECIPE.duplicate(true))
	maker.call("_refresh_preview")
	await _frames(10)
	if not _snap(disk_dir, "avatar_compare_customize.png"):
		quit(1)
		return
	_apply_look(gs, ps)
	if change_scene_to_file("res://scenes/loyalty/loyalty.tscn") != OK:
		push_error("CAPTURE FAIL loyalty")
		quit(1)
		return
	if not await _wait_for(func() -> bool: return _avatar() != null, 80):
		push_error("CAPTURE FAIL loyalty avatar")
		quit(1)
		return
	await _frames(10)
	if not _snap(disk_dir, "avatar_compare_loyalty.png"):
		quit(1)
		return
	_apply_look(gs, ps)
	if change_scene_to_file("res://scenes/explore/explore_3d.tscn") != OK:
		push_error("CAPTURE FAIL explore")
		quit(1)
		return
	if not await _wait_for(func() -> bool: return _avatar() != null, 180):
		push_error("CAPTURE FAIL explore avatar")
		quit(1)
		return
	var avatar: Node3D = _avatar()
	avatar.call("rebuild", RECIPE.duplicate(true))
	var hud := current_scene.get_node_or_null("HUD")
	if hud:
		hud.visible = false
	var cam := Camera3D.new()
	cam.name = "CompareCam"
	current_scene.add_child(cam)
	cam.global_position = avatar.global_position + Vector3(0.42, 1.05, 2.35)
	cam.look_at(avatar.global_position + Vector3(0, 0.72, 0))
	cam.current = true
	await _frames(8)
	if not _snap(disk_dir, "avatar_compare_explore.png"):
		quit(1)
		return
	print("CAPTURE avatar compare ok")
	quit(0)


func _apply_look(gs: Node, ps: Node) -> void:
	var look := RECIPE.duplicate(true)
	gs.set("avatar_recipe", look)
	ps.set("avatar", look)


func _avatar() -> Node3D:
	if current_scene == null:
		return null
	return current_scene.find_child("Avatar", true, false) as Node3D


func _wait_for(pred: Callable, frames: int) -> bool:
	for _i in frames:
		await process_frame
		if pred.is_valid() and bool(pred.call()):
			return true
	return false


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
