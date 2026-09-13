extends Node3D
## Orbiting Irondale-patio backdrop for the main menu.

const VoxelKit := preload("res://scripts/explore/voxel_kit.gd")
const LOGO := "res://assets/branding/sunshine-logo-girl.jpg"

var _cam: Camera3D
var _pivot: Node3D
var _t: float = 0.0


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	_t += delta * 0.16
	if _pivot:
		_pivot.rotation.y = _t
	if _cam:
		_cam.look_at(Vector3(0, 1.3, 0.4), Vector3.UP)


func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	VoxelKit.add_box(self, size, pos, VoxelKit.flat(color), false)


func _build() -> void:
	var env := WorldEnvironment.new()
	var we := Environment.new()
	we.background_mode = Environment.BG_COLOR
	we.background_color = Color("87c8f0")
	we.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.ambient_light_color = Color("d0e0b8")
	we.ambient_light_energy = 0.4
	env.environment = we
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_color = Color("fff1c8")
	sun.light_energy = 1.05
	add_child(sun)

	var grass := Color("4a9a32")
	var white := Color("f3f0ea")
	var pink := Color("e8b4b8")
	var wine := Color("6b2d3c")
	var deck := Color("e4d3a4")
	var yellow := Color("e8d070")
	var green := Color("7ed45a")
	var leaf := Color("2f6a28")

	_box(Vector3(24, 0.55, 24), Vector3(0, -0.28, 1.0), grass)
	_box(Vector3(2.2, 0.12, 14), Vector3(0, 0.06, 0.4), Color("d5d1c8"))
	_box(Vector3(12, 0.12, 2.2), Vector3(0, 0.06, 0.5), Color("d5d1c8"))
	# White bakery + pink soffit.
	_box(Vector3(4.6, 2.7, 3.6), Vector3(0.0, 1.35, 3.4), white)
	_box(Vector3(5.2, 0.18, 4.0), Vector3(0.0, 2.78, 3.4), pink)
	_box(Vector3(5.0, 0.28, 3.8), Vector3(0.0, 3.02, 3.4), white)
	_box(Vector3(1.05, 1.8, 0.12), Vector3(0, 0.95, 1.55), wine)
	VoxelKit.add_box(self, Vector3(0.7, 0.7, 0.14), Vector3(0, 2.55, 1.52), VoxelKit.tex(LOGO), false)
	# Green cottage + tan deck + green roof.
	_box(Vector3(3.2, 2.2, 2.8), Vector3(5.4, 1.1, 2.0), Color("8fbf6a"))
	_box(Vector3(4.6, 0.16, 4.2), Vector3(3.6, 1.15, 0.2), deck)
	_box(Vector3(4.2, 0.22, 3.8), Vector3(3.6, 2.55, 0.2), green)
	_box(Vector3(0.16, 1.1, 3.4), Vector3(5.6, 1.7, 0.2), yellow)
	# Mailbox + tree + picnic.
	_box(Vector3(0.35, 1.05, 0.28), Vector3(-3.6, 0.55, -1.2), Color("1c1c1e"))
	_box(Vector3(0.62, 0.42, 0.4), Vector3(-3.6, 1.2, -1.2), Color("1c1c1e"))
	_box(Vector3(0.4, 1.3, 0.4), Vector3(-5.0, 0.65, 0.6), Color("3a2416"))
	_box(Vector3(1.6, 1.6, 1.6), Vector3(-5.0, 1.85, 0.6), leaf)
	_box(Vector3(1.5, 0.08, 0.7), Vector3(-1.6, 0.7, -0.4), Color("c8c4bc"))

	_pivot = Node3D.new()
	add_child(_pivot)
	_cam = Camera3D.new()
	_cam.position = Vector3(1.2, 6.4, -12.4)
	_cam.current = true
	_cam.fov = 46
	_pivot.add_child(_cam)
	_cam.look_at(Vector3(0, 1.2, 1.2), Vector3.UP)
