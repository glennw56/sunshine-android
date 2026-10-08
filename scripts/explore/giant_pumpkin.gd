extends Node3D
## Test-world landmark. A carved jack-o'-lantern about 30 m tall
## at the far southeast corner. A railed spiral stays outside the ribs
## and ends on a deck beside the crown.

const JackLanternScript := preload("res://scripts/explore/jack_lantern.gd")
const Look := preload("res://scripts/explore/authored_look.gd")
const PUMPKIN_GLB := "res://assets/explore/halloween/giant_pumpkin.glb"
const STAIRS_GLB := "res://assets/explore/halloween/pumpkin_stairs.glb"
const PLACE := Vector3(72.0, 0.0, 78.0)
const TARGET_H := 30.0
const TURNS := 1.6
const SEGMENTS := 78
const IN_SEG := 28
const IN_TURNS := 0.55
const RAIL_H := 1.35
const TREAD_W := 1.85
const TREAD_T := 0.18
const CLEAR := 2.15
const WOOD := Color("c49a62")
const WOOD_DK := Color("8a5a32")

var walk_points := PackedVector3Array()
var rib_points := PackedVector3Array()
var bridge_angle := 0.0
var deck_top := 28.4
var crown_floor_y := 16.5
var _rx := 15.0
var _ry := 15.0
var _cy := 15.0
var _profile_y := PackedFloat32Array()
var _profile_r := PackedFloat32Array()


func _ready() -> void:
	name = "GiantPumpkin"
	position = PLACE
	add_to_group("giant_pumpkin")
	_body()
	_path()
	_deck()
	_walk_surface()
	_attach_stair_visual()


func _body() -> void:
	var model := Look.lift(PUMPKIN_GLB, "CarvedPumpkin")
	if model == null:
		model = JackLanternScript.new()
	add_child(model)
	var toward := Vector3(-global_position.x, 0.0, -global_position.z)
	if toward.length_squared() > 1.0:
		model.look_at(model.global_position + toward.normalized(), Vector3.UP)
	_place_jack_light(model)
	_strip_collision(model)
	var box := _mesh_aabb(model)
	_rx = maxf(box.size.x, box.size.z) * 0.5
	_ry = box.size.y * 0.5
	_cy = box.get_center().y
	_measure_profile(model)


func _path() -> void:
	var outer := _rx + CLEAR
	deck_top = _cy + _ry * 0.90
	var pad_r := _silhouette(deck_top) + CLEAR + 1.6
	var pts := PackedVector3Array()
	for i in SEGMENTS + 1:
		var t := float(i) / float(SEGMENTS)
		var y := lerpf(0.08, deck_top, _ease(t))
		var ang := t * TURNS * TAU
		var r := maxf(outer, _silhouette(y) + CLEAR)
		pts.append(Vector3(cos(ang) * r, y, sin(ang) * r))
	var ang0 := TURNS * TAU
	var r_start := maxf(outer, _silhouette(deck_top) + CLEAR)
	for i in IN_SEG:
		var t := float(i + 1) / float(IN_SEG)
		var ang := ang0 + t * IN_TURNS * TAU
		var r := maxf(lerpf(r_start, pad_r, t), _silhouette(deck_top) + CLEAR)
		pts.append(Vector3(cos(ang) * r, deck_top, sin(ang) * r))
	bridge_angle = ang0 + IN_TURNS * TAU
	var pad := Vector3(cos(bridge_angle) * pad_r, deck_top, sin(bridge_angle) * pad_r)
	if pts[pts.size() - 1].distance_to(pad) > 0.2:
		pts.append(pad)
	walk_points = pts
	for i in pts.size() - 1:
		_span(pts[i], pts[i + 1], i, pad)


