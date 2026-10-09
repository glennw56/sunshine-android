extends Node3D
## Carved test-world landmark. Built here, not a scaled toss prop.
## Ribs are in the mesh. The face is open so an orange shell shows through.
## One shadowless light warms the front. The stairs live on the parent.

const BODY_H := 24.6
const RX := 13.5
const LOBES := 8
const RINGS := 30
const SEGS := 64


func _ready() -> void:
	name = "CarvedPumpkin"
	_shell(1.0, false)
	_shell(0.84, true)
	_stem()
	var light := OmniLight3D.new()
	light.name = "JackLight"
	light.position = Vector3(0.0, 14.4, -17.2)
	light.light_color = Color("ff7a28")
	light.light_energy = 2.6
	light.omni_range = 24.0
	light.omni_attenuation = 1.35
	light.shadow_enabled = false
	add_child(light)


func _shell(inset: float, glow: bool) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for ring in RINGS + 1:
		var row: Array = []
		var v := float(ring) / float(RINGS)
		for s in SEGS:
			var theta := TAU * float(s) / float(SEGS)
			var p := _point(v, theta, inset)
			row.append({"p": p, "n": _normal(v, theta, inset), "c": _color(v, theta, p, glow)})
		grid.append(row)
	var v0 := 0.30 if glow else 0.0
	var v1 := 0.80 if glow else 1.0
	for ring in RINGS:
		var v := (float(ring) + 0.5) / float(RINGS)
		if v < v0 or v > v1:
			continue
		for s in SEGS:
			var s2 := (s + 1) % SEGS
			var a: Dictionary = grid[ring][s]
			var b: Dictionary = grid[ring][s2]
			var c: Dictionary = grid[ring + 1][s]
			var d: Dictionary = grid[ring + 1][s2]
			if glow and not _front_tri(a["p"], b["p"], c["p"]):
				continue
			if not glow and _open_tri(a["p"], b["p"], c["p"]):
				pass
			else:
				_tri(st, a, b, c)
			if glow and not _front_tri(b["p"], d["p"], c["p"]):
				continue
			if not glow and _open_tri(b["p"], d["p"], c["p"]):
				continue
			_tri(st, b, d, c)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "JackGlow" if glow else "PumpkinShell"
	mi.mesh = mesh
	mi.material_override = _glow_mat() if glow else _skin_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _tri(st: SurfaceTool, a: Dictionary, b: Dictionary, c: Dictionary) -> void:
	for v in [a, b, c]:
		st.set_color(v["c"])
		st.set_normal(v["n"])
		st.add_vertex(v["p"])


func _point(v: float, theta: float, inset: float) -> Vector3:
	var y := v * BODY_H
	var profile := pow(sin(v * PI), 0.58)
	var groove := pow(0.5 - 0.5 * cos(LOBES * theta), 0.48)
	var radial := profile * RX * inset * (1.0 - 0.24 * groove)
	if v > 0.9:
		radial *= lerpf(1.0, 0.18, (v - 0.9) / 0.1)
	return Vector3(cos(theta) * radial, y, sin(theta) * radial)


func _normal(v: float, theta: float, inset: float) -> Vector3:
	if v < 0.03:
		return Vector3.DOWN
	if v > 0.97:
		return Vector3.UP
	var pv := _point(v + 0.012, theta, inset) - _point(v - 0.012, theta, inset)
	var pt := _point(v, theta + 0.02, inset) - _point(v, theta - 0.02, inset)
	var n := pt.cross(pv)
	if n.length_squared() < 0.000001:
		return Vector3.UP
	n = n.normalized()
	var p := _point(v, theta, inset)
	if n.dot(Vector3(p.x, 0.0, p.z)) < 0.0:
		n = -n
	return n


func _color(v: float, theta: float, p: Vector3, glow: bool) -> Color:
	if glow:
		return Color(1.0, 0.46, 0.08)
	var groove := pow(0.5 - 0.5 * cos(LOBES * theta), 0.48)
	var c := Color(0.98, 0.40, 0.06).lerp(Color(0.36, 0.08, 0.025), groove)
	var mott := 0.5 + 0.5 * sin(theta * 5.0 + v * 11.0)
	c = c.lerp(Color(0.62, 0.18, 0.03), mott * 0.14)
	if p.z < -6.0 and (_in_cut(Vector2(p.x, p.y)) or _near_cut(Vector2(p.x, p.y))):
		c = Color(0.08, 0.025, 0.015)
	return c


func _open_tri(a: Vector3, b: Vector3, c: Vector3) -> bool:
	var mid := (a + b + c) / 3.0
	if mid.z > -7.2:
		return false
	return _in_cut(Vector2(mid.x, mid.y))


func _front_tri(a: Vector3, b: Vector3, c: Vector3) -> bool:
	var mid := (a + b + c) / 3.0
	return mid.z < -4.5


func _in_cut(p: Vector2) -> bool:
	return _in_eye(p, true) or _in_eye(p, false) or _in_mouth(p, 1.0)


