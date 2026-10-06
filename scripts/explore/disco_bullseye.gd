extends Node3D
class_name DiscoBullseye
## Small patio bullseye. A cookie that hits the disc asks the room to start disco.
## The face is much smaller than a practice post so it is a skill shot.
## Crossed discs carry the same cream / red / yellow rings. Only the disc
## turned toward the camera is drawn, so a side approach still reads as the
## target and a frontal look stays the flat bullseye.
## Each disc is one face of abutting rings. Stacked cylinder caps share a
## plane and speckle at a low angle; these rings do not overlap.

## Smaller than the old 0.26 m lawn disc. The collider never disables.
const FACE := 0.14
## About 10 ft above the patio. The pole grows up to this disc.
const FACE_Y := 3.05
## Keep the current disc until the other one is clearly more face-on.
const _AIM_HOLD := 0.82
const _RING_SEGMENTS := 20
const _CREAM_R := 0.095
const _RED_R := 0.062
const _YELLOW_R := 0.028
## Same thickness as the old ring cylinders, only on the outer lip.
const _DISC_THICK := 0.02

var _ring_mesh: ArrayMesh

var hits: int = 0
var _t: float = 0.0
var _label: Label3D
var _face: Node3D
var _front: Node3D
var _side: Node3D
var _show_front := true


func _ready() -> void:
	add_to_group("disco_bullseye")
	name = "DiscoBullseye"
	_build()
	_aim_discs()


func register_hit() -> void:
	hits += 1
	_t = 0.42
	if _label:
		_label.visible = true
		_label.text = "Party!"
		_label.modulate.a = 1.0
	if ExploreNet:
		ExploreNet.send_disco()
	## Test world only. The room echo still refreshes the shared clock, but a
	## hit also starts the 20s party on this phone. Night patio materials are
	## unshaded, so waiting on a missed broadcast looks like the party never
	## happened. Store builds keep waiting for t:disco.
	if AppConfig and AppConfig.test_world:
		var party := get_tree().get_first_node_in_group("disco_party") if is_inside_tree() else null
		if party and party.has_method("apply_until"):
			party.call("apply_until", Time.get_unix_time_from_system() + DiscoParty.DISCO_SEC)


func _process(delta: float) -> void:
	_aim_discs()
	if _t <= 0.0:
		return
	_t = maxf(0.0, _t - delta)
	var u := 1.0 - (_t / 0.42)
	var pop := 1.0 + sin(u * PI) * 0.18
	if _face:
		_face.scale = Vector3(pop, pop, pop)
	if _label:
		_label.position.y = FACE_Y + 0.40 + u * 0.35
		var tint := _label.modulate
		tint.a = 1.0 - u
		_label.modulate = tint
	if _t <= 0.0 and _face:
		_face.scale = Vector3.ONE
		if _label:
			_label.visible = false


func _aim_discs() -> void:
	if _front == null or _side == null or _face == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var to_cam := cam.global_position - _face.global_position
	if to_cam.length_squared() < 0.0004:
		return
	## Disc normal is local Y.
	var front_w := absf(to_cam.dot(_front.global_transform.basis.y))
	var side_w := absf(to_cam.dot(_side.global_transform.basis.y))
	if _show_front:
		_show_front = front_w >= side_w * _AIM_HOLD
	else:
		_show_front = front_w > side_w / _AIM_HOLD
	_front.visible = _show_front
	_side.visible = not _show_front


func _build() -> void:
	var pole := MeshInstance3D.new()
	var stem := CylinderMesh.new()
	stem.top_radius = 0.035
	stem.bottom_radius = 0.045
	stem.height = FACE_Y - 0.06
	stem.radial_segments = 8
	pole.mesh = stem
	pole.position = Vector3(0, stem.height * 0.5, 0)
	pole.material_override = _mat(Color("2a1c18"))
	add_child(pole)
	_face = Node3D.new()
	_face.name = "Face"
	_face.position = Vector3(0, FACE_Y, 0)
	add_child(_face)
	## Front faces ±Z (lawn and tables). Side faces ±X (yaw ~90° approaches).
	_front = _disc("FrontDisc", Basis(Vector3(1, 0, 0), PI * 0.5))
	_side = _disc("SideDisc", Basis(Vector3(0, 0, 1), -PI * 0.5))
	_side.visible = false
	_face.add_child(_front)
	_face.add_child(_side)
	_label = Label3D.new()
	_label.name = "PartyTag"
	_label.text = ""
	_label.font_size = 42
	_label.pixel_size = 0.0045
	_label.position = Vector3(0, FACE_Y + 0.40, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color("ffe600")
	_label.outline_size = 8
	_label.outline_modulate = Color("1a1030")
	_label.visible = false
	add_child(_label)
	var CutePackLib := preload("res://scripts/explore/cute_pack.gd")
	CutePackLib.collider(self, Vector3(FACE, FACE, 0.1), Vector3(0, FACE_Y, 0))


func _disc(node_name: String, orient: Basis) -> Node3D:
	var disc := MeshInstance3D.new()
	disc.name = node_name
	disc.basis = orient
	if _ring_mesh == null:
		_ring_mesh = _build_ring_mesh()
	disc.mesh = _ring_mesh
	return disc


func _build_ring_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var yellow := _mat(Color("ffe600"))
	var red := _mat(Color("e10600"))
	var cream := _mat(Color("fff6ea"))
	_add_annulus(mesh, 0.0, _YELLOW_R, yellow)
	_add_annulus(mesh, _YELLOW_R, _RED_R, red)
	_add_annulus(mesh, _RED_R, _CREAM_R, cream)
	_add_rim(mesh, cream)
	return mesh


func _add_annulus(mesh: ArrayMesh, inner: float, outer: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := _RING_SEGMENTS
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var o0 := Vector3(cos(a0) * outer, 0.0, sin(a0) * outer)
		var o1 := Vector3(cos(a1) * outer, 0.0, sin(a1) * outer)
		if inner <= 0.0001:
			_tri(st, Vector3.ZERO, o0, o1)
		else:
			var i0 := Vector3(cos(a0) * inner, 0.0, sin(a0) * inner)
			var i1 := Vector3(cos(a1) * inner, 0.0, sin(a1) * inner)
			_tri(st, i0, o0, o1)
			_tri(st, i0, o1, i1)
	_commit_surface(mesh, st, mat)


func _add_rim(mesh: ArrayMesh, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := _RING_SEGMENTS
	var half := _DISC_THICK * 0.5
	var r := _CREAM_R
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var b0 := Vector3(cos(a0) * r, -half, sin(a0) * r)
		var b1 := Vector3(cos(a1) * r, -half, sin(a1) * r)
		var t0 := Vector3(cos(a0) * r, half, sin(a0) * r)
		var t1 := Vector3(cos(a1) * r, half, sin(a1) * r)
		_tri(st, b0, t0, t1)
		_tri(st, b0, t1, b1)
	_commit_surface(mesh, st, mat)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() > 0.0000001:
		normal = normal.normalized()
	else:
		normal = Vector3.UP
	st.set_normal(normal)
	st.add_vertex(a)
	st.set_normal(normal)
	st.add_vertex(b)
	st.set_normal(normal)
	st.add_vertex(c)


func _commit_surface(mesh: ArrayMesh, st: SurfaceTool, mat: Material) -> void:
	var built := st.commit()
	var arrays: Array = built.surface_get_arrays(0)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.45
	return mat
