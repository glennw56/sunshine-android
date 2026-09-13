extends Node3D
class_name ReviewCameras
## Fixed Camera3D markers for screenshot feedback. Never current during play
## unless tools/capture_review.gd activates them.
## Names: Entrance, Counter, Dining, LeftCorner, RightCorner, SunshineCloseup, PastryCase, Exterior.

const SHOT_NAMES: PackedStringArray = [
	"Entrance",
	"Counter",
	"Dining",
	"LeftCorner",
	"RightCorner",
	"SunshineCloseup",
	"PastryCase",
	"Exterior",
]


func _ready() -> void:
	_ensure_cameras()


func _ensure_cameras() -> void:
	var shots: Array[Dictionary] = [
		{"name": "Entrance", "pos": Vector3(0.0, 1.75, -6.4), "look": Vector3(0.2, 1.4, -0.4), "fov": 70.0},
		{"name": "Counter", "pos": Vector3(0.15, 1.55, 1.7), "look": Vector3(0.1, 1.2, 4.4), "fov": 60.0},
		{"name": "Dining", "pos": Vector3(-1.4, 1.85, -5.8), "look": Vector3(2.0, 1.1, -1.6), "fov": 64.0},
		{"name": "LeftCorner", "pos": Vector3(-9.4, 2.5, -0.2), "look": Vector3(-5.0, 1.7, -2.2), "fov": 60.0},
		{"name": "RightCorner", "pos": Vector3(9.6, 2.5, 0.2), "look": Vector3(5.1, 1.7, -1.8), "fov": 60.0},
		{"name": "SunshineCloseup", "pos": Vector3(-2.2, 1.45, -3.4), "look": Vector3(0.0, 2.5, -1.4), "fov": 42.0},
		{"name": "PastryCase", "pos": Vector3(-0.4, 1.45, 2.4), "look": Vector3(0.1, 1.25, 4.35), "fov": 55.0},
		{"name": "Exterior", "pos": Vector3(0.4, 5.4, -12.2), "look": Vector3(0.0, 1.8, 0.4), "fov": 62.0},
	]
	for shot in shots:
		var cam_name := str(shot["name"])
		var cam := get_node_or_null(cam_name) as Camera3D
		if cam == null:
			cam = Camera3D.new()
			cam.name = cam_name
			add_child(cam)
		cam.current = false
		cam.fov = float(shot["fov"])
		cam.position = shot["pos"]
		cam.look_at(shot["look"], Vector3.UP)


func camera_named(shot: String) -> Camera3D:
	return get_node_or_null(shot) as Camera3D


func all_cameras() -> Array[Camera3D]:
	var out: Array[Camera3D] = []
	for shot_name in SHOT_NAMES:
		var cam := camera_named(shot_name)
		if cam:
			out.append(cam)
	return out
