extends SceneTree
## Capture NPCs on the ground with held snacks, plus the logo sun.
##   DISPLAY=:1 godot --path . --display-driver x11 --rendering-driver opengl3 \
##     -s res://tools/capture_npc_sun.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/explore/explore_3d.tscn")
	if packed == null:
		push_error("CAPTURE FAIL load explore_3d")
		quit(1)
		return
	var explore: Node = packed.instantiate()
	root.add_child(explore)
	await process_frame
	await process_frame
	await process_frame
	var hud := explore.get_node_or_null("HUD")
	if hud:
		hud.queue_free()
	var notice := explore.get_tree().root.get_node_or_null("NoticeService")
	if notice:
		notice.visible = false
	await process_frame
	var player_cam := explore.get_node_or_null("Player/Camera3D") as Camera3D
	if player_cam:
		player_cam.current = false
	var world := explore.get_node_or_null("World") as Node3D
	var npcs := 0
	var held := 0
	if world:
		for child in world.get_children():
			if child.is_in_group("village_npc"):
				npcs += 1
				print("CAPTURE npc ", child.name, " y=", child.global_position.y)
		for n in explore.get_tree().get_nodes_in_group("held_snack"):
			held += 1
	var sun := world.get_node_or_null("LogoSun") as Node3D if world else null
	if sun and sun.has_method("set_phase"):
		sun.call("set_phase", 0.48)
	print("CAPTURE npcs=", npcs, " held=", held, " sun=", sun.global_position if sun else Vector3.ZERO)
	if npcs < 8 or held < npcs or sun == null:
		push_error("CAPTURE FAIL npcs/held/sun")
		quit(1)
		return
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var shots: Array[Dictionary] = [
		{"name": "npc_ground_west", "pos": Vector3(-8.35, 1.38, 4.85), "look": Vector3(-6.55, 0.72, 3.15), "fov": 46.0},
		{"name": "npc_ground_east", "pos": Vector3(8.35, 1.38, 4.85), "look": Vector3(6.55, 0.72, 3.15), "fov": 46.0},
		{"name": "npc_staff_hold", "pos": Vector3(-8.35, 1.42, 8.05), "look": Vector3(-6.6, 0.78, 6.35), "fov": 44.0},
		{"name": "logo_sun_sky", "pos": Vector3(0.0, 1.7, 14.0), "look": Vector3(0.0, 22.0, -18.0), "fov": 55.0},
		{"name": "logo_sun_spawn", "pos": Vector3(0.0, 1.55, 11.0), "look": Vector3(0.0, 8.5, -6.0), "fov": 50.0},
	]
	var cam := Camera3D.new()
	cam.name = "NpcSunCaptureCam"
	root.add_child(cam)
	var saved := 0
	for shot in shots:
		cam.current = true
		cam.fov = float(shot["fov"])
		cam.position = shot["pos"]
		cam.look_at(shot["look"], Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var tex: ViewportTexture = root.get_texture()
		if tex == null:
			push_error("CAPTURE FAIL viewport")
			quit(1)
			return
		var img: Image = tex.get_image()
		if img == null:
			push_error("CAPTURE FAIL image " + str(shot["name"]))
			quit(1)
			return
		var disk := disk_dir.path_join("%s.png" % str(shot["name"]))
		var err := img.save_png(disk)
		print("CAPTURE ", shot["name"], " ", img.get_width(), "x", img.get_height(), " -> ", disk, " err=", err)
		saved += 1
	print("CAPTURE done ", saved, " pngs")
	quit(0)
