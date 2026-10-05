extends Node3D
class_name PumpkinBin
## Pickup pile beside the practice lane. Walk up and take one pumpkin.

const PumpkinProp := preload("res://scripts/explore/pumpkin_prop.gd")
const CutePackLib := preload("res://scripts/explore/cute_pack.gd")

const PICKUP_RADIUS := 2.15


func build(at: Vector3) -> void:
	name = "PumpkinBin"
	position = at
	add_to_group("pumpkin_bin")
	CutePackLib.add_mesh(self, CutePackLib.cyl(0.62, 0.7, 0.28, 14), Color("c49a62"), Vector3(0, 0.16, 0))
	CutePackLib.add_mesh(self, CutePackLib.cyl(0.66, 0.58, 0.08, 14), Color("8a5a32"), Vector3(0, 0.32, 0))
	var a := PumpkinProp.instantiate()
	a.position = Vector3(-0.12, 0.28, 0.02)
	a.scale = Vector3(0.85, 0.85, 0.85)
	add_child(a)
	var b := PumpkinProp.instantiate()
	b.position = Vector3(0.16, 0.30, -0.06)
	b.scale = Vector3(0.72, 0.72, 0.72)
	add_child(b)
	var sign := Label3D.new()
	sign.text = "Pumpkins"
	sign.font_size = 48
	sign.pixel_size = 0.004
	sign.position = Vector3(0, 0.95, 0)
	sign.modulate = Color("722F37")
	sign.outline_size = 8
	sign.outline_modulate = Color("FFF8F0")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)
	CutePackLib.collider(self, Vector3(1.35, 0.55, 1.35), Vector3(0, 0.28, 0))


func contains_point(world: Vector3) -> bool:
	var flat := world - global_position
	flat.y = 0.0
	return flat.length() <= PICKUP_RADIUS
