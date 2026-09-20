extends Object
class_name CutePack
## Rounded bakery-lot props. Capsules / cylinders / spheres — no crate cubes.

const WOOD := Color("e0c090")
const WOOD_DK := Color("c49a62")
const PINK := Color("e8b4b8")
const WINE := Color("4a1c28")
const CREAM := Color("f7f0e6")
const LEAF := Color("3a7a34")
const LEAF_LT := Color("5aa03c")
const METAL := Color("9aa0a6")
const GOLD := Color("e6b14a")


static func mat(c: Color, rough := 0.62) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


static func add_mesh(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, fade := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	if fade > 0.0:
		mi.visibility_range_end = fade
		mi.visibility_range_end_margin = 8.0
	parent.add_child(mi)
	return mi


static func collider(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	VoxelKit.add_collider(parent, size, pos)


static func cyl(r_top: float, r_bot: float, h: float, segs := 20) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = h
	mesh.radial_segments = segs
	mesh.rings = 2
	return mesh


static func ball(r: float, segs := 16) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = segs
	mesh.rings = 10
	return mesh


static func cap(r: float, h: float, segs := 16) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = r
	mesh.height = h
	mesh.radial_segments = segs
	return mesh


static func practice_target(parent: Node3D, pos: Vector3, color: Color = WOOD_DK) -> void:
	add_mesh(parent, cyl(0.42, 0.48, 0.18), color, pos + Vector3(0, 0.1, 0))
	add_mesh(parent, cyl(0.22, 0.22, 0.72), color.darkened(0.12), pos + Vector3(0, 0.52, 0))
	add_mesh(parent, ball(0.28), PINK, pos + Vector3(0, 0.98, 0))
	collider(parent, Vector3(0.9, 0.95, 0.9), pos + Vector3(0, 0.48, 0))


static func planter(parent: Node3D, pos: Vector3, pot: Color = WOOD, bloom: Color = PINK) -> void:
	add_mesh(parent, cyl(0.55, 0.62, 0.42), pot, pos + Vector3(0, 0.22, 0))
	add_mesh(parent, ball(0.38, 14), LEAF, pos + Vector3(0, 0.55, 0))
	add_mesh(parent, ball(0.16, 12), bloom, pos + Vector3(0.18, 0.72, 0.04))
	add_mesh(parent, ball(0.13, 12), GOLD, pos + Vector3(-0.16, 0.7, 0.08))
	add_mesh(parent, ball(0.12, 12), bloom.lightened(0.12), pos + Vector3(0.02, 0.78, -0.12))
	collider(parent, Vector3(1.2, 0.7, 1.2), pos + Vector3(0, 0.32, 0))


static func picnic_table(parent: Node3D, pos: Vector3, yaw := 0.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	add_mesh(root, cyl(1.15, 1.15, 0.1, 22), WOOD, Vector3(0, 0.78, 0))
	add_mesh(root, cap(0.07, 0.78), WOOD_DK, Vector3(0, 0.39, 0))
	add_mesh(root, cap(0.06, 1.55), WOOD, Vector3(0, 0.42, -0.72), Vector3(1.2, 0, 0))
	add_mesh(root, cap(0.06, 1.55), WOOD, Vector3(0, 0.42, 0.72), Vector3(-1.2, 0, 0))
	collider(parent, Vector3(2.2, 0.9, 1.7), pos + Vector3(0, 0.45, 0))


static func market_stall(parent: Node3D, pos: Vector3, color: Color = WOOD_DK) -> void:
	add_mesh(parent, cap(0.07, 1.55), color, pos + Vector3(-0.7, 0.78, -0.7))
	add_mesh(parent, cap(0.07, 1.55), color, pos + Vector3(0.7, 0.78, -0.7))
	add_mesh(parent, cap(0.07, 1.55), color, pos + Vector3(-0.7, 0.78, 0.7))
	add_mesh(parent, cap(0.07, 1.55), color, pos + Vector3(0.7, 0.78, 0.7))
	add_mesh(parent, cyl(1.25, 0.15, 0.55, 18), PINK, pos + Vector3(0, 1.55, 0))
	add_mesh(parent, cyl(0.7, 0.7, 0.08, 16), WOOD, pos + Vector3(0, 0.72, 0))
	collider(parent, Vector3(2.2, 1.6, 2.2), pos + Vector3(0, 0.8, 0))


static func lamp(parent: Node3D, pos: Vector3, height := 2.4) -> void:
	add_mesh(parent, cyl(0.08, 0.12, height), Color("3a3834"), pos + Vector3(0, height * 0.5, 0))
	add_mesh(parent, ball(0.22), GOLD, pos + Vector3(0, height + 0.08, 0))
	collider(parent, Vector3(0.35, height, 0.35), pos + Vector3(0, height * 0.5, 0))


static func trash(parent: Node3D, pos: Vector3) -> void:
	add_mesh(parent, cyl(0.28, 0.32, 0.85, 16), METAL, pos + Vector3(0, 0.44, 0))
	add_mesh(parent, cyl(0.3, 0.3, 0.08, 16), Color("5c6064"), pos + Vector3(0, 0.9, 0))
	collider(parent, Vector3(0.7, 0.95, 0.7), pos + Vector3(0, 0.48, 0))


static func cornhole(parent: Node3D, pos: Vector3, yaw := 0.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	add_mesh(root, cyl(0.55, 0.62, 0.12, 18), WOOD, Vector3(0, 0.16, 0), Vector3(0.35, 0, 0))
	add_mesh(root, ball(0.12), WINE, Vector3(0, 0.28, -0.12))
	collider(parent, Vector3(1.1, 0.35, 1.2), pos + Vector3(0, 0.16, 0))


static func hedge_row(parent: Node3D, box: AABB) -> void:
	var c := box.get_center()
	var along_x := box.size.x >= box.size.z
	var length := maxf(box.size.x, box.size.z)
	var count := clampi(int(length / 1.35), 2, 18)
	for i in count:
		var t := 0.0 if count <= 1 else float(i) / float(count - 1)
		var p := c
		if along_x:
			p.x = c.x - box.size.x * 0.5 + t * box.size.x
		else:
			p.z = c.z - box.size.z * 0.5 + t * box.size.z
		p.y = 0.55
		add_mesh(parent, ball(0.62 + float(i % 3) * 0.06, 14), LEAF if i % 2 == 0 else LEAF_LT, p)
	collider(parent, Vector3(maxf(box.size.x, 0.7), 1.2, maxf(box.size.z, 0.7)), Vector3(c.x, 0.55, c.z))


static func bistro_set(parent: Node3D, pos: Vector3) -> void:
	add_mesh(parent, cyl(0.55, 0.55, 0.08, 20), CREAM, pos + Vector3(0, 0.74, 0))
	add_mesh(parent, cap(0.05, 0.74), WOOD_DK, pos + Vector3(0, 0.37, 0))
	for i in 2:
		var side := -0.7 if i == 0 else 0.7
		add_mesh(parent, cap(0.08, 0.55), PINK, pos + Vector3(side, 0.38, 0.05))
		add_mesh(parent, ball(0.16, 12), PINK, pos + Vector3(side, 0.72, -0.02))
	collider(parent, Vector3(1.7, 0.9, 1.3), pos + Vector3(0, 0.45, 0))


static func shade_tree(parent: Node3D, pos: Vector3, height := 3.2) -> void:
	add_mesh(parent, cap(0.14, height * 0.55), Color("5a3a22"), pos + Vector3(0, height * 0.28, 0), Vector3.ZERO, Vector3.ONE, 52.0)
	add_mesh(parent, ball(height * 0.38, 14), LEAF, pos + Vector3(0, height * 0.72, 0), Vector3.ZERO, Vector3.ONE, 52.0)
	add_mesh(parent, ball(height * 0.26, 12), LEAF_LT, pos + Vector3(height * 0.12, height * 0.88, height * 0.06), Vector3.ZERO, Vector3.ONE, 52.0)
	collider(parent, Vector3(0.5, height * 0.5, 0.5), pos + Vector3(0, height * 0.25, 0))


static func beanbag(parent: Node3D, pos: Vector3, color: Color = PINK) -> void:
	var root := Node3D.new()
	root.position = pos
	root.add_to_group("cute_beanbag")
	parent.add_child(root)
	add_mesh(root, ball(0.62, 16), color, Vector3(0, 0.28, 0), Vector3.ZERO, Vector3(1.45, 0.62, 1.2))
	add_mesh(root, ball(0.22, 12), color.darkened(0.08), Vector3(0.1, 0.4, 0.05), Vector3.ZERO, Vector3(1.15, 0.42, 1.0))
	collider(parent, Vector3(1.55, 0.55, 1.3), pos + Vector3(0, 0.28, 0))


static func umbrella(parent: Node3D, pos: Vector3, color: Color = PINK) -> void:
	add_mesh(parent, cyl(0.04, 0.05, 2.15), WOOD_DK, pos + Vector3(0, 1.08, 0))
	add_mesh(parent, ball(1.15, 16), color, pos + Vector3(0, 2.28, 0), Vector3.ZERO, Vector3(1.0, 0.38, 1.0), 46.0)
	add_mesh(parent, ball(0.08, 10), GOLD, pos + Vector3(0, 2.48, 0), Vector3.ZERO, Vector3.ONE, 46.0)
	collider(parent, Vector3(0.28, 2.2, 0.28), pos + Vector3(0, 1.1, 0))


static func paver_lane(parent: Node3D, origin: Vector3, direction: Vector3, count: int, spacing: float) -> void:
	var dir := direction.normalized()
	for i in count:
		var t := (float(i) - float(count - 1) * 0.5) * spacing
		add_mesh(parent, cyl(0.78, 0.82, 0.07, 16), Color("e8e2d4"), origin + dir * t + Vector3(0, 0.04, 0), Vector3.ZERO, Vector3.ONE, 56.0)


static func replace_named(parent: Node3D, mesh_name: String, box: AABB) -> void:
	if box.size.length() <= 0.2:
		return
	var c := box.get_center()
	var feet := Vector3(c.x, 0.0, c.z)
	if mesh_name.begins_with("Picnic"):
		picnic_table(parent, feet)
	elif mesh_name.begins_with("Beanbag"):
		var bags: Array[Color] = [PINK, CREAM, Color("6b2d3c")]
		var idx := clampi(int(mesh_name.substr(mesh_name.length() - 1)), 0, 2)
		beanbag(parent, feet, bags[idx])
	elif mesh_name.begins_with("Bistro"):
		bistro_set(parent, feet)
		if mesh_name.ends_with("SE") or mesh_name.ends_with("SW"):
			umbrella(parent, feet, PINK if mesh_name.ends_with("SE") else CREAM)
	elif mesh_name.begins_with("FlowerPlanter"):
		planter(parent, feet)
	elif mesh_name.begins_with("LightPost"):
		lamp(parent, feet, maxf(box.size.y, 2.1))
	elif mesh_name.begins_with("Trash"):
		trash(parent, feet)
	elif mesh_name.begins_with("Cornhole"):
		cornhole(parent, feet)
	elif mesh_name.ends_with("Border"):
		hedge_row(parent, box)
	elif mesh_name == "Menu_Board":
		add_mesh(parent, cyl(0.06, 0.06, 1.2), WOOD_DK, feet + Vector3(-0.45, 0.6, 0))
		add_mesh(parent, cyl(0.06, 0.06, 1.2), WOOD_DK, feet + Vector3(0.45, 0.6, 0))
		add_mesh(parent, cyl(0.7, 0.7, 0.08, 16), CREAM, feet + Vector3(0, 1.15, 0), Vector3(1.2, 0, 0))
		collider(parent, Vector3(maxf(box.size.x, 1.2), 1.3, maxf(box.size.z, 0.4)), Vector3(c.x, 0.65, c.z))
