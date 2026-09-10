extends Object
class_name ImportedModels
## Optional GLB drop-ins. Placeholder stubs (root name PLACEHOLDER_*) are ignored.

const GIRL := "res://assets/models/sunshine_logo_girl.glb"
const EXTERIOR := "res://assets/models/sunshine_shop_exterior.glb"
const BACKYARD := "res://assets/models/sunshine_backyard.glb"
const INTERIOR := "res://assets/models/sunshine_interior.glb"


static func path_exists(path: String) -> bool:
	return ResourceLoader.exists(path)


static func is_placeholder(node: Node) -> bool:
	return str(node.name).begins_with("PLACEHOLDER")


static func instantiate_if_real(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed: Resource = load(path)
	if packed == null or not (packed is PackedScene):
		return null
	var inst: Node = (packed as PackedScene).instantiate()
	if inst == null:
		return null
	if is_placeholder(inst):
		inst.free()
		return null
	if inst is Node3D:
		return inst as Node3D
	var wrap := Node3D.new()
	wrap.name = inst.name
	wrap.add_child(inst)
	return wrap


static func attach(parent: Node3D, path: String, pos: Vector3 = Vector3.ZERO, rot_y: float = 0.0) -> bool:
	var node := instantiate_if_real(path)
	if node == null:
		return false
	node.position = pos
	node.rotation.y = rot_y
	parent.add_child(node)
	return true
