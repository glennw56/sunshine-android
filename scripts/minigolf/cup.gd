extends RefCounted
## A recessed cup. The green collider is cut open and the ball falls in.
## A bevelled rim kicks a fast putt back out. Nothing teleports the ball.

const Catalog := preload("res://scripts/minigolf/catalog.gd")

const OPENING := 0.20
const THROAT := 0.155
const DEPTH := 0.17


static func build(hole: Node3D) -> Dictionary:
	var marker := hole.find_child("CupCenter", true, false) as Node3D
	if marker == null:
		push_error("Mini golf cup missing on " + str(hole.name))
		return {}
	var surface := _surface_y(hole, marker.global_position)
	var cup := Vector3(marker.global_position.x, surface, marker.global_position.z)
	var removed := _punch(hole, cup, OPENING + 0.045)
	_well(hole, cup)
	_visual(hole, cup)
	print("CUP build hole %s surface %.3f punched %d" % [hole.name, surface, removed])
	return {"y": surface, "radius": THROAT, "opening": OPENING}


static func _surface_y(hole: Node3D, marker: Vector3) -> float:
	var space := hole.get_world_3d().direct_space_state if hole.is_inside_tree() else null
	if space == null:
		return marker.y
	var query := PhysicsRayQueryParameters3D.create(marker + Vector3(0, 1.6, 0), marker + Vector3(0, -0.6, 0))
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return marker.y
	var at: Vector3 = hit.position
	if absf(at.y - marker.y) > 0.45:
		return marker.y
	return at.y


static func _punch(hole: Node3D, cup: Vector3, radius: float) -> int:
	var removed := 0
	var stack: Array = [hole]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CollisionShape3D and (node as CollisionShape3D).shape != null:
			var body := node.get_parent()
			if body is CollisionObject3D and _should_punch(body as CollisionObject3D, node as CollisionShape3D, cup, radius):
				removed += _punch_shape(node as CollisionShape3D, cup, radius)
		for child in node.get_children():
			stack.append(child)
	return removed


static func _should_punch(body: CollisionObject3D, shape: CollisionShape3D, cup: Vector3, radius: float) -> bool:
	var label := str(body.name)
	if label == "CupRim" or label == "CupFloor" or label == "CupVisual":
		return false
	# Every deck is SolidDeck_<n>. Walls share that prefix but are too tall to cut.
	var floorish := label.begins_with("Green") or label.begins_with("Bowl") or label.begins_with("Chute") or label.begins_with("SolidDeck") or label == "Cup" or label.begins_with("Cup-")
	if not floorish:
		return false
	if shape.shape is BoxShape3D:
		var box := shape.shape as BoxShape3D
		if box.size.y > 0.22:
			return false
		var local: Vector3 = shape.global_transform.affine_inverse() * cup
		var half := box.size * 0.5
		if absf(local.y) > half.y + 0.12:
			return false
		return absf(local.x) < half.x + radius and absf(local.z) < half.z + radius
	return true


static func _punch_shape(shape: CollisionShape3D, cup: Vector3, radius: float) -> int:
	var source: PackedVector3Array = PackedVector3Array()
	if shape.shape is ConcavePolygonShape3D:
		source = (shape.shape as ConcavePolygonShape3D).get_faces()
	elif shape.shape is BoxShape3D:
		_punch_box(shape, cup, radius)
		return 1
	else:
		return 0
	if source.size() < 9:
		return 0
	var xf := shape.global_transform
	var inv := xf.affine_inverse()
	var local := PackedVector3Array()
	var dropped := 0
	var i := 0
	while i + 2 < source.size():
		var a := xf * source[i]
		var b := xf * source[i + 1]
		var c := xf * source[i + 2]
		var before := local.size()
		_clip_triangle(local, a, b, c, cup, radius, inv)
		if local.size() == before:
			dropped += 1
		i += 3
	if local.size() < 12 and source.size() > 48:
		push_error("Cup punch collapsed a collider on " + str(shape.name))
		return 0
	var carved := ConcavePolygonShape3D.new()
	carved.set_faces(local)
	shape.shape = carved
	shape.disabled = local.is_empty()
	return dropped


