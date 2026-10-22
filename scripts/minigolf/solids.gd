extends RefCounted
## Box and ramp colliders for the holes whose glTF trimesh snags the ball
## or dumps it through the green. The art stays. These shapes are the surface
## the ball actually rolls on.

const GREEN_FRICTION := 0.2
const RAMP_FRICTION := 0.12
const LEDGE_FRICTION := 0.08


static func apply(hole: Node3D, index: int, visual: Node) -> void:
	match index:
		2:
			_silence(visual, ["Green-colonly"])
			_hole2(hole)
		4:
			_hole4(hole)
		7:
			_silence(visual, ["Green-colonly", "Rails-colonly"])
			_hole7(hole)
		12:
			_maze_corridor(hole)
			_silence(visual, ["Obstacles-colonly", "Green-colonly", "Rails-colonly"])
		14:
			# Base is the saucer under the mug. It domes through the landing and rolls the ball back out.
			_silence(visual, ["Green-colonly", "Obstacles-colonly", "Rails-colonly", "Base-colonly"])
			_hole14(hole)
		16:
			# The glazed ledge is too slippery to rest on, and its rails bounce.
			_silence(visual, ["Rails-colonly", "Green-colonly", "Base-colonly", "Obstacles-colonly"])
			_hole16(hole)
		18:
			# Art rails bounce the ball back down the shop, and the ramp
			# trimesh is open along the centre line.
			_silence(visual, ["Rails-colonly"])
			_hole18(hole)


static func _hole2(hole: Node3D) -> void:
	# Flat decks. The glazed green banks into the flour; a centred bridge does not.
	# The bridge is the groove between the pins (centres x = ±0.105).
	_deck(hole, Vector3(0, 0.0, 0.45), Vector3(0, 0.0, -2.3), 1.15, GREEN_FRICTION)
	_deck(hole, Vector3(0, 0.02, -2.15), Vector3(0, 0.02, -3.95), 0.34, GREEN_FRICTION)
	_lip_pair(hole, Vector3(0, 0.02, -2.2), Vector3(0, 0.02, -3.9), 0.34)
	_deck(hole, Vector3(0.05, 0.0, -3.8), Vector3(0.22, 0.0, -6.9), 1.15, GREEN_FRICTION)
	_wall(hole, Vector3(0.22, 0.12, -6.55), Vector3(1.1, 0.24, 0.08))
	_lip_pair(hole, Vector3(0, 0.0, 0.4), Vector3(0, 0.0, -2.25), 1.15)


static func _hole4(hole: Node3D) -> void:
	# Channel loop. The riding face points at the circle centre, so the top
	# of the loop holds the ball. One turn drifts +1 m in X, matching the art.
	_deck(hole, Vector3(0, 0.0, 0.45), Vector3(0, 0.04, -3.55), 0.7, 0.04)
	var segs := 32
	var radius := 0.8
	var cy := 0.84
	var cz := -3.5
	for i in segs:
		var u0 := float(i) / float(segs)
		var u1 := float(i + 1) / float(segs)
		var a0 := TAU * u0
		var a1 := TAU * u1
		var p0 := _loop_point(a0, u0, radius, cy, cz)
		var p1 := _loop_point(a1, u1, radius, cy, cz)
		var amid := (a0 + a1) * 0.5
		var normal := Vector3(0, cos(amid), sin(amid))
		_deck_normal(hole, p0, p1, 0.42, normal, 0.02, 1.5)
		if i > 2:
			_loop_lips(hole, p0, p1, normal, 0.42, 0.18)
	_deck(hole, Vector3(1.0, 0.02, -3.45), Vector3(1.0, 0.0, -6.75), 0.75, GREEN_FRICTION)


static func _loop_point(ang: float, u: float, radius: float, cy: float, cz: float) -> Vector3:
	return Vector3(lerpf(0.0, 1.0, u), cy - radius * cos(ang), cz - radius * sin(ang))


