extends SceneTree
## Before shots: sheet ghosts facing their travel, and the horseman hit boxes.
## Run with a display. Does not change gameplay.


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
	for _i in 12:
		await process_frame
	var world := current_scene.get_node("Explore/World") as Node3D
	_prove_yaw()
	await _ghost_before(world, dir)
	await _horseman_before(world, dir)
	print("CAPTURE before ok")
	quit(0)


func _prove_yaw() -> void:
	var n := Node3D.new()
	root.add_child(n)
	for deg in [0, 90, 180, -90]:
		n.rotation = Vector3(0, deg_to_rad(deg), 0)
		var fwd := -n.global_transform.basis.z
		print("YAW ", deg, " forward=", fwd)
	n.queue_free()


func _ghost_before(world: Node3D, dir: String) -> void:
	var ghosts := world.get_node("PatioGhosts")
	ghosts.set_process(false)
	var ghost := ghosts.get_child(0) as Node3D
	var ang := 1.15
	var radius := 6.2
	var vel := Vector3(-sin(ang) * radius, 0.0, cos(ang) * radius * 0.82)
	ghost.position = Vector3(1.2 + cos(ang) * radius, 0.35, -0.6 + sin(ang) * radius * 0.82)
	ghost.rotation = Vector3(0.0, ang + PI * 0.5, 0.0)
	var face := -ghost.global_transform.basis.z
	var flat := Vector3(face.x, 0.0, face.z).normalized()
	var travel := Vector3(vel.x, 0.0, vel.z).normalized()
	print("GHOST BEFORE face_dot_travel=", flat.dot(travel), " face=", flat, " travel=", travel)
	_arrow(world, ghost.global_position + Vector3(0, 1.15, 0), travel)
	var cam := _cam()
	var eye := ghost.global_position + Vector3(0, 1.25, 0)
	cam.global_position = eye + travel * 4.2 + Vector3(0, 0.35, 0)
	cam.look_at(eye, Vector3.UP)
	for _i in 4:
		await process_frame
		await RenderingServer.frame_post_draw
	_save(dir, "ghost_before.png")


func _horseman_before(world: Node3D, dir: String) -> void:
	var yard := world.get_node("Graveyard") as Node3D
	yard.set_process(false)
	var rider := yard.get_node("HeadlessHorseman") as Node3D
	rider.position = Vector3(2.2, 0.0, 0.4)
	rider.rotation = Vector3.ZERO
	for leg_name in ["LegFL", "LegFR", "LegBL", "LegBR"]:
		var leg := rider.find_child(leg_name, true, false) as Node3D
		if leg:
			leg.rotation.x = 0.6 if leg_name.ends_with("L") else -0.6
	_paint_shapes(rider)
	var cam := _cam()
	var focus := rider.global_position + Vector3(0, 1.3, 0)
	cam.global_position = focus + Vector3(4.6, 1.5, 3.2)
	cam.look_at(focus, Vector3.UP)
	for _i in 4:
		await process_frame
		await RenderingServer.frame_post_draw
	_save(dir, "horseman_hitbox_before.png")


func _paint_shapes(rider: Node3D) -> void:
	var body := rider.find_child("HorsemanHit", true, false)
	if body == null:
		push_error("CAPTURE no HorsemanHit")
		return
	for col in body.find_children("*", "CollisionShape3D", true, false):
		var shape := (col as CollisionShape3D).shape as BoxShape3D
		if shape == null:
			continue
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = shape.size
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.15, 0.12, 0.38)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(col as Node3D).add_child(mi)
		print("HITBOX BEFORE size=", shape.size, " pos=", (col as Node3D).position)


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


func _cam() -> Camera3D:
	var cam := current_scene.find_child("Camera3D", true, false) as Camera3D
	if cam == null:
		cam = Camera3D.new()
		current_scene.add_child(cam)
	cam.current = true
	cam.fov = 42.0
	return cam


func _save(dir: String, name: String) -> void:
	var img: Image = root.get_texture().get_image()
	var path := dir.path_join(name)
	var err := img.save_png(path)
	print("CAPTURE ", name, " ", img.get_width(), "x", img.get_height(), " err=", err, " ", path)