static func _punch_box(shape: CollisionShape3D, cup: Vector3, radius: float) -> void:
	# Four solid boxes around a square hole. A triangle mesh lets a fast
	# putt fall through the fairway.
	var box := shape.shape as BoxShape3D
	var half := box.size * 0.5
	var local: Vector3 = shape.global_transform.affine_inverse() * cup
	var axes := shape.global_transform.basis
	var rx := radius / maxf(Vector2(axes.x.x, axes.x.z).length(), 0.25)
	var rz := radius / maxf(Vector2(axes.z.x, axes.z.z).length(), 0.25)
	var parent := shape.get_parent()
	shape.disabled = true
	var left_w := (local.x - rx) + half.x
	var right_w := half.x - (local.x + rx)
	var near_d := (local.z - rz) + half.z
	var far_d := half.z - (local.z + rz)
	_frame_piece(parent, shape, Vector3(-half.x + left_w * 0.5, 0.0, 0.0), Vector3(left_w, box.size.y, box.size.z))
	_frame_piece(parent, shape, Vector3(local.x + rx + right_w * 0.5, 0.0, 0.0), Vector3(right_w, box.size.y, box.size.z))
	_frame_piece(parent, shape, Vector3(0.0, 0.0, -half.z + near_d * 0.5), Vector3(box.size.x, box.size.y, near_d))
	_frame_piece(parent, shape, Vector3(0.0, 0.0, local.z + rz + far_d * 0.5), Vector3(box.size.x, box.size.y, far_d))


static func _frame_piece(parent: Node, shape: CollisionShape3D, center: Vector3, size: Vector3) -> void:
	if size.x < 0.03 or size.z < 0.03 or size.y < 0.02:
		return
	var piece := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	piece.shape = box
	piece.transform = Transform3D(shape.transform.basis, shape.transform * center)
	parent.add_child(piece)


static func _box_faces(shape: CollisionShape3D) -> PackedVector3Array:
	var half := (shape.shape as BoxShape3D).size * 0.5
	var hx := half.x
	var hy := half.y
	var hz := half.z
	var p := [
		Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, -hy, hz), Vector3(-hx, -hy, hz),
		Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz),
	]
	var quads := [
		[4, 5, 6, 7],
		[0, 3, 2, 1],
		[0, 1, 5, 4],
		[3, 2, 6, 7],
		[1, 2, 6, 5],
		[0, 4, 7, 3],
	]
	var faces := PackedVector3Array()
	for quad in quads:
		var i0 := int(quad[0])
		var i1 := int(quad[1])
		var i2 := int(quad[2])
		var i3 := int(quad[3])
		faces.append_array(PackedVector3Array([p[i0], p[i1], p[i2], p[i0], p[i2], p[i3]]))
	return faces


static func _clip_triangle(out: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, cup: Vector3, radius: float, inv: Transform3D) -> void:
	# Leave fairway triangles alone. Only faces near the cup are cut.
	if _dist_xz(a, cup) > radius + 0.75 and _dist_xz(b, cup) > radius + 0.75 and _dist_xz(c, cup) > radius + 0.75:
		out.append(inv * a)
		out.append(inv * b)
		out.append(inv * c)
		return
	# A green triangle often contains the whole cup. Split it into wedges
	# that each touch the hole, then clip those.
	if _in_tri_xz(cup, a, b, c) and not _any_hit(a, b, c, cup, radius):
		var src: Array[Vector3] = [a, b, c]
		var samples := 4
		for e in 3:
			var p0: Vector3 = src[e]
			var p1: Vector3 = src[(e + 1) % 3]
			for s in samples:
				var t0 := float(s) / float(samples)
				var t1 := float(s + 1) / float(samples)
				var p: Vector3 = p0.lerp(p1, t0)
				var q: Vector3 = p0.lerp(p1, t1)
				var hub := Vector3(cup.x, (p.y + q.y) * 0.5, cup.z)
				_clip_open(out, p, q, hub, cup, radius, inv)
		return
	_clip_open(out, a, b, c, cup, radius, inv)