func _ease(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _silhouette(y: float) -> float:
	if _profile_y.is_empty():
		var frac := (y - _cy) / maxf(_ry, 0.01)
		if absf(frac) >= 1.0:
			return 0.0
		return _rx * sqrt(1.0 - frac * frac)
	if y <= _profile_y[0]:
		return _profile_r[0]
	var last := _profile_y.size() - 1
	if y >= _profile_y[last]:
		return _profile_r[last]
	for i in last:
		if y <= _profile_y[i + 1]:
			var span := maxf(_profile_y[i + 1] - _profile_y[i], 0.001)
			return lerpf(_profile_r[i], _profile_r[i + 1], (y - _profile_y[i]) / span)
	return _profile_r[last]


func _measure_profile(model: Node3D) -> void:
	var y0 := _cy - _ry
	var y1 := _cy + _ry
	var bins := 36
	var max_r := PackedFloat32Array()
	max_r.resize(bins)
	var counts := PackedInt32Array()
	counts.resize(bins)
	var span := maxf(y1 - y0, 0.01)
	var stack: Array = [model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var mi := n as MeshInstance3D
			var xf := global_transform.affine_inverse() * mi.global_transform
			for s in mi.mesh.get_surface_count():
				var arrays: Array = mi.mesh.surface_get_arrays(s)
				if arrays.is_empty():
					continue
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for v in verts:
					var p: Vector3 = xf * v
					var b := clampi(int((p.y - y0) / span * float(bins)), 0, bins - 1)
					var radial := Vector2(p.x, p.z).length()
					if radial > max_r[b]:
						max_r[b] = radial
					counts[b] += 1
		for child in n.get_children():
			stack.append(child)
	_profile_y.resize(bins)
	_profile_r.resize(bins)
	for i in bins:
		_profile_y[i] = y0 + (float(i) + 0.5) / float(bins) * span
		if counts[i] > 0:
			_profile_r[i] = max_r[i]
			continue
		var neighbor := 0.0
		for j in range(i - 1, -1, -1):
			if counts[j] > 0:
				neighbor = max_r[j]
				break
		for j in range(i + 1, bins):
			if counts[j] > 0:
				neighbor = maxf(neighbor, max_r[j])
				break
		_profile_r[i] = neighbor
	for i in range(1, bins - 1):
		var beside := minf(_profile_r[i - 1], _profile_r[i + 1])
		if _profile_r[i] + 0.35 < beside:
			_profile_r[i] = beside


func _strip_collision(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	for child in node.get_children():
		_strip_collision(child)


func _span(a: Vector3, b: Vector3, i: int, pad: Vector3) -> void:
	var delta := b - a
	var flat := Vector2(delta.x, delta.z)
	var run := flat.length()
	if run < 0.05:
		return
	var tangent := Vector3(delta.x / run, 0.0, delta.z / run)
	var slope := delta.y / run
	var y_axis := (-tangent * slope + Vector3.UP).normalized()
	var x_axis := delta.normalized()
	var outward := Vector3((a.x + b.x) * 0.5, 0.0, (a.z + b.z) * 0.5)
	if outward.length() < 0.2:
		outward = Vector3(cos(bridge_angle), 0.0, sin(bridge_angle))
	outward = outward.normalized()
	if x_axis.cross(y_axis).dot(outward) < 0.0:
		x_axis = -x_axis
	var basis := Basis(x_axis, y_axis, x_axis.cross(y_axis))
	var mid := (a + b) * 0.5
	var wood := WOOD if i % 2 == 0 else WOOD.darkened(0.06)
	_box(Vector3(delta.length(), TREAD_T, TREAD_W), _mat(wood), mid - y_axis * (TREAD_T * 0.5), basis, "RampStep")
	if Vector2(mid.x - pad.x, mid.z - pad.z).length() < 2.4:
		return
	var rail_x := tangent
	var rail_z := Vector3.UP.cross(rail_x).normalized()
	if rail_z.dot(outward) < 0.0:
		rail_x = -rail_x
		rail_z = -rail_z
	var rail_basis := Basis(rail_x, Vector3.UP, rail_z)
	var edge := TREAD_W * 0.5 + 0.02
	var lift := Vector3(0, RAIL_H * 0.5 - 0.02, 0)
	var near_pad := mid.distance_to(Vector3(pad.x, mid.y, pad.z)) < 10.0
	var rail_name := "DeckRail" if near_pad else "RampRail"
	_box(Vector3(run, RAIL_H, 0.14), _mat(WOOD_DK), mid + outward * edge + lift, rail_basis, rail_name)
	_box(Vector3(run, RAIL_H, 0.14), _mat(WOOD_DK), mid - outward * edge + lift, rail_basis, rail_name)


func _deck() -> void:
	if walk_points.is_empty():
		return
	var pad := walk_points[walk_points.size() - 1]
	var deck_y := pad.y - TREAD_T - 0.16
	var body := StaticBody3D.new()
	body.name = "PumpkinDeck"
	body.position = Vector3(pad.x, deck_y, pad.z)
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 2.35
	shape.height = 0.28
	col.shape = shape
	body.add_child(col)
	add_child(body, true)
	var disk := CylinderMesh.new()
	disk.top_radius = 2.35
	disk.bottom_radius = 2.35
	disk.height = 0.28
	disk.radial_segments = 20
	var deck_mesh := MeshInstance3D.new()
	deck_mesh.name = "DeckDisc"
	deck_mesh.set_meta("procedural_stair", true)
	deck_mesh.mesh = disk
	deck_mesh.material_override = _mat(WOOD)
	deck_mesh.position = body.position
	deck_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(deck_mesh)
	var approach := walk_points[walk_points.size() - 2] - pad
	var approach_ang := atan2(approach.x, approach.z)
	for i in 14:
		var ang := float(i) / 14.0 * TAU
		if absf(wrapf(ang - approach_ang, -PI, PI)) < 1.0:
			continue
		var radial := Vector3(sin(ang), 0, cos(ang))
		var tangent := Vector3(cos(ang), 0, -sin(ang))
		var basis := Basis(tangent, Vector3.UP, tangent.cross(Vector3.UP))
		var pos := Vector3(pad.x, pad.y + RAIL_H * 0.42, pad.z) + radial * 2.15
		_box(Vector3(1.15, RAIL_H, 0.14), _mat(WOOD_DK), pos, basis, "DeckRail")


func _place_jack_light(model: Node3D) -> void:
	var light := model.find_child("JackLight", true, false) as OmniLight3D
	if light == null:
		light = OmniLight3D.new()
		light.name = "JackLight"
		light.light_color = Color("ff7a28")
		light.light_energy = 2.6
		light.omni_range = 24.0
		light.omni_attenuation = 1.35
		light.shadow_enabled = false
		light.position = Vector3(0.0, 14.4, -17.2)
		model.add_child(light)
	if model.find_child("Vine", true, false) == null:
		return
	var glow := model.find_child("JackGlow", true, false) as MeshInstance3D
	var shell := model.find_child("PumpkinShell", true, false) as MeshInstance3D
	if glow == null or glow.mesh == null or shell == null or shell.mesh == null:
		return
	var gbox := _local_mesh_box(model, glow)
	var sbox := _local_mesh_box(model, shell)
	if gbox.size.length() < 0.2 or sbox.size.length() < 0.2:
		return
	## Sit in the carved face. The shell's -Z side is the face that look_at turns toward the patio.
	var center := gbox.get_center()
	light.position = Vector3(center.x, center.y, sbox.position.z + 1.6)


func _local_mesh_box(root_node: Node3D, mi: MeshInstance3D) -> AABB:
	return (root_node.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()


func _attach_stair_visual() -> void:
	## Visual only, in this node's unrotated space. The RampStep bodies stay.
	var stairs := Look.lift(STAIRS_GLB, "PumpkinStairs")
	if stairs == null:
		return
	stairs.position = Vector3.ZERO
	stairs.basis = Basis.IDENTITY
	stairs.scale = Vector3.ONE
	add_child(stairs)
	_hide_procedural_stair_meshes()


func _hide_procedural_stair_meshes() -> void:
	## Godot renames later siblings that share RampStep / RampRail / DeckRail,
	## so a name lookup only hid the first copy of each. Hide every code mesh.
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and bool(n.get_meta("procedural_stair", false)):
			(n as MeshInstance3D).visible = false
		for child in n.get_children():
			stack.append(child)


func crown_stand_local() -> Vector3:
	## A spot above the orange crown. A body dropped here should land on the shell.
	var y := 21.4
	var reach := _silhouette(y) * 0.58
	return Vector3(reach * 0.72, y + 1.6, reach * 0.38)


func _walk_surface() -> void:
	## The carved mesh is visual only. A convex crown matches the upper shell
	## (the part whose slope a player can stand on). Rib shelves step up the
	## outside of the ribs, clear of the wooden stair, so a jump lands on the
	## pumpkin itself. No trimesh: the capsule falls through those.
	var body := StaticBody3D.new()
	body.name = "PumpkinWalk"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body, true)
	_rib_shelves(body)
	_crown_hull(body)


func _rib_shelves(body: StaticBody3D) -> void:
	var y := 1.05
	var ang := 0.85
	var guard := 0
	while y < crown_floor_y - 0.85 and guard < 28:
		var skin := _silhouette(y)
		var outer := skin + 0.72
		var radial_w := 1.2
		var mid_r := outer - radial_w * 0.5
		var thick := 0.2
		var radial := Vector3(cos(ang), 0.0, sin(ang))
		var tangent := Vector3(-sin(ang), 0.0, cos(ang))
		var basis := Basis(tangent, Vector3.UP, tangent.cross(Vector3.UP)).orthonormalized()
		var top := y
		var pos := radial * mid_r + Vector3(0.0, top - thick * 0.5, 0.0)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.65, thick, radial_w)
		col.shape = shape
		col.transform = Transform3D(basis, pos)
		body.add_child(col)
		rib_points.append(radial * mid_r + Vector3(0.0, top, 0.0))
		var step_r := maxf(mid_r, 1.0)
		ang += 1.05 / step_r
		y += 0.86
		guard += 1


func _crown_hull(body: StaticBody3D) -> void:
	var pts := PackedVector3Array()
	var y0 := crown_floor_y
	var y1 := 23.6
	var rings := 12
	var segs := 16
	for ring in rings:
		var y := lerpf(y0, y1, float(ring) / float(rings - 1))
		var radial := maxf(_silhouette(y) * 0.995, 0.35)
		for s in segs:
			var a := TAU * float(s) / float(segs)
			pts.append(Vector3(cos(a) * radial, y, sin(a) * radial))
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)


func _keep_look(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var src := mi.get_active_material(i)
				if src == null:
					src = mi.mesh.surface_get_material(i)
				var mat := StandardMaterial3D.new()
				if src is BaseMaterial3D:
					var bm := src as BaseMaterial3D
					mat.albedo_color = bm.albedo_color
					mat.albedo_texture = bm.albedo_texture
					mat.vertex_color_use_as_albedo = bm.vertex_color_use_as_albedo
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
				mi.set_surface_override_material(i, mat)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_keep_look(child)


func _mesh_aabb(root_node: Node3D) -> AABB:
	var box := AABB()
	var any := false
	var inv := global_transform.affine_inverse()
	var stack: Array = [root_node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var piece: AABB = (inv * mi.global_transform) * mi.get_aabb()
			if not any:
				box = piece
				any = true
			else:
				box = box.merge(piece)
		for child in n.get_children():
			stack.append(child)
	return box


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


func _box(size: Vector3, mat: Material, pos: Vector3, basis: Basis, body_name: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = body_name
	mi.set_meta("procedural_stair", true)
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.basis = basis
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = pos
	body.basis = basis
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body, true)
