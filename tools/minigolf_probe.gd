extends SceneTree
## Throw a few scripted putts and print where the ball ends.
##   godot --headless --path . -s res://tools/minigolf_probe.gd

const HoleScript := preload("res://scripts/minigolf/hole.gd")
const BallScript := preload("res://scripts/minigolf/ball.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.time_scale = 1.0
	var hole: Node3D = HoleScript.new()
	var ball: RigidBody3D = BallScript.new()
	root.add_child(hole)
	root.add_child(ball)
	quit(0)


func _tracks(index: int) -> void:
	var packed := load("res://assets/minigolf/hole%02d/hole%02d.glb" % [index, index]) as PackedScene
	var visual := packed.instantiate()
	var stack: Array = [visual]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is AnimationPlayer:
			var player := n as AnimationPlayer
			var parent_name := str(player.get_parent().name) if player.get_parent() else ""
			print("PLAYER hole %d parent %s root %s" % [index, parent_name, player.root_node])
			for lib_name in player.get_animation_library_list():
				var lib := player.get_animation_library(lib_name)
				for anim_name in lib.get_animation_list():
					var anim := lib.get_animation(anim_name)
					for t in anim.get_track_count():
						print("TRACK hole %d %s %s" % [index, anim_name, anim.track_get_path(t)])
		for child in n.get_children():
			stack.append(child)
	visual.free()


func _putt(hole: Node3D, ball: RigidBody3D, index: int, dir: Vector3, speed: float, _nudge: Vector3) -> void:
	if hole.get_child_count() > 0:
		for child in hole.get_children():
			hole.remove_child(child)
			child.free()
	hole.setup(index)
	var tee: Vector3 = hole.tee_pos()
	ball.park(tee)
	hole.arm(ball)
	for _i in 8:
		await physics_frame
	var under := _ray(ball)
	print("PROBE hole %d tee %s under %s" % [index, tee, under])
	ball.launch(dir, speed)
	var last := ""
	var max_y := ball.global_position.y
	var max_z := ball.global_position.z
	for i in 420:
		await physics_frame
		max_y = maxf(max_y, ball.global_position.y)
		if ball.global_position.z < max_z:
			max_z = ball.global_position.z
		var ev := str(hole.poll())
		if ev == "cup" or ev == "oob":
			print("PROBE hole %d speed %.1f frame %d %s pos %s maxy %.2f maxz %.2f under %s" % [index, speed, i, ev, ball.global_position, max_y, max_z, _ray(ball)])
			return
		if i > 50 and ball.linear_velocity.length() < 0.07 and ball.angular_velocity.length() < 1.1:
			print("PROBE hole %d speed %.1f STOP frame %d pos %s maxy %.2f maxz %.2f under %s" % [index, speed, i, ball.global_position, max_y, max_z, _ray(ball)])
			return
		last = ev
	print("PROBE hole %d speed %.1f END %s pos %s maxy %.2f" % [index, speed, last, ball.global_position, max_y])


func _from(hole: Node3D, ball: RigidBody3D, index: int, at: Vector3, dir: Vector3, speed: float) -> void:
	if hole.get_child_count() > 0:
		for child in hole.get_children():
			hole.remove_child(child)
			child.free()
	hole.setup(index)
	ball.park(at)
	hole.arm(ball)
	for _i in 8:
		await physics_frame
	ball.launch(dir, speed)
	var max_y := ball.global_position.y
	for i in 300:
		await physics_frame
		max_y = maxf(max_y, ball.global_position.y)
		var ev := str(hole.poll())
		if ev == "cup" or ev == "oob" or (i > 30 and ball.linear_velocity.length() < 0.07):
			print("ROLL speed %.1f %s pos %s maxy %.2f" % [speed, ev if ev != "" else "stop", ball.global_position, max_y])
			return


func _clear_hole(hole: Node3D) -> void:
	if hole.get_child_count() > 0:
		for child in hole.get_children():
			hole.remove_child(child)
			child.free()


func _scan_lane(hole: Node3D, index: int) -> void:
	_clear_hole(hole)
	hole.setup(index)
	for _i in 4:
		await physics_frame
	var space := hole.get_world_3d().direct_space_state
	print("SCAN hole %d" % index)
	for z in range(0, -100, -4):
		var row := ""
		for x in range(-16, 18, 2):
			var p := Vector3(x * 0.1, 0.08, z * 0.1)
			var q := PhysicsRayQueryParameters3D.create(p, p + Vector3(0, 0, -0.35))
			var hit := space.intersect_ray(q)
			var ch := "."
			if not hit.is_empty():
				var label := str((hit.collider as Node).name)
				if label.begins_with("Rails"):
					ch = "R"
				elif label.begins_with("Obstacles") or label.find("Pin") >= 0 or label.find("Spoon") >= 0 or label.find("Mug") >= 0:
					ch = "#"
				elif label.find("Flour") >= 0 or label.find("Base") >= 0 or label.find("Coffee") >= 0:
					ch = "h"
				else:
					ch = "+"
			row += ch
		print("SCAN z=%.1f %s" % [z * 0.1, row])


func _roll_until(hole: Node3D, ball: RigidBody3D, index: int, dir: Vector3, speed: float) -> void:
	_clear_hole(hole)
	hole.setup(index)
	for _i in 6:
		await physics_frame
	ball.park(hole.tee_pos())
	hole.arm(ball)
	ball.launch(dir, speed)
	var max_y := 0.0
	for i in 360:
		await physics_frame
		max_y = maxf(max_y, ball.global_position.y)
		var event := str(hole.poll())
		if i % 20 == 0 or event != "":
			print("ROLL h%d i=%d ev=%s pos=%s vel=%.2f maxy=%.2f" % [index, i, event, ball.global_position, ball.linear_velocity.length(), max_y])
		if event == "cup" or event == "oob":
			return


func _maze_path(hole: Node3D) -> void:
	hole.setup(12)
	for _i in 6:
		await physics_frame
	var space := hole.get_world_3d().direct_space_state
	var step := 0.15
	var cols := 40
	var rows := 30
	var blocked := {}
	for r in rows:
		for c in cols:
			var x := -2.4 + float(c) * step
			var z := 0.3 - float(r) * step
			blocked["%d,%d" % [c, r]] = _solid(space, Vector3(x, 0.06, z))
	var start_c := int(round((0.0 + 2.4) / step))
	var start_r := int(round((0.3 - 0.0) / step))
	var goal_c := int(round((1.3 + 2.4) / step))
	var goal_r := int(round((0.3 - (-3.2)) / step))
	print("PATH start %d,%d goal %d,%d blocked_start %s blocked_goal %s" % [start_c, start_r, goal_c, goal_r, blocked["%d,%d" % [start_c, start_r]], blocked["%d,%d" % [goal_c, goal_r]]])
	var q: Array[Vector2i] = [Vector2i(start_c, start_r)]
	var prev := {}
	prev["%d,%d" % [start_c, start_r]] = Vector2i(-1, -1)
	var found := false
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		if cur.x == goal_c and cur.y == goal_r:
			found = true
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + d
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= cols or nxt.y >= rows:
				continue
			var key := "%d,%d" % [nxt.x, nxt.y]
			if prev.has(key) or bool(blocked[key]):
				continue
			var from := Vector3(-2.4 + float(cur.x) * step, 0.06, 0.3 - float(cur.y) * step)
			var to := Vector3(-2.4 + float(nxt.x) * step, 0.06, 0.3 - float(nxt.y) * step)
			if not _edge_clear(space, from, to):
				continue
			prev[key] = cur
			q.append(nxt)
	print("PATH found ", found)
	if not found:
		return
	var cells: Array[Vector2i] = []
	var walk := Vector2i(goal_c, goal_r)
	while walk.x >= 0:
		cells.append(walk)
		walk = prev["%d,%d" % [walk.x, walk.y]]
	cells.reverse()
	var prev_dir := Vector2i(0, 0)
	for i in cells.size():
		var cell: Vector2i = cells[i]
		var p := Vector2(-2.4 + float(cell.x) * step, 0.3 - float(cell.y) * step)
		var dir := Vector2i(0, 0)
		if i + 1 < cells.size():
			var nxt: Vector2i = cells[i + 1]
			dir = nxt - cell
		if i == 0 or dir != prev_dir:
			print("WAY %.2f %.2f" % [p.x, p.y])
		prev_dir = dir


func _hit_wall(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	var label := str((hit.collider as Node).name)
	return label.begins_with("Obstacles") or label.begins_with("Rails")


func _solid(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	for i in 8:
		var ang := float(i) * TAU / 8.0
		var delta := Vector3(cos(ang), 0.0, sin(ang)) * 0.08
		if _hit_wall(space, at, at + delta):
			return true
	return false


func _edge_clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var delta := to - from
	if delta.length() < 0.001:
		return true
	var side := Vector3(-delta.z, 0.0, delta.x).normalized()
	for off in [-0.07, 0.0, 0.07]:
		var shift := side * float(off)
		if _hit_wall(space, from + shift, to + shift):
			return false
	return not _solid(space, to)


func _maze_roll(hole: Node3D, ball: RigidBody3D) -> void:
	hole.setup(12)
	for _i in 8:
		await physics_frame
	ball.park(hole.tee_pos())
	hole.arm(ball)
	ball.launch(Vector3(-1, 0, 0), 2.0)
	for i in 400:
		await physics_frame
		var event := str(hole.poll())
		if i % 15 == 0 or event != "":
			print("ROLL i=%d ev=%s pos=%s vel=%.2f" % [i, event, ball.global_position, ball.linear_velocity.length()])
		if event == "cup" or event == "oob":
			return
	print("ROLL end pos=%s" % ball.global_position)


func _maze(hole: Node3D) -> void:
	if hole.get_child_count() > 0:
		for child in hole.get_children():
			hole.remove_child(child)
			child.free()
	hole.setup(12)
	for _i in 5:
		await physics_frame
	var space := hole.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.07
	print("GRID x from -2.6 to 2.4 step 0.2")
	for zi in range(2, -38, -2):
		var row := ""
		for xi in range(-26, 26, 2):
			var params := PhysicsShapeQueryParameters3D.new()
			params.shape = shape
			params.transform = Transform3D(Basis(), Vector3(xi * 0.1, 0.08, zi * 0.1))
			var hits := space.intersect_shape(params, 4)
			var blocked := false
			for hit in hits:
				var label := str((hit.collider as Node).name)
				if label.begins_with("Obstacles") or label.begins_with("Rails"):
					blocked = true
			row += "#" if blocked else "."
		print("GRID z=%.1f %s" % [zi * 0.1, row])


func _anim(hole: Node3D, index: int, part: String) -> void:
	if hole.get_child_count() > 0:
		for child in hole.get_children():
			hole.remove_child(child)
			child.free()
	hole.setup(index)
	var node := hole.call("find_part", part) as Node3D
	if node == null:
		print("PROBE anim hole %d missing %s" % [index, part])
		return
	var first_rot: Vector3 = node.rotation
	var first_pos: Vector3 = node.position
	for step in 6:
		for _i in 30:
			await physics_frame
		print("PROBE anim hole %d %s t=%.1f pos %s rot %s" % [index, part, 0.5 * float(step + 1), node.position, node.rotation])
	print("PROBE anim hole %d %s rot %s -> %s pos %s -> %s" % [index, part, first_rot, node.rotation, first_pos, node.position])


func _ray(ball: RigidBody3D) -> String:
	var space := ball.get_world_3d().direct_space_state
	if space == null:
		return "no-space"
	var pos := ball.global_position
	var query := PhysicsRayQueryParameters3D.create(pos, pos + Vector3(0, -0.35, 0))
	query.exclude = [ball.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return "none"
	var label := str((hit.collider as Node).name) if hit.collider is Node else "?"
	return "%s d=%.3f" % [label, pos.distance_to(hit.position)]
