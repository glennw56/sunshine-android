extends SceneTree
## Visual proof: local baker vs screen midline.
##   DISPLAY=:1 godot --path . --rendering-method gl_compatibility --resolution 720x1280 \
##     -s res://tools/capture_centered_baker.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	if change_scene_to_file("res://scenes/explore/explore_3d.tscn") != OK:
		push_error("CAPTURE FAIL explore")
		quit(1)
		return
	for _i in 48:
		await process_frame
		await RenderingServer.frame_post_draw
	var player := current_scene.get_node_or_null("Player") as Node3D
	if player == null:
		push_error("CAPTURE FAIL player")
		quit(1)
		return
	var src := FileAccess.get_file_as_string("res://scripts/explore/player.gd")
	if src.find("SpringArm3D") < 0 or src.find("const SHOULDER := Vector3(0.0, 1.78, 0.12)") < 0:
		push_error("CAPTURE FAIL this Godot project is not the centered TPP player.gd")
		quit(1)
		return
	if src.find("center_baker_v069") < 0:
		push_error("CAPTURE FAIL CAMERA_BUILD mark missing")
		quit(1)
		return
	var cam := player.find_child("Camera3D", true, false) as Camera3D
	var arm := player.get_node_or_null("SpringArm") as SpringArm3D
	if cam == null or arm == null:
		push_error("CAPTURE FAIL camera rig — stub player has no SpringArm")
		quit(1)
		return
	if not _measure_and_save(player, cam, arm, "explore_baker_hud_on.png", disk_dir):
		quit(1)
		return
	var hud := current_scene.get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = false
	_draw_midline()
	for _j in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	if not _measure_and_save(player, cam, arm, "explore_baker_midline.png", disk_dir):
		quit(1)
		return
	print("CAPTURE centered baker ok")
	quit(0)


func _measure_and_save(player: Node3D, cam: Camera3D, arm: SpringArm3D, name: String, disk_dir: String) -> bool:
	var chest := player.global_position + Vector3(0, 0.78, 0)
	var screen := cam.unproject_position(chest)
	var head := cam.unproject_position(player.global_position + Vector3(0, 1.28, 0))
	var vp := cam.get_viewport().get_visible_rect().size
	var nx := screen.x / vp.x
	var hx := head.x / vp.x
	print(
		"CENTER file=",
		name,
		" chest_nx=",
		nx,
		" head_nx=",
		hx,
		" chest_px=",
		screen,
		" mid_px=",
		vp.x * 0.5,
		" chest_off_px=",
		screen.x - vp.x * 0.5,
		" arm=",
		arm.position,
		" h_offset=",
		cam.h_offset,
		" vp=",
		vp
	)
	if absf(arm.position.x) > 0.08 or absf(nx - 0.5) > 0.08:
		push_error("CAPTURE FAIL baker not centered nx=%.3f arm.x=%.3f" % [nx, arm.position.x])
		return false
	return _save(name, disk_dir)


func _draw_midline() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	root.add_child(layer)
	var vp := root.get_visible_rect().size
	var line := ColorRect.new()
	line.color = Color(1.0, 0.15, 0.2, 0.9)
	line.size = Vector2(3, vp.y)
	line.position = Vector2(vp.x * 0.5 - 1.5, 0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(line)
	var tag := Label.new()
	tag.text = "SCREEN MIDLINE"
	tag.position = Vector2(vp.x * 0.5 + 8, 12)
	tag.add_theme_font_size_override("font_size", 18)
	tag.add_theme_color_override("font_color", Color(1, 0.15, 0.2))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tag)


func _save(name: String, disk_dir: String) -> bool:
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("CAPTURE FAIL image " + name)
		return false
	var disk := disk_dir.path_join(name)
	var err := img.save_png(disk)
	print("CAPTURE ", name, " ", img.get_width(), "x", img.get_height(), " -> ", disk, " err=", err)
	img.save_png("/opt/cursor/artifacts/" + name)
	return err == OK
