extends SceneTree
## Portrait spawn + lot proof for the denser trimesh bakery GLB.
##   DISPLAY=:1 godot --path . --rendering-method gl_compatibility --resolution 720x1280 \
##     -s res://tools/capture_dense_storefront.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://scenes/explore/explore_3d.tscn") != OK:
		push_error("CAPTURE FAIL explore")
		quit(1)
		return
	await _settle(28)
	var explore := current_scene
	var hud := explore.get_node_or_null("HUD") if explore else null
	if hud:
		hud.visible = false
	var world := explore.get_node_or_null("World") if explore else null
	var shop := world.get_node_or_null("ChatGPTStorefront") if world else null
	if shop == null:
		push_error("CAPTURE FAIL missing ChatGPTStorefront")
		quit(1)
		return
	var meshes := 0
	var stack: Array = [shop]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			meshes += 1
		for child in n.get_children():
			stack.append(child)
	var bakery := _named_aabb(shop, "BakeryMain")
	var sign := _named_aabb(shop, "BakerySign")
	var logo := _named_aabb(shop, "LogoDisc")
	print(
		"CAPTURE dense glb_meshes=",
		meshes,
		" bakery=",
		bakery,
		" sign=",
		sign,
		" logo=",
		logo
	)
	if not await _snap("explore_dense_spawn.png"):
		quit(1)
		return
	var rig := explore.get_node_or_null("ReviewCameras")
	var player_cam := explore.get_node_or_null("Player/Camera3D") as Camera3D
	if player_cam:
		player_cam.current = false
	for shot in [["Dining", "explore_dense_yard.png"], ["Exterior", "explore_dense_lot.png"]]:
		var cam := rig.get_node_or_null(shot[0]) as Camera3D if rig else null
		if cam == null:
			push_error("CAPTURE FAIL camera " + shot[0])
			quit(1)
			return
		cam.current = true
		if not await _snap(shot[1]):
			quit(1)
			return
		cam.current = false
	quit(0)


func _named_aabb(root: Node, mesh_name: String) -> AABB:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and str(n.name) == mesh_name:
			var mi := n as MeshInstance3D
			return mi.global_transform * mi.get_aabb()
		for child in n.get_children():
			stack.append(child)
	return AABB()


func _settle(frames: int) -> void:
	for _i in frames:
		await process_frame
		await RenderingServer.frame_post_draw


func _snap(name: String) -> bool:
	await _settle(8)
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("CAPTURE FAIL image " + name)
		return false
	var err := img.save_png(disk_dir.path_join(name))
	print("CAPTURE ", name, " ", img.get_width(), "x", img.get_height(), " err=", err)
	return err == OK
