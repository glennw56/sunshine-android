extends RefCounted
## Plays a full round with the same rules as a finger. Powers for the donut
## loop and the coffee-cup jump are the catalog tunables.

const Catalog := preload("res://scripts/minigolf/catalog.gd")

const WAYPOINTS := {
	3: [Vector2(1.15, -1.5), Vector2(1.2, -3.1), Vector2(1.15, -4.55), Vector2(0.55, -5.35)],
	6: [Vector2(0.4, -1.5), Vector2(1.6, -2.15), Vector2(2.7, -1.15), Vector2(3.0, -0.25)],
	7: [Vector2(0.15, -2.2), Vector2(0.35, -4.2), Vector2(0.5, -5.88)],
	9: [Vector2(0, -2.4), Vector2(0, -5.6), Vector2(0, -7.35)],
	10: [Vector2(-0.15, -2.2), Vector2(0.35, -4.0), Vector2(-0.15, -5.5), Vector2(-0.4, -6.7)],
	11: [Vector2(0, -1.6), Vector2(0, -3.6), Vector2(0, -5.4), Vector2(-0.25, -7.1)],
	12: [Vector2(-0.6, 0.0), Vector2(-0.6, -0.75), Vector2(-1.05, -0.75), Vector2(-1.05, -1.65), Vector2(0.45, -1.65), Vector2(0.45, -2.7), Vector2(1.35, -2.7), Vector2(1.35, -3.15)],
	13: [Vector2(0.05, -1.8), Vector2(0.12, -3.6), Vector2(0.2, -5.2), Vector2(0.25, -6.3)],
	18: [Vector2(0.0, -2.6), Vector2(0.9, -4.15), Vector2(0.95, -5.7), Vector2(0.15, -6.7), Vector2(0.0, -7.8), Vector2(0.0, -8.95)],
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
	if hole_index == 4 and ball.z > -4.55:
		dir = Vector3(0, 0, -1)
		power = Catalog.LOOP_POWER
		scripted = true
	elif hole_index == 14 and ball.y < 0.28 and ball.z > -3.7:
		dir = Vector3(0, 0, -1)
		power = Catalog.JUMP_POWER
		scripted = true
	elif hole_index == 2 and ball.z > -4.35:
		dir = Vector3(-0.08, 0, -1).normalized()
		power = Catalog.power_for_speed(4.4)
		scripted = true
	elif hole_index == 11 and ball.z > -5.3:
		dir = Vector3(0, 0, -1)
		power = Catalog.power_for_speed(4.4)
		scripted = true
	elif hole_index == 16 and ball.y < 0.45:
		dir = Vector3(0, 0, -1)
		power = Catalog.power_for_speed(4.6)
		scripted = true
	elif hole_index == 5 and ball.z > -5.0:
		dir = Vector3(0, 0, -1)
		power = Catalog.power_for_speed(5.0)
		scripted = true
	elif hole_index == 8 and ball.z > -4.6:
		dir = Vector3(0, 0, -1)
		power = Catalog.power_for_speed(6.1)
		scripted = true
	elif hole_index == 6 and ball.x < 2.15 and ball.z < -1.35:
		power = Catalog.power_for_speed(4.4)
	elif hole_index == 7 and ball.z > -5.15:
		dir = Vector3(0.08, 0, -1).normalized()
		power = Catalog.power_for_speed(1.7)
		scripted = true
	elif hole_index == 9 and ball.y > -0.72:
		dir = Vector3(0, 0, -1)
		power = Catalog.power_for_speed(6.2)
		scripted = true
	elif hole_index == 12 and ball.z > -2.55:
		power = Catalog.power_for_speed(3.2)
	elif hole_index == 13 and ball.z > -5.05:
		dir = Vector3(0.04, 0, -1).normalized()
		power = Catalog.power_for_speed(3.0)
		scripted = true
	elif hole_index == 15:
		dir = _macaron_dir(ball, hole, cup)
		if dist > 1.7:
			power = clampf(dist / 5.5, 0.16, 0.52)
	elif hole_index == 18 and ball.z < -6.4 and ball.y < 0.3:
		power = maxf(power, Catalog.power_for_speed(3.4))
	var cup_flat := cup - ball
	cup_flat.y = 0.0
	var cup_dist := cup_flat.length()
	var finishable := hole_index != 10 and hole_index != 15 and hole_index != 17
	if hole_index == 3 and ball.z > -5.15:
		finishable = false
	if hole_index == 12 and ball.z > -2.5:
		finishable = false
	if hole_index == 16 and ball.y < 0.9:
		finishable = false
	var finishing := false
	if not scripted and finishable and cup_dist < 2.15 and cup_dist > 0.05:
		dir = cup_flat.normalized()
		if cup_dist < 0.55:
			power = Catalog.power_for_speed(1.05)
		elif cup_dist < 1.05:
			power = Catalog.power_for_speed(1.5)
		elif cup_dist < 1.6:
			power = Catalog.power_for_speed(2.0)
		else:
			power = Catalog.power_for_speed(2.5)
		finishing = true
	if not scripted and not finishing and hole_index != 16:
		dir = _clear(space, ball, dir, exclude)
	if not scripted and absf(bias) > 0.01 and hole_index != 16:
		dir = dir.rotated(Vector3.UP, clampf(bias, -0.35, 0.35))
	if not scripted and absf(bias) > 0.22:
		power = minf(Catalog.power_for_speed(3.2), power + 0.08)
	if dir.length() < 0.01:
		dir = Vector3(0, 0, -1)
	return {"dir": dir.normalized(), "power": clampf(power, 0.02, 1.0), "wp": wp_i}


static func _target(hole_index: int, ball: Vector3, cup: Vector3, hole: Node3D, wp_i: int) -> Vector3:
	if hole_index == 17 and ball.z > -4.2:
		var mouth := hole.call("find_part", "PipeB_In") as Node3D
		if mouth:
			return mouth.global_position
	var wps: Array = WAYPOINTS.get(hole_index, [])
	if wps.is_empty() or wp_i >= wps.size():
		return cup
	var wp: Vector2 = wps[wp_i]
	return Vector3(wp.x, ball.y, wp.y)


static func _advanced_wp(hole_index: int, ball: Vector3, wp_i: int) -> int:
	var wps: Array = WAYPOINTS.get(hole_index, [])
	if wp_i >= wps.size():
		return wp_i
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
	var passed: bool = ball.z < wps[wp_i].y - 0.15 and hole_index != 6 and hole_index != 12 and hole_index != 16 and hole_index != 18
	var reach := 0.45 if hole_index == 12 or hole_index == 18 else 0.75
	if cur < reach or passed:
		return wp_i + 1
	return wp_i


static func _spiral_dir(ball: Vector3, cup: Vector3, bias: float) -> Vector3:
	if ball.distance_to(cup) < 0.85:
		var to := cup - ball
		to.y = 0.0
		return to.normalized() if to.length() > 0.05 else Vector3(0, 0, -1)
	var center := Vector3(-2.05, ball.y, 0.0)
	var rel := ball - center
	rel.y = 0.0
	if rel.length() < 0.05:
		rel = Vector3(0, 0, 1)
	var sign := -1.0 if bias < 0.0 else 1.0
	var tangent := Vector3(-rel.z, 0.0, rel.x).normalized() * sign
	var inward := (-rel.normalized()) * 0.18
	return (tangent + inward).normalized()


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
