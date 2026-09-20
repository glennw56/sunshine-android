extends Node3D
class_name AvatarBody
## Rounded chibi from an approved avatar recipe. Feet sit on y=0. No cubes as the body.

const CosContracts := preload("res://scripts/contracts/cos_contracts.gd")
const PLATE_NEAR := 5.5
const PLATE_FAR := 10.0
const THROW_TIME := 0.32

var recipe: Dictionary = {}
var _hand: Node3D
var _head: Node3D
var _plate: Label3D
var _lleg: Node3D
var _rleg: Node3D
var _larm: Node3D
var _rarm: Node3D
var _moving := false
var _walk: float = 0.0
var _display: String = ""
var _hide_plate := false
var _throw_left := 0.0
var _hit_left := 0.0


func _ready() -> void:
	if recipe.is_empty():
		rebuild(ProfileStore.current_avatar())


func rebuild(raw: Dictionary, display_name: String = "") -> void:
	recipe = CosContracts.sanitize_avatar(raw)
	if display_name != "":
		_display = display_name
	for child in get_children():
		child.queue_free()
	_hand = null
	_head = null
	_plate = null
	_lleg = null
	_rleg = null
	_larm = null
	_rarm = null
	_build()


func hand_socket() -> Node3D:
	return _hand


func head_node() -> Node3D:
	return _head


func set_nameplate(text: String) -> void:
	var label := text.strip_edges()
	if label == "":
		label = "Sunshine Guest"
	_display = label
	if _plate:
		_plate.text = label
		if _hide_plate:
			_plate.visible = false


func hide_nameplate() -> void:
	_hide_plate = true
	if _plate:
		_plate.visible = false


func update_nameplate_for(viewer: Vector3) -> void:
	if _hide_plate or _plate == null:
		if _plate:
			_plate.visible = false
		return
	var d := global_position.distance_to(viewer)
	var far := PLATE_FAR
	var generic := _is_generic_plate(_display)
	if generic:
		far = 3.8
	if d > far:
		_plate.visible = false
		return
	_plate.visible = true
	var alpha := 1.0
	if d > PLATE_NEAR:
		alpha = 1.0 - (d - PLATE_NEAR) / (PLATE_FAR - PLATE_NEAR)
	_plate.modulate = Color(1.0, 0.965, 0.918, clampf(alpha, 0.0, 1.0))
	_plate.font_size = 18 if d > 7.0 else 20


func _is_generic_plate(display: String) -> bool:
	var d := display.strip_edges()
	return d == "" or d == "Baker" or d == "Guest" or d.ends_with(" Guest")


func set_moving(on: bool) -> void:
	_moving = on


func play_throw(skip_windup := false) -> void:
	# Local bakers wind up 0.12s then fling. Remotes already waited on the
	# sender, so start at the release pose so the cookie leaves the hand.
	_hit_left = 0.0
	_throw_left = THROW_TIME * (0.62 if skip_windup else 1.0)
	_apply_throw_pose()


func play_hit() -> void:
	_throw_left = 0.0
	_hit_left = 0.42
	_apply_hit_pose(0.0)


func _apply_throw_pose() -> void:
	if _rarm == null or _throw_left <= 0.0:
		return
	var k := 1.0 - _throw_left / THROW_TIME
	if k < 0.38:
		_rarm.rotation.x = lerpf(0.0, 0.95, k / 0.38)
	else:
		_rarm.rotation.x = lerpf(0.95, -1.15, (k - 0.38) / 0.62)


func _apply_hit_pose(k: float) -> void:
	# Lean back, both arms up — a hit, not a throw.
	var lean := sin(clampf(k, 0.0, 1.0) * PI) * -0.55
	rotation.x = lean
	if _rarm:
		_rarm.rotation.x = -1.05
	if _larm:
		_larm.rotation.x = -0.85


func _process(delta: float) -> void:
	if _hit_left > 0.0:
		_hit_left = maxf(0.0, _hit_left - delta)
		_apply_hit_pose(1.0 - _hit_left / 0.42)
		if _hit_left <= 0.0:
			rotation.x = 0.0
		return
	if _throw_left > 0.0:
		_throw_left = maxf(0.0, _throw_left - delta)
		_apply_throw_pose()
		return
	if _moving:
		_walk += delta * 9.0
	else:
		_walk = lerpf(_walk, 0.0, clampf(delta * 8.0, 0.0, 1.0))
	var swing := sin(_walk) * (0.55 if _moving else 0.0)
	if _lleg:
		_lleg.rotation.x = swing
	if _rleg:
		_rleg.rotation.x = -swing
	if _larm:
		_larm.rotation.x = -swing * 0.65
	if _rarm:
		_rarm.rotation.x = swing * 0.65


