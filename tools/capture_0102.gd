extends SceneTree
## Wardrobe shots: both bodies, outfits, hats, a held pastry, a pet, and the pumpkin stairs.


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
	var explore := current_scene.get_node("Explore")
	for child in explore.get_children():
		if child is CanvasLayer or child is Control:
			(child as Node).visible = false
	var world := explore.get_node("World") as Node3D
	var player := explore.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	var avatar := player.get_node("Avatar")
	await _portraits(player, avatar, dir)
	await _holds(player, avatar, world, dir)
	await _stairs(player, world, dir)
	await _doorway(player)
	print("CAPTURE 0102 ok")
	quit(0)


func _portraits(player: CharacterBody3D, avatar: Node, dir: String) -> void:
	_place(player, Vector3(1.4, 0.05, 5.2), 0.0)
	var looks := [
		[{}, "player_female_default.png"],
		[{"body": "male", "accessory": "none"}, "player_male_default.png"],
		[{"body": "female", "outfit": "wine", "hair": "wavy", "hair_color": "wine", "bottoms": "pants", "pants": "navy", "hat": "none", "apron": "none", "accessory": "glasses"}, "player_female_wine_wavy.png"],
		[{"body": "female", "outfit": "cream", "hair": "bun", "hair_color": "honey", "hat": "bow", "accessory": "flower", "apron": "blush"}, "player_female_bun_bow.png"],
		[{"body": "male", "accessory": "none", "hair": "short", "hair_color": "black", "outfit": "wine", "bottoms": "pants", "pants": "navy", "hat": "beanie", "apron": "none"}, "player_male_short_beanie.png"],
		[{"body": "male", "accessory": "scarf", "hair": "bangs", "outfit": "apricot", "hat": "sun", "apron": "grey"}, "player_male_bangs_sun.png"],
	]
	for row in looks:
		avatar.call("rebuild", row[0])
		await process_frame
		_frame(player, 30.0, 2.15)
		await _draw()
		_save(dir, str(row[1]))


func _holds(player: CharacterBody3D, avatar: Node, world: Node, dir: String) -> void:
	var Menu := load("res://scripts/explore/menu_props.gd")
	var pastry: Node3D = Menu.call("instantiate_named", "nutella_croissant")
	if pastry == null:
		push_error("CAPTURE FAIL pastry missing")
		return
	Menu.call("flatten_prop", pastry)
	pastry.scale = Vector3.ONE
	for row in [["female", "glasses", "player_female_pastry.png"], ["male", "none", "player_male_pastry.png"]]:
		if pastry.get_parent():
			pastry.get_parent().remove_child(pastry)
		avatar.call("rebuild", {"body": row[0], "accessory": row[1], "hat": "none", "hair": "bangs"})
		await process_frame
		var hand := avatar.call("hand_socket") as Node3D
		hand.add_child(pastry)
		pastry.position = Vector3.ZERO
		pastry.rotation = Vector3.ZERO
		_frame(player, 22.0, 1.35)
		await _draw()
		_save(dir, str(row[2]))
		avatar.call("play_throw", true)
		await _draw()
		_save(dir, "player_%s_toss.png" % str(row[0]))
		if pastry.get_parent():
			pastry.get_parent().remove_child(pastry)
	avatar.call("rebuild", {"body": "female", "hat": "sun"})
	await process_frame
	var pet := world.find_child("PatioPets", true, false)
	var cat: Node3D = null
	if pet and pet.get_child_count() > 0:
		cat = pet.get_child(0) as Node3D
	if cat and cat.has_method("follow_chest"):
		cat.call("follow_chest", avatar)
		_frame(player, 32.0, 2.3)
		await _draw()
		_save(dir, "player_pet_head.png")
		avatar.call("rebuild", {"body": "male", "accessory": "none", "hat": "beanie", "hair": "short"})
		await process_frame
		cat.call("follow_chest", avatar)
		_frame(player, 32.0, 2.3)
		await _draw()
		_save(dir, "player_male_pet_head.png")


func _stairs(player: CharacterBody3D, world: Node, dir: String) -> void:
	var pumpkin := world.get_node("GiantPumpkin") as Node3D
	var pts: PackedVector3Array = pumpkin.walk_points
	var at: Vector3 = pumpkin.to_global(pts[40])
	player.global_position = at + Vector3(0, 0.2, 0)
	var avatar := player.get_node("Avatar")
	avatar.call("rebuild", {"body": "female", "hat": "sun"})
	await process_frame
	var cam := _cam(48.0)
	cam.global_position = player.global_position + Vector3(4.2, 2.4, 3.6)
	cam.look_at(player.global_position + Vector3(0, 1.1, 0), Vector3.UP)
	await _draw()
	_save(dir, "player_pumpkin_climb.png")


func _doorway(player: CharacterBody3D) -> void:
	player.set_physics_process(true)
	player.global_position = Vector3(0.0, 0.3, 10.0)
	player.velocity = Vector3.ZERO
	var stuck := 0
	var prev := player.global_position
	for _i in 180:
		player.velocity = Vector3(0.0, -2.0, -2.6)
		player.move_and_slide()
		await physics_frame
		if player.global_position.distance_to(prev) < 0.01:
			stuck += 1
		else:
			stuck = 0
		prev = player.global_position
		if stuck > 8:
			break
	print("CAPTURE doorway stop ", player.global_position, " floor ", player.is_on_floor(), " stuck_frames ", stuck)
	player.set_physics_process(false)


func _place(player: CharacterBody3D, at: Vector3, yaw: float) -> void:
	player.global_position = at
	player.rotation = Vector3(0, yaw, 0)


func _frame(player: Node3D, fov: float, dist: float) -> void:
	var cam := _cam(fov)
	var focus := player.global_position + Vector3(0, 1.05, 0)
	cam.global_position = focus + Vector3(0.35, 0.15, -dist)
	cam.look_at(focus, Vector3.UP)


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
	print("CAPTURE ", path, " ", err, " ", img.get_size())