static func _any_hit(a: Vector3, b: Vector3, c: Vector3, cup: Vector3, radius: float) -> bool:
	if not _seg_hits(a, b, cup, radius).is_empty():
		return true
	if not _seg_hits(b, c, cup, radius).is_empty():
		return true
	return not _seg_hits(c, a, cup, radius).is_empty()


static func _clip_open(out: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, cup: Vector3, radius: float, inv: Transform3D) -> void:
	var poly := _outside_poly(a, b, c, cup, radius)
	if poly.size() < 3:
		return
	poly = _with_arcs(poly, cup, radius, a, b, c)
	if poly.size() < 3:
		return
	var p0: Vector3 = poly[0]
	for i in range(1, poly.size() - 1):
		out.append(inv * p0)
		out.append(inv * poly[i])
		out.append(inv * poly[i + 1])


static func _outside_poly(a: Vector3, b: Vector3, c: Vector3, cup: Vector3, radius: float) -> Array[Vector3]:
	var src: Array[Vector3] = [a, b, c]
	var poly: Array[Vector3] = []
	for i in 3:
		var p: Vector3 = src[i]
		var q: Vector3 = src[(i + 1) % 3]
		if not _inside(p, cup, radius):
			_push_unique(poly, p)
		var hits := _seg_hits(p, q, cup, radius)
		for h_i in hits.size():
			_push_unique(poly, hits[h_i])
	return poly