func _mat(c: Color, rough := 0.58) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_BACK
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	mi.visibility_range_end = 40.0
	mi.visibility_range_end_margin = 8.0
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, r: float, mat: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 18
	mesh.rings = 10
	return _mesh(parent, mesh, mat, pos, Vector3.ZERO, scl)


func _cap(parent: Node3D, r: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = r
	mesh.height = h
	mesh.radial_segments = 14
	return _mesh(parent, mesh, mat, pos, rot)


func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = h
	mesh.radial_segments = 16
	return _mesh(parent, mesh, mat, pos, rot)


func _build() -> void:
	var skin := _mat(CosContracts.SKIN_COLORS.get(recipe["skin"], Color("f7d3b8")))
	var hair_c := _mat(CosContracts.HAIR_TINTS.get(recipe["hair_color"], Color("3d2418")), 0.7)
	var outfit := _mat(CosContracts.OUTFIT_COLORS.get(recipe["outfit"], Color("e8a8b4")), 0.65)
	var root := Node3D.new()
	root.name = "Rig"
	root.position.y = -0.05
	add_child(root)
	## Contact shadow so the soles read as planted, not hovering.
	var shadow := CylinderMesh.new()
	shadow.top_radius = 0.28
	shadow.bottom_radius = 0.28
	shadow.height = 0.02
	var shadow_mat := _mat(Color(0.12, 0.08, 0.06, 0.38), 1.0)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh(root, shadow, shadow_mat, Vector3(0, 0.012, 0.02))
	_cap(root, 0.16, 0.58, outfit, Vector3(0, 0.72, 0))
	_sphere(root, 0.2, outfit, Vector3(0, 0.98, 0), Vector3(1.15, 0.7, 0.95))
	var apron := str(recipe.get("apron", "none"))
	if apron != "none":
		var apron_col := Color("c5c0be")
		if apron == "blush":
			apron_col = Color("e8b4b8")
		elif apron == "wine":
			apron_col = Color("6b2d3c")
		_cyl(root, 0.17, 0.2, 0.3, _mat(apron_col, 0.7), Vector3(0, 0.7, 0.11))
	_larm = Node3D.new()
	_larm.position = Vector3(-0.22, 0.92, 0.02)
	root.add_child(_larm)
	_cap(_larm, 0.055, 0.36, outfit, Vector3(0, -0.14, 0), Vector3(0, 0, 18))
	_rarm = Node3D.new()
	_rarm.position = Vector3(0.22, 0.92, 0.02)
	root.add_child(_rarm)
	_cap(_rarm, 0.055, 0.36, outfit, Vector3(0, -0.14, 0), Vector3(0, 0, -18))
	_hand = Node3D.new()
	_hand.name = "HandSocket"
	_hand.position = Vector3(0.08, -0.28, -0.08)
	_rarm.add_child(_hand)
	_lleg = Node3D.new()
	_lleg.position = Vector3(-0.08, 0.42, 0.02)
	root.add_child(_lleg)
	_cap(_lleg, 0.06, 0.38, skin, Vector3(0, -0.16, 0))
	_sphere(_lleg, 0.072, _mat(Color("2a1c18")), Vector3(0, -0.34, 0.03))
	_rleg = Node3D.new()
	_rleg.position = Vector3(0.08, 0.42, 0.02)
	root.add_child(_rleg)
	_cap(_rleg, 0.06, 0.38, skin, Vector3(0, -0.16, 0))
	_sphere(_rleg, 0.072, _mat(Color("2a1c18")), Vector3(0, -0.34, 0.03))
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 1.28, 0)
	root.add_child(_head)
	_sphere(_head, 0.26, skin, Vector3.ZERO)
	_sphere(_head, 0.055, _mat(Color("14110f"), 0.25), Vector3(-0.08, 0.02, -0.2))
	_sphere(_head, 0.055, _mat(Color("14110f"), 0.25), Vector3(0.08, 0.02, -0.2))
	_sphere(_head, 0.018, _mat(Color.WHITE, 0.2), Vector3(-0.06, 0.04, -0.24))
	_sphere(_head, 0.018, _mat(Color.WHITE, 0.2), Vector3(0.1, 0.04, -0.24))
	_sphere(_head, 0.045, _mat(Color("f4a8b0"), 0.5), Vector3(-0.16, -0.04, -0.12), Vector3(1.0, 0.7, 0.6))
	_sphere(_head, 0.045, _mat(Color("f4a8b0"), 0.5), Vector3(0.16, -0.04, -0.12), Vector3(1.0, 0.7, 0.6))
	_build_hair(_head, hair_c)
	_build_hat(_head)
	_build_accessory(_head)
	_plate = Label3D.new()
	_plate.name = "Nameplate"
	_plate.text = _display if _display != "" else (ProfileStore.display_name if ProfileStore.display_name != "" else "Sunshine Guest")
	_plate.font_size = 20
	_plate.outline_size = 4
	_plate.pixel_size = 0.0042
	_plate.position = Vector3(0, 1.72, 0)
	_plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_plate.modulate = Color("fff6ea")
	_plate.outline_modulate = Color("4a1c28")
	_plate.no_depth_test = false
	_plate.visible = false
	add_child(_plate)


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _build_hair(head: Node3D, hair: Material) -> void:
	var style := str(recipe.get("hair", "bangs"))
	if style == "none":
		return
	_sphere(head, 0.22, hair, Vector3(0, 0.08, 0.08), Vector3(1.15, 0.7, 0.95))
	if style == "bangs" or style == "wavy":
		_sphere(head, 0.1, hair, Vector3(-0.1, 0.16, -0.16), Vector3(1.3, 0.5, 0.7))
		_sphere(head, 0.1, hair, Vector3(0.08, 0.17, -0.16), Vector3(1.2, 0.45, 0.7))
	if style == "wavy":
		_sphere(head, 0.16, hair, Vector3(-0.2, -0.04, 0.06), Vector3(0.9, 1.3, 0.8))
		_sphere(head, 0.16, hair, Vector3(0.2, -0.04, 0.06), Vector3(0.9, 1.3, 0.8))
	if style == "short":
		_sphere(head, 0.2, hair, Vector3(0, 0.1, 0.04), Vector3(1.05, 0.55, 1.0))
	if style == "bun":
		_sphere(head, 0.1, hair, Vector3(0, 0.24, 0.06))