static func _hole7(hole: Node3D) -> void:
	# Slope ends on the cup. The back rail used to pocket the ball past the hole.
	_deck(hole, Vector3(0.05, 0.0, -0.4), Vector3(0.5, -0.34, -6.4), 0.95, RAMP_FRICTION)
	_wall(hole, Vector3(0.5, -0.2, -6.15), Vector3(0.9, 0.28, 0.08))
	_lip_pair(hole, Vector3(0.05, 0.0, -0.4), Vector3(0.48, -0.28, -5.7), 0.95)
	_wall(hole, Vector3(-0.55, 0.15, -3.0), Vector3(0.08, 0.35, 5.4))
	_wall(hole, Vector3(1.05, 0.0, -3.0), Vector3(0.08, 0.35, 5.4))


static func _hole14(hole: Node3D) -> void:
	_deck(hole, Vector3(0, 0.0, 0.4), Vector3(0, 0.0, -1.7), 0.85, GREEN_FRICTION)
	_deck(hole, Vector3(0, 0.0, -1.55), Vector3(0, 0.48, -3.22), 0.7, RAMP_FRICTION, 1.02)
	_lip_pair_points(hole, Vector3(0, 0.0, -1.6), Vector3(0, 0.46, -3.15), 0.7, 0.14)
	# Landing starts just past the lip so a short hop cannot drop under the mug.
	# High friction so the hop does not spin back off the foam.
	_deck(hole, Vector3(0, 0.4, -3.4), Vector3(0, 0.4, -5.8), 1.6, 1.0)
	_wall(hole, Vector3(-0.72, 0.56, -4.55), Vector3(0.08, 0.3, 2.3))
	_wall(hole, Vector3(0.72, 0.56, -4.55), Vector3(0.08, 0.3, 2.3))
	_mug_rim(hole, Vector3(0, 0.4, -5.05), 0.92)


static func _hole16(hole: Node3D) -> void:
	# A rolling ball will not rest on the cake's slope. Flat shelves sit outside
	# the tiers, and each putt ends against a wall so it cannot roll back down.
	# Tee pad. Flat, so the spawn does not roll off before the first putt.
	_deck(hole, Vector3(0.1, 0.0, 0.5), Vector3(0.1, 0.0, -0.2), 0.7, 1.0, 1.02)
	_wall(hole, Vector3(0.1, 0.16, 0.55), Vector3(0.8, 0.32, 0.08))
	# East lane, south to the first shelf.
	_deck(hole, Vector3(0.1, -0.02, -0.08), Vector3(0.1, 0.36, -2.05), 0.62, 0.35, 1.03)
	_deck(hole, Vector3(0.1, 0.30, -1.92), Vector3(0.1, 0.30, -2.78), 0.95, 1.0, 1.02)
	_wall(hole, Vector3(0.1, 0.52, -2.88), Vector3(1.05, 0.48, 0.1))
	_wall(hole, Vector3(0.58, 0.28, -1.2), Vector3(0.08, 0.4, 2.4))
	_wall(hole, Vector3(-0.28, 0.22, -0.7), Vector3(0.08, 0.36, 1.5))
	# South lane, west to the second shelf. Low end is flush with the first shelf.
	_deck(hole, Vector3(-0.15, 0.30, -2.5), Vector3(-3.55, 0.78, -2.5), 0.9, 0.35, 1.03)
	_deck(hole, Vector3(-3.6, 0.72, -2.5), Vector3(-4.45, 0.72, -2.5), 1.05, 1.0, 1.02)
	_wall(hole, Vector3(-4.58, 0.98, -2.5), Vector3(0.1, 0.55, 1.15))
	_wall(hole, Vector3(-1.9, 0.7, -2.02), Vector3(3.5, 0.95, 0.08))
	_wall(hole, Vector3(-1.9, 0.7, -3.02), Vector3(3.5, 0.95, 0.08))
	# West lane, north to the third shelf.
	_deck(hole, Vector3(-4.2, 0.72, -2.2), Vector3(-4.2, 1.20, 1.5), 0.75, 0.35, 1.03)
	_deck(hole, Vector3(-4.2, 1.14, 1.55), Vector3(-4.2, 1.14, 2.35), 0.8, 1.0, 1.02)
	_wall(hole, Vector3(-4.2, 1.42, 2.48), Vector3(0.95, 0.55, 0.1))
	_wall(hole, Vector3(-4.68, 1.4, 1.95), Vector3(0.1, 0.55, 0.85))
	_wall(hole, Vector3(-4.62, 1.1, 0.25), Vector3(0.08, 1.05, 3.5))
	_wall(hole, Vector3(-3.72, 1.1, 0.15), Vector3(0.08, 1.05, 3.2))
	# North lane, east to the fourth shelf, still clear of the top tier.
	_deck(hole, Vector3(-3.9, 1.14, 2.15), Vector3(-2.35, 1.50, 2.15), 0.58, 0.3, 1.02)
	_deck(hole, Vector3(-2.45, 1.44, 2.15), Vector3(-1.35, 1.44, 2.15), 0.62, 1.0, 1.02)
	_wall(hole, Vector3(-2.35, 1.45, 2.52), Vector3(2.4, 0.55, 0.08))
	_wall(hole, Vector3(-2.95, 1.45, 1.82), Vector3(1.4, 0.55, 0.08))
	# Last lane runs south across the top tier into the cup.
	_deck(hole, Vector3(-1.71, 1.44, 2.2), Vector3(-1.71, 1.50, -0.28), 1.05, 0.55, 1.02)
	_wall(hole, Vector3(-1.71, 1.74, -0.36), Vector3(0.85, 0.5, 0.08))
	_wall(hole, Vector3(-2.14, 1.7, 0.7), Vector3(0.08, 0.48, 2.0))
	_wall(hole, Vector3(-1.18, 1.72, 1.1), Vector3(0.08, 0.5, 2.9))


