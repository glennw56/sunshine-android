extends RefCounted
## Plays a full round with the same rules as a finger. Powers for the donut
## loop and the coffee-cup jump are the catalog tunables.

const Catalog := preload("res://scripts/minigolf/catalog.gd")

const WAYPOINTS := {
	3: [Vector2(0.82, -1.35), Vector2(0.86, -2.85), Vector2(0.84, -4.25), Vector2(0.55, -5.55)],
	6: [Vector2(0.4, -1.5), Vector2(1.6, -2.15), Vector2(2.7, -1.15), Vector2(3.0, -0.25)],
	7: [Vector2(0.15, -2.2), Vector2(0.35, -4.2), Vector2(0.5, -5.88)],
	9: [Vector2(0, -2.4), Vector2(0, -5.6), Vector2(0, -7.35)],
	10: [Vector2(-0.15, -2.2), Vector2(0.35, -4.0), Vector2(-0.15, -5.5), Vector2(-0.4, -6.7)],
	11: [Vector2(0, -1.6), Vector2(0, -3.6), Vector2(0, -5.4), Vector2(-0.25, -7.1)],
	12: [Vector2(-0.9, -0.2), Vector2(-0.9, -1.6), Vector2(0.75, -1.6), Vector2(0.75, -2.7), Vector2(1.3, -3.15)],
	13: [Vector2(0.05, -1.8), Vector2(0.12, -3.6), Vector2(0.2, -5.2), Vector2(0.25, -6.3)],
	16: [Vector2(-0.13, -0.94), Vector2(-0.87, -2.28), Vector2(-2.13, -3.15), Vector2(-3.64, -3.39), Vector2(-5.10, -2.94), Vector2(-6.22, -1.90), Vector2(-6.77, -0.47), Vector2(-6.63, 1.05), Vector2(-5.85, 2.36), Vector2(-4.56, 3.19), Vector2(-3.04, 3.38), Vector2(-1.78, 2.92)],
	18: [Vector2(0.0, -2.6), Vector2(0.95, -4.2), Vector2(0.95, -5.9), Vector2(0.25, -6.5), Vector2(0.0, -7.7), Vector2(0.0, -8.95)],
}


static func ready(hole_index: int, hole: Node3D) -> bool:
	if hole_index == 5:
		var whisk := hole.call("find_part", "Whisk") as Node3D
		if whisk == null:
			return true
		return absf(sin(whisk.rotation.z)) > 0.82
	if hole_index == 8:
		var door := hole.call("find_part", "OvenDoor") as Node3D
		if door == null:
			return true
		return absf(wrapf(door.rotation.x, -PI, PI)) < 0.45
	return true


