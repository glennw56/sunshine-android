extends Node3D
class_name DiscoBullseye
## Small patio bullseye. A cookie that hits the disc asks the room to start disco.
## The face is much smaller than a practice post so it is a skill shot.
## Crossed discs carry the same cream / red / yellow rings. Only the disc
## turned toward the camera is drawn, so a side approach still reads as the
## target and a frontal look stays the flat bullseye.

## Smaller than the old 0.26 m lawn disc. The collider never disables.
const FACE := 0.14
## About 10 ft above the patio. The pole grows up to this disc.
const FACE_Y := 3.05
## Keep the current disc until the other one is clearly more face-on.
const _AIM_HOLD := 0.82

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
	## Cylinder axis (local Y) is the disc normal.
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
	var disc := Node3D.new()
	disc.name = node_name
	disc.basis = orient
	_ring(disc, 0.095, Color("fff6ea"))
	_ring(disc, 0.062, Color("e10600"))
	_ring(disc, 0.028, Color("ffe600"))
	return disc


func _ring(parent: Node3D, radius: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 20
	mi.mesh = disc
	mi.material_override = _mat(color)
	parent.add_child(mi)


func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.45
	return mat
