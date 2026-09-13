extends Node3D
## Orbiting Minecraft-village backdrop for the main menu.

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


func _oak(size: Vector3, pos: Vector3, color: Color = Color("c4a06a")) -> void:
	VoxelKit.add_box(self, size, pos, VoxelKit.flat(color), false)


func _build() -> void:
	var env := WorldEnvironment.new()
	var we := Environment.new()
	we.background_mode = Environment.BG_COLOR
	we.background_color = Color("7ec4ee")
	we.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.ambient_light_color = Color("c8d8a8")
	we.ambient_light_energy = 0.4
	env.environment = we
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_color = Color("fff1c8")
	sun.light_energy = 1.05
	add_child(sun)

	var grass := Color("3f8f28")
	var dirt := Color("7a4a22")
	var oak := Color("8b6234")
	var roof := Color("5a3214")
	var leaf := Color("2d5a22")
	var wine := Color("6b2d3c")

	_oak(Vector3(24, 0.55, 24), Vector3(0, -0.28, 1.0), grass)
	_oak(Vector3(2.2, 0.12, 14), Vector3(0, 0.06, 0.4), dirt)
	_oak(Vector3(12, 0.12, 2.2), Vector3(0, 0.06, 0.5), dirt)
	# Solid cottages (full boxes, not paper-thin fronts).
	_oak(Vector3(4.0, 2.5, 3.4), Vector3(-5.2, 1.25, 2.6), oak)
	_oak(Vector3(4.6, 0.38, 3.8), Vector3(-5.2, 2.65, 2.6), roof)
	_oak(Vector3(3.8, 2.4, 3.2), Vector3(5.1, 1.2, 2.3), oak)
	_oak(Vector3(4.4, 0.38, 3.6), Vector3(5.1, 2.55, 2.3), roof)
	_oak(Vector3(4.6, 2.7, 3.6), Vector3(0.0, 1.35, 3.4), oak)
	_oak(Vector3(5.2, 0.4, 4.0), Vector3(0.0, 2.85, 3.4), roof)
	_oak(Vector3(1.05, 1.8, 0.12), Vector3(0, 0.95, 1.55), wine)
	VoxelKit.add_box(self, Vector3(0.8, 0.8, 0.14), Vector3(0, 2.55, 1.52), VoxelKit.tex(LOGO), false)
	# Well + tree + villager
	_oak(Vector3(1.4, 0.4, 1.4), Vector3(2.2, 0.28, -0.8), Color("6e6a64"))
	_oak(Vector3(0.85, 0.45, 0.85), Vector3(2.2, 0.38, -0.8), Color("2a6a96"))
	_oak(Vector3(0.4, 1.3, 0.4), Vector3(-3.8, 0.65, -1.4), Color("3a2416"))
	_oak(Vector3(1.6, 1.6, 1.6), Vector3(-3.8, 1.85, -1.4), leaf)
	_oak(Vector3(0.34, 0.7, 0.22), Vector3(-1.4, 0.52, -0.2), Color("8b5a2b"))
	_oak(Vector3(0.28, 0.28, 0.28), Vector3(-1.4, 1.0, -0.2), Color("e6c8a0"))

	_pivot = Node3D.new()
	add_child(_pivot)
	_cam = Camera3D.new()
	_cam.position = Vector3(1.2, 6.4, -12.4)
	_cam.current = true
	_cam.fov = 46
	_pivot.add_child(_cam)
	_cam.look_at(Vector3(0, 1.2, 1.2), Vector3.UP)