static func _funnel(hole: Node3D, a: Vector3, b: Vector3) -> void:
	var along := b - a
	if along.length() < 0.05:
		return
	var z := along.normalized()
	var x := z.cross(Vector3.UP)
	if x.length() < 0.05:
		return
	x = x.normalized()
	if x.x * a.x > 0.0:
		x = -x
	_deck_normal(hole, a, b, 0.4, x, 0.3, 1.02)


static func _hole18(hole: Node3D) -> void:
	# Catch falls through the shop green without lifting the tee ball.
	_deck(hole, Vector3(0.0, -0.03, 0.35), Vector3(0.0, -0.03, -6.6), 3.2, 0.35)
	# The shop banks are only a centimetre above the ball, so a putt hops them.
	_wall(hole, Vector3(-0.48, 0.16, -2.0), Vector3(0.08, 0.32, 4.2))
	_wall(hole, Vector3(0.48, 0.16, -2.0), Vector3(0.08, 0.32, 4.2))
	_wall(hole, Vector3(-1.25, 0.16, -5.4), Vector3(0.08, 0.32, 2.6))
	_wall(hole, Vector3(1.25, 0.16, -5.4), Vector3(0.08, 0.32, 2.6))
	_wall(hole, Vector3(-1.45, 0.18, -6.8), Vector3(0.1, 0.4, 5.2))
	_wall(hole, Vector3(1.45, 0.18, -6.8), Vector3(0.1, 0.4, 5.2))
	_wall(hole, Vector3(0.0, 0.18, -9.45), Vector3(3.0, 0.4, 0.1))
	_funnel(hole, Vector3(-1.15, 0.2, -5.15), Vector3(-0.55, 0.2, -6.55))
	_funnel(hole, Vector3(1.15, 0.2, -5.15), Vector3(0.55, 0.2, -6.55))
	# The ramp mesh is open on the centre line. This deck is the surface.
	_deck(hole, Vector3(0.0, -0.04, -6.15), Vector3(0.0, 0.38, -9.2), 1.8, 0.75)
	_lip_pair_points(hole, Vector3(0.0, 0.05, -7.05), Vector3(0.0, 0.36, -9.1), 1.6, 0.16)