func _near_cut(p: Vector2) -> bool:
	return _in_eye_pad(p, true) or _in_eye_pad(p, false) or _in_mouth(p, 1.28)


func _in_eye(p: Vector2, left: bool) -> bool:
	var a := Vector2(-4.7, 17.4)
	var b := Vector2(-1.7, 16.5)
	var c := Vector2(-3.35, 12.7)
	if not left:
		a.x = -a.x
		b.x = -b.x
		c.x = -c.x
	return _bary(p, a, b, c)


func _in_eye_pad(p: Vector2, left: bool) -> bool:
	var a := Vector2(-5.25, 17.9)
	var b := Vector2(-1.2, 16.9)
	var c := Vector2(-3.35, 12.15)
	if not left:
		a.x = -a.x
		b.x = -b.x
		c.x = -c.x
	return _bary(p, a, b, c)


func _in_mouth(p: Vector2, widen: float) -> bool:
	var x := p.x
	var half := 5.7 * widen
	if absf(x) > half:
		return false
	var u := x / half
	var arch := 1.45 * u * u
	var mid := 10.15 + arch
	var tooth := sin(x * 2.05) * 0.7
	var top := mid + 1.35 * widen + maxf(tooth, 0.0)
	var bot := mid - 1.55 * widen + minf(tooth, 0.0)
	return p.y < top and p.y > bot


func _bary(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var v0 := c - a
	var v1 := b - a
	var v2 := p - a
	var den := v0.x * v1.y - v1.x * v0.y
	if absf(den) < 0.0001:
		return false
	var u := (v2.x * v1.y - v1.x * v2.y) / den
	var v := (v0.x * v2.y - v2.x * v0.y) / den
	return u >= 0.0 and v >= 0.0 and u + v <= 1.0


func _stem() -> void:
	var curve: Array[Vector3] = [
		Vector3(0.0, 23.5, 0.2),
		Vector3(0.45, 25.3, -0.7),
		Vector3(1.7, 27.2, 0.95),
		Vector3(2.45, 28.7, 0.1),
		Vector3(1.7, 30.0, -0.45),
	]
	var steps := 20
	var sides := 8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols: Array = []
	var pts: Array = []
	for i in steps + 1:
		var t := float(i) / float(steps)
		var center := _curve(curve, t)
		var ahead := _curve(curve, minf(t + 0.04, 1.0))
		var tangent := (ahead - center).normalized()
		if tangent.length_squared() < 0.1:
			tangent = Vector3.UP
		var side := tangent.cross(Vector3.FORWARD)
		if side.length_squared() < 0.01:
			side = Vector3.RIGHT
		side = side.normalized()
		var up := side.cross(tangent).normalized()
		var rad := lerpf(1.12, 0.22, t)
		var ring: Array = []
		for s in sides:
			var ang := TAU * float(s) / float(sides)
			var wobble := 1.0 + 0.1 * sin(float(i) * 1.7 + float(s) * 2.3)
			var bark := (side * cos(ang) + up * sin(ang)) * rad * wobble
			var p: Vector3 = center + bark
			ring.append(p)
			var green := Color(0.30, 0.46, 0.18)
			var tan := Color(0.58, 0.52, 0.32)
			var col := green.lerp(tan, t)
			if s % 2 == 0:
				col = col.darkened(0.28)
			cols.append(col)
		pts.append(ring)
	var ci := 0
	for i in steps:
		for s in sides:
			var s2 := (s + 1) % sides
			var a: Vector3 = pts[i][s]
			var b: Vector3 = pts[i][s2]
			var c: Vector3 = pts[i + 1][s]
			var d: Vector3 = pts[i + 1][s2]
			var n := (b - a).cross(c - a).normalized()
			_stem_tri(st, a, b, c, n, cols[ci + s], cols[ci + s2], cols[ci + sides + s])
			n = (c - b).cross(d - b).normalized()
			_stem_tri(st, b, d, c, n, cols[ci + s2], cols[ci + sides + s2], cols[ci + sides + s])
		ci += sides
	var mi := MeshInstance3D.new()
	mi.name = "GnarledStem"
	mi.mesh = st.commit()
	mi.material_override = _skin_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _stem_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	if n.length_squared() < 0.1:
		n = Vector3.UP
	st.set_color(ca)
	st.set_normal(n)
	st.add_vertex(a)
	st.set_color(cb)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_color(cc)
	st.set_normal(n)
	st.add_vertex(c)


func _curve(pts: Array[Vector3], t: float) -> Vector3:
	var n := pts.size() - 1
	var x := clampf(t, 0.0, 1.0) * float(n)
	var i := mini(int(x), n - 1)
	var f := x - float(i)
	var p0: Vector3 = pts[maxi(i - 1, 0)]
	var p1: Vector3 = pts[i]
	var p2: Vector3 = pts[i + 1]
	var p3: Vector3 = pts[mini(i + 2, n)]
	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * f
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f * f * f
	)


func _skin_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.86
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


func _glow_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.48, 0.08)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.42, 0.05)
	m.emission_energy_multiplier = 2.4
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
