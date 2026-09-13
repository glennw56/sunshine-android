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

	_oak(Vector3(22, 0.55, 22), Vector3(0, -0.28, 0.6), grass)
	_oak(Vector3(2.0, 0.1, 12), Vector3(0, 0.04, 0.2), dirt)
	_oak(Vector3(10, 0.1, 2.0), Vector3(0, 0.04, 0.4), dirt)
	# Three village houses
	_oak(Vector3(4.2, 2.6, 0.4), Vector3(-5.4, 1.3, 2.2), oak)
	_oak(Vector3(4.6, 0.3, 3.4), Vector3(-5.4, 2.75, 2.6), roof)
	_oak(Vector3(4.2, 2.8, 0.4), Vector3(5.2, 1.4, 2.0), oak)
	_oak(Vector3(4.6, 0.3, 3.4), Vector3(5.2, 2.95, 2.4), roof)
	_oak(Vector3(5.0, 2.9, 0.45), Vector3(0.0, 1.45, 2.5), oak)
	_oak(Vector3(5.4, 0.32, 3.6), Vector3(0.0, 3.05, 2.9), roof)
	_oak(Vector3(1.4, 1.7, 0.12), Vector3(0, 0.9, 2.24), wine)
	VoxelKit.add_box(self, Vector3(0.85, 0.85, 0.14), Vector3(0, 2.7, 2.28), VoxelKit.tex(LOGO), false)
	# Well + tree + villager boxes
	_oak(Vector3(1.3, 0.35, 1.3), Vector3(2.6, 0.25, -1.2), Color("8a8580"))
	_oak(Vector3(0.8, 0.4, 0.8), Vector3(2.6, 0.35, -1.2), Color("3a7ca5"))
	_oak(Vector3(0.35, 1.1, 0.35), Vector3(-4.2, 0.55, -1.8), Color("4a3424"))
	_oak(Vector3(1.5, 1.5, 1.5), Vector3(-4.2, 1.7, -1.8), leaf)
	_oak(Vector3(0.32, 0.65, 0.22), Vector3(-1.6, 0.5, -0.6), Color("8b5a2b"))
	_oak(Vector3(0.28, 0.28, 0.28), Vector3(-1.6, 0.95, -0.6), Color("e6c8a0"))

	_pivot = Node3D.new()
	add_child(_pivot)
	_cam = Camera3D.new()
	_cam.position = Vector3(8.8, 5.4, -10.2)
	_cam.current = true
	_cam.fov = 48
	_pivot.add_child(_cam)
	_cam.look_at(Vector3(0, 1.3, 0.4), Vector3.UP)