static func choose(hole_index: int, ball: Vector3, cup: Vector3, hole: Node3D, wp_i: int, bias: float, space: PhysicsDirectSpaceState3D, exclude: RID) -> Dictionary:
	var guard := 0
	while guard < 8:
		var nxt := _advanced_wp(hole_index, ball, wp_i)
		if nxt == wp_i:
			break
		wp_i = nxt
		guard += 1
	var target := _target(hole_index, ball, cup, hole, wp_i)
	var flat := target - ball
	flat.y = 0.0
	var dist := flat.length()
	var dir := Vector3(0, 0, -1) if dist < 0.05 else flat.normalized()
	var power := Catalog.power_for_speed(4.2)
	if dist < 1.15:
		power = Catalog.power_for_speed(1.5)
	elif dist < 2.2:
		power = Catalog.power_for_speed(2.1)
	elif dist < 3.4:
		power = Catalog.power_for_speed(3.0)
	else:
		power = Catalog.power_for_speed(clampf(4.0 + (dist - 3.4) * 0.4, 4.0, 6.0))
	var scripted := false
	if hole_index == 4 and ball.z > -0.35:
		# Into the mouth. The tee is too far for one putt to clear the donut.
		dir = Vector3(0, 0, -1)
		power = Catalog.power_for_speed(9.0)
		scripted = true
	elif hole_index == 4 and ball.z < -2.6 and ball.x < 0.45:
		# Back to the approach. From here a full putt reaches the exit lane.
		dir = Vector3(0, 0, 1)
		power = Catalog.power_for_speed(2.4)
		scripted = true
	elif hole_index == 4 and ball.x < 0.45:
		dir = Vector3(0, 0, -1)
		power = Catalog.power_for_speed(9.0)
		scripted = true
	elif hole_index == 4 and ball.x > 0.45 and ball.z < -3.7 and ball.y < 0.25:
		var to_loop := Vector3(1.0, 0.0, -6.6) - ball
		to_loop.y = 0.0
		dir = to_loop.normalized() if to_loop.length() > 0.05 else Vector3(0, 0, -1)
		power = Catalog.power_for_speed(clampf(1.4 + to_loop.length() * 0.28, 1.45, 1.9))
		scripted = true
	elif hole_index == 14 and ball.y < 0.28 and ball.z > -3.7:
		dir = Vector3(0, 0, -1)
		power = Catalog.power_for_speed(6.0)
		scripted = true
	elif hole_index == 14 and ball.y > 0.3:
		var to_mug := cup - ball
		to_mug.y = 0.0
		dir = to_mug.normalized() if to_mug.length() > 0.05 else Vector3(0, 0, -1)
		var mug_dist := to_mug.length()
		var mug_pace := 1.25 if mug_dist < 0.55 else clampf(1.2 + mug_dist * 0.25, 1.35, 1.7)
		power = Catalog.power_for_speed(mug_pace)
		scripted = true
	elif hole_index == 2:
		# The flour pit is the hazard. The ball crosses on the pins when the
		# putt stays on x = 0. A rolling putt still has its speed at the pins,
		# and anything quicker than this kicks into the flour.
		var mark := Vector3(0.22, 0.0, -6.32)
		var pace := 2.2
		if ball.z > -1.7:
			mark = Vector3(0.0, 0.0, -5.2)
			pace = 3.6
		elif ball.z > -4.6:
			mark = Vector3(0.0, 0.0, -5.2)
			pace = 2.4
		else:
			var hop2 := Vector2(ball.x - 0.22, ball.z + 6.32).length()
			pace = 1.45 if hop2 < 0.55 else clampf(1.45 + hop2 * 0.55, 1.7, 2.4)
		var to_pin := mark - ball
		to_pin.y = 0.0
		dir = to_pin.normalized() if to_pin.length() > 0.05 else Vector3(0, 0, -1)
		power = Catalog.power_for_speed(pace)
		scripted = true
	elif hole_index == 3 and ball.z > -5.05:
		power = maxf(power, Catalog.power_for_speed(3.6))
	elif hole_index == 11 and ball.z > -5.3:
		# A rolling putt keeps its pace onto the 0.30 m baguette. 3 m/s
		# skips off into the coffee; this stays on the deck.
		dir = Vector3(0, 0, -1)
		power = Catalog.power_for_speed(2.3)
		scripted = true
	elif hole_index == 5 and ball.z > -5.0:
		dir = Vector3(0, 0, -1)
		power = Catalog.power_for_speed(5.0)
		scripted = true
	elif hole_index == 8 and ball.z > -4.6:
		dir = Vector3(0, 0, -1)
		power = Catalog.power_for_speed(6.1)
		scripted = true
	elif hole_index == 6:
		# One firm putt, a little right of -Z, carries the banked U.
		# Anything that dies in the trough does not climb back out.
		var bend := Vector3(3.0, 0.0, -0.25)
		var pace := 1.6
		if ball.x < 2.2 and ball.z > -1.3:
			bend = Vector3(0.55, 0.0, -3.6)
			pace = 9.0
		else:
			var hop6 := Vector2(ball.x - 3.0, ball.z + 0.25).length()
			pace = 1.45 if hop6 < 0.55 else clampf(1.4 + hop6 * 0.7, 1.6, 2.4)
		var to_bend := bend - ball
		to_bend.y = 0.0
		dir = to_bend.normalized() if to_bend.length() > 0.05 else Vector3(0, 0, -1)
		power = Catalog.power_for_speed(pace)
		scripted = true
	elif hole_index == 7 and ball.z > -5.15:
		dir = Vector3(0.08, 0, -1).normalized()
		power = Catalog.power_for_speed(2.6)
		scripted = true
	elif hole_index == 7:
		var to_shelf := Vector3(0.50, 0.0, -5.88) - ball
		to_shelf.y = 0.0
		dir = to_shelf.normalized() if to_shelf.length() > 0.05 else Vector3(0, 0, -1)
		power = Catalog.power_for_speed(clampf(1.4 + to_shelf.length() * 0.35, 1.45, 2.1))
		scripted = true
	elif hole_index == 9 and ball.y > -0.72:
		dir = Vector3(0, 0, -1)
		power = Catalog.power_for_speed(6.2)
		scripted = true
	elif hole_index == 12:
		# Lattice gaps: x -0.4 near the tee, x -1.5 at z -1.4, x 0.1 at z -2.4, then the cup.
		var mark := Vector3(1.3, 0.0, -3.2)
		var pace := 2.1
		if ball.z > -0.45:
			mark = Vector3(-0.28, 0.0, -0.9)
			pace = 1.7
		elif ball.z > -1.4:
			mark = Vector3(-1.50, 0.0, -1.55)
			pace = 1.75
		elif ball.x < -0.9:
			mark = Vector3(0.05, 0.0, -2.6)
			pace = 1.8
		elif ball.z > -2.7:
			mark = Vector3(1.15, 0.0, -3.15)
			pace = 1.8
		else:
			var hop12 := Vector2(ball.x - 1.3, ball.z + 3.2).length()
			pace = 1.45 if hop12 < 0.55 else 1.9
		var to_maze := mark - ball
		to_maze.y = 0.0
		dir = to_maze.normalized() if to_maze.length() > 0.05 else Vector3(0, 0, -1)
		power = Catalog.power_for_speed(pace)
		scripted = true
	elif hole_index == 16 and not _on_cake_green(ball, cup):
		# The lane laps the cake. A line to the cup crosses it, so follow
		# the centerline. Each putt is short enough to stay in the lane.
		# Uphill needs a firm putt. Near the top of the second ramp a firm
		# rolling putt leaves the lane and comes back down, so ease off.
		var pace := 3.0
		if ball.y < 0.18:
			pace = 6.0
		elif ball.y < 0.38:
			pace = 5.4
		else:
			pace = clampf(1.7 + dist * 0.4, 1.8, 2.8)
		var to_lane := target - ball
		to_lane.y = 0.0
		dir = to_lane.normalized() if to_lane.length() > 0.05 else Vector3(0, 0, -1)
		power = Catalog.power_for_speed(pace)
		scripted = true
	elif hole_index == 18 and ball.y < 0.34:
		# Obstacles block the middle. The open lane is on the right, then one
		# climb. The terraces are flat, so a putt that dies on a shelf stays.
		if ball.z > -2.2:
			dir = Vector3(0, 0, -1)
			power = Catalog.power_for_speed(3.6)
		elif ball.x < 0.70 and ball.y < 0.08 and ball.z > -5.20:
			var gap := Vector3(1.15, 0.0, -5.15) - ball
			gap.y = 0.0
			dir = gap.normalized() if gap.length() > 0.05 else Vector3(1, 0, 0)
			power = Catalog.power_for_speed(2.6)
		else:
			dir = Vector3(0, 0, -1)
			power = Catalog.power_for_speed(5.6)
		scripted = true
	elif hole_index == 13 and ball.z > -5.05:
		dir = Vector3(0.04, 0, -1).normalized()
		power = Catalog.power_for_speed(3.0)
		scripted = true
	elif hole_index == 15:
		dir = _macaron_dir(ball, hole, cup)
		if dist > 1.7:
			power = clampf(dist / 5.5, 0.16, 0.52)
	var cup_flat := cup - ball
	cup_flat.y = 0.0
	var cup_dist := cup_flat.length()
	var finishable := hole_index != 10 and hole_index != 15 and hole_index != 17
	if hole_index == 3 and ball.z > -5.15:
		finishable = false
	if hole_index == 12 and (ball.z > -2.85 or ball.x < 0.7):
		finishable = false
	if hole_index == 16 and not _on_cake_green(ball, cup):
		finishable = false
	if hole_index == 18 and ball.y < 0.34:
		finishable = false
	var finishing := false
	if not scripted and finishable and cup_dist < 2.15 and cup_dist > 0.05:
		dir = cup_flat.normalized()
		if cup_dist < 0.55:
			power = Catalog.power_for_speed(1.45)
		elif cup_dist < 1.05:
			power = Catalog.power_for_speed(1.5)
		elif cup_dist < 1.6:
			power = Catalog.power_for_speed(2.0)
		else:
			power = Catalog.power_for_speed(2.5)
		finishing = true
	if not scripted and not finishing and hole_index != 18:
		dir = _clear(space, ball, dir, exclude)
	if not scripted and absf(bias) > 0.01:
		dir = dir.rotated(Vector3.UP, clampf(bias, -0.35, 0.35))
	if not scripted and absf(bias) > 0.22:
		power = minf(Catalog.power_for_speed(3.2), power + 0.08)
	if dir.length() < 0.01:
		dir = Vector3(0, 0, -1)
	return {"dir": dir.normalized(), "power": clampf(power, 0.02, 1.0), "wp": wp_i}


