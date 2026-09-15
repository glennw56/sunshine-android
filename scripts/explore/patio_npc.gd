extends Node3D
class_name PatioNpc
## Low-poly patio guests / staff in Sunshine blush + wine. Idle bob, seated hangout,
## or a short grass stroll. No paid character packs.

enum Pose { STAND, SIT, STROLL }

const SKIN := Color("f3c7a8")
const HAIR_DK := Color("2b1a12")
const HAIR_BR := Color("5a3318")
const HAIR_WN := Color("4a1c28")
const BLUSH := Color("e8b4b8")
const WINE := Color("4a1c28")
const CREAM := Color("f7f0e6")
const ORANGE := Color("e3922e")
const WHITE := Color("fbf8f3")
const SHOE := Color("2a1c18")
const APRON := Color("f4ece0")

@export var pose: int = Pose.STAND
@export var outfit: String = "blush"
@export var hair: String = "brown"
@export var waypoint_b: Vector3 = Vector3.ZERO

var _t: float = 0.0
var _toward_b := true
var _home: Vector3 = Vector3.ZERO
var _torso: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _head: Node3D


func _ready() -> void:
	add_to_group("village_npc")
	_home = global_position
	_t = randf() * TAU
	_build()
	if pose == Pose.SIT:
		_apply_sit()


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.roughness = 1.0
	return m


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(parent, mesh, mat, pos, rot)


func _sphere(parent: Node3D, r: float, mat: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	var mi := _part(parent, mesh, mat, pos)
	mi.scale = scl
	return mi


func _cyl(parent: Node3D, r: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = h
	mesh.radial_segments = 10
	return _part(parent, mesh, mat, pos, rot)


func _colors() -> Dictionary:
	match outfit:
		"wine":
			return {"top": WINE, "pants": Color("2a1418"), "trim": BLUSH}
		"cream":
			return {"top": CREAM, "pants": WINE, "trim": BLUSH}
		"orange":
			return {"top": ORANGE, "pants": WINE, "trim": CREAM}
		"staff":
			return {"top": WHITE, "pants": WINE, "trim": BLUSH}
		_:
			return {"top": BLUSH, "pants": WINE, "trim": CREAM}


func _hair_color() -> Color:
	match hair:
		"dark":
			return HAIR_DK
		"wine":
			return HAIR_WN
		_:
			return HAIR_BR


func _build() -> void:
	var col := _colors()
	var body := Node3D.new()
	body.name = "Rig"
	add_child(body)
	_torso = Node3D.new()
	_torso.position = Vector3(0, 0.92, 0)
	body.add_child(_torso)
	_box(_torso, Vector3(0.42, 0.58, 0.28), _mat(col["top"]), Vector3.ZERO)
	_box(_torso, Vector3(0.46, 0.08, 0.3), _mat(col["trim"]), Vector3(0, 0.28, 0))
	if outfit == "staff":
		_box(_torso, Vector3(0.38, 0.42, 0.08), _mat(APRON), Vector3(0, -0.04, 0.16))
		_box(_torso, Vector3(0.08, 0.42, 0.06), _mat(WINE), Vector3(0, -0.04, 0.2))
	_head = Node3D.new()
	_head.position = Vector3(0, 0.48, 0)
	_torso.add_child(_head)
	_sphere(_head, 0.2, _mat(SKIN), Vector3.ZERO)
	_sphere(_head, 0.21, _mat(_hair_color()), Vector3(0, 0.06, -0.02), Vector3(1.05, 0.7, 1.1))
	_box(_head, Vector3(0.22, 0.04, 0.04), _mat(HAIR_DK), Vector3(0, 0.04, 0.16))
	_sphere(_head, 0.035, _mat(Color("1a1210")), Vector3(-0.07, 0.02, 0.16))
	_sphere(_head, 0.035, _mat(Color("1a1210")), Vector3(0.07, 0.02, 0.16))
	_arm_l = Node3D.new()
	_arm_l.position = Vector3(-0.28, 0.18, 0)
	_torso.add_child(_arm_l)
	_cyl(_arm_l, 0.055, 0.5, _mat(col["top"]), Vector3(0, -0.22, 0))
	_sphere(_arm_l, 0.055, _mat(SKIN), Vector3(0, -0.48, 0))
	_arm_r = Node3D.new()
	_arm_r.position = Vector3(0.28, 0.18, 0)
	_torso.add_child(_arm_r)
	_cyl(_arm_r, 0.055, 0.5, _mat(col["top"]), Vector3(0, -0.22, 0))
	_sphere(_arm_r, 0.055, _mat(SKIN), Vector3(0, -0.48, 0))
	_leg_l = Node3D.new()
	_leg_l.position = Vector3(-0.11, 0.62, 0)
	body.add_child(_leg_l)
	_cyl(_leg_l, 0.07, 0.52, _mat(col["pants"]), Vector3(0, -0.26, 0))
	_box(_leg_l, Vector3(0.16, 0.08, 0.22), _mat(SHOE), Vector3(0, -0.54, 0.04))
	_leg_r = Node3D.new()
	_leg_r.position = Vector3(0.11, 0.62, 0)
	body.add_child(_leg_r)
	_cyl(_leg_r, 0.07, 0.52, _mat(col["pants"]), Vector3(0, -0.26, 0))
	_box(_leg_r, Vector3(0.16, 0.08, 0.22), _mat(SHOE), Vector3(0, -0.54, 0.04))


func _apply_sit() -> void:
	_leg_l.rotation.x = -1.15
	_leg_r.rotation.x = -1.15
	_arm_l.rotation.x = -0.55
	_arm_r.rotation.x = -0.45
	position.y = 0.42


func _process(delta: float) -> void:
	_t += delta
	if _torso:
		_torso.position.y = 0.92 + sin(_t * 2.1) * (0.012 if pose != Pose.SIT else 0.006)
	if _head:
		_head.rotation.y = sin(_t * 0.7) * 0.18
	if pose == Pose.STROLL:
		_stroll(delta)
	elif pose == Pose.STAND:
		rotation.y += sin(_t * 0.35) * 0.0008


func _stroll(delta: float) -> void:
	var dest := waypoint_b if _toward_b else _home
	var to := dest - global_position
	to.y = 0.0
	if to.length() < 0.45:
		_toward_b = not _toward_b
		return
	var dir := to.normalized()
	global_position += dir * 1.05 * delta
	global_position.y = _home.y
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(5.0 * delta, 0.0, 1.0))
	var swing := sin(_t * 6.4) * 0.55
	_arm_l.rotation.x = swing
	_arm_r.rotation.x = -swing
	_leg_l.rotation.x = -swing * 0.7
	_leg_r.rotation.x = swing * 0.7
