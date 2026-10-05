extends Object
class_name PumpkinProp
## Toss pumpkin, 0.40 m tall, origin on the bottom (HandSocket and ground).
## Drop res://assets/explore/prop_pumpkin_toss.glb to replace this stand-in.
## Expected GLB: 0.35–0.45 m, origin at the bottom, modest tris.

const GLB_PATH := "res://assets/explore/prop_pumpkin_toss.glb"
const HEIGHT := 0.40


static func instantiate() -> Node3D:
	if ResourceLoader.exists(GLB_PATH):
		var packed := load(GLB_PATH) as PackedScene
		if packed != null:
			var node := packed.instantiate() as Node3D
			if node != null:
				node.name = "PropPumpkin"
				return node
	return procedural()


static func procedural() -> Node3D:
	var root := Node3D.new()
	root.name = "PropPumpkin"
	var body := MeshInstance3D.new()
	body.name = "Body"
	var ball := SphereMesh.new()
	ball.radius = 0.18
	ball.height = 0.36
	ball.radial_segments = 16
	ball.rings = 10
	body.mesh = ball
	body.position = Vector3(0, 0.18, 0)
	body.scale = Vector3(1.08, 0.92, 1.0)
	body.material_override = _mat(Color("e07a32"))
	root.add_child(body)
	var rib := MeshInstance3D.new()
	rib.name = "Rib"
	var band := CylinderMesh.new()
	band.top_radius = 0.155
	band.bottom_radius = 0.155
	band.height = 0.30
	band.radial_segments = 12
	rib.mesh = band
	rib.position = Vector3(0, 0.18, 0)
	rib.scale = Vector3(0.55, 1.0, 1.05)
	rib.material_override = _mat(Color("d26522"))
	root.add_child(rib)
	var stem := MeshInstance3D.new()
	stem.name = "Stem"
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.028
	stalk.bottom_radius = 0.04
	stalk.height = 0.09
	stalk.radial_segments = 8
	stem.mesh = stalk
	stem.position = Vector3(0, 0.38, 0)
	stem.material_override = _mat(Color("3d6b32"))
	root.add_child(stem)
	var accent := MeshInstance3D.new()
	accent.name = "BlushCheek"
	var dot := SphereMesh.new()
	dot.radius = 0.035
	dot.height = 0.07
	dot.radial_segments = 8
	dot.rings = 6
	accent.mesh = dot
	accent.position = Vector3(0.08, 0.22, 0.12)
	accent.material_override = _mat(Color("e8b4b8"))
	root.add_child(accent)
	return root


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.72
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
