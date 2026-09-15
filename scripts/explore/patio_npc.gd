extends Node3D
class_name PatioNpc
## Chibi patio guests in Sunshine blush / wine / cream — round heads, shiny
## eyes, blush cheeks, like the logo girl. Idle bob, sit at tables, or stroll
## the lawn. No paid character packs.

enum Pose { STAND, SIT, STROLL }

const SKIN := Color("f7d3b8")
const HAIR_DK := Color("2b1a12")
const HAIR_BR := Color("3d2418")
const HAIR_WN := Color("4a1c28")
const BLUSH := Color("e8a8b4")
const WINE := Color("4a1c28")
const CREAM := Color("f7f0e6")
const ORANGE := Color("e3922e")
const WHITE := Color("fbf8f3")
const SHOE := Color("2a1c18")
const APRON := Color("c5c0be")
const COLLAR := Color("c45c6a")
const HAT := Color("e6b14a")
const HAT_BAND := Color("1a1a1a")
const EYE := Color("14110f")
const SHINE := Color("ffffff")
const CHEEK := Color("f4a8b0")

@export var pose: int = Pose.STAND
@export var outfit: String = "blush"
@export var hair: String = "brown"
@export var look: String = "bangs"
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


func _mat(c: Color, rough := 0.62) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
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
	mesh.radial_segments = 16
	mesh.rings = 10
	return _part(parent, mesh, mat, pos, Vector3.ZERO, scl)


func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = h
	mesh.radial_segments = 14
	return _part(parent, mesh, mat, pos, rot)


