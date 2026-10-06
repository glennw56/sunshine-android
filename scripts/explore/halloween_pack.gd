extends Object
class_name HalloweenPack
## Three modest Halloween pockets for the test world only.
## Blush #e8b4b8, wine #722F37, cream #FFF8F0. No fog, graves, or full recolor.

const CutePackLib := preload("res://scripts/explore/cute_pack.gd")
const BLUSH := Color("e8b4b8")
const WINE := Color("722F37")
const CREAM := Color("FFF8F0")
const HAY := Color("e2c27a")
const HAY_DK := Color("c9a15a")
const PUMPKIN := Color("e07a32")
const PUMPKIN_DK := Color("c45e1c")
const LANTERN := Color("f2c14e")
const WOOD := Color("c49a62")
const WOOD_DK := Color("8a5a32")
const NORTH_GLB := "res://assets/explore/halloween/HW_NorthLawn.glb"
const WEST_GLB := "res://assets/explore/halloween/HW_WestCorner.glb"
const DISCO_GLB := "res://assets/explore/halloween/HW_DiscoFringe.glb"


static func dress(parent: Node3D, island: AABB) -> void:
	if not _place_glb(parent, NORTH_GLB, "HW_NorthLawn", Vector3(-14.0, 0.0, -32.0)):
		_north_lawn(parent)
	else:
		CutePackLib.collider(parent.get_node("HW_NorthLawn"), Vector3(4.4, 1.05, 4.4), Vector3(0, 0.52, 0))
	if not _place_glb(parent, WEST_GLB, "HW_WestCorner", _west_anchor(island)):
		_west_corner(parent, island)
	else:
		CutePackLib.collider(parent.get_node("HW_WestCorner"), Vector3(1.2, 0.8, 1.2), Vector3(0, 0.4, 0))
	if not _place_glb(parent, DISCO_GLB, "HW_DiscoFringe", Vector3(2.3, 0.0, -4.7)):
		_disco_fringe(parent)


static func _place_glb(parent: Node3D, path: String, node_name: String, pos: Vector3) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	var node := packed.instantiate() as Node3D
	if node == null:
		return false
	node.name = node_name
	node.position = pos
	parent.add_child(node)
	return true


static func _west_anchor(island: AABB) -> Vector3:
	var x := -8.0
	var z := 4.5
	if island.size.x > 4.0:
		x = island.position.x + 1.55
		z = island.get_center().z + island.size.z * 0.22
	return Vector3(x, 0.0, z)


static func _north_lawn(parent: Node3D) -> void:
	## Hay, pumpkins, and lanterns on the north lawn (z −25…−40).
	## Offset from the market stalls at x ±6.5, z −38.
	var root := Node3D.new()
	root.name = "HW_NorthLawn"
	parent.add_child(root)
	var spots: Array[Vector3] = [
		Vector3(-16.0, 0.0, -28.0),
		Vector3(-12.5, 0.0, -33.5),
		Vector3(13.5, 0.0, -30.0),
		Vector3(17.0, 0.0, -36.0),
	]
	for i in spots.size():
		var at: Vector3 = spots[i]
		_hay(root, at + Vector3(-0.7, 0.0, 0.2), 0.4 if i % 2 == 0 else -0.2)
		_pumpkin(root, at + Vector3(0.85, 0.0, -0.35), 0.34 + float(i % 2) * 0.06)
		if i % 2 == 0:
			_lantern(root, at + Vector3(0.1, 0.0, 0.85))
	CutePackLib.collider(root, Vector3(3.2, 0.7, 1.6), Vector3(-14.2, 0.35, -30.5))
	CutePackLib.collider(root, Vector3(3.2, 0.7, 1.6), Vector3(15.2, 0.35, -33.0))


static func _west_corner(parent: Node3D, island: AABB) -> void:
	## Crate, candy bowl, and one standing pumpkin on the west side of the deck.
	## South of center so the logo wall (north / −Z) stays clear.
	var root := Node3D.new()
	root.name = "HW_WestCorner"
	var x := -8.0
	var z := 4.5
	if island.size.x > 4.0:
		x = island.position.x + 1.55
		z = island.get_center().z + island.size.z * 0.22
	root.position = Vector3(x, 0.0, z)
	parent.add_child(root)
	_crate(root, Vector3(0.0, 0.0, 0.0))
	_candy_bowl(root, Vector3(0.95, 0.0, 0.35))
	_pumpkin(root, Vector3(0.15, 0.0, 1.15), 0.58)
	CutePackLib.collider(root, Vector3(1.3, 0.7, 0.9), Vector3(0.05, 0.35, 0.05))
	CutePackLib.collider(root, Vector3(0.7, 0.7, 0.7), Vector3(0.15, 0.35, 1.15))