static func _maze_corridor(hole: Node3D) -> void:
	# Open floor with a border. The lattice trimesh pinned the ball, so the
	# route is this deck and the bot's corner aims.
	_deck(hole, Vector3(0.0, 0.0, 0.45), Vector3(0.0, 0.0, -3.45), 4.4, GREEN_FRICTION)
	_wall(hole, Vector3(-1.55, 0.16, -1.5), Vector3(0.1, 0.32, 3.6))
	_wall(hole, Vector3(1.7, 0.16, -1.5), Vector3(0.1, 0.32, 3.6))
	_wall(hole, Vector3(0.0, 0.16, 0.4), Vector3(3.2, 0.32, 0.1))
	_wall(hole, Vector3(-0.15, 0.16, -3.5), Vector3(2.6, 0.32, 0.1))


static func _silence(visual: Node, names: Array) -> void:
	var stack: Array = [visual]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CollisionObject3D:
			var label := str(n.name)
			for wanted in names:
				var stem := str(wanted).trim_suffix("-colonly")
				if label == str(wanted) or label == stem or label.begins_with(stem + "-"):
					(n as CollisionObject3D).collision_layer = 0
					break
		for child in n.get_children():
			stack.append(child)


static func _deck(hole: Node3D, a: Vector3, b: Vector3, width: float, friction: float, overlap: float = 1.15) -> void:
	var along := b - a
	if along.length() < 0.05:
		return
	var z := along.normalized()
	var x := z.cross(Vector3.UP)
	if x.length() < 0.05:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := x.cross(z).normalized()
	_deck_normal(hole, a, b, width, y, friction, overlap)


static func _deck_normal(hole: Node3D, a: Vector3, b: Vector3, width: float, normal: Vector3, friction: float, overlap: float) -> void:
	var along := b - a
	var length := along.length()
	if length < 0.02:
		return
	var z := along.normalized()
	var y := normal.normalized()
	var x := y.cross(z)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	y = z.cross(x).normalized()
	var thick := 0.1
	var body := _body(hole, friction)
	body.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5 - y * thick * 0.5)
	_box(body, Vector3(width, thick, length * overlap))


static func _loop_lips(hole: Node3D, a: Vector3, b: Vector3, normal: Vector3, width: float, tall: float = 0.12) -> void:
	var along := b - a
	if along.length() < 0.02:
		return
	var z := along.normalized()
	var y := normal.normalized()
	var x := y.cross(z).normalized()
	var mid := (a + b) * 0.5
	for side_i in 2:
		var side := -1.0 if side_i == 0 else 1.0
		var body := _body(hole, RAMP_FRICTION)
		var center: Vector3 = mid + x * side * (width * 0.5 - 0.02) + y * (tall * 0.35)
		body.transform = Transform3D(Basis(x, y, z), center)
		_box(body, Vector3(0.07, tall, along.length() * 1.45))


static func _lip_pair(hole: Node3D, a: Vector3, b: Vector3, width: float) -> void:
	_lip_pair_points(hole, a, b, width, 0.08)


static func _lip_pair_points(hole: Node3D, a: Vector3, b: Vector3, width: float, height: float) -> void:
	var along := b - a
	if along.length() < 0.05:
		return
	var z := along.normalized()
	var x := z.cross(Vector3.UP)
	if x.length() < 0.05:
		return
	x = x.normalized()
	var y := x.cross(z).normalized()
	for side_i in 2:
		var side := -1.0 if side_i == 0 else 1.0
		var body := _body(hole, GREEN_FRICTION)
		var center: Vector3 = (a + b) * 0.5 + x * side * (width * 0.5)
		center += y * (height * 0.5)
		body.transform = Transform3D(Basis(x, y, z), center)
		_box(body, Vector3(0.06, height, along.length()))


static func _mug_rim(hole: Node3D, center: Vector3, radius: float) -> void:
	var count := 14
	for i in count:
		var ang := TAU * float(i) / float(count)
		var at := center + Vector3(cos(ang) * radius, 0.14, sin(ang) * radius)
		_wall(hole, at, Vector3(0.18, 0.28, 0.18))


static func _wall(hole: Node3D, center: Vector3, size: Vector3) -> void:
	var body := _body(hole, 0.3)
	body.position = center
	_box(body, size)


static func _body(hole: Node3D, friction: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "SolidDeck"
	body.collision_layer = 1
	body.collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.friction = friction
	mat.bounce = 0.02
	body.physics_material_override = mat
	hole.add_child(body)
	return body


static func _box(body: StaticBody3D, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