func _capsule(parent: Node3D, r: float, h: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = r
	mesh.height = h
	mesh.radial_segments = 12
	return _part(parent, mesh, mat, pos)


func _colors() -> Dictionary:
	match outfit:
		"wine":
			return {"top": WINE, "pants": Color("2a1418"), "trim": BLUSH}
		"cream":
			return {"top": CREAM, "pants": WINE, "trim": BLUSH}
		"orange":
			return {"top": ORANGE, "pants": WINE, "trim": CREAM}
		"staff":
			return {"top": WHITE, "pants": WINE, "trim": COLLAR}
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
	var skin := _mat(SKIN, 0.55)
	var hair_m := _mat(_hair_color(), 0.7)
	var body := Node3D.new()
	body.name = "Rig"
	add_child(body)
	_torso = Node3D.new()
	_torso.position = Vector3(0, 0.78, 0)
	body.add_child(_torso)
	_capsule(_torso, 0.15, 0.42, _mat(col["top"], 0.65), Vector3(0, 0.02, 0))
	_sphere(_torso, 0.16, _mat(col["top"], 0.65), Vector3(0, 0.16, 0), Vector3(1.35, 0.55, 0.95))
	_cyl(_torso, 0.11, 0.11, 0.045, _mat(col["trim"], 0.5), Vector3(0, 0.24, -0.02))
	if outfit == "staff":
		_box(_torso, Vector3(0.28, 0.32, 0.06), _mat(APRON, 0.7), Vector3(0, -0.02, 0.12))
		_box(_torso, Vector3(0.04, 0.28, 0.03), _mat(APRON, 0.7), Vector3(-0.07, 0.12, 0.1))
		_box(_torso, Vector3(0.04, 0.28, 0.03), _mat(APRON, 0.7), Vector3(0.07, 0.12, 0.1))
	_head = Node3D.new()
	_head.position = Vector3(0, 0.42, 0)
	_torso.add_child(_head)
	_sphere(_head, 0.22, skin, Vector3.ZERO)
	_face(hair_m)
	_hairdo(hair_m)
	_arm_l = Node3D.new()
	_arm_l.position = Vector3(-0.2, 0.14, 0)
	_torso.add_child(_arm_l)
	_cyl(_arm_l, 0.045, 0.05, 0.38, _mat(col["top"]), Vector3(0, -0.16, 0))
	_sphere(_arm_l, 0.05, skin, Vector3(0, -0.36, 0))
	_arm_r = Node3D.new()
	_arm_r.position = Vector3(0.2, 0.14, 0)
	_torso.add_child(_arm_r)
	_cyl(_arm_r, 0.045, 0.05, 0.38, _mat(col["top"]), Vector3(0, -0.16, 0))
	_sphere(_arm_r, 0.05, skin, Vector3(0, -0.36, 0))
	_leg_l = Node3D.new()
	_leg_l.position = Vector3(-0.08, 0.52, 0)
	body.add_child(_leg_l)
	_cyl(_leg_l, 0.055, 0.06, 0.42, _mat(col["pants"]), Vector3(0, -0.2, 0))
	_box(_leg_l, Vector3(0.14, 0.07, 0.2), _mat(SHOE, 0.5), Vector3(0, -0.42, 0.03))
	_leg_r = Node3D.new()
	_leg_r.position = Vector3(0.08, 0.52, 0)
	body.add_child(_leg_r)
	_cyl(_leg_r, 0.055, 0.06, 0.42, _mat(col["pants"]), Vector3(0, -0.2, 0))
	_box(_leg_r, Vector3(0.14, 0.07, 0.2), _mat(SHOE, 0.5), Vector3(0, -0.42, 0.03))


func _face(hair_m: Material) -> void:
	_sphere(_head, 0.055, _mat(EYE, 0.25), Vector3(-0.07, 0.02, -0.18))
	_sphere(_head, 0.055, _mat(EYE, 0.25), Vector3(0.07, 0.02, -0.18))
	_sphere(_head, 0.018, _mat(SHINE, 0.2), Vector3(-0.055, 0.04, -0.22))
	_sphere(_head, 0.018, _mat(SHINE, 0.2), Vector3(0.085, 0.04, -0.22))
	_sphere(_head, 0.04, _mat(CHEEK, 0.7), Vector3(-0.12, -0.04, -0.14), Vector3(1.1, 0.7, 0.5))
	_sphere(_head, 0.04, _mat(CHEEK, 0.7), Vector3(0.12, -0.04, -0.14), Vector3(1.1, 0.7, 0.5))
	_box(_head, Vector3(0.08, 0.012, 0.012), _mat(COLLAR, 0.4), Vector3(0, -0.08, -0.19))
	if look == "glasses" or look == "visor":
		_glasses()
	if look == "glasses":
		_sphere(_head, 0.01, hair_m, Vector3(0.11, -0.06, -0.17))


func _glasses() -> void:
	var glass := _mat(EYE, 0.3)
	_torus(_head, 0.07, 0.01, Vector3(-0.07, 0.02, -0.19), glass)
	_torus(_head, 0.07, 0.01, Vector3(0.07, 0.02, -0.19), glass)
	_box(_head, Vector3(0.05, 0.01, 0.01), glass, Vector3(0, 0.02, -0.19))


func _torus(parent: Node3D, r: float, t: float, pos: Vector3, mat: Material) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(r - t, 0.004)
	mesh.outer_radius = r + t
	mesh.rings = 12
	mesh.ring_segments = 8
	_part(parent, mesh, mat, pos, Vector3(PI * 0.5, 0, 0))


func _hairdo(hair_m: Material) -> void:
	match look:
		"bun":
			_sphere(_head, 0.2, hair_m, Vector3(0, 0.08, 0.04), Vector3(1.05, 0.75, 1.05))
			_sphere(_head, 0.1, hair_m, Vector3(0, 0.2, 0.08))
			_sphere(_head, 0.08, hair_m, Vector3(-0.08, 0.14, -0.12), Vector3(1.2, 0.45, 0.6))
			_sphere(_head, 0.08, hair_m, Vector3(0.06, 0.15, -0.12), Vector3(1.1, 0.4, 0.6))
		"pony":
			_sphere(_head, 0.21, hair_m, Vector3(0, 0.06, 0.02), Vector3(1.05, 0.8, 1.05))
			_sphere(_head, 0.09, hair_m, Vector3(-0.08, 0.14, -0.13), Vector3(1.2, 0.45, 0.65))
			_sphere(_head, 0.09, hair_m, Vector3(0.07, 0.14, -0.13), Vector3(1.15, 0.4, 0.65))
			_sphere(_head, 0.08, hair_m, Vector3(0, -0.02, 0.2), Vector3(0.7, 1.6, 0.7))
			_sphere(_head, 0.07, hair_m, Vector3(0, -0.18, 0.22), Vector3(0.65, 1.3, 0.65))
		"pixie":
			_sphere(_head, 0.21, hair_m, Vector3(0, 0.05, 0.02), Vector3(1.02, 0.65, 1.02))
			_sphere(_head, 0.07, hair_m, Vector3(-0.06, 0.12, -0.14), Vector3(1.1, 0.4, 0.55))
		"hat":
			_sphere(_head, 0.2, hair_m, Vector3(0, 0.04, 0.06), Vector3(1.1, 0.85, 0.95))
			_sphere(_head, 0.16, hair_m, Vector3(-0.16, -0.02, 0.04), Vector3(0.85, 1.15, 0.7))
			_sphere(_head, 0.16, hair_m, Vector3(0.16, -0.02, 0.04), Vector3(0.85, 1.15, 0.7))
			_straw_hat()
		"visor":
			_sphere(_head, 0.2, hair_m, Vector3(0, 0.06, 0.03), Vector3(1.05, 0.7, 1.0))
			_staff_visor()
		"glasses":
			_sphere(_head, 0.21, hair_m, Vector3(0, 0.06, 0.04), Vector3(1.08, 0.75, 1.05))
			_sphere(_head, 0.16, hair_m, Vector3(-0.16, 0.0, 0.04), Vector3(0.9, 1.2, 0.75))
			_sphere(_head, 0.16, hair_m, Vector3(0.16, 0.0, 0.04), Vector3(0.9, 1.2, 0.75))
			_sphere(_head, 0.085, hair_m, Vector3(-0.08, 0.14, -0.14), Vector3(1.25, 0.45, 0.65))
			_sphere(_head, 0.085, hair_m, Vector3(0.07, 0.15, -0.14), Vector3(1.15, 0.4, 0.65))
		_:
			_sphere(_head, 0.2, hair_m, Vector3(0, 0.08, 0.06), Vector3(1.15, 0.7, 0.95))
			_sphere(_head, 0.16, hair_m, Vector3(-0.16, 0.0, 0.04), Vector3(0.95, 1.25, 0.75))
			_sphere(_head, 0.16, hair_m, Vector3(0.16, 0.0, 0.04), Vector3(0.95, 1.25, 0.75))
			_sphere(_head, 0.085, hair_m, Vector3(-0.08, 0.16, -0.14), Vector3(1.3, 0.5, 0.7))
			_sphere(_head, 0.085, hair_m, Vector3(0.07, 0.17, -0.14), Vector3(1.2, 0.45, 0.7))
			_sphere(_head, 0.07, hair_m, Vector3(-0.02, 0.14, -0.16), Vector3(1.1, 0.4, 0.55))


func _straw_hat() -> void:
	var hat_m := _mat(HAT, 0.5)
	var brim := CylinderMesh.new()
	brim.top_radius = 0.38
	brim.bottom_radius = 0.38
	brim.height = 0.035
	brim.radial_segments = 18
	_part(_head, brim, hat_m, Vector3(0, 0.16, 0.02), Vector3(0.18, 0, -0.12))
	_cyl(_head, 0.16, 0.19, 0.12, hat_m, Vector3(0, 0.22, 0.03), Vector3(0.16, 0, -0.1))
	_cyl(_head, 0.17, 0.17, 0.035, _mat(HAT_BAND, 0.4), Vector3(0, 0.17, 0.025), Vector3(0.16, 0, -0.1))
	_sphere(_head, 0.045, _mat(Color("5c3310"), 0.7), Vector3(0.2, 0.24, -0.08))
	for i in 8:
		var ang := float(i) * TAU / 8.0
		_sphere(_head, 0.022, _mat(ORANGE if i % 2 == 0 else Color("c45c1a"), 0.55), Vector3(0.2 + cos(ang) * 0.055, 0.24 + sin(ang) * 0.055, -0.08))


func _staff_visor() -> void:
	var visor := _mat(WINE, 0.45)
	_cyl(_head, 0.2, 0.22, 0.1, visor, Vector3(0, 0.16, 0.02))
	_box(_head, Vector3(0.28, 0.02, 0.16), visor, Vector3(0, 0.12, -0.16))
	_cyl(_head, 0.21, 0.21, 0.03, _mat(BLUSH, 0.5), Vector3(0, 0.12, 0.02))


func _apply_sit() -> void:
	_leg_l.rotation.x = -1.25
	_leg_r.rotation.x = -1.2
	_arm_l.rotation.x = -0.7
	_arm_r.rotation.x = -0.55
	_torso.rotation.x = 0.12
	position.y = 0.46


func _process(delta: float) -> void:
	_t += delta
	if _torso:
		_torso.position.y = 0.78 + sin(_t * 2.1) * (0.012 if pose != Pose.SIT else 0.005)
	if _head:
		_head.rotation.y = sin(_t * 0.7) * 0.22
		_head.rotation.x = sin(_t * 0.45) * 0.05
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
