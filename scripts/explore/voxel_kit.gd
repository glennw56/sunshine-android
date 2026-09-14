extends Object
class_name VoxelKit
## Shared Minecraft-like cubes. Not a voxel engine — MeshInstance3D boxes only.

static var _cache: Dictionary = {}


static func flat(c: Color, unshaded: bool = false, emission: float = 0.0) -> StandardMaterial3D:
	var key := "flat|%s|%s|%.2f" % [c, unshaded, emission]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.88
	m.metallic = 0.0
	m.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	)
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_cache[key] = m
	return m


static func accent(c: Color, _glow: float = 0.22) -> StandardMaterial3D:
	# Unshaded so blush/orange stay punchy on gl_compatibility (no muddy PBR).
	return flat(c, true, 0.0)


static func tex(
	path: String,
	color: Color = Color.WHITE,
	uv_scale: float = 1.0,
	nearest: bool = false,
	roughness: float = 0.9
) -> StandardMaterial3D:
	var key := "tex|%s|%s|%.2f|%s|%.2f" % [path, color, uv_scale, nearest, roughness]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = 0.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if path != "" and ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	m.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	m.texture_filter = (
		BaseMaterial3D.TEXTURE_FILTER_NEAREST
		if nearest
		else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	)
	_cache[key] = m
	return m


static func glass(color: Color, dark: bool = false) -> StandardMaterial3D:
	var key := "glass|%s|%s" % [color, dark]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, 0.72 if dark else 0.48)
	m.metallic = 0.28
	m.roughness = 0.1
	m.rim_enabled = true
	m.rim = 0.4
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_cache[key] = m
	return m


static func add_box(
	parent: Node3D,
	size: Vector3,
	pos: Vector3,
	mat: Material,
	collide: bool = true,
	rot_y: float = 0.0,
	rot_x: float = 0.0
) -> Node3D:
	var mesh_i := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_i.mesh = box
	mesh_i.material_override = mat
	if collide:
		var body := StaticBody3D.new()
		body.position = pos
		body.rotation.y = rot_y
		body.rotation.x = rot_x
		body.collision_layer = 1
		body.collision_mask = 0
		body.add_child(mesh_i)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		parent.add_child(body)
		return body
	mesh_i.position = pos
	mesh_i.rotation.y = rot_y
	mesh_i.rotation.x = rot_x
	parent.add_child(mesh_i)
	return mesh_i


static func add_collider(parent: Node3D, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	return body


static func add_sign(
	parent: Node3D,
	text: String,
	pos: Vector3,
	font_size: int,
	color: Color,
	rot_y_deg: float = 180.0,
	pixel_size: float = 0.005
) -> Label3D:
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = font_size
	lab.pixel_size = pixel_size
	lab.modulate = color
	lab.outline_size = 8
	lab.outline_modulate = Color("1a1410")
	lab.position = pos
	lab.rotation_degrees.y = rot_y_deg
	lab.shaded = false
	lab.double_sided = true
	parent.add_child(lab)
	return lab