static func _on_cake_green(ball: Vector3, cup: Vector3) -> bool:
	# The last 2.3 m of the lane is flat at the tier-1 height. A putt from
	# there reaches the cup without crossing the cake.
	if ball.y < 0.50 or ball.z < 2.0:
		return false
	return Vector2(ball.x - cup.x, ball.z - cup.z).length() < 2.8


static func _target(hole_index: int, ball: Vector3, cup: Vector3, hole: Node3D, wp_i: int) -> Vector3:
	if hole_index == 17 and ball.z > -4.2:
		var mouth := hole.call("find_part", "PipeB_In") as Node3D
		if mouth:
			return mouth.global_position
	var wps := _wps(hole_index)
	if wps.is_empty() or wp_i >= wps.size():
		return cup
	var wp: Vector2 = wps[wp_i]
	return Vector3(wp.x, ball.y, wp.y)


static func _wps(hole_index: int) -> Array:
	return WAYPOINTS.get(hole_index, [])


static func _advanced_wp(hole_index: int, ball: Vector3, wp_i: int) -> int:
	var wps := _wps(hole_index)
	if wp_i >= wps.size():
		return wp_i
	if hole_index == 16:
		return _advance_lap(ball, wps, wp_i)
	if hole_index == 12:
		var best := wp_i
		var best_d := 999.0
		for i in range(wp_i, wps.size()):
			var mark: Vector2 = wps[i]
			var dist_mark := Vector2(ball.x - mark.x, ball.z - mark.y).length()
			if dist_mark < best_d:
				best = i
				best_d = dist_mark
			elif dist_mark > best_d + 1.2:
				break
		if best_d < 0.36:
			return mini(best + 1, wps.size())
		return best
	# The conveyor parks the first putt just past this mark. Treat that as reached
	# so the next putt keeps going down the lane instead of back across the belt.
	if hole_index == 10 and wp_i == 0 and ball.z < -1.85:
		return 1
	var cur := Vector2(ball.x - wps[wp_i].x, ball.z - wps[wp_i].y).length()
	if hole_index != 12 and hole_index != 18:
		var best := wp_i
		var best_d := cur
		for i in range(wp_i + 1, wps.size()):
			var later: Vector2 = wps[i]
			var dist_later := Vector2(ball.x - later.x, ball.z - later.y).length()
			if dist_later < best_d:
				best = i
				best_d = dist_later
		if best != wp_i:
			return best
	var passed: bool = ball.z < float(wps[wp_i].y) - 0.15 and hole_index != 6 and hole_index != 12 and hole_index != 16
	var reach := 0.45 if hole_index == 12 or hole_index == 16 or hole_index == 18 else 0.75
	if cur < reach or passed:
		return wp_i + 1
	return wp_i


