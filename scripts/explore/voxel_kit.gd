extends Object
class_name VoxelKit
## Shared Minecraft-like cubes. Not a voxel engine — MeshInstance3D boxes only.

static func flat(c: Color, unshaded: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.metallic = 0.0
	m.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


static func tex(path: String, color: Color = Color.WHITE) -> StandardMaterial3D:
	var m := flat(color, false)
	if path != "" and ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


static func add_box(
	parent: Node3D,
	size: Vector3,
	pos: Vector3,
	mat: Material,
	collide: bool = true,
	rot_y: float = 0.0
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
	parent.add_child(mesh_i)
	return mesh_i


static func add_sign(parent: Node3D, text: String, pos: Vector3, font_size: int, color: Color, rot_y_deg: float = 180.0) -> Label3D:
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = font_size
	lab.modulate = color
	lab.outline_size = 6
	lab.outline_modulate = Color("1a1410")
	lab.position = pos
	lab.rotation_degrees.y = rot_y_deg
	parent.add_child(lab)
	return lab