static func _with_arcs(poly: Array[Vector3], cup: Vector3, radius: float, a: Vector3, b: Vector3, c: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n := poly.size()
	for i in n:
		var p: Vector3 = poly[i]
		var q: Vector3 = poly[(i + 1) % n]
		out.append(p)
		if not _on_rim(p, cup, radius) or not _on_rim(q, cup, radius):
			continue
		var mid := p.lerp(q, 0.5)
		if _dist_xz(mid, cup) >= radius * 0.992:
			continue
		var arc := _arc(p, q, cup, radius, a, b, c)
		for k in range(1, arc.size() - 1):
			out.append(arc[k])
	return out


static func _arc(p: Vector3, q: Vector3, cup: Vector3, radius: float, a: Vector3, b: Vector3, c: Vector3) -> Array[Vector3]:
	var a0 := atan2(p.z - cup.z, p.x - cup.x)
	var a1 := atan2(q.z - cup.z, q.x - cup.x)
	# A big green triangle contains both arcs. The hole boundary is the
	# shorter one that still sits inside the triangle.
	var sweep := wrapf(a1 - a0, -PI, PI)
	var best_abs := 99.0
	for dir_i in 2:
		var dir := 1.0 if dir_i == 0 else -1.0
		var delta := _directed_delta(a0, a1, dir)
		var mid_ang := a0 + delta * 0.5
		var mid := Vector3(cup.x + cos(mid_ang) * radius, lerpf(p.y, q.y, 0.5), cup.z + sin(mid_ang) * radius)
		if _in_tri_xz(mid, a, b, c) and absf(delta) < best_abs:
			sweep = delta
			best_abs = absf(delta)
	var steps := clampi(int(absf(sweep) / 0.42) + 1, 2, 8)
	var pts: Array[Vector3] = []
	for s in steps + 1:
		var t := float(s) / float(steps)
		var ang := a0 + sweep * t
		pts.append(Vector3(cup.x + cos(ang) * radius, lerpf(p.y, q.y, t), cup.z + sin(ang) * radius))
	return pts


static func _directed_delta(a0: float, a1: float, dir: float) -> float:
	var delta := wrapf(a1 - a0, -PI, PI)
	if dir > 0.0 and delta < 0.0:
		delta += TAU
	elif dir < 0.0 and delta > 0.0:
		delta -= TAU
	return delta


static func _seg_hits(p: Vector3, q: Vector3, cup: Vector3, radius: float) -> Array[Vector3]:
	var dx := q.x - p.x
	var dz := q.z - p.z
	var fx := p.x - cup.x
	var fz := p.z - cup.z
	var a := dx * dx + dz * dz
	var b := 2.0 * (fx * dx + fz * dz)
	var c := fx * fx + fz * fz - radius * radius
	var hits: Array[Vector3] = []
	if a < 1e-10:
		return hits
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return hits
	var root := sqrt(disc)
	for side_i in 2:
		var sign := -1.0 if side_i == 0 else 1.0
		var t := (-b + sign * root) / (2.0 * a)
		if t > 0.004 and t < 0.996:
			hits.append(p.lerp(q, t))
	if hits.size() == 2 and p.distance_squared_to(hits[0]) > p.distance_squared_to(hits[1]):
		var swap: Vector3 = hits[0]
		hits[0] = hits[1]
		hits[1] = swap
	return hits


static func _push_unique(poly: Array[Vector3], point: Vector3) -> void:
	if poly.is_empty() or poly[poly.size() - 1].distance_to(point) > 0.0015:
		poly.append(point)


static func _inside(point: Vector3, cup: Vector3, radius: float) -> bool:
	return _dist_xz(point, cup) < radius - 0.001


static func _on_rim(point: Vector3, cup: Vector3, radius: float) -> bool:
	return absf(_dist_xz(point, cup) - radius) < 0.006


static func _dist_xz(point: Vector3, cup: Vector3) -> float:
	return Vector2(point.x - cup.x, point.z - cup.z).length()


static func _in_tri_xz(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var v0 := Vector2(c.x - a.x, c.z - a.z)
	var v1 := Vector2(b.x - a.x, b.z - a.z)
	var v2 := Vector2(p.x - a.x, p.z - a.z)
	var dot00 := v0.dot(v0)
	var dot01 := v0.dot(v1)
	var dot02 := v0.dot(v2)
	var dot11 := v1.dot(v1)
	var dot12 := v1.dot(v2)
	var den := dot00 * dot11 - dot01 * dot01
	if absf(den) < 1e-8:
		return false
	var u := (dot11 * dot02 - dot01 * dot12) / den
	var v := (dot00 * dot12 - dot01 * dot02) / den
	return u >= -0.04 and v >= -0.04 and u + v <= 1.04


static func _well(hole: Node3D, cup: Vector3) -> void:
	# Low bounce. A fast putt lips out because it hits the far slope, not
	# because the rim is a trampoline.
	var rim := _body(hole, "CupRim", 0.06, 0.18)
	var floor_body := _body(hole, "CupFloor", 0.55, 0.02)
	rim.global_position = Vector3(cup.x, 0.0, cup.z)
	floor_body.global_position = Vector3(cup.x, 0.0, cup.z)
	_collar(rim, cup.y)
	_bevel(rim, cup.y)
	_vertical_wall(rim, cup.y - 0.07, cup.y - DEPTH, THROAT)
	var floor_shape := CollisionShape3D.new()
	var disk := CylinderShape3D.new()
	# Wider than the throat, so a gap between wall segments cannot swallow the ball.
	# Wider than the stairstep cut, so a ball cannot fall past the cup onto the base.
	disk.radius = OPENING + 0.22
	disk.height = 0.06
	floor_shape.shape = disk
	floor_shape.position = Vector3(0.0, cup.y - DEPTH, 0.0)
	floor_body.add_child(floor_shape)


static func _collar(body: StaticBody3D, surface_y: float) -> void:
	var segs := 18
	var inner := OPENING
	var outer := OPENING + 0.07
	var mid_r := (inner + outer) * 0.5
	var height := 0.04
	var mid_y := surface_y - height * 0.5
	for i in segs:
		var ang := TAU * (float(i) + 0.5) / float(segs)
		var radial := Vector3(cos(ang), 0.0, sin(ang))
		var tangent := Vector3.UP.cross(radial).normalized()
		var chord := 2.2 * outer * sin(PI / float(segs))
		var box := BoxShape3D.new()
		box.size = Vector3(outer - inner, height, chord)
		var shape := CollisionShape3D.new()
		shape.shape = box
		shape.transform = Transform3D(Basis(radial, Vector3.UP, tangent), radial * mid_r + Vector3(0.0, mid_y, 0.0))
		body.add_child(shape)


static func _bevel(body: StaticBody3D, surface_y: float) -> void:
	# Slope faces the cup. The outer edge is flush with the green and the
	# inner edge is lower, so a slow putt falls in and a fast one hits the
	# far side and comes back out.
	var segs := 24
	var drop := 0.055
	var span := OPENING - THROAT
	var tilt := atan2(drop, span)
	var mid_r := (OPENING + THROAT) * 0.5
	var slope_len := Vector2(span, drop).length()
	for i in segs:
		var ang := TAU * (float(i) + 0.5) / float(segs)
		var radial := Vector3(cos(ang), 0.0, sin(ang))
		var tangent := Vector3.UP.cross(radial).normalized()
		var normal := (-radial * sin(tilt) + Vector3.UP * cos(tilt)).normalized()
		var down := normal.cross(tangent).normalized()
		var chord := 2.35 * OPENING * sin(PI / float(segs))
		var thick := 0.04
		var box := BoxShape3D.new()
		# Slightly short of the slope so the outer corner stays under the green.
		box.size = Vector3(slope_len * 0.92, thick, chord)
		var shape := CollisionShape3D.new()
		shape.shape = box
		var top := radial * mid_r + Vector3(0.0, surface_y - drop * 0.5, 0.0)
		shape.transform = Transform3D(Basis(down, normal, tangent), top - normal * thick * 0.5)
		body.add_child(shape)


static func _vertical_wall(body: StaticBody3D, y0: float, y1: float, radius: float) -> void:
	var segs := 16
	var height := absf(y1 - y0)
	var mid_y := (y0 + y1) * 0.5
	for i in segs:
		var ang := TAU * (float(i) + 0.5) / float(segs)
		var radial := Vector3(cos(ang), 0.0, sin(ang))
		var tangent := Vector3.UP.cross(radial).normalized()
		var chord := 2.15 * radius * sin(PI / float(segs)) + 0.01
		var box := BoxShape3D.new()
		box.size = Vector3(0.06, height, chord)
		var shape := CollisionShape3D.new()
		shape.shape = box
		var center := radial * (radius + 0.03) + Vector3(0.0, mid_y, 0.0)
		shape.transform = Transform3D(Basis(radial, Vector3.UP, tangent), center)
		body.add_child(shape)


static func _visual(hole: Node3D, cup: Vector3) -> void:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "CupVisual"
	var mesh := CylinderMesh.new()
	mesh.top_radius = THROAT - 0.01
	mesh.bottom_radius = THROAT * 0.86
	mesh.height = DEPTH - 0.03
	mesh.radial_segments = 28
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.09, 0.045, 0.035)
	mesh.material = mat
	mesh_node.mesh = mesh
	hole.add_child(mesh_node)
	mesh_node.global_position = Vector3(cup.x, cup.y - DEPTH * 0.55, cup.z)


static func _body(hole: Node3D, body_name: String, friction: float, bounce: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = 1
	body.collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.friction = friction
	mat.bounce = bounce
	body.physics_material_override = mat
	hole.add_child(body)
	return body