static func _disco_fringe(parent: Node3D) -> void:
	## Two jack-o'-lanterns only. No cobweb, fog, or extra lights on the disco.
	var root := Node3D.new()
	root.name = "HW_DiscoFringe"
	parent.add_child(root)
	_jack(root, Vector3(3.15, 0.0, -5.35))
	_jack(root, Vector3(-3.05, 0.0, -4.85))


static func _hay(parent: Node3D, pos: Vector3, yaw: float) -> void:
	CutePackLib.add_mesh(parent, CutePackLib.cyl(0.55, 0.55, 0.38, 12), HAY, pos + Vector3(0, 0.2, 0), Vector3(0, yaw, 1.5708))
	CutePackLib.add_mesh(parent, CutePackLib.cyl(0.42, 0.42, 0.32, 12), HAY_DK, pos + Vector3(0.15, 0.42, 0.05), Vector3(0.2, yaw, 1.5708))


static func _pumpkin(parent: Node3D, pos: Vector3, height: float) -> void:
	var r := height * 0.46
	CutePackLib.add_mesh(parent, CutePackLib.ball(r, 12), PUMPKIN, pos + Vector3(0, height * 0.46, 0), Vector3.ZERO, Vector3(1.05, 0.86, 1.0))
	CutePackLib.add_mesh(parent, CutePackLib.cyl(0.035, 0.05, 0.12, 8), Color("3d6b32"), pos + Vector3(0, height * 0.88, 0))
	CutePackLib.add_mesh(parent, CutePackLib.ball(0.045, 8), BLUSH, pos + Vector3(0.12, height * 0.55, 0.16))


static func _lantern(parent: Node3D, pos: Vector3) -> void:
	CutePackLib.add_mesh(parent, CutePackLib.cyl(0.04, 0.05, 0.55, 8), WOOD_DK, pos + Vector3(0, 0.28, 0))
	var glow := CutePackLib.ball(0.16, 10)
	var mi := CutePackLib.add_mesh(parent, glow, LANTERN, pos + Vector3(0, 0.62, 0))
	var mat := mi.material_override as StandardMaterial3D
	if mat:
		mat.emission_enabled = true
		mat.emission = LANTERN
		mat.emission_energy_multiplier = 0.35
	CutePackLib.add_mesh(parent, CutePackLib.cyl(0.1, 0.12, 0.06, 8), WINE, pos + Vector3(0, 0.78, 0))


static func _crate(parent: Node3D, pos: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.72, 0.42, 0.56)
	CutePackLib.add_mesh(parent, box, WOOD, pos + Vector3(0, 0.24, 0))
	CutePackLib.add_mesh(parent, CutePackLib.cyl(0.02, 0.02, 0.74, 6), WOOD_DK, pos + Vector3(0, 0.36, 0.22), Vector3(0, 0, 1.5708))
	CutePackLib.add_mesh(parent, CutePackLib.cyl(0.02, 0.02, 0.74, 6), WOOD_DK, pos + Vector3(0, 0.36, -0.22), Vector3(0, 0, 1.5708))


static func _candy_bowl(parent: Node3D, pos: Vector3) -> void:
	CutePackLib.add_mesh(parent, CutePackLib.cyl(0.22, 0.16, 0.16, 12), CREAM, pos + Vector3(0, 0.16, 0))
	CutePackLib.add_mesh(parent, CutePackLib.ball(0.07, 8), BLUSH, pos + Vector3(-0.06, 0.26, 0.02))
	CutePackLib.add_mesh(parent, CutePackLib.ball(0.06, 8), WINE, pos + Vector3(0.07, 0.25, -0.02))
	CutePackLib.add_mesh(parent, CutePackLib.ball(0.055, 8), Color("e0b04a"), pos + Vector3(0.0, 0.28, 0.06))


static func _jack(parent: Node3D, pos: Vector3) -> void:
	_pumpkin(parent, pos, 0.4)
	CutePackLib.add_mesh(parent, CutePackLib.ball(0.035, 8), Color("2a140c"), pos + Vector3(-0.08, 0.28, 0.16))
	CutePackLib.add_mesh(parent, CutePackLib.ball(0.035, 8), Color("2a140c"), pos + Vector3(0.08, 0.28, 0.16))
	var glow := CutePackLib.add_mesh(parent, CutePackLib.ball(0.05, 8), LANTERN, pos + Vector3(0.0, 0.2, 0.18))
	var mat := glow.material_override as StandardMaterial3D
	if mat:
		mat.emission_enabled = true
		mat.emission = LANTERN
		mat.emission_energy_multiplier = 0.25