func _build_hat(head: Node3D) -> void:
	var hat := str(recipe.get("hat", "none"))
	if hat == "none":
		return
	if hat == "sun":
		var brim := CylinderMesh.new()
		brim.top_radius = 0.42
		brim.bottom_radius = 0.42
		brim.height = 0.035
		brim.radial_segments = 18
		_mesh(head, brim, _mat(Color("e6b14a"), 0.5), Vector3(0, 0.22, 0.0), Vector3(10, 0, -6))
		_cyl(head, 0.16, 0.18, 0.12, _mat(Color("e6b14a"), 0.5), Vector3(0, 0.3, 0.03), Vector3(8, 0, -4))
		_cyl(head, 0.17, 0.17, 0.04, _mat(Color("1a1a1a"), 0.4), Vector3(0, 0.24, 0.02), Vector3(8, 0, -4))
	elif hat == "beanie":
		_sphere(head, 0.2, _mat(Color("6b2d3c")), Vector3(0, 0.18, 0.02), Vector3(1.15, 0.7, 1.05))
	elif hat == "bow":
		_sphere(head, 0.07, _mat(Color("e8a8b4")), Vector3(-0.08, 0.24, -0.04))
		_sphere(head, 0.07, _mat(Color("e8a8b4")), Vector3(0.08, 0.24, -0.04))


func _build_accessory(head: Node3D) -> void:
	var acc := str(recipe.get("accessory", "none"))
	if acc == "glasses":
		_torus(head, 0.07, 0.01, Vector3(-0.08, 0.02, -0.21))
		_torus(head, 0.07, 0.01, Vector3(0.08, 0.02, -0.21))
		_mesh(head, _box(Vector3(0.05, 0.01, 0.01)), _mat(Color("1a1a1a"), 0.3), Vector3(0, 0.02, -0.21))
	elif acc == "flower":
		_sphere(head, 0.05, _mat(Color("e8942a")), Vector3(0.22, 0.16, -0.04))
	elif acc == "scarf":
		_cyl(head, 0.16, 0.16, 0.05, _mat(Color("e8b4b8")), Vector3(0, -0.22, 0.0))


func _torus(parent: Node3D, r: float, t: float, pos: Vector3) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = r - t
	mesh.outer_radius = r + t
	mesh.rings = 12
	mesh.ring_segments = 10
	_mesh(parent, mesh, _mat(Color("1a1a1a"), 0.3), pos, Vector3(90, 0, 0))
