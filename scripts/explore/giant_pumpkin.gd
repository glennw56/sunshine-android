extends Node3D
## Test-world landmark. About 30 m tall, southeast of the patio, inside the
## photo border and clear of spawn, practice, and the Halloween pockets.
## A sloped spiral plus a short bridge reach a railed deck. No lights.

const PLACE := Vector3(72.0, 0.0, 78.0)
const BODY_R := 13.4
const BODY_Y := 14.2
const DECK_TOP := 27.85
const DECK_HALF := 3.4
const RAMP_R := 19.6
const TURNS := 1.75
const SEGMENTS := 84
const RAIL_H := 1.4
const TREAD_W := 1.9
const TREAD_T := 0.18
const ORANGE := Color("e07a32")
const ORANGE_DK := Color("c45e1c")
const STEM := Color("3a7a34")
const WOOD := Color("c49a62")
const WOOD_DK := Color("8a5a32")

var walk_points := PackedVector3Array()
var bridge_angle := 0.0


func _ready() -> void:
	name = "GiantPumpkin"
	position = PLACE
	add_to_group("giant_pumpkin")
	_body()
	_path()
	_deck()


func _body() -> void:
	_sphere(BODY_R, _mat(ORANGE), Vector3(0, BODY_Y, 0), Vector3(1.05, 1.0, 0.98), 20)
	_sphere(BODY_R * 0.72, _mat(ORANGE_DK), Vector3(-6.2, BODY_Y - 1.0, 1.5), Vector3(0.85, 1.05, 0.9), 14)
	_sphere(BODY_R * 0.68, _mat(ORANGE.lightened(0.08)), Vector3(5.8, BODY_Y + 0.4, -1.2), Vector3(0.9, 1.02, 0.88), 14)


func _path() -> void:
	var pts := PackedVector3Array()
	for i in SEGMENTS + 1:
		var t := float(i) / float(SEGMENTS)
		var y := lerpf(0.06, DECK_TOP, t)
		var ang := t * TURNS * TAU
		pts.append(Vector3(cos(ang) * RAMP_R, y, sin(ang) * RAMP_R))
	## Flat inward spiral on top of the deck, so the climb never meets a vertical lip.
	var ang0 := TURNS * TAU
	const IN_SEG := 40
	const IN_TURNS := 0.85
	for i in IN_SEG:
		var t := float(i + 1) / float(IN_SEG)
		var r := lerpf(RAMP_R, 0.7, t)
		var ang := ang0 + t * IN_TURNS * TAU
		pts.append(Vector3(cos(ang) * r, DECK_TOP, sin(ang) * r))
	bridge_angle = ang0 + IN_TURNS * TAU
	walk_points = pts
	for i in pts.size() - 1:
		_span(pts[i], pts[i + 1], i)


func _span(a: Vector3, b: Vector3, i: int) -> void:
	var delta := b - a
	var flat := Vector2(delta.x, delta.z)
	var run := flat.length()
	if run < 0.05:
		return
	var tangent := Vector3(delta.x / run, 0.0, delta.z / run)
	var slope := delta.y / run
	## Physics bodies drop shear. Keep this rotation orthonormal or the
	## plank becomes a flat step and the capsule cannot climb it.
	var y_axis := (-tangent * slope + Vector3.UP).normalized()
	var x_axis := delta.normalized()
	var outward := Vector3((a.x + b.x) * 0.5, 0.0, (a.z + b.z) * 0.5)
	if outward.length() < 0.2:
		outward = Vector3(cos(bridge_angle), 0.0, sin(bridge_angle))
	outward = outward.normalized()
	if x_axis.cross(y_axis).dot(outward) < 0.0:
		x_axis = -x_axis
	var z_axis := x_axis.cross(y_axis)
	var basis := Basis(x_axis, y_axis, z_axis)
	var mid := (a + b) * 0.5
	var wood := WOOD if i % 2 == 0 else WOOD.darkened(0.06)
	var center := mid - y_axis * (TREAD_T * 0.5)
	_box(Vector3(delta.length(), TREAD_T, TREAD_W), _mat(wood), center, basis, "RampStep")
	var radius := Vector2(mid.x, mid.z).length()
	if radius < 1.55:
		return
	var rail_x := tangent
	var rail_z := Vector3.UP.cross(rail_x).normalized()
	if rail_z.dot(outward) < 0.0:
		rail_x = -rail_x
		rail_z = -rail_z
	var rail_basis := Basis(rail_x, Vector3.UP, rail_z)
	var rail_y := Vector3(0, RAIL_H * 0.5 - 0.02, 0)
	var edge := TREAD_W * 0.5 + 0.02
	var rail_name := "DeckRail" if radius < 8.0 else "RampRail"
	_box(Vector3(run, RAIL_H, 0.14), _mat(WOOD_DK), mid + outward * edge + rail_y, rail_basis, rail_name)
	_box(Vector3(run, RAIL_H, 0.14), _mat(WOOD_DK), mid - outward * edge + rail_y, rail_basis, rail_name)


func _deck() -> void:
	## Sits just under the planks so its rim is not a step the capsule has to hop.
	var deck_y := DECK_TOP - TREAD_T - 0.16
	var body := StaticBody3D.new()
	body.name = "PumpkinDeck"
	body.position = Vector3(0, deck_y, 0)
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = DECK_HALF
	shape.height = 0.28
	col.shape = shape
	body.add_child(col)
	add_child(body, true)
	var disk := CylinderMesh.new()
	disk.top_radius = DECK_HALF
	disk.bottom_radius = DECK_HALF
	disk.height = 0.28
	disk.radial_segments = 24
	var deck_mesh := MeshInstance3D.new()
	deck_mesh.mesh = disk
	deck_mesh.material_override = _mat(WOOD)
	deck_mesh.position = body.position
	deck_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(deck_mesh)
	var back := Vector3(cos(bridge_angle + PI), 0.0, sin(bridge_angle + PI)) * 1.35
	var stem_h := 30.05 - DECK_TOP
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.48
	cyl.bottom_radius = 0.66
	cyl.height = stem_h
	cyl.radial_segments = 12
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = _mat(STEM)
	mi.position = back + Vector3(0, DECK_TOP + stem_h * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_box(Vector3(1.15, stem_h, 1.15), _mat(STEM), mi.position, Basis.IDENTITY, "PumpkinStem")


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


func _sphere(r: float, mat: Material, pos: Vector3, scl: Vector3, segs: int) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = segs
	mesh.rings = maxi(segs / 2, 8)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _visual_box(size: Vector3, mat: Material, pos: Vector3, basis: Basis) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.basis = basis
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _box(size: Vector3, mat: Material, pos: Vector3, basis: Basis, body_name: String) -> void:
	_visual_box(size, mat, pos, basis)
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
