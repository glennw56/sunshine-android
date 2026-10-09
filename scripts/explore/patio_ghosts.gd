extends Node3D
## Sheet ghosts for the test world. No colliders. A shared mesh, four of them.

const Look := preload("res://scripts/explore/authored_look.gd")
const GHOST_GLB := "res://assets/explore/halloween/ghost_sheet.glb"
const COUNT := 4
const SHEET := Color(0.94, 0.96, 1.0, 0.86)
const EYE := Color("1a1c22")
const BLUSH := Color("f0b0b8")


func _ready() -> void:
	name = "PatioGhosts"
	if ResourceLoader.exists(GHOST_GLB):
		for i in COUNT:
			var ghost := Look.lift(GHOST_GLB, "Ghost")
			if ghost == null:
				continue
			ghost.name = "Ghost%d" % i
			_show_face(ghost, i)
			_force_sheet_alpha(ghost)
			add_child(ghost)
		if get_child_count() == COUNT:
			return
	var sheet := _sheet_mesh()
	var sheet_mat := _sheet_mat()
	for i in COUNT:
		add_child(_ghost(i, sheet, sheet_mat))


func _show_face(ghost: Node3D, i: int) -> void:
	var smile := ghost.find_child("FaceSmile", true, false) as Node3D
	var oh := ghost.find_child("FaceOh", true, false) as Node3D
	if smile:
		smile.visible = i % 2 == 0
	if oh:
		oh.visible = i % 2 == 1


func _force_sheet_alpha(ghost: Node3D) -> void:
	## The sheet stays alpha blended. The patio ghosts read at 0.86.
	var sheet := ghost.find_child("Sheet", true, false) as MeshInstance3D
	if sheet == null or sheet.mesh == null:
		return
	for i in sheet.mesh.get_surface_count():
		var mat := sheet.get_surface_override_material(i) as StandardMaterial3D
		if mat == null:
			continue
		mat.albedo_color.a = 0.86


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in get_child_count():
		var ghost := get_child(i) as Node3D
		if ghost == null:
			continue
		var phase := float(i) * 1.7
		var radius := 6.2 + float(i) * 2.6
		var speed := 0.15 + float(i) * 0.03
		var ang := t * speed + phase
		var bob := sin(t * 1.35 + phase) * 0.16
		var vel := Vector3(-sin(ang) * radius, 0.0, cos(ang) * radius * 0.82)
		ghost.position = Vector3(1.2 + cos(ang) * radius, 0.02 + bob, -0.6 + sin(ang) * radius * 0.82)
		## The sheet face is on local -Z. The old yaw (angle + 90°) only matched
		## travel on part of the ellipse, so the back led the way around the loop.
		face_travel(ghost, vel, cos(t * 0.7 + phase) * 0.05, sin(t * 0.9 + phase) * 0.1)
		var arm_l := ghost.find_child("ArmL", true, false) as Node3D
		var arm_r := ghost.find_child("ArmR", true, false) as Node3D
		if arm_l:
			arm_l.rotation.z = 0.35 + sin(t * 1.4 + phase) * 0.18
		if arm_r:
			arm_r.rotation.z = -0.35 + sin(t * 1.4 + phase + 1.2) * 0.18


func face_travel(ghost: Node3D, travel: Vector3, tilt_x: float, tilt_z: float) -> void:
	var flat := Vector3(travel.x, 0.0, travel.z)
	if flat.length_squared() < 0.0000001:
		return
	var dir := flat.normalized()
	ghost.rotation = Vector3(0.0, atan2(-dir.x, -dir.z), 0.0)
	ghost.rotate_object_local(Vector3.RIGHT, tilt_x)
	ghost.rotate_object_local(Vector3.FORWARD, tilt_z)


