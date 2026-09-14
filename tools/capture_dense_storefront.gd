extends SceneTree
## Portrait spawn + lot proof for the textured v3 bakery GLB.
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
	var bakery := _named_aabb(shop, "BakeryBody")
	var facade := _named_mesh(shop, "BakeryFrontFacade")
	var green := _named_mesh(shop, "GreenFrontFacade")
	var facade_tex := _mesh_has_albedo_texture(facade)
	var green_tex := _mesh_has_albedo_texture(green)
	print(
		"CAPTURE textured glb_meshes=",
		meshes,
		" bakery=",
		bakery,
		" facade_tex=",
		facade_tex,
		" green_tex=",
		green_tex
	)
	if meshes < 50 or bakery.size.length() < 0.2:
		push_error("CAPTURE FAIL textured v3 bakery mesh missing")
		quit(1)
		return
	if not facade_tex:
		push_error("CAPTURE FAIL BakeryFrontFacade missing albedo texture")
		quit(1)
		return
	if not await _snap("explore_dense_spawn.png"):
		quit(1)
		return
	var rig := explore.get_node_or_null("ReviewCameras")
	var player_cam := explore.get_node_or_null("Player/Camera3D") as Camera3D
	if player_cam:
		player_cam.current = false
	for shot in [
		["Dining", "explore_dense_yard.png"],
		["Exterior", "explore_dense_lot.png"],
		["SunshineCloseup", "explore_dense_facade.png"],
	]:
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
	var mi := _named_mesh(root, mesh_name)
	if mi == null:
		return AABB()
	return mi.global_transform * mi.get_aabb()


func _named_mesh(root: Node, mesh_name: String) -> MeshInstance3D:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and str(n.name) == mesh_name:
			return n as MeshInstance3D
		for child in n.get_children():
			stack.append(child)
	return null


func _mesh_has_albedo_texture(mi: MeshInstance3D) -> bool:
	if mi == null or mi.mesh == null:
		return false
	for i in mi.mesh.get_surface_count():
		var mat := mi.get_active_material(i)
		if mat == null:
			mat = mi.mesh.surface_get_material(i)
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null:
			return true
	return false


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
