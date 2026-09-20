extends Node3D
class_name AvatarBody
## Rounded chibi from an approved avatar recipe. No cubes as the body.

const CosContracts := preload("res://scripts/contracts/cos_contracts.gd")

var recipe: Dictionary = {}
var _hand: Node3D
var _head: Node3D


func _ready() -> void:
	rebuild(ProfileStore.current_avatar())


func rebuild(raw: Dictionary) -> void:
	recipe = CosContracts.sanitize_avatar(raw)
	for child in get_children():
		child.queue_free()
	_hand = null
	_head = null
	_build()


func hand_socket() -> Node3D:
	return _hand


func head_node() -> Node3D:
	return _head


func _mat(c: Color, rough := 0.58) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
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
	add_child(root)
	_cap(root, 0.16, 0.62, outfit, Vector3(0, 0.62, 0))
	_sphere(root, 0.2, outfit, Vector3(0, 0.92, 0), Vector3(1.15, 0.7, 0.95))
	var apron := str(recipe.get("apron", "none"))
	if apron != "none":
		var apron_col := Color("c5c0be")
		if apron == "blush":
			apron_col = Color("e8b4b8")
		elif apron == "wine":
			apron_col = Color("6b2d3c")
		_mesh(root, _box(Vector3(0.28, 0.28, 0.04)), _mat(apron_col, 0.7), Vector3(0, 0.62, 0.14))
	_cap(root, 0.055, 0.36, outfit, Vector3(-0.22, 0.78, 0.02), Vector3(0, 0, 18))
	_cap(root, 0.055, 0.36, outfit, Vector3(0.22, 0.78, 0.02), Vector3(0, 0, -18))
	_hand = Node3D.new()
	_hand.name = "HandSocket"
	_hand.position = Vector3(0.28, 0.72, -0.08)
	root.add_child(_hand)
	_cap(root, 0.06, 0.4, skin, Vector3(-0.08, 0.26, 0.02))
	_cap(root, 0.06, 0.4, skin, Vector3(0.08, 0.26, 0.02))
	_sphere(root, 0.07, _mat(Color("2a1c18")), Vector3(-0.08, 0.08, 0.04))
	_sphere(root, 0.07, _mat(Color("2a1c18")), Vector3(0.08, 0.08, 0.04))
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 1.22, 0)
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
	var plate := Label3D.new()
	plate.name = "Nameplate"
	plate.text = ProfileStore.display_name if ProfileStore.display_name != "" else "Sunshine Guest"
	plate.font_size = 28
	plate.outline_size = 6
	plate.position = Vector3(0, 1.72, 0)
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.modulate = Color("fff6ea")
	plate.outline_modulate = Color("4a1c28")
	add_child(plate)


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