func _ghost(i: int, sheet: ArrayMesh, sheet_mat: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Ghost%d" % i
	var body := MeshInstance3D.new()
	body.name = "Sheet"
	body.mesh = sheet
	body.material_override = sheet_mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.visibility_range_end = 80.0
	body.visibility_range_end_margin = 8.0
	root.add_child(body)
	_arm(root, "ArmL", -1.0)
	_arm(root, "ArmR", 1.0)
	_eye(root, Vector3(-0.12, 1.22, -0.30))
	_eye(root, Vector3(0.12, 1.22, -0.30))
	if i % 2 == 0:
		_smile(root)
		_blush(root, Vector3(-0.2, 1.08, -0.30))
		_blush(root, Vector3(0.2, 1.08, -0.30))
	else:
		_oh(root)
	return root


func _sheet_mesh() -> ArrayMesh:
	var rings := 14
	var segs := 18
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for r in rings + 1:
		var row: Array = []
		var v := float(r) / float(rings)
		for s in segs:
			var theta := TAU * float(s) / float(segs)
			var y: float
			var rad: float
			if v < 0.38:
				var a := (v / 0.38) * PI * 0.5
				y = 1.12 + cos(a) * 0.5
				rad = sin(a) * 0.4
			else:
				var f := (v - 0.38) / 0.62
				y = lerpf(1.12, 0.06, pow(f, 0.9))
				rad = lerpf(0.4, 0.58, f)
			var hem := 0.0
			if v > 0.62:
				hem = sin(theta * 5.0 + float(r)) * 0.1 * smoothstep(0.62, 1.0, v)
			var p := Vector3(cos(theta) * (rad + hem * 0.35), y + hem, sin(theta) * (rad + hem * 0.35))
			row.append(p)
		grid.append(row)
	for r in rings:
		for s in segs:
			var s2 := (s + 1) % segs
			var a: Vector3 = grid[r][s]
			var b: Vector3 = grid[r][s2]
			var c: Vector3 = grid[r + 1][s]
			var d: Vector3 = grid[r + 1][s2]
			var n := (b - a).cross(c - a).normalized()
			if n.dot(Vector3(a.x, 0.0, a.z)) < 0.0:
				n = -n
			_face(st, a, c, b, n)
			n = (d - b).cross(c - b).normalized()
			if n.length_squared() > 0.1 and n.dot(Vector3(b.x, 0.0, b.z)) < 0.0:
				n = -n
			_face(st, b, c, d, n)
	return st.commit()


func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if n.length_squared() < 0.1:
		n = Vector3.FORWARD
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)


func _arm(root: Node3D, arm_name: String, side: float) -> void:
	var pivot := Node3D.new()
	pivot.name = arm_name
	pivot.position = Vector3(0.32 * side, 1.02, 0.02)
	root.add_child(pivot)
	var upper := _cyl(0.075, 0.36, _sheet_mat())
	upper.position = Vector3(0.12 * side, -0.16, 0.02)
	upper.rotation_degrees = Vector3(18, 0, 24 * side)
	pivot.add_child(upper)
	var lower := _cyl(0.06, 0.28, _sheet_mat())
	lower.position = Vector3(0.22 * side, -0.42, 0.06)
	lower.rotation_degrees = Vector3(36, 0, 18 * side)
	pivot.add_child(lower)
	var hand := _ball(0.07, _sheet_mat())
	hand.position = Vector3(0.28 * side, -0.58, 0.08)
	pivot.add_child(hand)


func _eye(root: Node3D, pos: Vector3) -> void:
	var eye := _ball(0.105, _flat(EYE))
	eye.position = pos
	eye.scale = Vector3(0.72, 1.28, 0.42)
	root.add_child(eye)


func _smile(root: Node3D) -> void:
	for i in 5:
		var u := float(i) / 4.0
		var x := lerpf(-0.12, 0.12, u)
		var y := 0.98 + sin(u * PI) * 0.045
		var dot := _ball(0.028, _flat(EYE))
		dot.position = Vector3(x, y, -0.34)
		dot.scale = Vector3(1.0, 0.7, 0.45)
		root.add_child(dot)


func _oh(root: Node3D) -> void:
	var mouth := _ball(0.055, _flat(EYE))
	mouth.position = Vector3(0.0, 0.98, -0.34)
	mouth.scale = Vector3(0.7, 0.95, 0.4)
	root.add_child(mouth)


func _blush(root: Node3D, pos: Vector3) -> void:
	var cheek := _ball(0.055, _flat(BLUSH))
	cheek.position = pos
	cheek.scale = Vector3(1.2, 0.7, 0.35)
	root.add_child(cheek)


func _sheet_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = SHEET
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_BACK
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


func _ball(r: float, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _cyl(r: float, h: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r * 0.85
	mesh.height = h
	mesh.radial_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
