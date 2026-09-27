extends SceneTree
## Prove a local Explore toss is not hidden inside the baker.
## Idle camera stays centered. During the toss the camera steps off the body,
## the cookie spawns on the look ray in front of the mesh, and the local baker
## ghosts. Move and look still work. Camera and body restore after the shot.
##
##   godot --headless --path . --rendering-method gl_compatibility -s res://tools/prove_toss_visible.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/explore/explore_3d.tscn")
	if packed == null:
		_fail("explore scene did not load")
		return
	var explore := packed.instantiate()
	root.add_child(explore)
	for _i in 6:
		await process_frame
		await physics_frame
	var player := explore.get_node_or_null("Player") as Node3D
	if player == null or not player.has_method("toss_cookie"):
		_fail("Player missing")
		return
	var arm := player.get_node_or_null("SpringArm") as SpringArm3D
	if arm == null:
		_fail("SpringArm missing")
		return
	if absf(arm.position.x) > 0.08 or absf(arm.spring_length - 4.15) > 0.05:
		_fail("idle camera should stay centered, arm=%s len=%.2f" % [str(arm.position), arm.spring_length])
		return
	if player.toss_ghost_alpha() < 0.95:
		_fail("idle baker should be solid, alpha=%.2f" % player.toss_ghost_alpha())
		return
	var save := root.get_node_or_null("GameSave")
	if save != null and int(save.throw_cookies) < 1:
		save.throw_cookies = 50
		save.call("persist")
	var start := player.global_position
	var yaw0 := player.rotation.y
	if not player.toss_cookie():
		_fail("toss_cookie returned false")
		return
	player.joy_vector = Vector2(0.0, 1.0)
	player.apply_touch_look(Vector2(70.0, 0.0))
	var shot: Node3D = null
	for _wait in 40:
		await physics_frame
		await process_frame
		var flying := get_nodes_in_group("cookie_projectile")
		if not flying.is_empty() and flying[0] is Node3D:
			shot = flying[0] as Node3D
			break
	if shot == null:
		_fail("toss did not spawn a cookie")
		return
	var ghost_wait := Time.get_ticks_msec()
	while player.toss_ghost_alpha() > 0.62 and Time.get_ticks_msec() - ghost_wait < 500:
		await process_frame
	if arm.position.x < 0.45:
		_fail("toss camera did not leave the baker, arm.x=%.3f" % arm.position.x)
		return
	if player.toss_ghost_alpha() > 0.62:
		_fail("local baker did not ghost, alpha=%.2f" % player.toss_ghost_alpha())
		return
	var flat := -player.global_transform.basis.z
	flat.y = 0.0
	flat = flat.normalized()
	var rel := shot.global_position - player.global_position
	var ahead := Vector2(rel.x, rel.z).dot(Vector2(flat.x, flat.z))
	if ahead < 0.45:
		_fail("cookie spawned inside/behind the baker, ahead=%.2f pos=%s" % [ahead, str(shot.global_position)])
		return
	var aim_from := arm.to_global(Vector3(0.0, 0.0, arm.spring_length))
	var chest := player.global_position + Vector3(0.0, 1.05, 0.0)
	var sep := (chest - aim_from).angle_to(shot.global_position - aim_from)
	if sep < 0.1:
		_fail("cookie still lies on the baker ray, sep=%.3f" % sep)
		return
	var spawned_at := shot.global_position
	for _fly in 8:
		await physics_frame
	if not is_instance_valid(shot):
		_fail("cookie vanished before its flight could be seen")
		return
	var flown := shot.global_position - spawned_at
	if flown.length() < 0.25:
		_fail("cookie did not travel, delta=%s" % str(flown))
		return
	var sep_fly := (chest - aim_from).angle_to(shot.global_position - aim_from)
	if sep_fly < 0.08:
		_fail("cookie flight fell back onto the baker, sep=%.3f" % sep_fly)
		return
	var moved := player.global_position.distance_to(start)
	if moved < 0.08:
		_fail("stick should still move the baker during a toss, moved=%.3f" % moved)
		return
	var yaw_delta := absf(angle_difference(player.rotation.y, yaw0))
	if yaw_delta < 0.04:
		_fail("look should still yaw during a toss, delta=%.3f" % yaw_delta)
		return
	player.joy_vector = Vector2.ZERO
	print("TOSS-VIS spawn sep=", sep, " fly_sep=", sep_fly, " ghost=", player.toss_ghost_alpha(), " arm.x=", arm.position.x, " ahead=", ahead, " moved=", moved, " yaw=", yaw_delta)
	for _back in 180:
		await physics_frame
		if absf(arm.position.x) < 0.05 and player.toss_ghost_alpha() > 0.95:
			break
	if absf(arm.position.x) > 0.08:
		_fail("camera did not return to center, arm.x=%.3f" % arm.position.x)
		return
	if absf(arm.spring_length - 4.15) > 0.05:
		_fail("tether did not return, len=%.3f" % arm.spring_length)
		return
	if player.toss_ghost_alpha() < 0.95:
		_fail("baker did not turn solid again, alpha=%.2f" % player.toss_ghost_alpha())
		return
	if absf(player.find_child("Camera3D", true, false).h_offset) > 0.02:
		_fail("Camera3D.h_offset must stay 0")
		return
	print("TOSS-VIS restored arm.x=", arm.position.x, " ghost=", player.toss_ghost_alpha())
	print("TOSS-VIS ok")
	quit(0)


func _fail(msg: String) -> void:
	push_error("TOSS-VIS FAIL " + msg)
	quit(1)
