extends Node3D
## Tiny orbiting voxel bakery for the main-menu backdrop.

const VoxelKit := preload("res://scripts/explore/voxel_kit.gd")
const LOGO := "res://assets/branding/sunshine-logo-girl.jpg"

var _cam: Camera3D
var _pivot: Node3D
var _t: float = 0.0


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	_t += delta * 0.18
	if _pivot:
		_pivot.rotation.y = _t
	if _cam:
		_cam.look_at(Vector3(0, 1.4, 0), Vector3.UP)


func _build() -> void:
	var env := WorldEnvironment.new()
	var we := Environment.new()
	we.background_mode = Environment.BG_COLOR
	we.background_color = Color("7ec4ee")
	we.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.ambient_light_color = Color("fff1dc")
	we.ambient_light_energy = 0.85
	env.environment = we
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_color = Color("fff1c8")
	sun.light_energy = 1.15
	add_child(sun)

	var grass := VoxelKit.flat(Color("5a9e3a"))
	var dirt := VoxelKit.flat(Color("8a5a32"))
	var cream := VoxelKit.flat(Color("f4f2ee"))
	var blush := VoxelKit.flat(Color("e8b4b8"))
	var wine := VoxelKit.flat(Color("6b2d3c"))
	var wood := VoxelKit.flat(Color("c4a06a"))
	var gold := VoxelKit.flat(Color("e0b04a"))
	var orange := VoxelKit.flat(Color("e07a45"))
	var leaf := VoxelKit.flat(Color("3f6b32"))

	VoxelKit.add_box(self, Vector3(18, 0.6, 18), Vector3(0, -0.3, 0.4), grass)
	VoxelKit.add_box(self, Vector3(18, 0.35, 18), Vector3(0, -0.72, 0.4), dirt, false)
	# Mini shop: cream cubes + blush trim + wine door frame.
	VoxelKit.add_box(self, Vector3(5.2, 3.2, 0.55), Vector3(-1.7, 1.6, 1.6), cream)
	VoxelKit.add_box(self, Vector3(5.2, 3.2, 0.55), Vector3(1.7, 1.6, 1.6), cream)
	VoxelKit.add_box(self, Vector3(2.0, 1.05, 0.55), Vector3(0, 2.65, 1.6), cream)
	VoxelKit.add_box(self, Vector3(8.6, 0.35, 0.7), Vector3(0, 3.35, 1.55), blush)
	VoxelKit.add_box(self, Vector3(0.35, 3.2, 0.7), Vector3(-4.3, 1.6, 1.55), blush)
	VoxelKit.add_box(self, Vector3(0.35, 3.2, 0.7), Vector3(4.3, 1.6, 1.55), blush)
	VoxelKit.add_box(self, Vector3(2.15, 2.15, 0.2), Vector3(0, 1.15, 1.28), wine)
	VoxelKit.add_box(self, Vector3(5.4, 0.7, 0.35), Vector3(0, 2.55, 1.22), orange)
	VoxelKit.add_sign(self, "SUNSHINE'S", Vector3(0, 2.55, 1.0), 48, Color("1a1410"), 180)
	var logo := VoxelKit.add_box(self, Vector3(1.15, 1.15, 0.18), Vector3(0, 4.15, 1.35), VoxelKit.tex(LOGO), false)
	logo.rotation_degrees.x = 0
	# Counter + pastry cubes
	VoxelKit.add_box(self, Vector3(2.4, 0.85, 0.85), Vector3(0.2, 0.5, 0.15), wood, false)
	VoxelKit.add_box(self, Vector3(0.32, 0.32, 0.32), Vector3(-0.45, 1.08, 0.1), gold, false)
	VoxelKit.add_box(self, Vector3(0.32, 0.32, 0.32), Vector3(0.15, 1.08, 0.1), blush, false)
	VoxelKit.add_box(self, Vector3(0.32, 0.32, 0.32), Vector3(0.75, 1.08, 0.1), VoxelKit.flat(Color("f3d9a8")), false)
	# Yard cubes + block tree
	VoxelKit.add_box(self, Vector3(1.8, 0.18, 0.8), Vector3(3.4, 0.55, -2.2), wood, false)
	VoxelKit.add_box(self, Vector3(0.35, 1.1, 0.35), Vector3(-4.6, 0.55, -1.6), VoxelKit.flat(Color("4a3424")), false)
	VoxelKit.add_box(self, Vector3(1.4, 1.4, 1.4), Vector3(-4.6, 1.7, -1.6), leaf, false)

	_pivot = Node3D.new()
	add_child(_pivot)
	_cam = Camera3D.new()
	_cam.position = Vector3(6.4, 4.2, -7.2)
	_cam.current = true
	_cam.fov = 52
	_pivot.add_child(_cam)
	_cam.look_at(Vector3(0, 1.4, 0), Vector3.UP)
