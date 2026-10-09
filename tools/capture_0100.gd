extends SceneTree
## After shots for 0.1.100: ghost facing, horseman hit shapes, perimeter wall.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var dir := "/opt/cursor/artifacts"
	DirAccess.make_dir_recursive_absolute(dir)
	if change_scene_to_file("res://scenes/explore/explore_test.tscn") != OK:
		push_error("CAPTURE FAIL explore_test")
		quit(1)
		return
	for _i in 8:
		await process_frame
	var world := current_scene.get_node("Explore/World") as Node3D
	await _ghost_after(world, dir)
	await _horseman_after(world, dir)
	await _wall_shots(world, dir)
	print("CAPTURE 0100 ok")
	quit(0)


func _ghost_after(world: Node3D, dir: String) -> void:
	var ghosts := world.get_node("PatioGhosts")
	ghosts.set_process(false)
	var ghost := ghosts.get_child(0) as Node3D
	var ang := 1.15
	var radius := 6.2
	var vel := Vector3(-sin(ang) * radius, 0.0, cos(ang) * radius * 0.82)
	ghost.position = Vector3(1.2 + cos(ang) * radius, 0.35, -0.6 + sin(ang) * radius * 0.82)
	ghosts.call("face_travel", ghost, vel, 0.0, 0.0)
	var face := Vector3((-ghost.global_transform.basis.z).x, 0.0, (-ghost.global_transform.basis.z).z).normalized()
	var travel := Vector3(vel.x, 0.0, vel.z).normalized()
	print("GHOST AFTER face_dot_travel=", face.dot(travel))
	_arrow(world, ghost.global_position + Vector3(0, 1.15, 0), travel)
	var cam := _cam(42.0)
	var eye := ghost.global_position + Vector3(0, 1.25, 0)
	cam.global_position = eye + travel * 4.2 + Vector3(0, 0.35, 0)
	cam.look_at(eye, Vector3.UP)
	await _draw()
	_save(dir, "ghost_after.png")


func _horseman_after(world: Node3D, dir: String) -> void:
	var yard := world.get_node("Graveyard") as Node3D
	yard.set_physics_process(false)
	var rider := yard.get_node("HeadlessHorseman") as Node3D
	rider.position = Vector3(2.2, 0.0, 0.4)
	rider.rotation = Vector3.ZERO
	for leg_name in ["LegFL", "LegFR", "LegBL", "LegBR"]:
		var leg := rider.find_child(leg_name, true, false) as Node3D
		if leg:
			leg.rotation.x = 0.6 if leg_name.ends_with("L") else -0.6
	yard.call("_sync_hit_shapes")
	var hit := rider.find_child("HorsemanHit", true, false) as Node3D
	for col in hit.find_children("*", "CollisionShape3D", true, false):
		var shape := (col as CollisionShape3D).shape as BoxShape3D
		if shape == null:
			continue
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = shape.size * 0.98
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.15, 0.12, 0.35)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(col as Node3D).add_child(mi)
	var cam := _cam(38.0)
	var focus := rider.global_position + Vector3(0, 1.2, 0)
	cam.global_position = focus + Vector3(4.8, 1.6, 3.4)
	cam.look_at(focus, Vector3.UP)
	await _draw()
	_save(dir, "horseman_hitbox_after.png")


func _wall_shots(world: Node3D, dir: String) -> void:
	var wall := world.get_node("PerimeterWall") as Node3D
	var north := wall.get_node("GateNorth") as Node3D
	var cam := _cam(48.0)
	cam.global_position = Vector3(0, 1.7, -78)
	cam.look_at(Vector3(0, 6.0, -102), Vector3.UP)
	await _draw()
	_save(dir, "wall_inside_ground.png")
	cam.fov = 36.0
	cam.global_position = north.global_position + Vector3(0, 3.2, 14)
	cam.look_at(north.global_position + Vector3(0, 4.6, 0), Vector3.UP)
	await _draw()
	_save(dir, "gate_closeup.png")
	cam.fov = 70.0
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 230.0
	cam.global_position = Vector3(0, 180, 0)
	cam.look_at(Vector3(0, 0, 0), Vector3(0, 0, -1))
	await _draw()
	_save(dir, "wall_overhead.png")
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 55.0
	var pumpkin := world.get_node("GiantPumpkin") as Node3D
	var deck: Vector3 = pumpkin.global_position + Vector3(8.0, 29.2, 6.0)
	cam.global_position = deck
	cam.look_at(Vector3(0, 8, 102), Vector3.UP)
	await _draw()
	_save(dir, "pumpkin_deck_wall.png")


func _arrow(world: Node3D, at: Vector3, dir: Vector3) -> void:
	var tip := MeshInstance3D.new()
	tip.name = "TravelArrow"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.12, 1.6)
	tip.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("ffb000")
	tip.material_override = mat
	world.add_child(tip)
	tip.global_position = at + dir * 0.9
	tip.look_at(tip.global_position + dir, Vector3.UP)


func _cam(fov: float) -> Camera3D:
	var cam := current_scene.find_child("ShotCam", true, false) as Camera3D
	if cam == null:
		cam = Camera3D.new()
		cam.name = "ShotCam"
		current_scene.add_child(cam)
	cam.current = true
	cam.fov = fov
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	return cam


func _draw() -> void:
	for _i in 3:
		await process_frame
		await RenderingServer.frame_post_draw


func _save(dir: String, name: String) -> void:
	var img: Image = root.get_texture().get_image()
	var path := dir.path_join(name)
	var err := img.save_png(path)
	print("CAPTURE ", name, " ", img.get_width(), "x", img.get_height(), " err=", err)