static func _advance_lap(ball: Vector3, wps: Array, wp_i: int) -> int:
	# Clockwise around the cake. A mark is done once the ball has gone past
	# it, even if the ball is still closer to that mark than to the next one.
	var center := Vector2(-3.4, 0.0)
	var ball_cw := _clockwise(Vector2(ball.x, ball.z) - center)
	while wp_i < wps.size():
		var mark: Vector2 = wps[wp_i]
		if Vector2(ball.x - mark.x, ball.z - mark.y).length() < 0.6:
			wp_i += 1
			continue
		var ahead := ball_cw - _clockwise(mark - center)
		if ahead < 0.0:
			ahead += TAU
		if ahead > 0.12 and ahead < PI:
			wp_i += 1
			continue
		break
	return wp_i


static func _clockwise(rel: Vector2) -> float:
	var ang := -atan2(rel.y, rel.x)
	if ang < 0.0:
		ang += TAU
	return ang


static func _macaron_dir(ball: Vector3, hole: Node3D, cup: Vector3) -> Vector3:
	var nearest: Node3D = null
	var nearest_z := -999.0
	for id in [1, 2, 3]:
		var gate := hole.call("find_part", "MacaronGate%d" % id) as Node3D
		if gate == null:
			continue
		var gz := gate.global_position.z
		if gz < ball.z - 0.25 and gz > nearest_z:
			nearest = gate
			nearest_z = gz
	if nearest == null:
		var to := cup - ball
		to.y = 0.0
		return to.normalized() if to.length() > 0.05 else Vector3(0, 0, -1)
	var open_x := -signf(nearest.global_position.x) * 0.36
	if absf(nearest.global_position.x) < 0.08:
		open_x = 0.36
	var aim := Vector3(open_x, ball.y, nearest.global_position.z - 0.35)
	var dir := aim - ball
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.05 else Vector3(0, 0, -1)


static func _clear(space: PhysicsDirectSpaceState3D, ball: Vector3, dir: Vector3, exclude: RID) -> Vector3:
	if space == null:
		return dir
	if not _blocked(space, ball, dir, 1.15, exclude):
		return dir
	for deg in [14, -14, 28, -28, 42, -42]:
		var turned := dir.rotated(Vector3.UP, deg_to_rad(float(deg)))
		if not _blocked(space, ball, turned, 1.05, exclude):
			return turned
	return dir


static func _blocked(space: PhysicsDirectSpaceState3D, ball: Vector3, dir: Vector3, reach: float, exclude: RID) -> bool:
	var from := ball + Vector3(0, 0.02, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * reach)
	query.collision_mask = 1
	if exclude.is_valid():
		query.exclude = [exclude]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	if normal.y > 0.65:
		return false
	var label := ""
	if hit.collider is Node:
		label = str((hit.collider as Node).name)
	if label.begins_with("Green") or label.begins_with("Conveyor") or label.begins_with("Bowl") or label.begins_with("Chute"):
		return false
	return true
