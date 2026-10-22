extends Node3D
## Festive lawn on the test-world grass. Hats sit on the cookie plate.
## They are not parented to the baker.

const Look := preload("res://scripts/explore/authored_look.gd")
const ROOT := "res://assets/christmas/"

const PLACE := Vector3(86.0, 0.0, -46.0)


func _ready() -> void:
	name = "ChristmasYard"
	position = PLACE
	add_to_group("christmas_yard")
	_ground()
	_prop("tree_big", "TreeBig", Vector3(0, 0, 0), 0.2)
	_prop("tree_snowy", "TreeSnowy", Vector3(-4.8, 0, 1.1), 0.5)
	_prop("tree_blush", "TreeBlush", Vector3(4.6, 0, -0.8), -0.4)
	_prop("tree_potted", "TreePotted", Vector3(2.3, 0, 4.0), 0.3)
	_prop("santa", "Santa", Vector3(1.7, 0.72, 3.35), PI)
	_prop("snowman", "Snowman", Vector3(-2.5, 0, 3.15), 0.6)
	_prop("reindeer", "Reindeer", Vector3(4.0, 0, 2.7), -0.8)
	_prop("sleigh", "Sleigh", Vector3(6.0, 0, 1.2), -0.5)
	_prop("gingerbread_house", "GingerbreadHouse", Vector3(-4.2, 0, -2.4), 0.4)
	_prop("gingerbread_man", "GingerbreadMan", Vector3(-1.8, 0, 2.35), 0.2)
	_prop("gift_stack", "GiftStack", Vector3(-1.3, 0, 1.5), 0.3)
	_prop("gift_wide", "GiftWide", Vector3(1.15, 0, 1.35), -0.2)
	_prop("gift_tall", "GiftTall", Vector3(0.35, 0, 1.9), 0.5)
	_prop("gift_small", "GiftSmall", Vector3(-0.55, 0, 2.15), 1.0)
	_prop("north_pole_sign", "NorthPoleSign", Vector3(0.2, 0, 6.4), PI)
	_prop("lamp_post", "LampL", Vector3(-3.4, 0, 5.3), 0.0)
	_prop("lamp_post", "LampR", Vector3(3.5, 0, 5.3), 0.0)
	_prop("string_lights", "StringLights", Vector3(0.05, 2.55, 5.3), 0.0)
	_prop("garland", "Garland", Vector3(0.0, 2.15, 5.15), 0.0)
	_prop("wreath", "Wreath", Vector3(0.0, 2.15, 1.85), 0.0)
	_prop("candy_cane_giant", "CandyCaneGiant", Vector3(-6.0, 0, 3.4), 0.3)
	_prop("candy_cane", "CaneA", Vector3(-1.55, 0, 4.6), 0.2)
	_prop("candy_cane", "CaneB", Vector3(1.7, 0, 4.7), -0.4)
	_prop("candy_cane", "CaneC", Vector3(5.3, 0, 3.6), 0.8)
	_prop("cookie_plate", "CookiePlate", Vector3(2.7, 0, 4.55), 0.4)
	_prop("hat_santa", "HatSanta", Vector3(2.45, 0.28, 4.45), 0.6)
	_prop("hat_elf", "HatElf", Vector3(2.95, 0.22, 4.7), -0.5)
	_prop("cocoa_mug", "CocoaA", Vector3(2.55, 0.12, 4.75), 0.2)
	_prop("cocoa_mug", "CocoaB", Vector3(2.9, 0.12, 4.35), 1.1)
	_prop("stocking", "StockingL", Vector3(-0.85, 1.15, 1.55), 0.1)
	_prop("stocking", "StockingR", Vector3(0.8, 1.2, 1.45), -0.2)
	_prop("ornaments", "Ornaments", Vector3(0.1, 1.55, 2.05), 0.0)
	_prop("snow_pile", "SnowPileL", Vector3(-3.6, 0, 4.2), 0.4)
	_prop("snow_pile", "SnowPileR", Vector3(4.8, 0, 4.4), -0.6)
	_lights()
	_sign()
	_blocks()


func _ground() -> void:
	var spots: Array[Vector3] = [
		Vector3(0, 0, 0.4), Vector3(2.6, 0, 1.8), Vector3(-2.8, 0, 1.2),
		Vector3(1.0, 0, 3.6), Vector3(-1.4, 0, -1.6), Vector3(3.8, 0, -0.4),
	]
	for i in spots.size():
		_prop("snow_patch", "SnowPatch%d" % i, spots[i], float(i) * 0.4)


func _prop(folder: String, node_name: String, pos: Vector3, yaw: float) -> void:
	var path := ROOT + folder + "/" + folder + ".glb"
	if not ResourceLoader.exists(path):
		push_error("Christmas prop missing " + path)
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var node := packed.instantiate() as Node3D
	if node == null:
		return
	node.name = node_name
	node.position = pos
	node.rotation.y = yaw
	add_child(node)
	Look.apply(node)


func _lights() -> void:
	for lamp_name in ["LampL", "LampR"]:
		var lamp := find_child(lamp_name, true, false) as Node3D
		if lamp == null:
			continue
		var socket := lamp.find_child("Light", true, false) as Node3D
		var light := OmniLight3D.new()
		light.name = "YardLamp"
		light.light_color = Color("ffd2a8")
		light.light_energy = 0.7
		light.omni_range = 8.0
		light.shadow_enabled = false
		if socket:
			socket.add_child(light)
		else:
			light.position = Vector3(0, 2.6, 0)
			lamp.add_child(light)
	var glow := OmniLight3D.new()
	glow.name = "TreeGlow"
	glow.position = Vector3(0, 2.8, 0.4)
	glow.light_color = Color("ffc4d0")
	glow.light_energy = 0.55
	glow.omni_range = 11.0
	glow.shadow_enabled = false
	add_child(glow)


func _sign() -> void:
	var label := Label3D.new()
	label.name = "ChristmasSign"
	label.text = "Christmas at Sunshine's"
	label.font_size = 64
	label.pixel_size = 0.012
	label.position = Vector3(0.2, 3.15, 6.15)
	label.rotation.y = PI
	label.modulate = Color("fff6ea")
	label.outline_modulate = Color("6b2d3c")
	label.outline_size = 16
	add_child(label)


func _blocks() -> void:
	_block(Vector3(1.6, 2.2, 1.6), Vector3(0, 1.1, 0))
	_block(Vector3(0.7, 1.3, 0.6), Vector3(1.7, 0.7, 3.35))
	_block(Vector3(0.9, 1.6, 0.7), Vector3(-2.5, 0.8, 3.15))
	_block(Vector3(1.4, 1.2, 2.4), Vector3(6.0, 0.6, 1.2))
	_block(Vector3(1.1, 1.0, 1.0), Vector3(-4.2, 0.5, -2.4))
	_block(Vector3(0.5, 3.2, 0.5), Vector3(-3.4, 1.6, 5.3))
	_block(Vector3(0.5, 3.2, 0.5), Vector3(3.5, 1.6, 5.3))
	_block(Vector3(1.2, 2.2, 0.4), Vector3(0.2, 1.1, 6.4))


func _block(size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	add_child(body)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
